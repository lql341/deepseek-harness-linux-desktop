English | [中文](SCNET-HANDOFF-PROMPT.zh-CN.md)

# SCNet project handoff prompt

Read the [plan](SCNET-PLATFORM-DEVELOPMENT-PLAN.md), [current handoff](SCNET-DEVELOPMENT-HANDOFF.md), [desktop follow-up](../DESKTOP-FOLLOWUP.md) and [README](../../README.md), then copy the prompt below. Live repository state overrides recorded snapshots.

## Initial read-only checks

```sh
git rev-parse --show-toplevel
git status --short --branch
git branch -vv
git log -6 --oneline
git rev-parse HEAD origin/main
gh run list -R lql341/deepseek-harness-linux-desktop --limit 8
gh release list -R lql341/deepseek-harness-linux-desktop --limit 8
```

Confirm branch/worktree state and fetch current CI/release evidence. A detached HEAD is acceptable when it matches the intended commit. Do not overwrite unrelated work or rewrite history to force equality. If GitHub is unavailable, continue local read-only investigation and do not invent CI success.

## Copy-ready prompt

```text
Continue the SCNet Linux Desktop project from its existing implementation.

Use the current workspace, not a hardcoded machine path. Read the English plan,
handoff, desktop follow-up and README; their Chinese counterparts must stay in sync.
Query the actual branch, remote head, CI and release before treating notes as current.

The default upstream base is read from ci/upstream-base-tag (dsh-v0.2.1-rc.5 in
this snapshot). Apply the active patches/*.patch with git apply --3way in order
on a clean checkout. Record the staged patched tree with git write-tree; HEAD
still names the upstream base. Express every upstream change as a new patch.

Desktop bundles dsh-scnet@0.6.13 and delivers client/Harness updates together.
Keep update and Configure SCNet actions in settings. Preserve explicit disabled
and custom profiles. Patch 0007 adds DevTools/report retrieval/update views.
Patch 0008 repairs the ASAR external-Python setup path, terminal visibility and
spawn failure. Check current CI for that repair; old passing runs are insufficient.
The public v0.2.1-rc.5-linux.2 prerelease contains both patches.

Continue useful offline desktop work while formal SCNet OAuth2/API contracts and
sandbox credentials are unavailable. Never guess issuer, endpoints, scopes,
client credentials or account linking. Offline PKCE/callback/keyring interfaces
and local diagnostics are not real login. Treat the unpublished server handoff
manual as a separate candidate protocol, not a public-client OAuth replacement.

Shared SCNet changes start at canonical scnet-hpc, synchronize dsh-scnet and
codex-scnet-hpc, then update Desktop. Do not update a downstream bundle alone.
No credentials, private endpoints or user identifiers belong in this repository.

Validate focused behavior, complete clean patch application, full typecheck,
host/desktop build, package preflight, SCNet artifact audit, deb installation and
session behavior. Require physical unpacked files and external Python help for
new setup packages. Real terminal clicks/focus and X11/Wayland behavior need their
own evidence. Debian/multi-distribution and long upstream checks are deliberate
manual legs, not daily development blockers. Attribute every failure.

Use a reviewable PR; merge only after the relevant checks pass. Publishing is a
separate manual workflow with exact source commit/tree, checksums and installed
bytes. Do not label a CI artifact as a published release. Report what changed,
what ran and what remains unsupported, then refresh both documentation languages.
```

## Completion criteria

The reviewed patch series applies to its declared base, relevant checks passed for the exact changes, source/CI/release evidence is distinct, English/Chinese pages and links agree, and no secret material was introduced. Recheck remote state at handoff rather than claiming a historic run is current.
