English | [中文](DESKTOP-PARITY.zh-CN.md)

# Desktop platform parity

This page compares the desktop capabilities of the official macOS release with the Linux port in this repository. It is an implementation inventory with named evidence, not a statement that both platforms behave identically.

## Scope and evidence

The official baseline is upstream `dsh-v0.2.1-rc.5`, the release that ships the macOS and Windows desktop shells. The Linux side is the active patch series in `patches/` plus the published `v0.2.1-rc.5-linux.1` package. Two later states are kept separate: patch 0007, 0008 and 0009 are source that is newer than that published package, and upstream `dsh-v0.2.2-alpha.2` is the development line that already contains work the port is still backporting.

Evidence for each row comes from the pinned upstream tree and the patched tree produced by `apply.sh`. The most useful files are `apps/desktop/src/main.ts`, `apps/desktop/src/windows-layout.ts`, `apps/desktop/src/platform-view.ts`, `apps/desktop/src/update-attention.ts`, `apps/desktop/src/command-management.ts`, `apps/desktop/scripts/electron-builder-config.mjs` and the focused desktop suites the verification workflow runs. A capability is only claimed when a test or a release gate exercises it; typecheck and a copied menu item are not platform evidence.

## Capability matrix

| Area | Official macOS desktop | Linux port | Remaining work |
| --- | --- | --- | --- |
| Window chrome | `hiddenInset` caption, inset traffic lights, sidebar vibrancy and a transparent backdrop | Window-controls overlay with a 40 DIP caption and localized caption menus, or a native frame with `DSH_DESKTOP_LINUX_NATIVE_FRAME=1` | Vibrancy and translucency depend on the compositor and are not implemented; themed caption colors are static |
| Fullscreen | Native fullscreen, overlay caption clearance and leaving fullscreen before hiding the window | Fullscreen state is relayed to the renderer for overlay clearance; hiding a fullscreen window is not handled separately | Handle hide while fullscreen on X11 and Wayland and test the restore path |
| Tray and window return | No menu bar icon; the Dock icon and a second launch return the window | Tray icon with Open and Quit plus a Show Window menu item; the Dock equivalent is the launcher | Tray availability depends on the desktop shell; GNOME without an extension only has relaunch |
| Close and quit lifecycle | Closing the last window keeps the application and its tasks running | Closing the last window keeps the Host and its tasks running, like macOS rather than Windows | Confirm on real desktops that hidden windows and the Host survive session switches |
| Update attention | Dock bounce plus a system notification for a prepared update | System notification only; neither Dock bounce nor taskbar flash is available | Add a Linux attention mechanism such as a badge or a freedesktop urgency hint |
| Application menu | File menu with single-key bindings, Edit, Window, and the Hide commands | Application and Edit caption menus plus a native Edit menu; no File or Window menu | Optional: expose a Window menu and single-key binding hints; DOM dispatch already works |
| Terminal command | `/usr/local/bin/dsh` with administrator authorization | `~/.local/bin/dsh` through a packaged launcher; the command-management worker supports Linux | The Manage dsh Command menu entry is hidden on Linux, so the working install path has no UI |
| Directory picker | Electron folder dialog attached to the window | Upstream already falls back to browse mode when zenity and kdialog are absent; the port keeps that behavior | Verify the fallback and the attached dialog on real desktops |
| Deep links | `dsh://` from the bundle, `open-url`, and Launch Services registration | `x-scheme-handler/dsh` in the desktop entry, `xdg-mime`, and single-instance command-line routing | `xdg-mime query default x-scheme-handler/dsh` must name the installed entry; dead links are a packaging defect |
| Single instance | Process-lifetime lock before profile access | Same lock; the headless session test covers plain relaunch and `dsh://open` | The ordinary second-launch window assertion needs a real desktop |
| Microphone | System authorization, usage description and audio-input entitlement | The primary application frame is the only accepted requester; non-macOS requests are granted without an OS prompt | Verify PipeWire and PulseAudio capture, and decide whether a portal permission flow is needed |
| Account sign-in and embedded Platform | Accepted desktop platform values are macOS and Windows; the Sign in button is disabled upstream | The port passes the macOS fallback because Linux is not an accepted value | Upstream must accept Linux before an honest client identity, embedded Platform view or sign-in can ship |
| Updates | Signed artifacts from the official update service, with channels and a mandatory policy | GitHub release discovery, checksum verification and PolicyKit installation of the rebuilt deb | Sign the package, route the menu action through the real updater, and decide how mandatory updates apply |
| Mandatory update policy | Windows and macOS identities are accepted by the policy service | The policy client is deliberately not initialized because Linux has no accepted identity | Define a Linux identity and service contract, or document the exemption as a product decision |
| Package signing | Developer ID signature and notarization | Unsigned deb with a SHA256SUMS file | Add a repository signing key or another verifiable trust chain before recommending automatic installs |
| Packaging targets | macOS arm64 and x64 images; Windows installer | Linux x64 deb only | Linux arm64, rpm, AppImage and Flatpak need separate runtime and acceptance work |
| Sandbox and permissions | Hardened runtime, entitlements and the macOS sandbox model | AppArmor profile, SUID `chrome-sandbox` fallback, and bwrap or Landlock sandbox legs | Keep the sandbox fallback covered and test the Wayland session manually |
| Developer tools | Command+Option+I and a hidden menu item | F12, Ctrl+Shift+I, a visible localized menu entry and native accelerators | Covered by focused keyboard and menu tests |
| Crash recovery | Reports under the macOS logs directory, with a native dialog | Reports under the userData logs directory, plus retrieval of a saved report from the Settings-owned menu | Real-desktop check of the reveal action and the ten-report retention |
| Computer use | The dedicated macOS provider uses Accessibility and Screen Recording | No Linux provider exists | Needs X11 and Wayland control, accessibility trees, capture and approval tests |
| Native file drag and new file actions | Present in the development line, not in the official baseline | Absent from the pinned baseline | Backport the file-drag provider, Host resource API and cleanup lifecycle together |
| Plugin operation history | Present in the development line, not in the official baseline | Backport candidate in patch 0009 | Merge and release it, then validate the journal and report Worker in an installed package |

