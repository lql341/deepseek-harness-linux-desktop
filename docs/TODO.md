English | [中文](TODO.zh-CN.md)

# Living TODO

This is the current to-do list for the repository. It records the tracked scope, the released state and every open item. Update it when a release lands, the scope changes or an item closes; history belongs in git and in the evidence pages, not here.

## Scope

The tracked goal is parity with the official `dsh-v0.2.2-rc.1` desktop release on a Linux x64 deb. The pinned base moved from `dsh-v0.2.1-rc.5` to that release; the previous series stays published and is not rebuilt. The upstream development line, platform-intrinsic macOS integrations, the experimental CUA provider and additional package formats are outside this scope by decision; [desktop platform parity](DESKTOP-PARITY.md) records the verdict and the excluded rows.

## Released state

| Item | Value |
| --- | --- |
| Release | `v0.2.1-rc.5-linux.2` |
| Patch series | 0001 to 0011 |
| Build commit | `32a509c6e5db91d6210f4fe23d4f9290c0df310a` |
| Patched tree | `0fef55a99edf4a7f857ab0365c98644bce9d7fff` |
| Release run | 41311729795 |
| Verification run | 41309525902 (19 suites, 486 tests) |
| Acceptance run | 41317916316 |

The table above describes the published package; its series is archived in git history and is not the active one.

## Current series

| Item | Value |
| --- | --- |
| Pinned base | `dsh-v0.2.2-rc.1` |
| Patch series | 0001 to 0005 |
| Patched tree | `7fa80b8b0c53456fcb53c8322a114fb4f3a72ca1` |
| Next release tag | `v0.2.2-rc.1-linux.1` (pending) |

The active series re-applies the Linux port to the newer base. Five topics remain because the newer base already ships the plugin operation history, the recovery menus and the update views that the previous series carried as backports. A local `apply.sh` plus `git write-tree` reproduces the tree above.

## Open items

| Item | State | Owner | Exit gate |
| --- | --- | --- | --- |
| `dsh-v0.2.2-rc.1` release | Open | Release owner | A green publish run for `v0.2.2-rc.1-linux.1`; record its run IDs here afterwards |
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
