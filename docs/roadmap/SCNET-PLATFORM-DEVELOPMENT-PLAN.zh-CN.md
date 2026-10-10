# SCNet 集成与多平台客户端开发计划

- 文档状态：`in progress`
- 版本：`1.0.0`
- 日期：2026-10-09
- 适用仓库：`deepseek-harness-linux-desktop`、`dsh-scnet`、上游 `deepseek-harness`
- 目标发布线：Linux x64 Desktop 首发，随后扩展移动端与更多桌面发行版

## 0.1 结论摘要

整体计划可行，但需要将原始目标改造成“一个认证协议、一个跨平台连接器契约、多个平台适配器”。预制 `dsh-scnet` 和 Linux Desktop 集成属于当前代码体系内的近期开工项；OAuth2 账户关联可实现，但前提是 SCNet 提供稳定的授权端点、scope、PKCE、token 刷新和账户关联接口；Android、iOS、HarmonyOS 不应直接运行当前 Node/Cordis + Python/Bash/SSH 插件，而应复用 OAuth2 和 OpenAPI 连接器。

## 0.2 原始计划与可实现版本

| 原始目标 | 可行性 | 可实现版本 | 主要限制 |
|---|---|---|---|
| 1. 预制 `dsh-scnet` plugin | 可行 | 在 Desktop release 中预置固定版本、离线包和 active bundle；Web 保持显式安装 | 预制不等于已授权；首次使用仍需 SCNet 登录 |
| 2. DeepSeek 账户授权到 `scnet.cn` | 有条件可行 | OAuth2 授权码 + PKCE + SCNet 账户关联；不传 DeepSeek API Key | 依赖 SCNet OAuth2/API 合同和 client 注册 |
| 3. Linux Desktop 支持 SCNet 登录 | 可行 | Desktop deep link/localhost callback + Secret Service/Keyring + 连接器 | 需处理 Python、网络、代理、桌面会话和无头环境 |
| 4. Android | 可行 | 原生 OAuth2 + Android Keystore + HTTPS OpenAPI 连接器 | 不支持直接执行桌面 Bash/SSH/任意 Python |
| 5. 更多发行版、iOS、HarmonyOS、信创 Linux | 分层可行 | 共用协议和连接器，按平台实现认证、存储、网络和打包适配 | iOS/HarmonyOS 权限与商店审核、国产 CPU/图形栈需单独验证 |

## 0.3 全局完成定义

只有同时满足以下条件，才将某个平台标记为可发布：

1. OAuth2 授权、刷新、撤销和账户解绑均有自动化测试。
2. access token、refresh token 和 DeepSeek 凭据均不会进入日志、会话、模型上下文或普通配置文件。
3. 平台能力矩阵明确标注 OpenAPI、SSH、Bash、Notebook、文件传输和作业操作的支持范围。
4. 失败时能区分认证失败、权限不足、网络失败、区域选择错误和平台不支持。
5. 有可回滚的版本化发布包、兼容矩阵和迁移说明。

## A 1.0 基础、范围与治理

### A 1.1 目标与非目标

- 目标：让用户在受支持客户端中完成 SCNet OAuth2 登录，并安全调用与平台能力匹配的 SCNet 服务。
- 目标：让 Linux Desktop 默认带有可加载的 `dsh-scnet`，同时支持显式禁用和卸载。
- 目标：让移动端使用轻量连接器，不复制桌面进程执行模型。
- 非目标：不在客户端内托管 SCNet 私有后端，不绕过 SCNet 的授权和配额策略，不承诺所有平台拥有 SSH 或计算节点能力。

### A 1.2 外部依赖清单

SCNet 侧需要确认并冻结以下接口：issuer、authorization endpoint、token endpoint、JWKS 或 introspection、scope 定义、PKCE 支持、access/refresh token 生命周期、撤销接口、账户关联接口、区域和调度器 API、错误码、限流策略、服务条款和隐私政策。

