[English](README.md) | 中文

# SCNet 平台路线图

用于 Linux Desktop 周边 SCNet 认证、固定 `dsh-scnet` Bundle 和平台客户端的规划与交接。默认英文，每篇文档提供中文切换。

| 文档 | 用途与维护 |
| --- | --- |
| [开发计划](SCNET-PLATFORM-DEVELOPMENT-PLAN.zh-CN.md) | A–G 阶段、依赖、里程碑和出口条件；范围或发布要求改变时更新 |
| [开发交接](SCNET-DEVELOPMENT-HANDOFF.zh-CN.md) | 当前实现、发布证据、边界和优先 TODO；里程碑或跨仓交接时更新 |
| [交接提示词](SCNET-HANDOFF-PROMPT.zh-CN.md) | 可复制的起步指令；基线、流程或发布门禁变化时刷新 |
| [ADR-0001](ADR-0001-plugin-and-connector-architecture.zh-CN.md) | 桌面/服务端插件与移动/原生连接器分层；后续决策新增 ADR |
| [ADR-0002](ADR-0002-dsh-superagent-bundle.zh-CN.md) | dsh-superagent 原型的可选打包决策、兼容性证据和实施阶段 |

## 状态词汇

- `proposed`：尚未批准实施。
- `ready`：依赖和负责人已明确。
- `in progress`：正在实现或验证。
- `blocked`：具名外部依赖阻止进展。
- `done`：出口条件和发布证据完整。

每个阶段都需要入口条件、交付物和出口门禁。协议假设必须明确记为依赖。凭据、账户标识和私有 endpoint 不得进入仓库。OAuth2 scope、回调、存储或能力策略变化需要更新 ADR。计划描述意图，实际行为由源码和发布流水线负责；两种语言必须同步。

| 方向 | 真相来源 |
| --- | --- |
| Linux Desktop 补丁、打包和发布 | 本仓库 |
| Bundle/Skill 分发 | `dsh-scnet`，从 canonical `scnet-hpc` 同步 |
| 共享 Harness 运行时和客户端 API | `apply.sh` 选择的上游 checkout |
| OAuth2 和账户关联 | SCNet 授权服务及外部版本化正式合同 |
