#!/usr/bin/env bash

# 使用的 OpenAPI
# CAS: https://help.aliyun.com/document_detail/126507.html
# CDN：https://help.aliyun.com/document_detail/106661.html

# 可配合 acme.sh 使用的 renewHook 脚本：自动将新证书上传至阿里云并更新对应 CDN 域名，然后删除对应域名的旧证书。
# 每次 API 执行都会检测是否失败，如果失败，会中断脚本执行并返回自定义错误代码。

AliAccessKeyId="<AliAccessKeyId>"
AliAccessKeySecret="<AliAccessKeySecret>"
# shellcheck source=AliyunOpenApiSDK.sh
source ../AliyunOpenApiSDK.sh

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
   [[ ! -v "$value" ]] || exit 1
done
unset value

# 获取证书自定义函数
get_cert() {
    # 使用 sed 删除掉证书文件的空行
    sed -e "/^$/d" "$CERT_FULLCHAIN_PATH"
}
# 获取密钥自定义函数
get_key() {
    cat "$CERT_KEY_PATH"
}

# shellcheck disable=SC2154
DOMAIN=$Le_Domain
# 证书名称 (替换域名的 . 为 _，以符合阿里云证书名称规范)
CERT_NAME="${DOMAIN//./_}-$(date +%s)"
# 需要更新证书的 CDN 域名列表
DOMAIN_LIST=(
    "example.example.com"
)

# 获取证书列表
result=$(aliapi_rpc GET cas.aliyuncs.com  2018-07-13 DescribeUserCertificateList --CurrentPage 1 --ShowSize 50)  || exit 101
# 使用 jq 处理返回的 JSON 数据并提取出匹配当前证书域名的证书列表的 ID，用于稍后的删除旧证书操作。
cert_list=$(jq -cr ".CertificateList|map(select(.common == \"$DOMAIN\"))|map(.id)|.[]" <<< "$result")

# 上传新的证书
aliapi_rpc GET cas.aliyuncs.com 2018-07-13 CreateUserCertificate --Cert "get_cert()" --Key "get_key()" --Name "$CERT_NAME" || exit 102

# 设置 CDN 域名列表使用新的证书
for _domain in "${DOMAIN_LIST[@]}"; do
    aliapi_rpc GET cdn.aliyuncs.com 2018-05-10 SetDomainServerCertificate --DomainName "$_domain" --ServerCertificateStatus on --CertName "$CERT_NAME" --CertType cas || exit 103
done
unset _domain

# 删除旧的证书
for _id in ${cert_list}; do
    aliapi_rpc GET cas.aliyuncs.com 2018-07-13 DeleteUserCertificate --CertId "$_id" || exit 104
done
unset _id
