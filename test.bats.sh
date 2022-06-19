#!/usr/bin/env bats
# shellcheck shell=bash disable=SC2154

setup() {
    [[ -f .env.test ]] && source .env.test
    source AliyunOpenApiSDK.sh
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

    run grep -P "^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])T(0\d|[1]\d|2[0-3]):[0-5]\d:[0-5]\d(Z|\+00:00)$" <<< "$timestamp"
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

test_api_rpc() { #@test
    if [[ ! -v AliAccessKeyId || ! -v AliAccessKeySecret ]]; then
        skip "'AliAccessKeyId' or 'AliAccessKeySecret' environment variable not found"
    fi

    _AliAccessKeyId=$AliAccessKeyId
    _AliAccessKeySecret=$AliAccessKeySecret
    unset AliAccessKeyId AliAccessKeySecret
    run aliapi_rpc
    [[ $status -eq 3 ]]
    [[ $output == "Aliyun OpenAPI SDK: 'AliAccessKeyId' or 'AliAccessKeySecret' environment variable not found" ]]
    AliAccessKeyId=$_AliAccessKeyId
    AliAccessKeySecret=$_AliAccessKeySecret

    run aliapi_rpc GET api.test 0
    [[ $status -eq 2 ]]
    [[ $output == "Aliyun OpenAPI SDK: aliapi_rpc() not enough parameters" ]]

    run aliapi_rpc GET api.test 0 api unknown
    [[ $status -eq 2 ]]
    [[ $output == "Aliyun OpenAPI SDK: aliapi_rpc() Unknown parameter: unknown" ]]

    run aliapi_rpc GET api.test 0 api --unknown
    [[ $status -eq 2 ]]
    [[ $output == "Aliyun OpenAPI SDK: aliapi_rpc() '--unknown' has no value" ]]

    run aliapi_rpc GET sts.aliyuncs.com 2015-04-01 GetCallerIdentity
    [[ $status -eq 0 ]]
    run grep "user/aliyun-openapi-shell-sdk-test" <<< "$output"
    [[ $status -eq 0 ]]

    getQueryType() {
        echo MetaTag
    }

    run aliapi_rpc GET tag.aliyuncs.com 2018-08-28 ListTagKeys --RegionId cn-hangzhou --QueryType "getQueryType()"
    [[ $status -eq 0 ]]
    run grep '"Key":"openapi-shell-sdk-test"' <<< "$output"
    [[ $status -eq 0 ]]
}
