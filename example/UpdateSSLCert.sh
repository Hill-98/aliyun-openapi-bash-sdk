#!/usr/bin/env bash

# https://help.aliyun.com/document_detail/126507.html
# https://help.aliyun.com/document_detail/106661.html

# 可用于 acme.sh 的 renewHook 脚本，可以自动更新阿里云 SSL 证书并更新对应 CDN 域名，然后删除对应域名旧的证书。
# 每次 API 的执行都会检测是否失败，如果失败，会中断脚本执行并返回自定义错误代码

# acme.sh 导出的环境变量
ENV_NAME=(
    "CERT_PATH"
    "CERT_KEY_PATH"
    "CA_CERT_PATH"
    "CERT_FULLCHAIN_PATH"
    "Le_Domain"
)
# 检查环境变量是否存在
for value in "${ENV_NAME[@]}" ; do
   printenv "$value" > /dev/null || exit 1
done

# 获取证书自定义函数
get_cert() {
    sed -e "/^$/d" "$(printenv CERT_FULLCHAIN_PATH)" # 使用 sed 删除掉证书文件的空行
}
# 获取密钥自定义函数
get_key() {
    cat "$(printenv CERT_KEY_PATH)"
}

# 导出 AliAccessKeyId 和 AliAccessKeySecret
export AliAccessKeyId="<AliAccessKeyId>"
export AliAccessKeySecret="<AliAccessKeySecret>"

DOMAIN=$(printenv Le_Domain)
CERT_NAME="${DOMAIN}-$(date +%s)" # 证书名称
# 需要更新证书的 CDN 域名列表
DOMAIN_LIST=(
    "example.example.com"
)
# shellcheck disable=SC1091
. ../AliyunOpenAPI.sh

ali_custom_name=(
    "CurrentPage"
    "ShowSize"
)
# 获取第一页的 50 个结果，如果你的证书列表条目较多，可以考虑增加获取数量。
ali_custom_value=(
    "1"
    "50"
)
# 获取证书列表
result=$(aliapi_rpc "cas.aliyuncs.com" "GET" "2018-07-13" "DescribeUserCertificateList" "${ali_custom_name[*]}" "${ali_custom_value[*]}" || exit 101)
# 使用 jq 处理返回的 JSON 数据并提取出匹配当前证书域名的证书列表的 ID，用于稍后的删除旧证书操作。
cert_list=$(echo "$result" | jq -cr ".CertificateList|map(select(.common == \"${DOMAIN}\"))|map(.id)|.[]")
ali_custom_name=(
    "Cert"
    "Key"
    "Name"
)
# 使用自定义函数获取证书和密钥，保证内容可以被安全的传递过去
ali_custom_value=(
    "get_cert()"
    "get_key()"
    "$CERT_NAME"
)
# 上传新的证书
aliapi_rpc "cas.aliyuncs.com" "GET" "2018-07-13" "CreateUserCertificate" "${ali_custom_name[*]}" "${ali_custom_value[*]}" || exit 102
# 设置 CDN 域名列表使用新的证书
for domain in "${DOMAIN_LIST[@]}"; do
    ali_custom_name=(
        "DomainName"
        "ServerCertificateStatus"
        "CertName"
        "CertType"
    )
    ali_custom_value=(
        "$domain"
        "on"
        "$CERT_NAME"
        "cas"
    )
    aliapi_rpc "cdn.aliyuncs.com" "GET" "2018-05-10" "SetDomainServerCertificate" "${ali_custom_name[*]}" "${ali_custom_value[*]}" || _exit 103 "Set cdn domain cert fail: $domain"
done
# 删除旧的证书
for id in ${cert_list}; do
    ali_custom_name=(
        "CertId"
    )
    ali_custom_value=(
        "$id"
    )
    aliapi_rpc "cas.aliyuncs.com" "GET" "2018-07-13" "DeleteUserCertificate" "${ali_custom_name[*]}" "${ali_custom_value[*]}" || _exit 104 "Delete old cert fail: $id"
done