## Gaps that need development

| Priority | Gap | Dependency | Exit gate |
| --- | --- | --- | --- |
| P0 | The published package predates patches 0007, 0008 and 0009 | Merge the operation-history pull request and run the publish workflow | An installed package from the current series passes verification and is published |
| P0 | The Check for Updates menu action uses the inert upstream channel on Linux | Small main-process change that calls the Harness update coordinator | The menu action reports the real Linux release state, and a focused test covers it |
| P0 | No trusted update chain | A signed repository or a signed package plus documented key handling | Update installation verifies the signature, not only a checksum |
| P1 | Mandatory updates are not enforced | A Linux client identity and a policy service contract, or an explicit exemption | The policy either blocks an outdated client or the exemption is documented and tested |
| P1 | Update attention is missing | A freedesktop notification with urgency or a launcher badge | A prepared update is noticeable from another workspace without focusing the window |
| P1 | CLI management has no Linux UI | Show the existing menu entry on Linux and adapt its copy | Install, repair and remove run from the menu and leave a working `dsh` on PATH |
| P1 | Fullscreen hide is unverified | A platform branch and a session test | X11 and Wayland leave fullscreen cleanly and restore the same document |
| P1 | No real desktop acceptance | Physical or virtual X11 and Wayland sessions | Focus, dragging, resizing, overlays, notifications, tray, deep links and updater prompts are recorded |
| P2 | File drag and new file actions are missing | Shared file-drag and Host resource APIs from the development line | A drag from the workspace creates a verifiable temporary file and cleans it up |
| P2 | Computer use is missing | A Linux control and accessibility implementation | Observation and input work under X11 and Wayland with explicit permission refusal and revocation |
| P2 | Distribution coverage is narrow | Packaging and runtime work per target | Linux arm64 and one non-deb format pass their own installation gates |

## Development line not in the official release

The official `dsh-v0.2.1-rc.5` baseline is not the newest source. Upstream `dsh-v0.2.2-alpha.2` adds desktop files the port does not carry yet. Treat them as planned backports rather than missing features of the official release.

| Development feature | What it adds | Port status |
| --- | --- | --- |
| Plugin operation history | Manager lifecycle events, a bounded journal and an isolated report Worker | Patch 0009, waiting for the verification run and the release |
| Native file drag | Verified copy drags scoped to the product main frame and the active Host | Not backported |
| Update window | A dedicated update window and revised overlay behavior | Partially present through the owner-attached dialogs from patch 0007 |
| Locale cache | A cached desktop locale with change notification | Not backported |

The file-drag and operation-history work both depend on shared Host and client APIs, so backporting only the desktop half would produce dead code. Either rebase the port onto a newer non-alpha tag or carry the provider, consumer and lifecycle together.

## What is intentionally different

- The Linux port adds capabilities macOS does not have: a tray, PolicyKit installation, the fixed SCNet bundle with setup and diagnostics, the Secret Service adapter, and an offline runtime package.
- Linux uses a window-controls overlay or the desktop frame instead of traffic lights and vibrancy. This is a deliberate shell decision, not a missing patch.
- Windows exits when the last window closes; Linux follows the macOS lifetime so background tasks continue. This changes the quit path and needs its own acceptance.
- The account and embedded Platform identity remains the macOS fallback until upstream accepts Linux. Do not treat a successful local account request as evidence of Linux account support.

## Verification boundaries

The Linux verification workflow proves source application, typecheck, focused regressions, deb construction, SCNet payload integrity and an installed headless session on Ubuntu 24.04. It does not prove real compositor behavior. Published-byte verification, upgrades, AppArmor, Wayland and Debian 13 remain manual jobs. A row marked implemented describes source and its tests; a row marked remaining describes work that has not been shown to run on a Linux desktop.

## References

- [Pinned upstream base](../ci/upstream-base-tag)
- [Linux verification workflow](../.github/workflows/linux-desktop-verify.yml)
- [Desktop follow-up](DESKTOP-FOLLOWUP.md)
- [Linux build and acceptance guide](../LINUX-DESKTOP.md)
