#!/usr/bin/env bats
# shellcheck shell=bash disable=SC2154

bats_require_minimum_version "1.5.0"

load "test_helper/bats-assert/load.bash"
load "test_helper/bats-support/load.bash"

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
    nonceA=$(_aliapi_signature_nonce)
    nonceB=$(_aliapi_signature_nonce)
    assert_not_equal "$nonceA" "$nonceB"
}

test_signature_rpc() { #@test
    assert_equal "$(_aliapi_signature_rpc GET "key=value&foo=bar")" "NcrN6odhMq2fD7LEpbT0A7K3TJg="
}

test_timestamp_rpc() { #@test
    run -0 _aliapi_timestamp_rpc
    assert_output --regexp "^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])T(0[0-9]|[1][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](Z|\+00:00)$"
}

test_urlencode() { #@test
    assert_equal "$(_aliapi_urlencode "/foo &bar#")" "%2Ffoo%20%26bar%23"
    assert_equal "$(_aliapi_urlencode "中文测试")" "%E4%B8%AD%E6%96%87%E6%B5%8B%E8%AF%95"
    assert_equal "$(_aliapi_urlencode "$(echo -e "new\nline\ntest")")" "new%0Aline%0Atest"
}

test_check_vars() { #@test
    skip_no_aliaccess

    _AliAccessKeyId=$AliAccessKeyId
    _AliAccessKeySecret=$AliAccessKeySecret
    unset AliAccessKeyId AliAccessKeySecret

    run -3 _aliapi_check_vars
    assert_output "Aliyun OpenAPI SDK: 'AliAccessKeyId' or 'AliAccessKeySecret' environment variable not found"

    AliAccessKeyId=$_AliAccessKeyId
    AliAccessKeySecret=$_AliAccessKeySecret

    _aliapi_check_vars
}

getQueryType() {
    echo MetaTag
}

test_rpc_api() { #@test
    skip_no_aliaccess

    run -2 aliapi_rpc GET api.test 0
    assert_output "aliapi_rpc: not enough parameters"

    run -2 aliapi_rpc GET api.test 0 api unknown
    assert_output "aliapi_rpc: 'unknown' is unknown parameter"

    run -2 aliapi_rpc GET api.test 0 api --unknown
    assert_output "aliapi_rpc: '--unknown' has no value"

    run -0 aliapi_rpc GET sts.aliyuncs.com 2015-04-01 GetCallerIdentity
    assert_output --partial "user/aliyun-openapi-shell-sdk-test"

    run -0 aliapi_rpc GET tag.aliyuncs.com 2018-08-28 ListTagKeys --RegionId cn-hangzhou --QueryType "getQueryType()"
    assert_output --partial '"Key":"openapi-shell-sdk-test"'
}

test_cli() { #@test
    skip_no_aliaccess

    export AliAccessKeyId AliAccessKeySecret

    run -2 ./AliyunOpenApiSDK.sh
    assert_output "AliyunOpenApiSDK.sh <--rpc> <http_method> <host> <api_version> <api_action> [<--key> <value>...]"

    run -2 ./AliyunOpenApiSDK.sh --cpr
    assert_output "Aliyun OpenAPI SDK: '--cpr' is unknown parameter"

    run -0 ./AliyunOpenApiSDK.sh --rpc GET sts.aliyuncs.com 2015-04-01 GetCallerIdentity
    assert_output --partial "user/aliyun-openapi-shell-sdk-test"

    run -0 ./AliyunOpenApiSDK.sh --rpc GET tag.aliyuncs.com 2018-08-28 ListTagKeys --RegionId cn-hangzhou --QueryType MetaTag
    assert_output --partial '"Key":"openapi-shell-sdk-test"'
}

test_command_not_found() { #@test
    run -127 /bin/bash -c 'PATH="" ./AliyunOpenApiSDK.sh'
    assert_output --regexp "^Aliyun OpenAPI SDK: [A-Za-z0-9_-]+ command not found$"
}
