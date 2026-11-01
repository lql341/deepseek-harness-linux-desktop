[English](SCNET-PLATFORM-DEVELOPMENT-PLAN.md) | 中文

# SCNet 集成与平台开发计划

状态：`in progress`。更新于 2026-11-01。范围：先 Linux x64 Desktop，再移动端和更多发行版。本当前状态计划替代旧快照，历史提交和 run 保留在 Git 历史及[交接文档](SCNET-DEVELOPMENT-HANDOFF.zh-CN.md)。

## 进度

| 里程碑 | 已完成 | 剩余 |
| --- | --- | --- |
| M0 | 未发布的服务端 handoff 手册已独立于 OAuth2 审阅 | 正式 OAuth2/API/安全合同、issuer/endpoint/scope/回调、client 注册和沙盒凭证 |
| M1 | 固定 `dsh-scnet@0.6.13`、离线 Bundle/Skill、默认激活、保留禁用/自定义 profile、本地诊断和包审计 | 在候选字节验证 SCNet 配置修复，并记录当前 canonical 同步证据 |
| M2 | 离线 PKCE、回调校验/一次性消费、结构化错误、凭据适配和 loopback listener | 在正式沙盒完成真实登录、刷新、撤销、账户关联和只读 OpenAPI |
| M3 | 本地就绪、Secret Service 接口、离线 `dsh://auth/scnet` 解析和单实例转发 | login/refresh/logout/link/unlink UI/IPC，锁定/缺失 keyring 和凭据清理验收 |
| M4–M6 | Android/HarmonyOS 协议优先骨架及离线合规 | 原生应用、更多 CPU/发行版矩阵、安全响应和稳定版证据 |

M0 阻塞时不能标记真实 SCNet 认证完成；预装 Bundle 不授予账户权限。OpenAPI 认证与 SSH 密钥/集群配置是独立状态。

## A. 范围与治理

**入口：**明确维护者和外部服务负责人。**交付：**版本化服务/能力/安全合同。**出口：**SCNet 书面合同、安全评审，以及后续阶段所需 client ID、redirect URI 和 scope 注册。

SCNet 需提供 issuer、authorization/token/revoke endpoint、JWKS 或 introspection、PKCE、scope 语义、token 生命周期、账户关联、区域/调度器、错误、限流和服务/隐私条款。DeepSeek 需明确允许读取的账户标识、第三方关联、client/回调政策和受保护凭据字段。

认证变更需要 ADR 和兼容矩阵；凭据变更需要迁移、撤销、回滚说明。文档、测试、包和安装说明保持同版本。公开客户端不托管私有 SCNet 后端，不绕过配额，也不暗示所有平台都拥有 SSH/计算节点权限。

## B. 固定桌面 Bundle

**入口：**固定包、依赖清单和合法分发权。**交付：**离线生产 package-set 和 profile 协调。**出口：**无网络启动并加载 Bundle/Skill，未认证状态可操作，产物不含凭据。

Desktop 初始化固定 Bundle，跨升级保留显式禁用/自定义 profile；加载失败必须可见并阻止验收，企业部署可禁用。记录版本、完整性和许可证；首次启动不下载 npm 包。Web 保持 `dsh plugin --profile web add dsh-scnet` 显式安装。

验证 PATH、Python、Bash、SSH/SCP、代理和证书链，尊重配置 Python 路径，不假定系统 `python3`。配置向导在 Electron 外执行时必须使用物理解包文件，包测试须通过外部 Python 执行且不进行网络登录。

## C. OAuth2 与连接器

**入口：**M0 合同和沙盒凭证。**交付：**版本化连接器和平台安全存储适配。**出口：**沙盒登录/刷新/撤销/关联，以及重放、并发、scope 和脱敏测试。

使用 Authorization Code + PKCE S256、state、verifier 和 nonce、系统浏览器，并验证 issuer/redirect/code。禁止 implicit flow 和公开客户端 secret。账户关联必须通过 SCNet 正式 API 由用户明确同意，不把 DeepSeek API key/session cookie 作为 SCNet 凭据。没有关联接口时，只提供分别登录或受控后端流程。

桌面分别使用 Linux Secret Service、macOS Keychain、Windows Credential Manager；Android 使用 Keystore 加密存储，iOS 使用 Keychain，HarmonyOS 使用系统安全存储或受控后端会话。access token 保持短期、仅存内存；refresh token 不进入 Skill、模型上下文、shell 环境或普通日志/配置。支持过期、并发刷新去重、撤销、解绑和完整清理。

