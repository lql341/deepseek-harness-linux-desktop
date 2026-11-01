English | [中文](README.zh-CN.md)

# Mobile skeleton

This is an offline, contract-first Android and HarmonyOS scaffold, separate from the Linux Desktop package. It contains a shared connector operation/capability manifest, [Android/Kotlin](android/README.md) and [HarmonyOS/ArkTS](harmony/README.md) state-machine interfaces, and conformance tests rejecting endpoint/credential material.

It has no real HTTP authentication, issuer/endpoints/redirect registration, client ID/secret, access/refresh tokens, AK/SK or private hosts. Desktop Node/Python/Bash/SSH/Notebook execution is not included.

The source is the published `dsh-scnet@0.6.13` connector contract. Changes begin at canonical `scnet-hpc`, flow through `dsh-scnet`, then reach mobile adapters.

## Offline check

```sh
node --test mobile-skeleton/tests/*.test.mjs
```

APK/HAP builds require the Android SDK/Gradle/Java and HarmonyOS DevEco toolchains in their platform repositories. Offline conformance is not evidence of a buildable or authenticated mobile application.
