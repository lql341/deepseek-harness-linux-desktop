[English](README.md) | 中文

# 移动端骨架

这是 Android 和 HarmonyOS 的离线、协议优先骨架，独立于 Linux Desktop 包。包含共享连接器操作/能力清单、[Android/Kotlin](android/README.zh-CN.md) 和 [HarmonyOS/ArkTS](harmony/README.zh-CN.md) 状态机接口，以及拒绝 endpoint/凭据材料的合规测试。

不包含真实 HTTP 认证、issuer/endpoint/回调注册、client ID/secret、access/refresh token、AK/SK 或私有主机，也不包含桌面的 Node/Python/Bash/SSH/Notebook 执行能力。

源头是已发布的 `dsh-scnet@0.6.13` connector contract。变更从 canonical `scnet-hpc` 开始，经 `dsh-scnet` 再进入移动适配器。

## 离线检查

```sh
node --test mobile-skeleton/tests/*.test.mjs
```

APK/HAP 构建需要在对应平台仓库准备 Android SDK/Gradle/Java 和 HarmonyOS DevEco 工具链。离线合规通过不能证明移动应用已可构建或已接通认证。