DeepSeek 侧需要确认：桌面端和移动端允许的登录/账户标识读取方式、是否允许第三方服务进行账户关联、客户端标识和回调注册政策，以及不得暴露的 session/API 凭据边界。

### A 1.3 交付与变更规则

- 认证协议变更必须新增或更新 ADR，并增加兼容矩阵。
- 任何凭据字段变更必须有迁移、撤销和回滚说明。
- 文档、测试、发行包和安装说明必须同一版本发布。

### A 1.4 阶段门槛

A 阶段出口条件是：SCNet OAuth2/API 合同已书面确认，安全评审通过，且 B、C、D 所需的 client ID、redirect URI 和 scope 已登记。未满足时只能做离线原型，不能声称“登录已实现”。

## B 2.0 预制 dsh-scnet Bundle

### B 2.1 Desktop 预置策略

在 Desktop release 的 profile 初始化时预置固定版本的 `dsh-scnet`，并将它加入 active bundle。插件加载失败时必须阻止发布验证或显示明确的诊断；不能静默跳过。保留配置开关，使企业部署可以禁用该 bundle。

### B 2.2 依赖与离线包

将 `dsh-scnet` 及其合法依赖纳入 Desktop package set，记录包版本、完整性和许可证。首次启动不能依赖 npm 网络下载；更新通过发行包或受控插件更新流程完成。

### B 2.3 Web 与 Desktop 的差异

Web profile 继续通过 `dsh plugin --profile web add dsh-scnet` 显式安装，避免未经用户同意改变现有 Web 用户环境。Desktop profile 可以预置，但第一次使用 SCNet 工具前仍须完成 OAuth2 登录或显式配置。

### B 2.4 插件运行时适配

确认 Desktop Host 的 PATH、Python 入口、Bash、SSH/SCP、代理和证书链。若使用内置 Python，给 `dsh-scnet` 增加可配置的 Python 路径注入；不得假设所有发行版都存在名为 `python3` 的系统命令。

### B 2.5 验收门

在无网络安装环境中，Desktop 能启动、能列出 `dsh-scnet` active bundle、能加载 `scnet-hpc` Skill，并在未登录时返回“需要授权”的结构化错误。预制包不能带任何用户凭据。

## C 3.0 OAuth2 账户授权与 SCNet 连接器

### C 3.1 授权流程

实现 OAuth2 Authorization Code + PKCE（S256）：生成 state、code_verifier 和 nonce；通过系统浏览器打开 SCNet authorization endpoint；校验 state、issuer、redirect URI 和 code；使用 code_verifier 换取 token。禁止 implicit flow 和把 client secret 放入公开客户端。

### C 3.2 DeepSeek 账户关联

“DeepSeek 账户授权到 SCNet”实现为显式账户关联，而不是凭据转交：客户端取得经过授权的 DeepSeek 账户标识后，调用 SCNet 规定的 link/claim endpoint；用户在 SCNet 授权页面确认关联；服务端返回不可逆或最小化的关联结果。若 SCNet 没有该接口，产品只能提供“分别登录”或受控后端关联，不能客户端自行猜测或拼接账号。

### C 3.3 Token 生命周期

- Desktop：Linux Secret Service/Keyring，macOS Keychain，Windows Credential Manager。
- Android：Android Keystore 保护的加密存储。
- iOS：Keychain。
- HarmonyOS：系统安全存储能力；若能力不足，使用受控后端会话。
- access token 只在内存和短期连接器调用中存在；refresh token 不进入 Skill、模型上下文、shell 环境或普通日志。
- 支持过期刷新、用户主动撤销、账户解绑和全量清理。

### C 3.4 连接器接口

定义版本化的连接器接口：`login`、`status`、`refresh`、`logout`、`listRegions`、`listSchedulers`、`listQueues`、`submitJob`、`getJob`、`cancelJob`、`listFiles`、`transferFile`。每个操作声明所需 scope、是否变更远端状态、是否支持 dry-run 和平台限制。

### C 3.5 安全验收门

