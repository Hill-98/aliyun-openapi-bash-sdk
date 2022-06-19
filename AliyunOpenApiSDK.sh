#!/bin/bash

for _aliapi_command in openssl curl; do
    if ! command -v $_aliapi_command &> /dev/null; then
        echo "Aliyun OpenAPI SDK: $_aliapi_command command not found"
        exit 127
    fi
done
unset _aliapi_command

# aliapi_rpc <http_method> <host> <api_version> <api_action> [<--key> <value>...]
aliapi_rpc() {
    _aliapi_check_vars || return $?

    if [[ $# -lt 4 ]];then
        echo "aliapi_rpc: not enough parameters" >&2
        return 2
    fi

    local -r _AliAccessKeyId=$AliAccessKeyId _AliAccessKeySecret=$AliAccessKeySecret

    local -u _http_method=$1
    local _http_host=$2
    local _api_version=$3
    local _api_action=$4
    shift 4

    local -A _api_params
    _api_params=(
        ["AccessKeyId"]=$_AliAccessKeyId
        ["Action"]=$_api_action
        ["Format"]="JSON"
        ["SignatureMethod"]="HMAC-SHA1"
        ["SignatureVersion"]="1.0"
        ["SignatureNonce"]=$(_aliapi_signature_nonce)
        ["Timestamp"]=$(_aliapi_timestamp_rpc)
        ["Version"]=$_api_version
    )
    # 解析其余参数
    while [[ $# -ne 0 ]]
    do
        case $1 in
            --*)
                if [[ $# -le 1 ]]; then
                    echo "aliapi_rpc: '$1' has no value" >&2
                    return 2
                fi
                _api_params[${1:2}]="$2"
                shift 2
                ;;
            *)
                echo "aliapi_rpc: '$1' is unknown parameter" >&2
                return 2
                ;;
        esac
    done

    local _query_str=""
    local _key _value
    for _key in "${!_api_params[@]}"; do
        _value=${_api_params[$_key]}
        # 参数值如果是以 () 结束，代表需要执行函数获取值，如果函数不存在，使用原始值。
        [[ $_value =~ .+\(\)$ && $(type -t "${_value:0:-2}") == "function" ]] && _value=$(${_value:0:-2})
        _value=$(_aliapi_urlencode "$_value")
        _query_str+="$_key=$_value&"
    done

    local _signature
    _signature=$(_aliapi_signature_rpc "$_http_method" "${_query_str:0:-1}")
    _query_str+="Signature=$(_aliapi_urlencode "$_signature")"
    local _curl_out _http_code _http_url="https://$_http_host/?$_query_str"
    _curl_out=$(mktemp)
    _http_code=$(curl --location --silent --show-error --request "$_http_method" --output "$_curl_out" --write-out "%{http_code}" --connect-timeout 3 "$_http_url") && cat "$_curl_out" - <<< ""
    rm -f "$_curl_out"
    [[ $_http_code -eq 200 ]] && return 0 || return 1
}

_aliapi_check_vars() {
    if [[ ! -v AliAccessKeyId || ! -v AliAccessKeySecret ]]; then
        echo "Aliyun OpenAPI SDK: 'AliAccessKeyId' or 'AliAccessKeySecret' environment variable not found" >&2
        return 3
    fi
}

_aliapi_signature_rpc() {
    local -u _http_method=$1
    local _str=$2 _query_str _sign_str
    local _newline='
'
    _str=$(LC_ALL=C sort <<< "${_str//&/$_newline}")
    _query_str=${_str//$_newline/&}
    _sign_str="$_http_method&$(_aliapi_urlencode "/")&$(_aliapi_urlencode "$_query_str")"
    echo -n "$_sign_str" | openssl sha1 -hmac "$_AliAccessKeySecret&" -binary | openssl base64 -e
}

_aliapi_timestamp_rpc() {
    # ISO8601 UTC
    date -u -Iseconds
}

_aliapi_signature_nonce() {
    local nonce=""
    if [[ -f /proc/sys/kernel/random/uuid ]]; then
        nonce=$(</proc/sys/kernel/random/uuid)
    else
        nonce=$(date "+%s%N")
    fi
    echo "$RANDOM${nonce//-/}$RANDOM"
}

_aliapi_urlencode() {
    local result
    result=$(curl --get --silent --output /dev/null --write-out "%{url_effective}" --data-urlencode "=$1" "")
    result="${result//+/%20}" # 替换 + 为 %20
    echo "${result#*\?}"
}

if [[ ${#BASH_SOURCE[@]} -eq 1 ]]; then
    set -euf -o pipefail
    if [[ $# -eq 0 ]]; then
        echo "$(basename "$0") <--rpc> <http_method> <host> <api_version> <api_action> [<--key> <value>...]" >&2
        exit 2
    fi

    case $1 in
        --rpc)
            shift
            aliapi_rpc "$@"
            ;;
        *)
            echo "Aliyun OpenAPI SDK: '$1' is unknown parameter" >&2
            exit 2
            ;;
    esac
fi
