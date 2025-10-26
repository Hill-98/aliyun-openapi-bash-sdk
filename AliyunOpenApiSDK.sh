#!/usr/bin/env bash

for _aliapi_command in openssl curl; do
    if ! command -v $_aliapi_command &> /dev/null; then
        echo "Aliyun OpenAPI SDK: $_aliapi_command command not found" >&2
        exit 127
    fi
done
unset _aliapi_command

if [[ -z $ALIYUN_SDK_RUN_ON_MUSL_LIBC ]] && command -v ldd &> /dev/null; then
    if [[ $(ldd "$SHELL") == *"ld-musl"* ]]; then
        ALIYUN_SDK_RUN_ON_MUSL_LIBC=1
    else
        ALIYUN_SDK_RUN_ON_MUSL_LIBC=0
    fi
fi

ALIYUN_SDK_LAST_HTTP_CODE=0

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

    local _query_str _signature_nonce _timestamp
    _signature_nonce=$(_aliapi_urlencode "$(_aliapi_signature_nonce)")
    _timestamp=$(_aliapi_urlencode "$(_aliapi_timestamp_rpc)")
    _query_str="AccessKeyId=$_AliAccessKeyId&Action=$_api_action&Format=JSON&SignatureMethod=HMAC-SHA1&SignatureVersion=1.0&SignatureNonce=$_signature_nonce&Timestamp=$_timestamp&Version=$_api_version&"
    # 解析其余参数
    local _key _value
    while [[ $# -ne 0 ]]
    do
        case $1 in
            --*)
                if [[ $# -le 1 ]]; then
                    echo "aliapi_rpc: '$1' has no value" >&2
                    return 2
                fi
                _key=${1:2}
                _value=$2
                [[ $_value =~ .+\(\)$ && $(type -t "${_value:0:-2}") == "function" ]] && _value=$(${_value:0:-2})
                _value=$(_aliapi_urlencode "$_value")
                _query_str+="$_key=$_value&"
                shift 2
                ;;
            *)
                echo "aliapi_rpc: '$1' is unknown parameter" >&2
                return 2
                ;;
        esac
    done

    local _signature
    _signature=$(_aliapi_signature_rpc "$_http_method" "${_query_str:0:-1}")
    _query_str+="Signature=$(_aliapi_urlencode "$_signature")"
    local _curl_out _http_url="https://$_http_host/?$_query_str"
    _curl_out=$(curl --location --silent --show-error --request "$_http_method" --write-out "%{http_code}" --connect-timeout 3 "$_http_url")
    printf %s "${_curl_out:0:-3}"
    ALIYUN_SDK_LAST_HTTP_CODE=${_curl_out:${#_curl_out}-3}
    [[ $ALIYUN_SDK_LAST_HTTP_CODE -eq 200 ]] && return 0 || return 1
}

_aliapi_check_vars() {
    if [[ -z ${AliAccessKeyId:-} || -z ${AliAccessKeySecret:-X} ]]; then
        echo "Aliyun OpenAPI SDK: 'AliAccessKeyId' or 'AliAccessKeySecret' environment variable not found" >&2
        return 3
    fi
}

_aliapi_signature_rpc() {
    if [[ ${LC_ALL:-X} != C ]]; then
        LC_ALL=C _aliapi_signature_rpc "$@"
        return $?
    fi

    local -u _http_method=$1
    local _str=$2 _query_str _sign_str
    local _newline="
"
    _str=$(sort <<< "${_str//"&"/"$_newline"}")
    _query_str=${_str//"$_newline"/"&"}
    _sign_str="$_http_method&$(_aliapi_urlencode "/")&$(_aliapi_urlencode "$_query_str")"
    printf "%s" "$_sign_str" | openssl dgst -sha1 -hmac "$_AliAccessKeySecret&" -binary | openssl base64 -e
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
        nonce=$(date +%s%N)
    fi
    echo "$RANDOM${nonce//-/}$RANDOM"
}

_aliapi_urlencode() {
    if [[ ${LC_ALL:-X} != C ]]; then
        LC_ALL=C _aliapi_urlencode "$@"
        return $?
    fi
    local char hex string=$1
    while [[ -n $string ]]; do
        char=${string:0:1}
        string=${string:1}
        case $char in
            [-._~0-9A-Za-z]) printf %c "$char";;
            *)
                if [[ ALIYUN_SDK_RUN_ON_MUSL_LIBC -eq 0 ]]; then
                    printf %%%02X "'$char"
                else
                    # Hack musl libc for not ASCII chars (incomplete test)
                    hex=$(printf %02X "'$char")
                    printf %%%s "${hex:${#hex}-2}"
                fi
            ;;
        esac
    done
    echo
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