通过 PKCE、state 重放、错误 issuer、错误 redirect、过期 token、撤销 token、并发刷新、日志脱敏和越权 scope 测试。任何“把 DeepSeek API Key 发送到 `scnet.cn`”的实现都必须判定为不合格。

## D 4.0 Linux Desktop

### D 4.1 Profile 与默认激活

将 B 阶段的固定 `dsh-scnet` 包接入 Desktop profile 初始化和升级迁移；新安装默认 active，已有用户升级时保持用户手动禁用状态。升级脚本不能覆盖用户 profile、凭据和自定义集群配置。

### D 4.2 OAuth2 回调

优先使用 `dsh://auth/scnet` 深链和一次性 state；桌面会话不可用时使用 loopback `127.0.0.1` 回调。回调处理必须绑定当前用户会话，拒绝跨用户 profile 写入 token。

### D 4.3 平台能力

Linux Desktop 可以支持 SCNet OpenAPI、SSH、Slurm、文件和 Notebook 能力，但必须显示依赖：系统网络、Python/Bash、SSH 密钥、集群 profile 和用户授权。OpenAPI 登录与 SSH 密钥配置是两个独立状态，不能互相冒充。

### D 4.4 发行包

第一阶段继续发布 Debian `deb`；第二阶段增加 AppImage 或 RPM 时，复用同一 runtime descriptor 和 package set，分别验证 glibc、Wayland/X11、Secret Service、CPU 架构和桌面深链注册。

### D 4.5 验收门

Ubuntu 24.04、Debian 13 至少完成安装、升级、卸载、首次 OAuth2 登录、刷新、退出登录、默认 bundle 加载、无凭据启动和 `dsh://` 回调测试；不能把 SCNet token 写入 `~/.dsh` 普通 JSON/YAML 或 session log。

## E 5.0 Android 客户端

### E 5.1 产品边界

Android 首发只承诺 OAuth2、OpenAPI、区域/队列/作业/文件等可由 HTTPS API 完成的能力。SSH、Bash、远端环境探针和本地 Python 不纳入首版承诺。

### E 5.2 登录与存储

使用系统浏览器 Custom Tab 或 AppAuth 兼容实现完成 PKCE；回调使用应用链接；token 使用 Android Keystore 加密；支持账户切换、撤销、网络离线状态和代理错误展示。

### E 5.3 DSH 集成

Android 可以通过内置 connector tools 或受控远程 DSH Host 调用 SCNet。若采用远程 Host，必须明确数据驻留、会话绑定、断线恢复和用户确认，不把桌面插件代码直接打进 APK。

### E 5.4 验收门

覆盖 Android 支持版本、ARM64、弱网、进程被系统回收、重复回调、刷新竞态、设备时间错误和卸载后凭据清理。高风险操作默认需要用户二次确认。

## F 6.0 iOS、HarmonyOS 与更多 Linux

### F 6.1 共用协议和能力矩阵

所有平台共用 C 阶段的 OAuth2/connector contract；每个平台维护 `supported`、`unsupported`、`requires-remote-host` 三态能力矩阵。不得用“插件已安装”暗示某项能力可用。

### F 6.2 iOS

使用 ASWebAuthenticationSession/系统浏览器和 Keychain；只实现 HTTPS OpenAPI 和用户确认流程。SSH、任意 shell 和后台常驻进程列为不支持或转交远程 Host；发布前完成 App Store 隐私、加密出口和后台行为审核。

### F 6.3 HarmonyOS

使用系统 Web Authentication、ArkUI/原生网络栈和安全存储；先验证 OAuth2 回调、TLS、应用链接和账户切换，再决定是否提供本地连接器。Node/Python/Bash 能力默认不迁移。

### F 6.4 信创 Linux 与发行版矩阵

以 Debian/Ubuntu `deb` 为基线，随后验证 RPM 系、国产发行版、x86_64、ARM64、LoongArch 或其他目标架构。每个发行版记录 glibc、Electron sandbox、Wayland/X11、Secret Service、系统 Python、SSH 和安装器能力；不满足项必须在发布说明中列为限制。