版本化操作包括 `login`、`status`、`refresh`、`logout`、`listRegions`、`listSchedulers`、`listQueues`、`submitJob`、`getJob`、`cancelJob`、`listFiles`、`transferFile`，各自声明 scope、远端变更、dry-run 和平台要求。测试错误 issuer/redirect、重复 state、过期/撤销 token、刷新竞态和越权 scope。

## D. Linux Desktop

**入口：**固定 Bundle 和已验收连接器。**交付：**设置/IPC 集成和 Debian 包。**出口：**Ubuntu 24.04/Debian 13 安装/升级/卸载、无凭据启动、Bundle 加载、真实登录/刷新/退出、keyring 和回调测试。

升级保留用户 profile、凭据和自定义集群。将 `dsh://auth/scnet` 或 loopback `127.0.0.1` 回调绑定当前用户的一次性会话，拒绝跨 profile 写 token。当前离线回调解析不交换 token。

展示 OpenAPI、SSH、Slurm、文件和 Notebook 的依赖：网络、Python/Bash、密钥、集群 profile 和用户授权。先交付 deb；AppImage/RPM 须单独验证 glibc、X11/Wayland、Secret Service、CPU 和协议注册。token 不写入普通 `~/.dsh` JSON/YAML 或 session log。

## E. Android

**入口：**稳定 OAuth2/连接器和 Android 工具链。**交付：**原生 HTTPS OpenAPI 连接器。**出口：**受支持系统/ARM64 构建，以及弱网、进程回收、重放、刷新竞态、时钟偏差、账户切换和卸载清理测试。

使用 Custom Tabs/AppAuth 兼容 PKCE、应用链接和 Keystore 加密存储。首版覆盖 OAuth2 及 HTTPS 区域/队列/作业/文件，不包含本地 Bash、SSH、任意 Python 或计算节点探针。使用远程 DSH Host 时明确数据驻留、会话绑定、重连和确认；高风险操作须用户明确确认。

## F. iOS、HarmonyOS 与更多 Linux

**入口：**共享连接器和受支持工具链。**交付：**平台适配器及 `supported`、`unsupported`、`requires-remote-host` 三态矩阵。**出口：**平台安装/升级/卸载、登录/撤销、最小 API、清理、恢复和回滚证据。

iOS 使用 ASWebAuthenticationSession/系统浏览器和 Keychain，处理 App Store 隐私、加密出口和后台规则；任意 shell 和常驻后台进程不支持或交给远程 Host。HarmonyOS 使用系统认证、ArkUI/网络和安全存储，增加本地连接器前先验证 TLS、链接、回调和账户切换；不复制 Node/Python/Bash 桌面运行时。

从 Debian/Ubuntu deb 扩展到 RPM/国产发行版及 x86_64/ARM64/LoongArch 前，实际测量 glibc、sandbox、X11/Wayland、Secret Service、Python、SSH 和安装器兼容性。不支持能力写进发布说明，并不展示相应 UI 入口。

## G. 验证、安全与发布

**入口：**跨仓负责人和兼容矩阵。**交付：**自动检查、回滚产物和运维文档。**出口：**每项宣传平台/能力的 M6 稳定发布证据。

canonical `scnet-hpc` 负责共享行为，先同步到 `dsh-scnet` 和 `codex-scnet-hpc`，再更新 Desktop/移动消费者，记录源码提交、包版本和最低兼容版本。本仓库维护桌面补丁，共享 Harness API 归上游负责。

测试 Bundle 内容/Cordis/peer 依赖/Skill 版本，OAuth2 state/PKCE/scope，连接器读写/dry-run/超时/重试/幂等，桌面 profile/深链/keyring/包升级，移动回调/存储/生命周期/网络/账户切换。凭据和私有 endpoint 不进入 release、session 或日志；最小化遥测并排除账户 ID、集群主机、作业号和私有路径。

按 `alpha -> beta -> stable` 推进：离线桌面与 OAuth2 沙盒，Linux 公开测试，移动/发行版扩展。保留回滚包、数据/凭据迁移说明、许可证清单、威胁模型和漏洞响应；只有完成证据充分才能标为 `done`。

## 交付顺序

1. M0 阻塞期间继续离线桌面修复和双语文档。
2. 冻结正式服务合同与沙盒，不使用未发布示例 endpoint。
3. 完成 M2 真实连接器，再完成 M3 Linux 登录和安全存储。
4. 完成 M4 Android、M5 更多平台和 M6 运维/稳定门禁。

当前源码与发布区别见[桌面跟进](../DESKTOP-FOLLOWUP.zh-CN.md)，构建/验收步骤见 [Linux 指南](../../LINUX-DESKTOP.zh-CN.md)。
