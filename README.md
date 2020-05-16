# Aliyun OpenAPI Shell SDK

这是一个非官方的阿里云 OpenAPI Shell SDK，方便 Shell 脚本调用阿里云 OpenAPI，SDK 主要实现了自动计算请求签名。

虽然阿里云官方有 [AliyunCLI](https://github.com/aliyun/aliyun-cli)，可以在 Shell 环境下使用阿里云 OpenAPI，不过某些 API (比如 SSL 证书) 它并不支持，或者说还没来得及支持，而且对于存储空间有限的嵌入式设备，Shell SDK 明显是更好的选择。

理论上支持所有阿里云 RPC OpenAPI，暂不支持 RESTful OpenAPI，将来可能会支持。

> 这可能是最好用的 Aliyun Shell SDK

## 依赖

* bash
* curl
* openssl

## 使用

1. 导出环境变量 `AliAccessKeyId` 和 `AliAccessKeySecret`
2. 导入 `AliyunOpenApiSDK.sh`
3. 调用 `aliapi_rpc` 函数

函数签名：
```
aliapi_rpc(host, http_method, api_version, api_action, api_custom_key[], api_custom_value[]): JsonResult
```

**示例：**

```bash
#!/usr/bin/env bash

# 导出 AliAccessKeyId 和 AliAccessKeySecret
export AliAccessKeyId="<AliAccessKeyId>"
export AliAccessKeySecret="<AliAccessKeySecret>"
# 导入 SDK
source AliyunOpenApiSDK.sh

# 自定义请求参数的键值数组顺序要一一对应，数组成员不能包含空格。
# 自定义值支持自定义函数，如果你需要包含空格或者读取文件等操作，可以声明一个自定义函数，像下面这样。
# 如果自定义值数组成员以 () 结尾，SDK 在获取值的时候会判断自定义函数是否存在并执行，如果不存在则使用原始值。

get_show_size() {
    echo 50
}

# 自定义请求参数的键
api_custom_key=(
    "CurrentPage"
    "ShowSize"
)
# 自定义请求参数的值
api_custom_value=(
    "1"
    "get_show_size()" # 解析参数时会执行函数 (所以最后提交的值是 50)
)
# 获取 SSL 证书列表：https://help.aliyun.com/document_detail/126511.html
aliapi_rpc "cas.aliyuncs.com" "GET" "2018-07-13" "DescribeUserCertificateList" "${api_custom_key[*]}" "${api_custom_value[*]}"
# $? == 0 代表 HTTP CODE == 200 反之 $? == 1
# 只要 curl 的返回代码 == 0 就会返回接收到的数据
if [[ $? -eq 0 ]]; then
    # 执行成功
else
    # 执行失败
fi
```

更多示例请参考 `example` 下的文件

如果你有好的示例，欢迎提交 [PR](https://github.com/Hill-98/aliyun-openapi-shell-sdk/pulls)

如果你有建议 / BUG 要反馈，也欢迎提交 [Issue](https://github.com/Hill-98/aliyun-openapi-shell-sdk/issues)
