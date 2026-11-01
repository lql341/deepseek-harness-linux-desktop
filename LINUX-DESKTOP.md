English | [中文](LINUX-DESKTOP.zh-CN.md)

# Linux desktop build and acceptance guide

## 0. Scope

This guide describes the current patch series on `dsh-v0.2.1-rc.5`, including fixed `dsh-scnet@0.6.13`. [README](README.md) distinguishes source capabilities from the published `v0.2.1-rc.5-linux.1` prerelease. Historical 0.2.0 topic patches are archived and must not be mixed into the active series.

## 1. Build prerequisites

Use Linux x86_64, Node `^22.19.0 || >=24.0.0`, pnpm `11.7.0`, Git and at least 15 GB free disk. The upstream workspace has its own package-manager pin. Package commands enforce a Linux x64 host. Dependencies require npm registries, GitHub/Electron, Node and Python distribution downloads. Set an appropriate proxy or approved mirror if those downloads are unavailable.

A real X11/Wayland session is needed for desktop acceptance. Xvfb, Openbox, xdotool and dbus-x11 provide the automated headless session. The app uses bundled WASM LibreOffice; system LibreOffice is not required for that conversion path.

## 2. Prepare the upstream source

Use the commands in [README](README.md). `apply.sh` reads [ci/upstream-base-tag](ci/upstream-base-tag); `BASE_TAG` overrides it. The script applies `patches/*.patch` with `git apply --3way`, leaving changes in the index, and creates `apps/desktop/.env.linux` from its template. Start from a fresh checkout: rerunning an already applied series is not an update operation.

`git rev-parse HEAD` identifies the unpatched base. Use `git write-tree` for the staged patched tree; unstaged edits are not included. Review `git diff --cached`, rather than expecting a commit per patch or an empty status. Keep `.env.linux` local and use only settings accepted by its current template.

`ci/update-upstream-and-build.sh` handles local migration; the daily sync workflow validates newer descendant tags and opens a PR. Alpha migration requires explicit selection. See [sync operations](ci/UPSTREAM-SYNC.md).

## 3. Build, inspect and install

After install/typecheck and host/desktop builds, run `check:package`, then `package:linux:x64`. An unpacked directory build is available through `package:linux:x64:dir`; it is useful for debugging but does not establish that deb installation works.

```sh
export TARGET_DIR="$SRC/apps/desktop/.desktop-build/targets/linux-x64"
export ARTIFACTS="$TARGET_DIR/artifacts"
git -C "$SRC" diff --cached --stat
git -C "$SRC" write-tree
ls -lh "$ARTIFACTS"/*.deb
node "$PATCH_REPO/ci/scnet-release-audit.mjs" \
  --deb "$(find "$ARTIFACTS" -maxdepth 1 -name '*.deb' -print -quit)" \
  --package-set "$TARGET_DIR/package-set" --expected-version 0.6.13 --require-setup true
sudo apt-get install --reinstall "$ARTIFACTS"/deepseek-harness-*-linux-amd64.deb
deepseek-harness
```

The audit reads the exact archive through the packaged Electron runtime. It checks fixed Bundle/Skill versions, package-set integrity and license, runtime descriptor hashes, credentials/private endpoints and generated caches. `--require-setup true` additionally requires physical unpacked SCNet files matching the archive and runs the packaged wizard's help through external Python. Omit that option only when auditing historical packages that predate this repair.

Artifacts are under `$TARGET_DIR`: `artifacts/` contains the deb/unpacked app, `runtime/` the prepared runtime, `dsh/` the bundled production tree, `package-set/` and `downloads/` the intermediate inputs, and `packaging-runs/` the build records. The installed launcher is `/usr/bin/deepseek-harness`, targeting `/opt/DeepSeek Harness/deepseek-harness`. The production CLI payload is inside `resources/app.asar/dsh`; ordinary shell file checks cannot read that virtual archive path. External Python requires `app.asar.unpacked`.

## 4. Acceptance checklist

