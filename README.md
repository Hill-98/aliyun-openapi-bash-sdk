# Aliyun OpenAPI Shell SDK

## 介绍

这是一个非官方的阿里云 OpenAPI Shell SDK，为了方便 Shell 脚本调用阿里云 OpenAPI，SDK 主要实现了自动计算请求签名。

虽然阿里云官方有 [AliyunCLI](https://github.com/aliyun/aliyun-cli)，可以在 Shell 环境下使用阿里云 OpenAPI。不过某些 API (比如 SSL 证书) 它并不支持，或者说还没来得及支持，所以我就想写一个可能是最好用的阿里云 Shell SDK。

理论上支持所有阿里云 RPC OpenAPI，RESTful OpenAPI 暂不支持，将来可能会支持。

## 依赖

* curl
* OpenSSL
* Python3

Python3 用于 `urlencode`，因为纯 Shell 实现的 `urlencode` 可用性较低，索性就直接使用 Python，不兼容 Python2。

## 使用

1. 导出`AliAccessKeyId` 和 `AliAccessKeySecret` 环境变量
2. 导入 `AliyunOpenAPI.sh`
3. 调用 `aliapi_rpc` 函数

函数签名：`aliapi_rpc(host, http_method, api_version, api_action, api_custom_key[], api_custom_value[]): JsonResult | ErrorCode`

**示例：**

```bash
#!/usr/bin/env bash
# 导出环境变量
export AliAccessKeyId="<AliAccessKeyId>" # 此处替换为你的阿里云 AliAccessKeyId
export AliAccessKeySecret="<AliAccessKeySecret>" # 此处替换为你的阿里云 AliAccessKeySecret
# 导入 SDK
. AliyunOpenAPI.sh

# 自定义请求参数的键值数组顺序要一一对应，数组成员不能包含空格。
# 自定义值支持自定义函数，如果你需要包含空格或者读取文件等操作，可以声明一个自定义函数，像下面这样。
# 如果自定义值数组成员以 () 结尾，SDK 在处理值的时候会自动执行自定义函数，但是如果自定义函数不存在则会导致获取值失败。

get_show_size() {
    echo 50
}

# 自定义请求参数的键
ali_custom_key=(
    "CurrentPage"
    "ShowSize"
)
# 自定义请求参数的值
ali_custom_value=(
    "1"
    "get_show_size()" # 这个值会在解析的时候执行函数获取
)
# 获取 SSL 证书列表：https://help.aliyun.com/document_detail/126511.html
aliapi_rpc "cas.aliyuncs.com" "GET" "2018-07-13" "DescribeUserCertificateList" "${ali_custom_key[*]}" "${ali_custom_value[*]}"
# 可以通过 $? 是否等于 0 判断是否执行成功（HTTP CODE == 200）
# 执行成功返回 JSON 格式的结果，执行失败返回 HTTP CODE 或 curl 的退出代码。
if [[ $? -eq 0 ]]; then
    # 执行成功
else
    # 执行失败
fi

```

更多示例请参考 `example` 下的文件

如果你有好的示例，欢迎提交 [PR](https://github.com/Hill-98/aliyun-openapi-shell-sdk/pulls)

如果你有问题 / BUG 要反馈，也欢迎提交 [Issue](https://github.com/Hill-98/aliyun-openapi-shell-sdk/issues)
