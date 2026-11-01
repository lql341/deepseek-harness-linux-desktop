[English](README.md) | 中文

# Android 骨架

`app/src/main/kotlin` 下的 Kotlin 源码定义移动连接器接口和离线认证状态机。在正式 SCNet 服务合同提供前，它独立于 Android UI、AppAuth、HTTP 客户端和真实安全存储。

这只是源码骨架，不是 APK 工程。后续 Android 仓库应复用[共享清单和离线测试](../README.zh-CN.md)，实现平台适配器，不复制桌面 shell、Python、Bash、SSH 或 Notebook 执行代码。
