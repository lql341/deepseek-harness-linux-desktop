[English](TODO.md) | 中文

# 当前待办（Living TODO）

这是本仓库当前的待办清单。它记录跟踪范围、已发布状态和所有未完成项。发布、范围变化或条目关闭时更新它；历史留在 git 和证据页，不写在这里。

## 范围

跟踪目标是官方 `dsh-v0.2.1-rc.5` 桌面版本在 Linux x64 deb 上的功能对齐。上游开发线、macOS 平台固有集成、实验性 CUA provider 和其他软件包格式按决定不在范围内；[桌面平台能力对齐](DESKTOP-PARITY.zh-CN.md)记录了结论和被排除的行。

## 已发布状态

| 项目 | 值 |
| --- | --- |
| 发布版本 | `v0.2.1-rc.5-linux.2` |
| 补丁系列 | 0001 到 0011 |
| 构建提交 | `32a509c6e5db91d6210f4fe23d4f9290c0df310a` |
| 补丁树 | `0fef55a99edf4a7f857ab0365c98644bce9d7fff` |
| 发布运行 | 41311729795 |
| 验证运行 | 41309525902（19 组、486 项测试） |
| 验收运行 | 41317916316 |

对当前系列本地执行 `apply.sh` 加 `git write-tree` 仍得到上面的补丁树，且发布提交之后没有补丁变化，因此已发布包就是当前系列。只有补丁变化时才需要新发布。

## 未完成项

| 项目 | 状态 | 负责人 | 出口条件 |
| --- | --- | --- | --- |
| 真实桌面交互验收 | 未完成，可选 | 桌面负责人 | 用 `ci/real-desktop-acceptance.sh` 在 X11 和 Wayland 各跑一次，tarball 记录到功能跟进 |

跟踪范围内没有其他未完成项。会扩大范围的条目必须先有新的决定，才会成为工作。

## 范围外

| 领域 | 决定 |
| --- | --- |
| 文件拖拽与新文件动作 | 暂不纳入；[ADR-0003](roadmap/ADR-0003-file-drag-backport.zh-CN.md)保留为未来范围变更的提案 |
| CUA Linux provider | 不纳入 |
| Linux arm64、rpm、AppImage、Flatpak 和 apt 仓库 | 不纳入；只维护 x64 deb |
| macOS 固有集成（Dock、毛玻璃、公证、官方策略身份） | 按设计使用不同实现，不算缺失工作 |
| 上游开发线 | 不跟踪；当非 alpha 版本替换固定基线时再评估 |

## 维护

- 已发布状态表只按发布运行更新，不按源码绿灯更新。
- 新证据写进[桌面功能跟进](DESKTOP-FOLLOWUP.zh-CN.md)；本页保持简短。
- 两种语言同步修改，并运行 `node ci/check-docs.mjs`。
- 某条目转入范围时，先在这里写决定和出口条件，再开工。

## 参考资料

- [发布 v0.2.1-rc.5-linux.2](https://github.com/lql341/deepseek-harness-linux-desktop/releases/tag/v0.2.1-rc.5-linux.2)
- [桌面平台能力对齐](DESKTOP-PARITY.zh-CN.md)
- [桌面功能跟进](DESKTOP-FOLLOWUP.zh-CN.md)
- [固定的上游基线](../ci/upstream-base-tag)
