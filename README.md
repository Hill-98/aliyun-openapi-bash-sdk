# Aliyun OpenAPI Bash SDK

这是一个非官方的阿里云 OpenAPI Bash SDK，方便 Bash 脚本调用阿里云 OpenAPI，SDK 主要实现了自动计算 OpenAPI 的请求签名。

理论上支持所有阿里云 RPC OpenAPI，暂不支持 RESTful OpenAPI，将来可能会支持。

> 这可能是最好用的 Aliyun OpenAPI Bash SDK

## 依赖

* coreutils (`cat`, `date`, `mktemp`, `rm`)
* curl
* openssl

## 使用

1. 声明变量 `AliAccessKeyId` 和 `AliAccessKeySecret`
2. 导入 `AliyunOpenApiSDK.sh`
3. 调用 `aliapi_rpc` 函数

函数签名：
```bash
# Output: JsonString
# Retrun Code: 0 = HTTP_STATUS_CODE == 200 | 1 = HTTP_STATUS_CODE != 200
aliapi_rpc <http_method> <host> <api_version> <api_action> [<--key> <value>...]
```

PS: `AliyunOpenApiSDK.sh` 可以作为脚本执行，脚本第一个参数为 `--rpc`，剩余参数为 `aliapi_rpc` 可接受参数。作为脚本运行时，`AliAccessKeyId` 和 `AliAccessKeySecret` 变量需要导出。

**示例：**

```bash
#!/usr/bin/env bash

# 设置 AliAccessKeyId 和 AliAccessKeySecret
AliAccessKeyId="<AliAccessKeyId>"
AliAccessKeySecret="<AliAccessKeySecret>"

# 导入 SDK
source AliyunOpenApiSDK.sh

# 如果值以 () 结尾，那么 SDK 会假设它是一个已定义函数，获取值时会判断函数是否存在并执行，如果不存在则使用原始值。

get_show_size() {
    echo 50
}

# 获取 SSL 证书列表：https://help.aliyun.com/document_detail/126511.html
# 解析参数时会执行函数 (所以 ShowSize 的值是 50)
aliapi_rpc GET cas.aliyuncs.com 2018-07-13 DescribeUserCertificateList --CurrentPage 1 --ShowSize "get_show_size()"
# $? == 0 代表 HTTP CODE == 200 反之 $? == 1
# 可以通过 ALIYUN_SDK_LAST_HTTP_CODE 变量获取最后一次的 HTTP CODE
# 只要 curl 的退出代码 == 0 就会返回接收到的数据
if [[ $? -eq 0 ]]; then
    # 执行成功
else
    # 执行失败
fi
```

更多示例请参考 [examples](https://github.com/Hill-98/aliyun-openapi-bash-sdk/tree/master/examples) 下的文件

如果你有好的示例，欢迎提交 [PR](https://github.com/Hill-98/aliyun-openapi-bash-sdk/pulls)。
