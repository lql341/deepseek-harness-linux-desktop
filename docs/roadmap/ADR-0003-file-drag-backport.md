English | [中文](ADR-0003-file-drag-backport.zh-CN.md)

# ADR-0003: Backport native file drag as a staged Linux feature

- Status: `proposed`
- Date: 2026-11-01
- Owner: Linux Desktop maintainers
- Scope: `apps/desktop`, `apps/desktop-host`, `packages/util/file-drag`, `packages/client/ui-file-drag`, packaging and acceptance

## Decision

Backport native file drag in four stages, and decide whether to keep the drag gesture after stage 0 proves it works on the target sessions. The first stage is a spike, not a port: Electron's `webContents.startDrag` has limited Wayland support, and a gesture that silently does nothing is worse than a documented "save to Downloads" action.

If the spike shows `startDrag` works on X11 and either works or has an honest fallback on Wayland, continue with the port. If Wayland cannot drag, ship the export-without-drag path first and treat the drag gesture as X11-only, labelled as such in the UI.

## Context

The pinned base `dsh-v0.2.1-rc.5` has no native file drag. Upstream `dsh-v0.2.2-alpha.2` adds it across four areas:

| Area | Files in the development line | Lines |
| --- | --- | --- |
| Shared naming and request types | `packages/util/file-drag` (`src/index.ts`, `tests/names.spec.ts`, package metadata) | ~110 |
| Desktop native preparation | `apps/desktop/src/file-drag.ts`, `apps/desktop/src/file-drag-files.ts` | ~290 |
| Host resource authorization | `apps/desktop-host/src/file-drag.ts` | ~120 |
| Client plugin and feedback | `packages/client/ui-file-drag` (client entries, locales, tests) | ~600 |

The desktop half depends on shared Host and client APIs (`util-file-drag` types, a Host resource address contract, trusted-window IPC, temporary-file lifecycle). Copying only the desktop half produces dead code, which is why the port was deferred rather than partially applied.

Callers also have to change: the deliverables file actions and the workspace file listing decide what can be dragged, and the Client must fall back to a byte copy when the Host cannot authorize borrowing a resource.

## Stage 0: feasibility spike (must run first)

Build a minimal Electron window on the pinned base, attach a `dragstart` handler that calls `webContents.startDrag`, and try to drop the file onto a file manager:

| Session | What to record |
| --- | --- |
| X11 (Openbox or GNOME on Xorg) | Whether a drop produces a file, the MIME type the receiver sees, and whether the temporary file survives long enough |
| Wayland (GNOME or KDE) | Same observations, plus whether `startDrag` throws, no-ops, or delivers through `xdg-desktop-portal` |
| Both | Whether `app.getPath('temp')` is usable for the staged copy, and whether the drag can be cancelled without leaking files |

Exit gate: a documented yes/no per session. A "no" on Wayland does not block the feature; it changes the acceptance and the UI copy.

## Stages

| Stage | Deliverable | Exit gate |
| --- | --- | --- |
| 0 | Spike result recorded in this ADR | Every session has a recorded yes/no and the fallback decision |
| 1 | `packages/util/file-drag` plus the Desktop native path and a single caller (drag a deliverable out) | The file lands in the target with a correct name and type; temporary files are cleaned after a bounded grace period; an unowned renderer cannot request a drag |
| 2 | Host resource borrowing instead of a byte copy | The Host authorizes a resource by address, the main process verifies size and digest, and the caller falls back to bytes when authorization is unavailable |
| 3 | `packages/client/ui-file-drag` feedback and localization | A refused or failed drag shows localized feedback; a successful drag does not |

Each stage lands as its own patch with its own verification run. A stage that only adds code without a reachable caller is rejected in review, because the product-use policy requires every maintained package to have an effective consumer.

## Consequences

- The port gains a workspace dependency (`mime`) that the base does not have, so the lockfile changes. The package is small and already present transitively in the dependency graph, but the lockfile delta must be reviewed.
- Native drag is a privileged operation: the main process materializes user files on disk and hands paths to the OS. It must accept only owned-renderer requests, sanitize names, bound sizes and clean up.
- Wayland support is a product question, not a code question. The port must not advertise drag where the compositor cannot deliver it.
- The feature increases the surface that must be re-validated on every upstream migration, especially the shared `util-file-drag` types.

## Alternatives

| Alternative | Why not |
| --- | --- |
| Copy all four areas in one patch | A 1100-line cross-package change cannot be reviewed or bisected; a failure anywhere blocks every other fix |
| Only copy the shared naming helper | No consumer, so the product-use policy rejects it and the user-visible feature does not exist |
| Ship "save to Downloads" only | Simplest and works everywhere, but loses the interaction users expect; keep it as the fallback instead |
| Wait for a newer upstream release | The development line is alpha; rebasing the whole port onto it is a larger risk than a staged backport |

## Risks

- `startDrag` may be unavailable on Wayland, which would make the gesture X11-only. Mitigation: stage 0 decides before any port work.
- Temporary files may outlive the application if the drop target never reads them. Mitigation: the bounded read grace period from the development line, and cleanup on next start.
- A renderer compromise could request arbitrary files. Mitigation: the main process never accepts a path from the renderer; it accepts bytes or an address the Host has authorized.
- The lockfile change could disturb unrelated dependency resolution. Mitigation: one dependency addition, reviewed in isolation.

## References

- [Development line file drag](https://github.com/deepseek-ai/deepseek-harness/tree/dsh-v0.2.2-alpha.2/apps/desktop/src/file-drag.ts)
- [Desktop platform parity](../DESKTOP-PARITY.md)
- [Desktop follow-up](../DESKTOP-FOLLOWUP.md)
- [Pinned upstream base](../../ci/upstream-base-tag)
