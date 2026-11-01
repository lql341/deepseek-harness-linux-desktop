[English](SCNET-DEVELOPMENT-HANDOFF.md) | 中文

# SCNet 开发交接

更新于 2026-11-01，状态：`in progress`。涉及 Linux Desktop 和 `dsh-scnet`，共享行为的 canonical 源头是 `scnet-hpc`。本当前交接替代互相矛盾的旧快照，完整历史发布/迁移记录仍在 Git 历史；阶段出口条件见[计划](SCNET-PLATFORM-DEVELOPMENT-PLAN.zh-CN.md)。

## 当前源码与发布

| 项目 | 已记录证据 |
| --- | --- |
| 上游基线 | `dsh-v0.2.1-rc.5`，由 `ci/upstream-base-tag` 读取 |
| Bundle | `dsh-scnet@0.6.13`，连接器词汇版本 `0.1.0` |
| 最近合并的桌面回移 | PR #5，main 提交 `7a96e872bd2807a3dae72a7485c91d5289a4081f` |
| PR 验证 | Run `41273560891`：八组/254 项测试、全仓类型、构建、deb 审计和安装后 Xvfb 会话通过 |
| main 验证 | Run `41274912984`：通过 |
| 已验证公开预发布 | `v0.2.1-rc.5-linux.1`，构建提交 `b860c05d4f771aa105290394e5d05fd2311e571f` |
| 发布验证 | Run `41269979995`：通过 |
| 已发 deb SHA-256 | `8ee9616ee40db44330c4b77dbae24173d0a48665a3478d075ff7c168422888c6` |

公开预发布不包含补丁 0007/0008。补丁 0008 修复配置 SCNet，需要新的候选包/CI 证据，旧运行不能验证它。把本快照当作最新状态前必须查询 GitHub，见[发布页](https://github.com/lql341/deepseek-harness-linux-desktop/releases/tag/v0.2.1-rc.5-linux.1)和 [Actions](https://github.com/lql341/deepseek-harness-linux-desktop/actions)。

## 已实现行为

- 固定离线 Bundle/Skill，审计版本、许可证、完整性和运行时 descriptor。Desktop 默认激活，升级协调保留显式禁用和自定义 profile；Web 保持显式安装。
- 本地 Bundle/Python/backend/凭据就绪诊断；隔离 renderer IPC 不暴露秘密值。设置页 Configure SCNet 调用本地配置向导。
- 连接器提供离线 Authorization Code + PKCE S256、state/nonce/issuer/redirect 校验、交换/刷新请求构造、token 生命周期及刷新去重、结构化错误、安全存储适配和一次性回调会话。
- 协议无关 loopback listener 有界运行、固定回调路径和通用浏览器响应。离线 `dsh://auth/scnet` 解析一次性消费已注册 state 并路由二次启动参数，不进行 token 交换。
- Linux Secret Service 以固定 application/profile 属性 lookup/store/clear，秘密值通过 stdin 传递；连接器存储接口无明文兜底。Python 注入优先 `DSH_SCNET_PYTHON`，再 `SCNET_PYTHON`；OpenAPI 与 SSH 就绪分开。
- 设置页更新整包交付 Desktop 和 Harness。补丁 0007 增加可见 DevTools、报告获取和主窗口附着更新视图；剩余平台差异见[桌面跟进](../DESKTOP-FOLLOWUP.zh-CN.md)。
- Android/HarmonyOS 只有源码接口和离线合规，不代表 APK/HAP 应用或真实认证。

## Configure SCNet 修复

旧启动器把 `app.asar/dsh/.../scnet.py` 交给外部 Python；Electron 可读虚拟路径，Python 不可读。补丁 0008 解包完整 SCNet Bundle，映射到物理 `app.asar.unpacked` 路径，要求可执行解释器/终端，等待终端 spawn 结果，并保留完成/错误输出。shell 参数保持路径和本地化文案原值，不进行源码插值。

源码测试覆盖打包/开发路径、仅归档文件拒绝、缺少前置、异步 spawn 失败和向导非零退出可见。包验收额外逐个对比物理 SCNet 文件与归档，并用外部 Python 执行打包向导帮助；这证明本地脚本可用，不证明认证成功或所有桌面终端行为。

## 供参考的历史证据

| 方向 | 历史 run |
| --- | --- |
| Ubuntu 基础安装/会话和 Debian 离线验收 | `38233490072`、`38233720311` |
| 候选升级与默认/禁用/自定义 profile | `38336572137`、`38660453246` |
| 修复 launcher 构建顺序后的 bwrap/Landlock 和 keyless smoke | `38343669703` |
| 完整预检、draft 构建和精确 draft 字节验证 | `38506728139`、`38516862762`、`38521128578` |
| 旧公开版预检/发布/独立验证 | `38709921855`、`38729878217`、`38731899365` |
| 干净 runner 的 host 构建顺序 | `39201850282` |

这些检查只适用于当时输入。归档主题补丁和旧 0.2.0 结果不描述当前补丁线。历史已记录 canonical `0.6.10` 同步，当前 `0.6.13` canonical 到消费者的发布证据仍需单独记录。当前产物审计从实际包读取文件数，不再固定旧的 55 文件说法。

## 外部依赖与安全边界

SCNet OAuth2/API 合同、获准 issuer/endpoint/scope/redirect/client 注册和沙盒凭证仍缺失。不猜测 endpoint，不把 DeepSeek API key/cookie 作为 SCNet 凭据；不声称真实登录/刷新/撤销/关联/OpenAPI 已完成。本地状态不能因文件存在就显示已认证。

2026-10-12 收到的未发布服务端接入手册版本为 `1.0.0`，描述服务端 HTTPS handoff：使用 appId/appSecret 和账户字段取得重定向链接。这是候选服务端协议，与公开客户端 PKCE 不同；需书面确认必填字段最小化、隐私、错误/版本语义、链接有效期/一次性/重放和允许目标。不把示例凭据、主机或用户资料复制入库，也不让公开客户端直接调用。

refresh/access token、DeepSeek 凭据、私有 endpoint 和账户标识不进入 release、模型上下文、session log 或普通配置。Linux OpenAPI 登录不等于 SSH/集群授权。

## 后续优先级

1. 完成 SCNet 配置修复的候选包和安装会话验证，包括物理 Python 导入和终端失败可见；真实 X11/Wayland 点击行为单独验收。
2. 保持英文/中文文档配对，区分源码、CI 候选包和公开 release；发布前查询精确提交/run/release/checksum，不忽略未归因失败。
3. 连同 provider、consumer 和生命周期测试继续完整功能回移；CUA、文件动作和插件历史依赖见桌面跟进。
4. 取得 M0 正式服务合同和沙盒，再实现 M2 真实连接器和 M3 Linux 登录、keyring/锁屏/无会话/清理测试。
5. 连接器门禁通过后扩展移动端/发行版，遵循 [ADR-0001](ADR-0001-plugin-and-connector-architecture.zh-CN.md)。

共享 SCNet 变更从 canonical `scnet-hpc` 开始，先同步 `dsh-scnet` 和 `codex-scnet-hpc`，再进入 Desktop；不能把桌面补丁或下游包当作 canonical 源头。上游变更必须存为新的 `patches/NNNN-*.patch`，在干净基线回放完整系列，相关检查通过后才合并。
