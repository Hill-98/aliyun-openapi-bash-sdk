#!/usr/bin/env bats
# shellcheck shell=bash disable=SC2154

setup() {
    # shellcheck disable=SC1091
    [[ -f .env.test ]] && source .env.test
    source AliyunOpenApiSDK.sh
}

skip_no_aliaccess() {
    if [[ ! -v AliAccessKeyId || ! -v AliAccessKeySecret ]]; then
        skip "'AliAccessKeyId' or 'AliAccessKeySecret' environment variable not found"
    fi
}

test_signature_nonce() { #@test
    run _aliapi_signature_nonce
    nonceA=$output
    [[ $status -eq 0 ]]
    run _aliapi_signature_nonce
    nonceB=$output
    [[ $status -eq 0 ]]
    [[ $nonceA != "$nonceB" ]]
}

test_signature_rpc() { #@test
    run _aliapi_signature_rpc GET "key=value&foo=bar"
    [[ $status -eq 0 ]]
    [[ $output == "NcrN6odhMq2fD7LEpbT0A7K3TJg=" ]]
}

test_timestamp_rpc() { #@test
    run _aliapi_timestamp_rpc
    [[ $status -eq 0 ]]
    timestamp=$output
    run grep -E "^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])T(0[0-9]|[1][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](Z|\+00:00)$" <<< "$timestamp"
    [[ $status -eq 0 ]]
    [[ $output == "$timestamp" ]]
}

test_urlencode() { #@test
    run _aliapi_urlencode "/foo &bar#"
    [[ $status -eq 0 ]]
    [[ $output == "%2Ffoo%20%26bar%23" ]]

    run _aliapi_urlencode "中文测试"
    [[ $status -eq 0 ]]
    [[ $output == "%E4%B8%AD%E6%96%87%E6%B5%8B%E8%AF%95" ]]

    run _aliapi_urlencode "$(echo -e "new\nline\ntest")"
    [[ $status -eq 0 ]]
    [[ $output == "new%0Aline%0Atest" ]]
}

test_check_vars() { #@test
    skip_no_aliaccess

    _AliAccessKeyId=$AliAccessKeyId
    _AliAccessKeySecret=$AliAccessKeySecret
    unset AliAccessKeyId AliAccessKeySecret

    run _aliapi_check_vars
    [[ $status -eq 3 ]]
    [[ $output == "Aliyun OpenAPI SDK: 'AliAccessKeyId' or 'AliAccessKeySecret' environment variable not found" ]]

    AliAccessKeyId=$_AliAccessKeyId
    AliAccessKeySecret=$_AliAccessKeySecret

    run _aliapi_check_vars
    [[ $status -eq 0 ]]
}

getQueryType() {
    echo MetaTag
}

test_rpc_api() { #@test
    skip_no_aliaccess

    run aliapi_rpc GET api.test 0
    [[ $status -eq 2 ]]
    [[ $output == "aliapi_rpc: not enough parameters" ]]

    run aliapi_rpc GET api.test 0 api unknown
    [[ $status -eq 2 ]]
    [[ $output == "aliapi_rpc: 'unknown' is unknown parameter" ]]

    run aliapi_rpc GET api.test 0 api --unknown
    [[ $status -eq 2 ]]
    [[ $output == "aliapi_rpc: '--unknown' has no value" ]]

    run aliapi_rpc GET sts.aliyuncs.com 2015-04-01 GetCallerIdentity
    [[ $status -eq 0 ]]
    run grep "user/aliyun-openapi-shell-sdk-test" <<< "$output"
    [[ $status -eq 0 ]]

    run aliapi_rpc GET tag.aliyuncs.com 2018-08-28 ListTagKeys --RegionId cn-hangzhou --QueryType "getQueryType()"
    [[ $status -eq 0 ]]
    run grep '"Key":"openapi-shell-sdk-test"' <<< "$output"
    [[ $status -eq 0 ]]
}

test_cli() { #@test
    skip_no_aliaccess

    export AliAccessKeyId AliAccessKeySecret

    run ./AliyunOpenApiSDK.sh
    [[ $status -eq 2 ]]
    [[ $output == "AliyunOpenApiSDK.sh <--rpc> <http_method> <host> <api_version> <api_action> [<--key> <value>...]" ]]

    run ./AliyunOpenApiSDK.sh --cpr
    [[ $status -eq 2 ]]
    [[ $output == "Aliyun OpenAPI SDK: '--cpr' is unknown parameter" ]]

    run ./AliyunOpenApiSDK.sh --rpc GET sts.aliyuncs.com 2015-04-01 GetCallerIdentity
    [[ $status -eq 0 ]]
    run grep "user/aliyun-openapi-shell-sdk-test" <<< "$output"
    [[ $status -eq 0 ]]

    run ./AliyunOpenApiSDK.sh --rpc GET tag.aliyuncs.com 2018-08-28 ListTagKeys --RegionId cn-hangzhou --QueryType MetaTag
    [[ $status -eq 0 ]]
    run grep '"Key":"openapi-shell-sdk-test"' <<< "$output"
    [[ $status -eq 0 ]]
}