### F 6.5 验收门

每个平台完成安装/升级/卸载、OAuth2 登录和撤销、最小 OpenAPI 调用、凭据清理、崩溃恢复和版本回滚。只有通过矩阵的能力才进入对应客户端菜单和文档。

## G 7.0 CI、安全、发布与长期维护

### G 7.1 多仓库交付

当前 Linux Desktop 补丁仓库负责 Desktop runtime 和发行包；`dsh-scnet` 仓库负责 Bundle、Skill 和 connector contract 适配；上游 Harness 负责通用 profile、工具和客户端 API。跨仓库变更用兼容矩阵记录提交、包版本和最低支持版本。

### G 7.2 自动化测试

- Bundle：包内容、Cordis patch、peer 依赖、Skill 文件和版本一致性。
- OAuth2：PKCE、state、刷新、撤销、scope 和错误码。
- Connector：只读、变更、dry-run、超时、重试和幂等语义。
- Desktop：预置 bundle、profile 迁移、深链、keyring、deb 安装和升级。
- 移动端：回调、Keystore/Keychain、生命周期、弱网和账户切换。

### G 7.3 安全与隐私

建立威胁模型、数据分类、日志脱敏规则、最小权限 scope、依赖许可证清单和漏洞响应流程。遥测默认关闭或最小化，并且不得包含 token、用户账号、集群主机、作业号或私有路径。

### G 7.4 发布策略

采用 `alpha -> beta -> stable` 三阶段：先桌面离线预置和 OAuth2 沙盒，再 Linux 公开测试，最后移动端和更多发行版。每阶段保留回滚包、数据库/凭据迁移说明和兼容矩阵。

### G 7.5 建议里程碑

| 里程碑 | 范围 | 出口条件 |
|---|---|---|
| M0 | A 阶段协议和安全冻结 | SCNet OAuth2/API 合同、client 注册、scope 和 redirect URI 已确认 |
| M1 | B 阶段预制 Bundle | Linux Desktop 离线包可加载，未登录状态可诊断 |
| M2 | C 阶段 OAuth2/connector | 沙盒登录、刷新、撤销、账户关联和安全测试通过 |
| M3 | D 阶段 Linux Desktop | Ubuntu/Debian 安装、深链、keyring、升级和真实 SCNet API 通过 |
| M4 | E 阶段 Android | Android 首版 OpenAPI connector 和 Keystore 通过 |
| M5 | F 阶段平台扩展 | iOS/HarmonyOS/目标 Linux 的能力矩阵和最小发布链路通过 |
| M6 | G 阶段稳定发布 | CI、漏洞响应、回滚、文档和版本兼容矩阵齐备 |

## 0.4 首批实现顺序

1. 冻结 SCNet OAuth2/API 合同与沙盒环境。
2. 在 `dsh-scnet` 增加 connector contract、OAuth2 状态机和安全存储抽象，但先不绑定具体 UI。
3. 在 Linux Desktop 预置固定版本 `dsh-scnet`，完成 profile 激活、Python/Keyring 和深链回调。
4. 完成真实 SCNet 沙盒登录、刷新、注销和一个只读资源查询。
5. 再开始 Android；移动端只复用协议和 OpenAPI connector，不复制桌面 shell 能力。

当前进度：第 2 项的离线协议骨架已完成，第 3 项已完成 Desktop 预置的第一步。
`dsh-scnet/connector` 提供版本化操作定义、平台能力状态、PKCE 授权请求、授权回调校验、
token exchange/refresh 请求构造和内存凭据存储抽象；Linux Desktop 补丁 `0018` 固定携带
`dsh-scnet@0.6.6`，首次启动默认激活、旧默认 profile 自动迁移，并保留显式禁用状态。
Python/Keyring、深链回调和真实 SCNet issuer、scope、redirect URI、账户关联 endpoint
仍待 M0 外部合同确认，因此当前实现不执行网络登录，也不代表 SCNet OAuth2 已完成。
