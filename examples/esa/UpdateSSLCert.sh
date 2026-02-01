#!/usr/bin/env bash

# 使用的 OpenAPI
# EAS: https://api.aliyun.com/product/ESA

# 可配合 acme.sh 使用的 renewHook 脚本：自动将新证书上传至阿里云 ESA，然后删除旧证书。
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
   [[ -v "$value" ]] || exit 1
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

# ESA 站点 ID（可使用 ListSites 获取）
SiteId=000000000000000

esa_result=$(aliapi_rpc GET esa.cn-hangzhou.aliyuncs.com 2024-09-10 ListCertificates --SiteId $SiteId) || exit 101
esa_cert_list=$(jq -c -r ".Result|map(.Id)|.[]" <<< "$esa_result" || echo "")

for _id in ${esa_cert_list}; do
    aliapi_rpc GET esa.cn-hangzhou.aliyuncs.com 2024-09-10 DeleteCertificate --SiteId $SiteId --Id "$_id" || exit 102
done
unset _id

aliapi_rpc POST esa.cn-hangzhou.aliyuncs.com 2024-09-10 SetCertificate --SiteId $SiteId --Name "$CERT_NAME" --Type upload --Certificate "get_cert()" --PrivateKey "get_key()" || exit 103
