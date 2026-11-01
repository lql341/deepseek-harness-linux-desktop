[English](README.md) | 中文

# HarmonyOS 骨架

`entry/src/main/ets/contract` 下的 ArkTS 源码对应平台无关移动状态机，不含 endpoint、浏览器注册、HTTP 传输、token 值或 DevEco 专用认证实现。

后续 HarmonyOS 应用应围绕[共享连接器接口](../README.zh-CN.md)实现平台适配器，不复制桌面 Node/Python/Bash/SSH 运行时。
