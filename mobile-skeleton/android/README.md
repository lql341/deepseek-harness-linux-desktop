English | [中文](README.zh-CN.md)

# Android scaffold

Kotlin sources under `app/src/main/kotlin` define the mobile connector interface and offline authentication state machine. They are independent of Android UI, AppAuth, HTTP clients and actual secure storage until the formal SCNet service contract is supplied.

This is a source scaffold, not an APK project. A future Android repository should reuse the [shared manifest and offline tests](../README.md), implementing platform adapters without copying Desktop shell, Python, Bash, SSH or Notebook execution.
