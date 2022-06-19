#!/bin/bash

for _command in openssl curl; do
    if ! command -v $_command &> /dev/null; then
        echo "Aliyun OpenAPI SDK: $_command command not found"
        exit 127
    fi
done
unset _command

declare AliAccessKeyId AliAccessKeySecret
_AliAccessKeyId=$AliAccessKeyId
_AliAccessKeySecret=$AliAccessKeySecret

# aliapi_rpc <host> <http_method> <api_version> <api_action> [api_custom_key] [api_custom_value]
aliapi_rpc() {
    _AliAccessKeyId=$AliAccessKeyId
    _AliAccessKeySecret=$AliAccessKeySecret
    if [[ -z $_AliAccessKeyId ]]; then
        echo "Aliyun OpenAPI SDK: 'AliAccessKeyId' environment variable not found or null"
        return 61
    fi
    if [[ -z $_AliAccessKeySecret ]]; then
        echo "Aliyun OpenAPI SDK: 'AliAccessKeySecret' environment variable not found or null"
        return 62
    fi

    if ! [[ $# -eq 4 || $# -eq 6 ]];then
        echo "Aliyun OpenAPI SDK: aliapi_rpc() not enough parameters"
        return 66
    fi
    local _http_host=$1 _http_method=$2 _api_action=$4 _api_version=$3
    # 兼容 BusyBox
    # shellcheck disable=SC2018,SC2019
    _http_method=$(tr "a-z" "A-Z" <<< "$_http_method")
    # 公共查询参数键
    local _api_common_key=(
        "AccessKeyId"
        "Action"
        "Format"
        "SignatureMethod"
        "SignatureVersion"
        "SignatureNonce"
        "Timestamp"
        "Version"
    )
    # 公共查询参数值
    local _ali_common_value=(
        "$_AliAccessKeyId"
        "$_api_action"
        "JSON"
        "HMAC-SHA1"
        "1.0"
        "$(_ali_signature_nonce)"
        "$(_ali_timestamp_rpc)"
        "$_api_version"
    )
    declare -a _ali_custom_key _ali_custom_value _ali_key _ali_value
    # 自定义查询参数键值
    read -r -a _ali_custom_key <<< "$5"
    read -r -a _ali_custom_value <<< "$6"
    # 合并查询键值
    read -r -a _ali_key <<< "${_api_common_key[*]} ${_ali_custom_key[*]}"
    read -r -a _ali_value <<< "${_ali_common_value[*]} ${_ali_custom_value[*]}"
    local _query_str=""
    local _key _value
    local i
    for (( i = 0; i < ${#_ali_key[@]}; ++i )); do
        _key=${_ali_key[$i]}
        _value=${_ali_value[$i]}
        # 参数值如果是以 () 结束，代表需要执行函数获取值，如果函数不存在，使用原始值。
        [[ ($(grep -E "^.+\(\)$" <<< "$_value")  == "$_value" && $(type -t "${_value:0:-2}") == "function") ]] && _value=$(${_value:0:-2})
        _value=$(_urlencode "$_value")
        _query_str+="$_key=$_value&"
    done
    local _ali_signature_value
    _ali_signature_value=$(_ali_signature_rpc "$_http_method" "$_query_str")
    _query_str+="Signature=$(_urlencode "$_ali_signature_value")"
    local _curl_out _http_code _http_url="https://$_http_host/?$_query_str"
    _curl_out=$(mktemp)
    _http_code=$(curl --location --silent --show-error --request "$_http_method" --output "$_curl_out" --write-out "%{http_code}" --connect-timeout 3 "$_http_url") && cat "$_curl_out" - <<< ""
    rm -f "$_curl_out"
    [[ $_http_code -eq 200 ]] && return 0 || return 1
}

_ali_signature_rpc() {
    local _http_method=$1 _str _query_str _sign_str
    _str=$(echo -n "$2" | tr "&" "\n" | sort)
    _query_str=$(echo -n "$_str" | tr "\n" "&")
    _sign_str="$_http_method&$(_urlencode "/")&$(_urlencode "$_query_str")"
    echo -n "$_sign_str" | openssl sha1 -hmac "$_AliAccessKeySecret&" -binary | openssl base64 -e
}

_aliapi_timestamp_rpc() {
    # ISO8601 UTC
    date -u -Iseconds
}

_ali_signature_nonce() {
    date "+%s%N"
}

_urlencode() {
    local result
    result=$(curl --get --silent --output /dev/null --write-out "%{url_effective}" --data-urlencode "=$1" "")
    echo "${result#*\?}"
}

[[ $# -ne 0 ]] && aliapi_rpc "$@"
