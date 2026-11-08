English | [中文](TODO.zh-CN.md)

# Living TODO

This is the current to-do list for the repository. It records the tracked scope, the released state and every open item. Update it when a release lands, the scope changes or an item closes; history belongs in git and in the evidence pages, not here.

## Scope

The tracked goal is parity with the official `dsh-v0.2.2-rc.1` desktop release on a Linux x64 deb. The pinned base moved from `dsh-v0.2.1-rc.5` to that release; the previous series stays published and is not rebuilt. The upstream development line, platform-intrinsic macOS integrations, the experimental CUA provider and additional package formats are outside this scope by decision; [desktop platform parity](DESKTOP-PARITY.md) records the verdict and the excluded rows.

## Released state

| Item | Value |
| --- | --- |
| Release | `v0.2.2-rc.1-linux.1` |
| Upstream base | `dsh-v0.2.2-rc.1` |
| Patch series | 0001 to 0006 |
| Build commit | `1915bd4f9a97b0b74a75ea82e4fb8c0297a45518` |
| Patched tree | `58d63c11500bdbeef6f3221756b0c307a65a5bf6` |
| Release run | 42448101556 |
| Latest | Yes; every release in this repository becomes latest, and this one replaced `v0.2.1-rc.2-linux.4` |
| Verification run | Green on source but not on infrastructure: five attempts reach `Build deb` and stop at a GitHub 504 for the Electron archive; every step before it passes. The build step now retries instead of failing the gate |
| Acceptance run | Not run for this release yet |

The table above describes the published package. The previous release `v0.2.1-rc.5-linux.2` and its eleven-patch series stay archived in git history.

## Current series

| Item | Value |
| --- | --- |
| Pinned base | `dsh-v0.2.2-rc.1` |
| Patch series | 0001 to 0006 |
| Patched tree | `d2d3f5c4c9a7e83a7cf5b2bbb230fdc982fc2786` |
| Next release tag | None; a new tag is needed only when a patch changes |

The active series re-applies the Linux port to the newer base. Six topics remain because the newer base already ships the plugin operation history, the recovery menus and the update views that the previous series carried as backports, and the newest base packs the operation-report worker, which patch 0006 unpacks again before it loads. A local `apply.sh` plus `git write-tree` reproduces the tree above; it differs from the released tree only by documentation records added after the release run.

## Open items

| Item | State | Owner | Exit gate |
| --- | --- | --- | --- |
| Real-desktop interactive pass | Open and optional | Desktop owner | `ci/real-desktop-acceptance.sh` tarballs from one X11 and one Wayland session recorded in the follow-up |

Nothing else is open inside the tracked scope. Items that would extend the scope need a new decision before they become work.

## Out of scope

| Area | Decision |
| --- | --- |
| File drag and new file actions | Arrived with the `dsh-v0.2.2-rc.1` base; [ADR-0003](roadmap/ADR-0003-file-drag-backport.md) records that the backport is no longer needed |
| CUA Linux provider | Excluded |
| Linux arm64, rpm, AppImage, Flatpak and an apt repository | Excluded; only the x64 deb is maintained |
| macOS-intrinsic integrations (Dock, vibrancy, notarization, official policy identity) | Different implementations by design, not missing work |
| Upstream development line | Not tracked; revisit when another non-alpha release replaces the pinned base |

## Maintenance

- Update the released-state table only from a publish run, not from a green source run.
- Record new evidence in [desktop follow-up](DESKTOP-FOLLOWUP.md); keep this page short.
- Keep both languages in sync and run `node ci/check-docs.mjs`.
- If an item moves into scope, add the decision and the exit gate here before opening the work.

## References

- [Release v0.2.1-rc.5-linux.2](https://github.com/lql341/deepseek-harness-linux-desktop/releases/tag/v0.2.1-rc.5-linux.2)
- [Desktop platform parity](DESKTOP-PARITY.md)
- [Desktop follow-up](DESKTOP-FOLLOWUP.md)
- [Pinned upstream base](../ci/upstream-base-tag)
