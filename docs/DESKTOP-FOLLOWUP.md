English | [中文](DESKTOP-FOLLOWUP.zh-CN.md)

# Desktop platform follow-up

Reviewed against upstream `dsh-v0.2.1-rc.5` and development commit `ce7073d51254c26cd63b22a60835b8f948deb447` on 2026-11-01. This is an implementation and evidence inventory, not a claim of complete platform parity.

## Stable baseline and published package

[rc.2 to rc.5](https://github.com/deepseek-ai/deepseek-harness/compare/dsh-v0.2.1-rc.2...dsh-v0.2.1-rc.5) contains 19 commits; the desktop directory changes only its package version. Shared client improvements arrive with rc.5, but that does not establish newer native-shell capabilities.

`v0.2.1-rc.5-linux.2` is the first release built from the full series and the first signed one; `v0.2.1-rc.5-linux.1` precedes patches 0007 to 0011. Source, CI candidate and release status must be checked separately.

## Implemented in the active source series

| Patch | Capability | Validation |
| --- | --- | --- |
| 0007 | Localized visible DevTools menu, native shortcuts/F12, preserved Linux Show Window/quit and SCNet actions | Menu tests cover Linux/macOS/Windows and English/Chinese |
| 0007 | Retrieve crash reports; pending/failed/saved states, delayed writes, visible reveal failure and retained path | Retrieval does not stop tasks or restart; focused recovery tests |
| 0007 | Isolated owner-attached update views, no independent native activation, caption/native-frame/fullscreen handling, input/lifetime cleanup, cancellation and mandatory-view recovery | Focused lifecycle/navigation tests plus Linux main/keyboard/updater/SCNet integration |
| 0008 | Repair Configure SCNet's external-Python ASAR path; unpack the whole Bundle, preserve terminal output and reject spawn failure | Source tests and package audit require physical file hashes and external Python help execution |
| 0009 | Correlated management events, validated Host IPC, a bounded local journal across Host restarts, and an isolated diagnostic-report Worker | Full verification in [run 41293513453](https://github.com/lql341/deepseek-harness-linux-desktop/actions/runs/41293513453): 19 suites and 475 tests, typecheck, deb build, SCNet audit and installed Xvfb session |
| 0010 | Linux menu actions: Check for Updates uses the Git-release package path and asks before installing, and Manage dsh Command is shown on Linux | Full verification in [run 41300916542](https://github.com/lql341/deepseek-harness-linux-desktop/actions/runs/41300916542): 19 suites and 478 tests, typecheck, deb build and installed Xvfb session |
| 0011 | Release trust chain: Ed25519-signed `SHA256SUMS` verified before a privileged install; `desktop-policy.json` support floor; Linux badge and urgent notification; Linux leaves fullscreen before hiding | Full verification in [run 41309525902](https://github.com/lql341/deepseek-harness-linux-desktop/actions/runs/41309525902): 19 suites and 486 tests, typecheck, deb build and installed Xvfb session |

Patch 0007 passed 254 tests across eight suites, full typecheck, build, deb audit and installed Xvfb session in [run 41273560891](https://github.com/lql341/deepseek-harness-linux-desktop/actions/runs/41273560891). Merged main passed [run 41274912984](https://github.com/lql341/deepseek-harness-linux-desktop/actions/runs/41274912984). Patch 0008 then passed 268 tests across ten suites, full typecheck, deb build, physical SCNet payload and external Python acceptance, and the installed session in [run 41278271808](https://github.com/lql341/deepseek-harness-linux-desktop/actions/runs/41278271808). The 26-page bilingual documentation check and eleven guard tests passed [run 41278271805](https://github.com/lql341/deepseek-harness-linux-desktop/actions/runs/41278271805). PR #6 merged as `c23d3cb6c849307d6eaaa2640016ec9b26436c8c`. Patch 0009 then passed 475 tests across 19 suites, full typecheck, deb build and the installed Xvfb session in [run 41293513453](https://github.com/lql341/deepseek-harness-linux-desktop/actions/runs/41293513453), and merged as `c4605797d7cdc3b4bdda31c098210b8e26134ec0`. Patch 0010 then passed 478 tests across 19 suites, full typecheck, deb build and the installed Xvfb session in [run 41300916542](https://github.com/lql341/deepseek-harness-linux-desktop/actions/runs/41300916542), and merged as `66ce96ebc7601c80b48be6b63b9e2f069c135a36`. Patch 0011 then passed 486 tests across 19 suites, full typecheck, deb build and the installed Xvfb session in [run 41309525902](https://github.com/lql341/deepseek-harness-linux-desktop/actions/runs/41309525902) and merged as `32a509c`. `v0.2.1-rc.5-linux.2` was published from that merge in [run 41311729795](https://github.com/lql341/deepseek-harness-linux-desktop/actions/runs/41311729795); its downloaded bytes verify against the pinned key with `node ci/verify-release-signature.mjs`.

History is local and bounded to two 256 KiB segments; report collection reads at most 64 KiB/100 records and appends at most 64 KiB after the independent basic report has been saved. Raw install specifications, credentials and package-manager output are excluded. Omission counters and a completion marker describe partial collection; absent records do not prove that no operation occurred.

## Remaining work

| Capability | Dependency and exit gate |
| --- | --- |
| CUA installation and permissions | The [macOS provider](https://github.com/deepseek-ai/deepseek-harness/tree/ce7073d51254c26cd63b22a60835b8f948deb447/packages/experimental/cua-macos) uses macOS APIs; Linux needs a native control/permission implementation and separate X11/Wayland approval, refusal, retry and revocation tests |
| New file actions and dragging | Development file-actions/file-drag modules require shared file-action, drag and Host resource APIs absent from rc.5; backport provider, consumer and lifecycle together, including trusted-window IPC and temporary-file cleanup |
| Real desktop acceptance | Run `ci/real-desktop-acceptance.sh` on actual X11/Wayland sessions; it records focus, caption dragging/resizing, tray, notifications, CLI, deep links, setup and update confirmation |

Linux PolicyKit installation and SCNet integrations must remain covered during future backports. macOS Dock/traffic lights, Windows installers and Linux compositor/keyring APIs have distinct implementations. Do not replace missing platform evidence with typecheck or a copied menu item.

## References

- [Pinned base](../ci/upstream-base-tag)
- [Linux workflow](../.github/workflows/linux-desktop-verify.yml)
- [Publish workflow](../.github/workflows/publish-linux-desktop.yml)
- [Linux guide](../LINUX-DESKTOP.md)
- [Desktop platform parity](DESKTOP-PARITY.md)
- [dsh-superagent add-on decision](roadmap/ADR-0002-dsh-superagent-bundle.md)
