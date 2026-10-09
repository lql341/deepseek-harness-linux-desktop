# ADR-0001：插件与跨平台连接器分层

- 状态：`accepted`
- 日期：2026-10-09
- 负责人：SCNet 集成维护者
- 适用范围：`dsh-scnet`、Linux Desktop、Android、iOS、HarmonyOS、信创 Linux

## 决策

保留 `dsh-scnet` 作为 Node/Cordis 运行时中的桌面和服务端 Bundle，同时定义一个与客户端平台无关的 SCNet 连接器协议。Android、iOS、HarmonyOS 和受限 Linux 客户端使用原生连接器或受控本地服务，不要求直接执行现有插件中的 Python、Bash、SSH 和 `execFile` 逻辑。

OAuth2 使用授权码 + PKCE。DeepSeek 账户凭据不直接发送给 SCNet；客户端只在用户明确同意后，通过 SCNet 的 OAuth2 授权端点取得 SCNet access token，并在 SCNet 支持的账户关联接口上完成绑定。refresh token 只进入操作系统安全存储，短期 access token 只提供给需要调用 SCNet 的连接器服务。

## 背景

当前 `dsh-scnet` 的 `index.mjs` 依赖 Node 子进程，并调用 `python3`、Bash、SSH/SCP。Linux Desktop 已包含可扩展的 Desktop profile 和 `dsh` 运行时，但移动系统不具备同样的进程、文件系统和网络权限模型。若把现有插件原样复制到移动端，会造成权限、凭据和发布包不可控。

## 采用原因

1. 共享协议可以复用 OAuth2、账户状态、区域/调度器选择、错误码和 token 生命周期。
2. 桌面端仍可保留完整的 deterministic tools、Skill 和 SSH 能力。
3. 移动端可以只提供 SCNet OpenAPI 能力，明确不承诺本地 Bash、SSH 或计算节点探针。
4. 连接器可以替换认证实现，不迫使每个平台嵌入 Node 或 Python。
5. 授权边界清晰：模型不能读取 refresh token，插件不能代替用户批准高风险操作。

## 不采用的方案

- 不把 DeepSeek API Key、DeepSeek session cookie 或 OAuth access token 作为 SCNet 凭据提交。
- 不在 `cordis.patch.yml` 中硬编码用户账号、client secret、内部 URL 或默认集群。
- 不让 iOS、Android 或 HarmonyOS 直接执行桌面插件里的任意 shell 命令。
- 不把“预制插件”解释成自动拥有 SCNet 账户权限；预制只代表已安装和可加载。

## 后续影响

- 需要维护一个版本化的 SCNet OAuth2/API 能力描述，包括 issuer、authorization endpoint、token endpoint、scope、PKCE 要求、redirect URI 和账户关联接口。
- 需要为 Desktop、Android、iOS、HarmonyOS 分别实现安全存储、回调和网络策略。
- `dsh-scnet` 与连接器版本必须有兼容矩阵；协议不兼容时客户端应显示可操作错误，而不是静默降级。
