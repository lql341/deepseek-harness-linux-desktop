English | [中文](README.zh-CN.md)

# HarmonyOS scaffold

ArkTS sources under `entry/src/main/ets/contract` mirror the platform-neutral mobile state machine. They contain no endpoint, browser registration, HTTP transport, token value or DevEco-specific authentication implementation.

The future HarmonyOS application should implement platform adapters around the [shared connector interface](../README.md), without copying the Desktop Node/Python/Bash/SSH runtime.
