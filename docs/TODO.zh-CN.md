[English](TODO.md) | 中文

# 当前待办（Living TODO）

这是本仓库当前的待办清单。它记录跟踪范围、已发布状态和所有未完成项。发布、范围变化或条目关闭时更新它；历史留在 git 和证据页，不写在这里。

## 范围

跟踪目标是官方 `dsh-v0.2.2-rc.1` 桌面版本在 Linux x64 deb 上的功能对齐。固定基线已从 `dsh-v0.2.1-rc.5` 迁移到该版本；旧系列仍然保持已发布状态，不再重建。上游开发线、macOS 平台固有集成、实验性 CUA provider 和其他软件包格式按决定不在范围内；[桌面平台能力对齐](DESKTOP-PARITY.zh-CN.md)记录了结论和被排除的行。

## 已发布状态

| 项目 | 值 |
| --- | --- |
| 发布版本 | `v0.2.2-rc.1-linux.1` |
| 上游基线 | `dsh-v0.2.2-rc.1` |
| 补丁系列 | 0001 到 0006 |
| 构建提交 | `1915bd4f9a97b0b74a75ea82e4fb8c0297a45518` |
| 补丁树 | `58d63c11500bdbeef6f3221756b0c307a65a5bf6` |
| 发布运行 | 42448101556 |
| Latest | 是；本仓库每次发布都会成为 latest，本次替换了 `v0.2.1-rc.2-linux.4` |
| 验证运行 | 直到 `Build deb` 之前的每一步都通过；门禁随后因 GitHub 对 Electron 归档返回 504 而停止。打包步骤现已改为重试，下一次运行会记录真实结果 |
| 验收运行 | 尚未通过 `ci/real-desktop-acceptance.sh` 记录；发布负责人已在真实 Linux 桌面安装该发布包并确认可运行 |

上表描述的是已发布的包。上一个发布 `v0.2.1-rc.5-linux.2` 及其十一个补丁的系列保留在 git 历史中。

## 当前系列

| 项目 | 值 |
| --- | --- |
| 固定基线 | `dsh-v0.2.2-rc.1` |
| 补丁系列 | 0001 到 0006 |
| 补丁树 | `d2d3f5c4c9a7e83a7cf5b2bbb230fdc982fc2786` |
| 下个发布 tag | 暂无；只有补丁变化时才需要新 tag |

活动系列把 Linux 移植重新应用到更新的基线上。只保留六个主题，是因为新基线已自带旧系列作为回移携带的插件操作历史、崩溃恢复菜单和更新视图，而最新基线把报告 Worker 打包进 asar，补丁 0006 让它在加载前重新解包。本地执行 `apply.sh` 加 `git write-tree` 可复现上面的补丁树；它与发布树只差发布运行之后新增的文档记录。

## 未完成项

| 项目 | 状态 | 负责人 | 出口条件 |
| --- | --- | --- | --- |
| 本版本的验证运行变绿 | 未完成 | 发布负责人 | 对应已发布系列的 `Linux desktop verification` 运行变绿，并用其 ID 替换上面的说明 |
| 记录的验收 tarball | 未完成，可选 | 桌面负责人 | 用 `ci/real-desktop-acceptance.sh` 在 X11 和 Wayland 各跑一次，tarball 记录到功能跟进 |
| 静默失效检查 | 未完成 | 桌面负责人 | 增加打包产物断言：`lib/operation-report-worker.js` 必须解包存在于 `app.asar` 旁，避免下一个基线重新引入发布审计已捕获的故障 |

跟踪范围内没有其他未完成项。会扩大范围的条目必须先有新的决定，才会成为工作。

## 范围外

| 领域 | 决定 |
| --- | --- |
| 文件拖拽与新文件动作 | 随 `dsh-v0.2.2-rc.1` 基线自带；[ADR-0003](roadmap/ADR-0003-file-drag-backport.zh-CN.md)记录该回移已不再需要 |
| CUA Linux provider | 不纳入 |
| Linux arm64、rpm、AppImage、Flatpak 和 apt 仓库 | 不纳入；只维护 x64 deb |
| macOS 固有集成（Dock、毛玻璃、公证、官方策略身份） | 按设计使用不同实现，不算缺失工作 |
| 上游开发线 | 不跟踪；当下一个非 alpha 版本替换固定基线时再评估 |

## 维护

- 已发布状态表只按发布运行更新，不按源码绿灯更新。
- 新证据写进[桌面功能跟进](DESKTOP-FOLLOWUP.zh-CN.md)；本页保持简短。
- 两种语言同步修改，并运行 `node ci/check-docs.mjs`。
- 某条目转入范围时，先在这里写决定和出口条件，再开工。

## 参考资料

- [发布 v0.2.2-rc.1-linux.1](https://github.com/lql341/deepseek-harness-linux-desktop/releases/tag/v0.2.2-rc.1-linux.1)
- [桌面平台能力对齐](DESKTOP-PARITY.zh-CN.md)
- [桌面功能跟进](DESKTOP-FOLLOWUP.zh-CN.md)
- [固定的上游基线](../ci/upstream-base-tag)
