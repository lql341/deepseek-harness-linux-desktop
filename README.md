# deepseek-harness-linux-desktop

Unofficial patch set that gives the **DeepSeek Harness desktop app** a Linux x64 release
target (`AppImage` + `deb`) and brings its behaviour in line with the macOS build.

Upstream ships macOS and Windows only — its own `apps/desktop/README.md` states
"Linux is not a supported Desktop release target", and the packaging tests assert that a
`linux-x64` target must be rejected. This repository is the set of diffs that opens that
path up.

> **Status: patches only, unverified on Linux.**
> The patches were written against the upstream tag and checked on macOS (syntax level,
> plus tree-hash verification that they apply cleanly). They have **never been compiled,
> packaged, or run on Linux**. Budget for a few small fixups on the first build — the
> guide lists exactly which lines to look at.

Base: upstream tag **`dsh-v0.2.0-rc.2`** (commit `639ed0153972`), 5 patches, 33 files,
+798 / −119.

## What you get

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
engine (`@deepseek-ai/libreoffice-kit-wasm`), not a system LibreOffice.

## Quick start

```sh
git clone https://github.com/lql341/deepseek-harness-linux-desktop.git
cd deepseek-harness-linux-desktop
./apply.sh ~/src/deepseek-harness          # clone upstream tag + apply patches + create .env.linux
cd ~/src/deepseek-harness
pnpm install --frozen-lockfile
pnpm --dir apps/desktop run package:linux:x64:dir   # directory output first: does it start?
pnpm --dir apps/desktop run package:linux:x64       # then AppImage + deb
```

`./apply.sh --install <dir>` also runs `pnpm install --frozen-lockfile`.
Requirements: a **Linux x64 build host**, Node `^22.19 || >=24`, pnpm `11.7.0`
(`corepack enable` is the easy route).

The target rule is deliberate: `linux-x64` refuses to build anywhere but a Linux x64 host,
so this cannot be cross-built from macOS.

## What is verified, and what is not

Verified:

- The series applies cleanly on `dsh-v0.2.0-rc.2`; after `git am` the resulting tree hash
  equals the development tree, with no leftover changes.
- `apply.sh` was run end to end under a C locale with no git identity configured:
  fresh shallow clone → 5 patches → `.env.linux` created → exit 0.
- Every changed file passes a syntax check; all native dependencies were resolved against
  the npm registry (Linux variants exist, `node-pty` ships `linux-x64/arm64` prebuilds).

Not verified (needs a Linux host):

- Compilation and type checking (`pnpm --dir apps/desktop run build`) — no `node_modules`
  on the authoring machine.
- Electron's `titleBarOverlay` appearance per desktop environment; window drag/resize,
  caption sizing in both themes.
- `landlock-run` unpacking and the bash sandbox, `deb` metadata, XDG deep-link association.
- The desktop test suite, which was never run on Linux upstream and may have pre-existing
  failures there. Run it once on the unpatched tag to get a baseline.

## Known limits

- **Not achievable 1:1**: macOS traffic-light buttons, sidebar `vibrancy`, Dock bounce.
  The patch set substitutes native overlay window controls, a flat sidebar, and notifications.
- **CLI on `PATH` requires the `deb`**: an AppImage's resources live in a transient mount,
  so installing a `dsh` command from it is refused with an actionable message
  (`DSH_DESKTOP_RESOURCES` is the escape hatch for an extracted tree).
- **Platform identity**: a Linux build reports the macOS desktop identity to DeepSeek
  Platform, because the shared account package only defines `darwin`/`win32` for
  `x-client-platform` (omitting it degrades to `web`).
- **Mandatory-update policy is inert on Linux** (there is no official Linux feed).
- Only `linux-x64`; `linux-arm64` is not part of this series.
- The welcome window's caption colour follows the system palette only at creation.

## Layout

```
patches/0001..0005*.patch   git format-patch series, applied in file-name order
apply.sh                    clone upstream at the base tag, apply the series, create .env.linux
LINUX-DESKTOP.md            full guide: build steps, acceptance checklist, per-file notes
LICENSE                     MIT (upstream DeepSeek + this patch set)
```

Each patch is one topic: (1) accept the target, (2) install the `dsh` command,
(3) prepare the Linux runtime payload, (4) macOS-like shell behaviour, (5) documentation.

## License and attribution

This patch set is distributed under the MIT License (see `LICENSE`). The patches are diffs
against [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness),
which is MIT-licensed, Copyright (c) 2026 DeepSeek; that notice is retained here.

Not affiliated with, endorsed by, or supported by DeepSeek. Upstream is in developer
preview and iterates quickly, so expect conflicts when rebasing onto newer tags.
