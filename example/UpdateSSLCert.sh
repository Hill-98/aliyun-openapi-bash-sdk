#!/usr/bin/env bash

# CAS https://help.aliyun.com/document_detail/126507.html
# CDN https://help.aliyun.com/document_detail/106661.html

# 可配合 acme.sh 使用的 renewHook 脚本：自动将新证书上传至阿里云并更新对应 CDN 域名，然后删除对应域名的旧证书。
# 每次 API 执行都会检测是否失败，如果失败，会中断脚本执行并返回自定义错误代码。

# 导出 AliAccessKeyId 和 AliAccessKeySecret
export AliAccessKeyId="<AliAccessKeyId>"
export AliAccessKeySecret="<AliAccessKeySecret>"
# shellcheck disable=SC1091
. ../AliyunOpenApiSDK.sh

# acme.sh 执行 renewHook 时导出的环境变量列表
ACME_ENV_LIST=(
    "CERT_PATH"
    "CERT_KEY_PATH"
    "CA_CERT_PATH"
    "CERT_FULLCHAIN_PATH"
    "Le_Domain"
)
# 检查环境变量是否存在
for value in "${ACME_ENV_LIST[@]}" ; do
   printenv "$value" > /dev/null || exit 1
done

# 获取证书自定义函数
get_cert() {
    # 使用 sed 删除掉证书文件的空行
    sed -e "/^$/d" "$(printenv CERT_FULLCHAIN_PATH)"
}
# 获取密钥自定义函数
get_key() {
    cat "$(printenv CERT_KEY_PATH)"
}

DOMAIN=$(printenv Le_Domain)
# 证书名称
CERT_NAME="${DOMAIN}-$(date +%s)"
# 需要更新证书的 CDN 域名列表
DOMAIN_LIST=(
    "example.example.com"
)

api_custom_key=(
    "CurrentPage"
    "ShowSize"
)
api_custom_value=(
    "1"
    "50"
)
# 获取证书列表
result=$(aliapi_rpc "cas.aliyuncs.com" "GET" "2018-07-13" "DescribeUserCertificateList" "${api_custom_key[*]}" "${api_custom_value[*]}" || exit 101)
# 使用 jq 处理返回的 JSON 数据并提取出匹配当前证书域名的证书列表的 ID，用于稍后的删除旧证书操作。
cert_list=$(echo "$result" | jq -cr ".CertificateList|map(select(.common == \"${DOMAIN}\"))|map(.id)|.[]")

api_custom_key=(
    "Cert"
    "Key"
    "Name"
)
# 使用自定义函数获取证书和密钥，保证内容可以被完整的传递。
api_custom_value=(
    "get_cert()"
    "get_key()"
    "$CERT_NAME"
)
# 上传新的证书
aliapi_rpc "cas.aliyuncs.com" "GET" "2018-07-13" "CreateUserCertificate" "${api_custom_key[*]}" "${api_custom_value[*]}" || exit 102
# 设置 CDN 域名列表使用新的证书
for domain in "${DOMAIN_LIST[@]}"; do
    api_custom_key=(
        "DomainName"
        "ServerCertificateStatus"
        "CertName"
        "CertType"
    )
    api_custom_value=(
        "$domain"
        "on"
        "$CERT_NAME"
        "cas"
    )
    aliapi_rpc "cdn.aliyuncs.com" "GET" "2018-05-10" "SetDomainServerCertificate" "${api_custom_key[*]}" "${api_custom_value[*]}" || exit 103
done
# 删除旧的证书
for id in ${cert_list}; do
    api_custom_key=(
        "CertId"
    )
    api_custom_value=(
        "$id"
    )
    aliapi_rpc "cas.aliyuncs.com" "GET" "2018-07-13" "DeleteUserCertificate" "${api_custom_key[*]}" "${api_custom_value[*]}" || exit 104
done