| Capability | Acceptance |
| --- | --- |
| Start and windows | Workspace/welcome appears; no unsupported-platform rejection; test drag/resize, light/dark and native frame fallback |
| Background work | Closing the last window preserves the Host/tasks; tray or Show Window restores the window |
| Single instance | Both plain second launch and `dsh://open` restore the window without another Host |
| CLI | Install the `dsh` command on PATH; report/back up a foreign launcher; execute it after installing the deb |
| Office | Convert representative DOCX/XLSX/PPTX through the bundled WASM engine |
| Updates | Check in settings; cancel safely; verify download, PolicyKit refusal/failure, running-task confirmation and restart |
| SCNet | Bundle/Skill available offline; default, disabled and custom profile states preserved; diagnostics expose no credentials |
| Developer tools | English/Chinese menu and F12/native shortcuts reach the intended product document |
| Recovery | Saved, delayed and failed crash reports are distinguishable; retrieval does not restart the app |
| Update views | Correct caption/fullscreen bounds, no background activation, input restored after closing, safe mandatory-view fallback |
| Configure SCNet | External Python opens the unpacked wizard; failures remain visible; cancel/close does not imply login |

Run focused regressions from the patched upstream root:

```sh
pnpm exec vitest run apps/desktop/tests/fatal-recovery.spec.ts \
  apps/desktop/tests/update-overlay.spec.ts apps/desktop/tests/update-dialog.spec.ts \
  apps/desktop/tests/mandatory-update-window.spec.ts apps/desktop/tests/main-startup.spec.ts \
  apps/desktop/tests/keyboard.spec.ts apps/desktop/tests/harness-update.spec.ts \
  apps/desktop/tests/scnet-diagnostics-window.spec.ts apps/desktop/tests/scnet-setup.spec.ts \
  apps/desktop/tests/installer-packaging.spec.ts
```

On Ubuntu, CI installs and starts the built deb under `ci/desktop-session.sh`. That covers mapped windows, close-keeps-running, profile activation and deep-link routing. Ordinary relaunch is deliberately skipped under Xvfb. Real desktop, Wayland, keyring and user interaction acceptance remain separate evidence.

## 5. Known limits

Only Linux x64 deb delivery is maintained. ARM64, AppImage and RPM need separate packaging/runtime verification. macOS traffic lights, vibrancy and Dock attention are not Linux features. Linux uses an overlay caption or `DSH_DESKTOP_LINUX_NATIVE_FRAME=1` and its desktop's tray/notifications.

There is no official Linux update feed. The port's update path delivers client and Harness together through Linux release packages and the system installer. A successful local SCNet readiness check does not mean OAuth2 login or SSH access; those have different prerequisites. The shared account protocol currently identifies Linux with the upstream desktop fallback because its accepted desktop platform values are macOS/Windows.

CUA requires Linux-native permissions/control. New file actions and complete plugin history require newer shared APIs; see [follow-up](docs/DESKTOP-FOLLOWUP.md). Historical CI counts and platform runs do not establish current release correctness.

## 6. Troubleshooting

| Symptom | Check |
| --- | --- |
| Unsupported linux-x64 or patch conflict | Fresh pinned base, active series only, and complete patch logs |
| Missing .env.linux | Copy the current template; verify accepted settings and app ID |
| Wrong host/toolchain | Linux x86_64, supported Node and the actual selected pnpm |
| Dependency/Electron timeout | Proxy, registry and Electron mirror; do not change patch behavior to hide network failure |
| Missing Office WASM | Production runtime closure and package-set inventory |
| Dead deep link | `xdg-mime query default x-scheme-handler/dsh` should name `deepseek-harness.desktop` |
| SCNet setup unavailable | Physical unpacked script, executable configured Python, supported terminal and visible terminal output |
| Sandbox rejection | Inspect user-namespace/AppArmor/SUID helper configuration; normal desktop operation must retain the sandbox |

`verify.sh` records per-step PASS/FAIL and creates a diagnostic tarball. It does not use sudo and does not replace installed-desktop acceptance. Check its expected versions against the current release before using historical diagnostics as a gate.

## 7. Verification boundaries

[Linux verification](.github/workflows/linux-desktop-verify.yml) is the authority for exact commits. PR/main checks cover source, regressions, candidate package and Ubuntu headless installation. Manual jobs cover long upstream gates, real-kernel bwrap/Landlock and keyless smoke, published bytes, AppArmor, Wayland, Debian 13 and profile upgrades.

The upstream gate tolerates only three explicitly enumerated coverage races; other failures remain failures. This is not a general coverage exemption. Screenshots or a headless startup do not establish real desktop focus, file dragging, keyring lifecycle or all compositor combinations. Record the package checksum, source commit, run, desktop/compositor and exact exercised behavior for each manual result.
