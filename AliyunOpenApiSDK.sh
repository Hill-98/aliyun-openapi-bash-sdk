#!/usr/bin/env bash
_exit() {
    echo "$2"
    exit "$1"
}

for c in openssl curl; do
    if ! command -v ${c} > /dev/null; then
        _exit 127 "Aliyun OpenAPI SDK: ${c} command not found"
    fi
done

_AliAccessKeyId=$(printenv AliAccessKeyId)
_AliAccessKeySecret=$(printenv AliAccessKeySecret)
_ali_format_rpc=JSON
_ali_signature_method=HMAC-SHA1
_ali_signature_version=1.0

# aliapi_rpc <host> <http_method> <api_version> <api_action> <api_custom_key[]> <api_custom_value[]>
aliapi_rpc() {
    [[ $# -lt 6 ]] && return 66
    # 公共查询参数键
    local _api_common_key=(
        "Format"
        "AccessKeyId"
        "SignatureMethod"
        "Timestamp"
        "SignatureVersion"
        "SignatureNonce"
        "Version"
        "Action"
    )
    # 公共查询参数值
    local _ali_common_value=(
        "$_ali_format_rpc"
        "$_AliAccessKeyId"
        "$_ali_signature_method"
        "$(_ali_timestamp_rpc)"
        "$_ali_signature_version"
        "$(_ali_signature_nonce)"
        "$3"
        "$4"
    )
    # 自定义查询参数键值
    local _ali_custom_key=() _ali_custom_value=()
    read -r -a _ali_custom_key <<< "$5"
    read -r -a _ali_custom_value <<< "$6"
    # 合并查询键值
    local _ali_key=() _ali_value=()
    read -r -a _ali_key <<< "${_api_common_key[*]} ${_ali_custom_key[*]}"
    read -r -a _ali_value <<< "${_ali_common_value[*]} ${_ali_custom_value[*]}"
    local _http_host=$1 _http_method=$2
    local _query_str=""
    local _key _value
    for (( i = 0; i < ${#_ali_key[@]}; ++i )); do
        _key=${_ali_key[$i]}
        _value=${_ali_value[$i]}
        # 参数值如果是以 () 结束，代表需要执行命令获取值。
        [[ $(grep -E "^.+\(\)$" <<< "$_value")  == "$_value" ]] && _value=$(${_value//()/})
        _value=$(_urlencode "$_value")
        _query_str+="$_key=$_value&"
    done
    local _ali_signature_value
    _ali_signature_value=$(_ali_signature_rpc "$_http_method" "$_query_str")
    _query_str+="Signature=$(_urlencode "$_ali_signature_value")"
    local _curl_out _result_code _http_url="https://${_http_host}/?${_query_str}"
    _curl_out=$(mktemp)
    _result_code=$(curl -L -s -X "$_http_method" -o "$_curl_out" --write-out "%{http_code}" "$_http_url" || echo $?)
    cat "$_curl_out" && echo
    rm -f "$_curl_out"
    [[ ${_result_code} -eq 200 ]] && return 0 || return 1
}

_ali_signature_rpc() {
    local _http_method=$1 _str _query_str _sign_str
    _str=$(echo -n "$2" | tr "&" "\n" | sort)
    _query_str=$(echo -n "$_str" | tr "\n" "&")
    _sign_str="${_http_method}&$(_urlencode "/")&$(_urlencode "$_query_str")"
    echo -n "$_sign_str" | openssl sha1 -hmac "${_AliAccessKeySecret}&" -binary | openssl base64 -e
}

_ali_timestamp_rpc() {
    # ISO8601 UTC
    date -u "+%FT%TZ"
}

_ali_signature_nonce() {
    date "+%s%N"
}

_urlencode() {
    local result
    result=$(curl -G -s -o /dev/null -w "%{url_effective}" --data-urlencode "=$1" file:///dev/null)
    echo "${result#*\?}"
}
