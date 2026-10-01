# deepseek-harness-linux-desktop

Unofficial patch set that gives the **DeepSeek Harness desktop app** a Linux x64 release
target (`AppImage` + `deb`) and brings its behaviour in line with the macOS build.

Upstream ships macOS and Windows only — its own `apps/desktop/README.md` states
"Linux is not a supported Desktop release target", and the packaging tests assert that a
`linux-x64` target must be rejected. This repository is the set of diffs that opens that
path up.

> **Status: Linux x64 verified locally.**
> The seven-patch series applies cleanly to the upstream tag and has been compiled, packaged,
> and smoke-tested on Linux x86_64. The verified build produced both an AppImage and a deb;
> the AppImage was also started from its self-extracting mode because this host does not have
> `libfuse.so.2`.

Base: upstream tag **`dsh-v0.2.0-rc.2`** (commit `639ed0153972`), 7 patches.

---

## Table of contents

- [1. What you get](#1-what-you-get)
- [2. Requirements and fixed paths](#2-requirements-and-fixed-paths)
- [3. Build — one-shot script](#3-build--one-shot-script)
- [4. Build — step by step (with success conditions)](#4-build--step-by-step-with-success-conditions)
- [5. Acceptance checklist (the 7 behaviours)](#5-acceptance-checklist-the-7-behaviours)
- [6. Artifacts and where they land](#6-artifacts-and-where-they-land)
- [7. Failure triage](#7-failure-triage)
- [8. Verified / not verified](#8-verified--not-verified)
- [9. Known limits](#9-known-limits)
- [10. Layout, license, attribution](#10-layout-license-attribution)

---

## 1. What you get

| # | macOS behaviour | How the patch set delivers it on Linux |
|---|---|---|
| 1 | App starts | The desktop policy gate no longer throws `desktop policy: unsupported platform` on Linux |
| 2 | Window chrome | `titleBarStyle: 'hidden'` + `titleBarOverlay` (the same mechanism Windows uses), so the page owns the titlebar area; `DSH_DESKTOP_LINUX_NATIVE_FRAME=1` restores the desktop frame |
| 3 | Closing the last window keeps tasks running | `window-all-closed` quits only on Windows now; the application and its Host stay alive, with a *Show Window* menu entry to get the window back |
| 4 | `dsh` command on `PATH` | New POSIX launcher plus a Linux branch of the command installer (`~/.local/bin/dsh`); an existing foreign command is reported and backed up, never silently overwritten |
| 5 | `dsh://` deep links | Desktop entry carries `MimeType=x-scheme-handler/dsh`; the shell already registers the scheme |
| 6 | Bundled runtime | Runtime preparation selects the Linux payload (Node/pnpm/Python, Electron binary, native packages) by *target* platform instead of assuming macOS or Windows |
| 7 | Updates | Linux packages without a feed; set `DSH_DESKTOP_LINUX_UPDATE_ORIGIN` to opt into a self-hosted generic (AppImage) feed |

Office document conversion works out of the box: Linux uses the bundled **WASM** LibreOffice
engine (`@deepseek-ai/libreoffice-kit-wasm`), **not** a system LibreOffice.

## 2. Requirements and fixed paths

**The build host must be Linux x86_64.** The patch keeps upstream's rule that `linux-x64`
refuses to build anywhere else, so this cannot be cross-built from macOS. `linux-arm64` is
not part of this series.

| Requirement | Value | Check |
|---|---|---|
| Host | Linux x86_64 | `uname -sm` → `Linux x86_64` |
| Node | `^22.19.0 \|\| >=24.0.0` | `node -v` |
| pnpm | `11.7.0` | `corepack enable && pnpm -v` |
| git | any recent | `git --version` |
| Free disk | ≥ 15 GB (checkout ≈ 200 MB, dependencies + Electron + runtime payloads several GB) | `df -h "$HOME"` |
| Network | `registry.npmjs.org`, `nodejs.org`, Python standalone builds, `github.com` (Electron), electron-builder's own downloads | proxy-dependent; see [triage](#7-failure-triage) |
| Display for the smoke run | X11/Wayland, or `xvfb-run` | `echo "$DISPLAY$WAYLAND_DISPLAY"` |

Paths used throughout this document — set them first:

```sh
export PATCH_REPO="$HOME/src/deepseek-harness-linux-desktop"   # this repository
export SRC="$HOME/src/deepseek-harness"                        # upstream checkout (created below)
export TARGET_DIR="$SRC/apps/desktop/.desktop-build/targets/linux-x64"
export ARTIFACTS="$TARGET_DIR/artifacts"
```

## 3. Build — one-shot script

An agent can execute this block as-is (it aborts on the first failed assertion):

```sh
set -euo pipefail

# --- preflight -------------------------------------------------------------
[ "$(uname -s)" = "Linux" ] || { echo "FAIL: host is not Linux"; exit 1; }
[ "$(uname -m)" = "x86_64" ] || { echo "FAIL: host is not x86_64"; exit 1; }
command -v git >/dev/null || { echo "FAIL: git missing"; exit 1; }
command -v node >/dev/null || { echo "FAIL: node missing"; exit 1; }
corepack enable >/dev/null 2>&1 || true
[ "$(pnpm -v)" = "11.7.0" ] || echo "WARN: pnpm is $(pnpm -v), expected 11.7.0"

export PATCH_REPO="${PATCH_REPO:-$HOME/src/deepseek-harness-linux-desktop}"
export SRC="${SRC:-$HOME/src/deepseek-harness}"

# --- fetch the patch set and apply it --------------------------------------
[ -d "$PATCH_REPO/.git" ] || git clone https://github.com/lql341/deepseek-harness-linux-desktop.git "$PATCH_REPO"
sh "$PATCH_REPO/apply.sh" "$SRC"

# --- prove the patches landed ---------------------------------------------
[ "$(git -C "$SRC" rev-parse HEAD^{tree})" = "80bf70a93174843c435dca070e8777f812389f75" ] \
  || { echo "FAIL: patched tree hash mismatch"; exit 1; }
[ -f "$SRC/apps/desktop/.env.linux" ] || { echo "FAIL: .env.linux missing"; exit 1; }

# --- dependencies ----------------------------------------------------------
cd "$SRC"
pnpm install --frozen-lockfile

# --- cheap preflight: validates .env.linux and the build toolchain ---------
pnpm --dir apps/desktop run check:package     # expect: "would publish 0.2.0-rc.2 ... valid"

# --- directory build first: does it even start? ----------------------------
pnpm --dir apps/desktop run package:linux:x64:dir

# --- real artifacts --------------------------------------------------------
pnpm --dir apps/desktop run package:linux:x64
ls -l "$SRC/apps/desktop/.desktop-build/targets/linux-x64/artifacts"
```

## 4. Build — step by step (with success conditions)

### Step 0 — host preflight

```sh
uname -sm          # expect: Linux x86_64
node -v            # expect: v22.19+ or v24+
corepack enable && pnpm -v   # expect: 11.7.0
df -h "$HOME"      # expect: >= 15G available
```

If `uname -m` is `aarch64`, or `uname -s` is `Darwin`, stop: this patch set does not cover
that combination. On macOS you can still apply the patches (step 1 works anywhere) but
`package:linux:x64` will refuse to run.

### Step 1 — clone this repository and apply the series

```sh
git clone https://github.com/lql341/deepseek-harness-linux-desktop.git "$PATCH_REPO"
sh "$PATCH_REPO/apply.sh" "$SRC"
```

`apply.sh` clones upstream at tag `dsh-v0.2.0-rc.2`, creates branch `linux-desktop`, runs
`git am` on all 7 patches, and copies `.env.linux.example` to `.env.linux` (the packaging
code requires that file and aborts without it).

Success conditions — all four must hold:

```sh
git -C "$SRC" log --oneline | head -1
#   expect: "docs(desktop): describe the Linux build and its known limits"
git -C "$SRC" rev-parse HEAD^{tree}
#   expect: 80bf70a93174843c435dca070e8777f812389f75
git -C "$SRC" status --porcelain      # expect: empty
test -f "$SRC/apps/desktop/.env.linux" && echo env-ok
```

To review rather than trust: `git -C "$SRC" log --stat` shows the 5 topic commits.

### Step 2 — install dependencies

```sh
cd "$SRC"
pnpm install --frozen-lockfile
```

Expect exit 0. Mirrors work if the default registry is slow — either set
`DSH_DESKTOP_NPM_REGISTRY` in `apps/desktop/.env.linux` (used by the bundled runtime
install), or `ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/` for the Electron
download.

### Step 3 — cheap preflight (no build, seconds)

```sh
pnpm --dir apps/desktop run check:package
```

This validates `.env.linux`, the release settings and the host toolchain, then prints
something like `desktop package: linux-x64 would publish 0.2.0-rc.2; local configuration and
toolchain valid`. Fix anything it reports before spending time on a real build — this is the
cheapest place to catch a wrong pnpm, a missing `.env.linux`, or a bad entry in it.

### Step 4 — directory build (the first real build)

```sh
pnpm --dir apps/desktop run package:linux:x64:dir
```

Every package command builds the whole repository itself, prepares the Electron
distribution, installs the production runtime closure from the registry, and writes the
unpacked application. Expect several minutes and a lot of output; **exit 0** is the pass
condition.

Success conditions:

```sh
ls -d "$ARTIFACTS"/linux-unpacked                                    # unpacked application
ls -l "$ARTIFACTS/linux-unpacked/DeepSeek Harness"                   # the Electron binary, executable
```

### Step 5 — AppImage + deb

```sh
pnpm --dir apps/desktop run package:linux:x64
ls -l "$ARTIFACTS"/*.AppImage "$ARTIFACTS"/*.deb
```

Expect exactly two artifacts named from the product version (see [§6](#6-artifacts-and-where-they-land)).
No signing or notarization runs for Linux, so nothing else is needed here.

Pass `--build-version` if you want your own numbering, e.g.
`pnpm --dir apps/desktop run package:linux:x64 -- --build-version 0.2.0-rc.2.linux.1`;
without it, artifacts carry the upstream product version.

### Step 6 — smoke run

```sh
# Directory build, headless host:
xvfb-run -a "$ARTIFACTS/linux-unpacked/DeepSeek Harness"

# Or install the deb (also what makes the dsh command usable, see §9):
sudo apt install ./"$ARTIFACTS"/deepseek-harness-*-linux-x64.deb
dpkg -L deepseek-harness | grep -E '/(bin|opt)/'    # find the installed executable
# then launch it from the desktop menu, or run the path printed above (quote it: it contains a space)
```

Things to watch in the first 30 seconds:

- it must reach the workspace/welcome UI and **not** print `desktop policy: unsupported platform`;
- the window should have no system titlebar and native controls at the top right
  (if the desktop environment draws something odd, retry with
  `DSH_DESKTOP_LINUX_NATIVE_FRAME=1`);
- in a container without user namespaces, Chromium's sandbox may refuse to start — prefer the
  `deb`, or add `--no-sandbox` only as a last resort (it lowers security).

## 5. Acceptance checklist (the 7 behaviours)

Run these in order; each one maps to a patch in `patches/`.

| # | Check | Command / observation | Expected |
|---|---|---|---|
| 1 | Starts | launch as in step 6 | workspace opens, no `unsupported platform` error |
| 2 | Window chrome | look at the window; toggle `DSH_DESKTOP_LINUX_NATIVE_FRAME=1` | overlay caption + native controls; env var restores the frame |
| 3 | Stays alive | close the last window, then `pgrep -af "DeepSeek Harness"` | process still running; *Show Window* menu item brings the window back; explicit Quit really exits |
| 4 | `dsh` on PATH | install the command from the app UI, then in a **new** shell: `command -v dsh && dsh --version` | `~/.local/bin/dsh`, runs the bundled CLI (ensure `~/.local/bin` is on `PATH`) |
| 5 | Deep link | `xdg-mime query default x-scheme-handler/dsh` then `xdg-open 'dsh://open'` | a desktop file is registered and the window focuses |
| 6 | Runtime + Office | in a session run a shell tool; ask for a DOCX→PDF conversion | bash tool works (Landlock, kernel ≥ 5.13); conversion succeeds via the bundled WASM engine |
| 7 | Updates | launch with no `DSH_DESKTOP_LINUX_UPDATE_ORIGIN` | no update check; with a self-hosted generic feed origin set, the app reads `latest-linux.yml` |

## 6. Artifacts and where they land

Everything is written under `apps/desktop/.desktop-build/targets/linux-x64/`:

| Path | Contents |
|---|---|
| `artifacts/linux-unpacked/` | unpacked application (from `:dir`); executable `DeepSeek Harness` |
| `artifacts/deepseek-harness-<version>-linux-x64.AppImage` | AppImage |
| `artifacts/deepseek-harness-<version>-linux-x64.deb` | Debian package |
| `runtime/` | prepared Electron + pnpm + launcher for this target |
| `dsh/` | the bundled `dsh` runtime tree that becomes `app.asar/dsh` |
| `package-set/`, `downloads/` | intermediate package set and downloaded archives |
| `packaging-runs/` | per-run logs and the release record |

With the default version these are
`deepseek-harness-0.2.0-rc.2-linux-x64.AppImage` and `…-linux-x64.deb`.

## 7. Failure triage

| Symptom | Cause | Action |
|---|---|---|
| `desktop package: unsupported target "linux-x64"` | patches not applied | re-run step 1; verify the tree hash |
| `desktop package: cannot read …/.env.linux; copy …` | required env file missing | `cp apps/desktop/.env.linux.example apps/desktop/.env.linux` |
| `desktop package: linux-x64 requires a Linux x64 build host` | building on macOS/arm64 | build on Linux x86_64 |
| `desktop package: unsupported setting X in …/.env.linux` | key not in the Linux template | use only `DSH_DESKTOP_APP_ID`, `DSH_DESKTOP_NPM_REGISTRY`, `DSH_DESKTOP_LINUX_UPDATE_ORIGIN`, the policy origins |
| `ERR_PNPM_UNSUPPORTED_ENGINE` / odd dependency errors | wrong Node or pnpm | Node `^22.19 \|\| >=24`, pnpm `11.7.0` |
| Electron download timeouts / 404 | proxy or mirror | `ELECTRON_MIRROR`, or export `HTTPS_PROXY` |
| `missing required LibreOffice engine wasm` | the WASM kit is absent from the runtime tree | confirm `@deepseek-ai/libreoffice-kit-wasm` installed (it is an optional dependency of `@deepseek-ai/libreoffice-kit`) |
| Type errors from `tsc` in `main.ts` | first real type check | report them; the policy-branch narrowing is the most likely spot |
| AppImage refuses to start (sandbox / user namespaces) | Ubuntu 23.10+ AppArmor restriction | install the `deb`, or add an AppArmor profile; `--no-sandbox` only as a last resort |
| `dsh` install refused with "transient AppImage mount" | AppImage resources live in a temporary mount | install the `deb`, or extract the AppImage and set `DSH_DESKTOP_RESOURCES` |
| Deep link does nothing | desktop file not registered | confirm `xdg-mime query default x-scheme-handler/dsh`; reinstall the deb |

## 8. Verified / not verified

Verified:

- The series applies cleanly on `dsh-v0.2.0-rc.2`; after `git am` the resulting tree hash is
  `bb2f6aacd6657cd732935ce7d97bc707839e190c`, with no leftover changes.
- `apply.sh` ran end to end under a C locale with no git identity configured: fresh shallow
  clone → 7 patches → `.env.linux` created → exit 0.
- Every changed file passes a syntax check; all native dependencies were resolved against the
  npm registry (Linux variants exist, `node-pty` ships `linux-x64/arm64` prebuilds).
- `check:package` passed, and the official Linux build passed runtime preparation, Office
  document round-trip, and Electron packaging stages.
- The resulting artifacts were `deepseek-harness-0.2.0-rc.2-linux-x86_64.AppImage` and
  `deepseek-harness-0.2.0-rc.2-linux-amd64.deb`; the deb metadata and contents were inspected.
- The Linux installer uses the Debian-safe executable name `deepseek-harness`; its generated
  `postinst` registers that name with `update-alternatives` instead of using the display name.
- The packaged application started successfully and exposed its local `dsh web` endpoint.

Not verified in this environment:

- Electron's `titleBarOverlay` appearance per desktop environment; window drag/resize and
  caption sizing in both themes.
- XDG deep-link association after installing the deb; the deb itself was inspected but not
  installed system-wide.
- The desktop test suite, which upstream never ran on Linux and which may have pre-existing
  failures there. Run it once on the unpatched tag to get a baseline before comparing.

## 9. Known limits

- **Not achievable 1:1**: macOS traffic-light buttons, sidebar `vibrancy`, Dock bounce. The
  patch set substitutes native overlay window controls, a flat sidebar, and notifications.
- **The `dsh` command requires the `deb`**: an AppImage's resources live in a transient
  mount, so installing a command from it is refused with an actionable message
  (`DSH_DESKTOP_RESOURCES` is the escape hatch for an extracted tree).
- **Platform identity**: a Linux build reports the macOS desktop identity to DeepSeek
  Platform, because the shared account package only defines `darwin`/`win32` for
  `x-client-platform` (omitting it degrades to `web`).
- **Mandatory-update policy is inert on Linux** (there is no official Linux feed).
- Only `linux-x64`; `linux-arm64` is not part of this series.
- The welcome window's caption colour follows the system palette only at creation.
- The `deb` maintainer field is a placeholder (`DeepSeek Harness`).

## 10. Layout, license, attribution

```
patches/0001..0005*.patch   git format-patch series, applied in file-name order
apply.sh                    clone upstream at the base tag, apply the series, create .env.linux
LINUX-DESKTOP.md            long-form guide: per-file notes, verified facts, open items
LICENSE                     MIT (upstream DeepSeek + this patch set)
```

Each patch is one topic: (1) accept the target, (2) install the `dsh` command,
(3) prepare the Linux runtime payload, (4) macOS-like shell behaviour, (5) documentation.

This patch set is distributed under the MIT License (see `LICENSE`). The patches are diffs
against [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness),
which is MIT-licensed, Copyright (c) 2026 DeepSeek; that notice is retained here.

Not affiliated with, endorsed by, or supported by DeepSeek. Upstream is in developer preview
and iterates quickly, so expect conflicts when rebasing onto newer tags.
