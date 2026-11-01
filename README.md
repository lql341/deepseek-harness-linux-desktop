English | [中文](README.zh.md)

# DeepSeek Harness Linux Desktop

Unofficial Linux x64 desktop port of [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness). This repository maintains an ordered patch series and Linux build, verification and release tools. It is not affiliated with or endorsed by DeepSeek.

The default upstream base is read from [ci/upstream-base-tag](ci/upstream-base-tag). The recorded verification baseline here is **`dsh-v0.2.1-rc.5`**. Linux packages bundle **`dsh-scnet@0.6.13`**. Use [Actions](https://github.com/lql341/deepseek-harness-linux-desktop/actions) to check the result for an exact commit.

## Install a published package

The verified public prerelease is [v0.2.1-rc.5-linux.1](https://github.com/lql341/deepseek-harness-linux-desktop/releases/tag/v0.2.1-rc.5-linux.1). Download its deb and `SHA256SUMS`, or use the installer below. The installer checks the checksum and amd64 architecture before asking apt to reinstall the package. It needs curl, Node, sha256sum, dpkg and sudo/apt on the installation host.

```sh
git clone https://github.com/lql341/deepseek-harness-linux-desktop.git
cd deepseek-harness-linux-desktop
bash ci/install-latest-linux.sh --tag v0.2.1-rc.5-linux.1
```

Without `--tag`, the script uses GitHub's latest non-prerelease endpoint; it may select an older stable release. Source changes on main and CI artifacts are separate from published releases. The release above does **not** contain the later desktop backports or the SCNet setup repair described below.

## Desktop capabilities

| Area | Linux behavior |
| --- | --- |
| Window and background work | Custom caption, optional native frame, tray/Show Window, and tasks kept running after the last window closes |
| System integration | `dsh` launcher, single-instance routing and registered `dsh://` links |
| Runtime | Linux target payload and bundled WASM Office conversion |
| Updates | Settings-owned check/update actions, verified Linux package download and PolicyKit installation; client and Harness are delivered together |
| SCNet | Fixed offline Bundle/Skill, default Desktop profile activation, preserved explicit disable/custom profile state, and local diagnostics |
| Developer tools | Visible English/Chinese menu and native shortcuts including F12 |
| Recovery | Retrieve a saved crash report, including delayed writes and visible reveal failures |
| Update dialogs | Owner-attached isolated views, Linux caption/fullscreen handling, cancellation and mandatory-view recovery |
| SCNet setup repair | External Python uses unpacked files; completion/errors remain visible in the terminal and spawn failures reject the action |

The final four rows describe the source patch series. See [desktop follow-up](docs/DESKTOP-FOLLOWUP.md) for evidence and remaining differences. Real SCNet OAuth2 login is still blocked on its formal service contract and sandbox credentials. Local diagnostics and an installed Bundle do not establish authorization.

## Build from source

Build on **Linux x86_64**, with Node `^22.19.0 || >=24.0.0`, pnpm `11.7.0`, Git, build-network access and at least 15 GB free disk. The current upstream workspace may select its own pinned pnpm via package-manager management. Cross-building this Linux target from macOS and `linux-arm64` releases are not supported by this series.

```sh
export PATCH_REPO="$HOME/src/deepseek-harness-linux-desktop"
export SRC="$HOME/src/deepseek-harness"
git clone https://github.com/lql341/deepseek-harness-linux-desktop.git "$PATCH_REPO"
sh "$PATCH_REPO/apply.sh" "$SRC"
cd "$SRC"
pnpm install --frozen-lockfile
pnpm run typecheck
pnpm run build:lib:host
pnpm --dir apps/desktop run build
pnpm --dir apps/desktop run check:package
pnpm --dir apps/desktop run package:linux:x64
```

Use a fresh `$SRC`. `apply.sh` checks out the pinned upstream tag, creates the Linux branch, applies every `patches/*.patch` in filename order with **`git apply --3way`**, and creates `.env.linux`. Changes are staged; they are not one commit per patch. Record the patched source with `git -C "$SRC" write-tree`; `HEAD` still names the upstream base. Build details, paths and troubleshooting are in the [Linux guide](LINUX-DESKTOP.md).

## Verification and release

PRs and relevant main pushes apply the series, typecheck the full workspace, run focused desktop regressions, build the deb, audit the SCNet payload, and install/start that same candidate on Ubuntu 24.04 under Xvfb. Draft pull requests do not start that job, and a newer push cancels an in-flight pull-request run, so work in progress cannot mail a failure for a commit that was already replaced. The ordinary second-launch window assertion is skipped in this headless session; it needs a real desktop. Published-byte verification, upgrades, AppArmor, Wayland and Debian 13 are separate manual jobs. A skipped job is not a passed platform check.

[PR #5](https://github.com/lql341/deepseek-harness-linux-desktop/pull/5) passed 254 desktop regressions, full typecheck, packaging and installed-session checks in [run 41273560891](https://github.com/lql341/deepseek-harness-linux-desktop/actions/runs/41273560891); the merged main was also verified in [run 41274912984](https://github.com/lql341/deepseek-harness-linux-desktop/actions/runs/41274912984). The SCNet setup repair and bilingual docs then passed [run 41278271808](https://github.com/lql341/deepseek-harness-linux-desktop/actions/runs/41278271808) with 268 desktop tests and [documentation run 41278271805](https://github.com/lql341/deepseek-harness-linux-desktop/actions/runs/41278271805). Plugin operation history is a new candidate requiring its own CI evidence.

Publishing is manual through [publish-linux-desktop.yml](.github/workflows/publish-linux-desktop.yml). It pins the build commit, records the staged patched tree, audits and installs the built bytes, then publishes the deb and checksums. Upstream synchronization creates reviewable PRs and never merges or publishes; a fresh upstream patch conflict is recorded as an issue instead of a failed scheduled run. See [sync operations](ci/UPSTREAM-SYNC.md).

## Documentation and project layout

English is the default documentation language. Every page has a Chinese counterpart and a language switch at the top; update both together. [Documentation maintenance](docs/DOCUMENTATION.md) describes the checks.

- [Linux build and acceptance guide](LINUX-DESKTOP.md)
- [Desktop feature follow-up](docs/DESKTOP-FOLLOWUP.md)
- [SCNet roadmap and handoff](docs/roadmap/README.md)
- [Android/HarmonyOS offline scaffold](mobile-skeleton/README.md)
- `patches/`: active upstream diffs; `patches-legacy-dsh-v0.2.0-rc.2/`: historical series
- `apply.sh`, `verify.sh`, `ci/`: source preparation, diagnostics, audits and installation tools

Only Linux x64 deb delivery is currently maintained here. macOS Dock/vibrancy, Windows installers and Linux permissions/compositors require distinct implementations. Native CUA and newer file interactions remain pending. Plugin operation history is implemented in the candidate source and awaits full CI. See the follow-up for their dependencies.

## License

[MIT](LICENSE). Upstream copyright (c) 2026 DeepSeek is retained. The project is an unofficial patch set; upstream is evolving and newer tags may require conflict resolution.
