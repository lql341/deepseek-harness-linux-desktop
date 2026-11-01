[English](SCNET-HANDOFF-PROMPT.md) | 中文

# SCNet 项目交接提示词

先读[计划](SCNET-PLATFORM-DEVELOPMENT-PLAN.zh-CN.md)、[当前交接](SCNET-DEVELOPMENT-HANDOFF.zh-CN.md)、[桌面跟进](../DESKTOP-FOLLOWUP.zh-CN.md)和 [README](../../README.zh.md)，再复制下方提示词；实时仓库状态优先于记录快照。

## 起始只读检查

```sh
git rev-parse --show-toplevel
git status --short --branch
git branch -vv
git log -6 --oneline
git rev-parse HEAD origin/main
gh run list -R lql341/deepseek-harness-linux-desktop --limit 8
gh release list -R lql341/deepseek-harness-linux-desktop --limit 8
```

确认分支/工作区，并查询当前 CI/release。detached HEAD 只要匹配预期提交即可；不要覆盖无关改动或重写历史来强行一致。GitHub 不可用时继续本地只读调查，不虚构 CI 成功。

## 可复制提示词

```text
接手现有 SCNet Linux Desktop 项目，不从零重建。

使用当前工作区，不硬编码机器路径。阅读英文计划、交接、桌面跟进和 README，
中文版本须同步。以实际分支、远端 head、CI 和 release 校验记录是否仍然有效。

默认上游基线从 ci/upstream-base-tag 读取，本快照为 dsh-v0.2.1-rc.5。
在干净 checkout 中按顺序 git apply --3way 应用当前 patches/*.patch。
用 git write-tree 记录暂存区补丁树，HEAD 仍指向上游基线。
每个上游变更都必须用新补丁表达。

Desktop 固定携带 dsh-scnet@0.6.13，客户端与 Harness 整包更新。
更新和 Configure SCNet 入口保留在设置，保留显式禁用和自定义 profile。
补丁 0007 增加 DevTools、报告获取和更新视图；补丁 0008 修复外部 Python
的 ASAR 路径、终端可见性和 spawn 失败。查询修复对应的当前 CI，旧成功运行不够。
公开 v0.2.1-rc.5-linux.1 预发布早于这两个补丁。

正式 SCNet OAuth2/API 合同和沙盒凭证缺失时，继续有用的离线桌面工作。
不猜测 issuer、endpoint、scope、client 凭据或账户关联。
离线 PKCE/回调/keyring 接口和本地诊断不是真实登录。
未发布服务端 handoff 手册只是独立候选协议，不替代公开客户端 OAuth。

共享 SCNet 变更从 canonical scnet-hpc 开始，先同步 dsh-scnet 和
codex-scnet-hpc，再更新 Desktop，不只修改下游包。
凭据、私有 endpoint 和用户标识不得入库。

验证定向行为、干净完整补丁应用、全仓类型、host/desktop 构建、打包预检、
SCNet 产物审计、deb 安装和会话。新配置包必须验证物理解包文件和外部 Python 帮助。
真实终端点击/焦点及 X11/Wayland 需要自己的证据。
Debian/多发行版和长期上游门禁是有意设置的手动阶段，不阻塞日常开发。
所有失败必须归因。

通过可审查 PR 交付，相关检查通过才合并。
发布是单独手动 workflow，记录精确源码提交/树、checksum 和安装字节。
CI artifact 不等于公开 release。
汇报改动、实际验证和仍不支持的能力，再同步两种语言文档。
```

## 完成条件

可审查补丁线能应用到声明基线，相关检查覆盖精确改动并通过，源码/CI/release 证据分开，英中文档和链接一致，未引入秘密材料。交接时重新查询远端，不把历史 run 当成当前证据。
