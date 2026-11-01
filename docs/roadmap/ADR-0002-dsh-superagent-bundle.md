English | [中文](ADR-0002-dsh-superagent-bundle.zh-CN.md)

# ADR-0002: Ship the dsh-superagent prototype as an opt-in add-on

- Status: `proposed`
- Date: 2026-11-01
- Owner: Linux Desktop maintainers
- Scope: Linux Desktop packaging, profile composition, plugin management, release and support

## Decision

Do not make `dsh-superagent` a default desktop feature. Ship it as an opt-in add-on, and until that packaging exists, document the supported manual installation.

The prototype is a DSH bundle that turns one GitHub repository into a proactive agent service. It needs its own DSH profile, its own background process, a dedicated GitHub account and, optionally, a Feishu bot. Those requirements are incompatible with a default-on desktop bundle, which must work for a person who never configures GitHub or runs a service.

The recommended sequence is:

1. Document the manual `dsh plugin` installation and the compatibility patch the current prototype needs.
2. Add an offline, non-default add-on to the Linux package: the built bundle, a Settings action that installs it into a separate `superagent` profile, and a documented service lifecycle.
3. Only promote it to a first-class optional bundle inside the desktop profile if upstream adopts the prototype and supplies metadata, locale, icons and compatibility ownership.

## Context

### What the prototype is

`dsh-superagent` listens to GitHub and, optionally, Feishu. An allowed request becomes a work item; the bundle runs it in its own agent session and directory and answers in the original conversation, for example with a pull request. A web panel shows what needs a person. The repository describes itself as a research prototype, not an official product, and its engineering practices may differ from the Harness core.

Its package declares `dsh.bundle.patch`, a Web client plugin, worker and router presets, and peer dependencies on the Harness packages. It is not published to the public registry, so an offline package must carry either a tarball or a vendored build.

### What it requires at runtime

| Requirement | Why it is needed | Present in the Linux deb |
| --- | --- | --- |
| A dedicated DSH profile | The plugin changes process-wide `PATH` and git settings and needs independent restarts | No; the Desktop owns one profile |
| A separate `superagent` profile and service | The service must keep running while the desktop window is closed | No service unit or launcher is shipped |
| `gh` authenticated as an agent account | Reads notifications, pushes branches and opens pull requests | No; not a package dependency |
| `lark-cli` and a Feishu bot | Optional chat source | No |
| `tmux` and `python3` | The provided start, stop and status script uses both | Python is not guaranteed; tmux is absent |
| `git` worktrees and a local clone | One working directory per ticket | `git` is present, but no clone is provisioned |
| A model provider and credentials | Every executor session needs a model | Configured by the person, not bundled |
| A writable state directory | Database, lock, command shims and work trees | No; it must stay outside the package |

The prototype documentation also recommends a separate operating-system account, because both presets run with full access as the desktop user and a worker can read the operator home directory. A desktop add-on must state that boundary instead of hiding it.

### Compatibility evidence

The prototype pins its published peers and devDependencies to `0.2.1-alpha.2`. The pinned Linux base is `dsh-v0.2.1-rc.5`, and the published packages exist for all peers.

A local experiment replaced every `@deepseek-ai/dsh-*` pin with `0.2.1-rc.5` and `@deepseek-ai/schemastery` with `~3.18.5`, installed without a lockfile, and ran the package check:

| Check | Result against the pinned base |
| --- | --- |
| Dependency resolution | All Harness peers resolve to `0.2.1-rc.5`; the declared engine range is satisfied |
| Unit tests | 59 files and 1197 tests pass |
| Bundle build | `tsdown` emits the server, watch, client and type outputs |
| Typecheck | Fails with four errors in three files from two API drifts |

The two drifts are small and known:

- `ConfigFormSnapshot.mode` was removed after the prototype's baseline. The deployment panel and its fixtures still read `mode === 'memory'`.
- `webServer.port` is now optional until the listener binds, so a route handler that passes it directly no longer typechecks.

Neither drift changes behaviour, and both are a few lines to repair. They prove the prototype is close to the pinned base but not drop-in: an add-on must carry a compatibility patch and re-run this check for every base migration.

### Why not make it default

- A default bundle must work without credentials. This one cannot start usefully without a GitHub account, a clone and a model.
- The plugin wants its own profile and process. The desktop profile is owned by the application and must not be restarted or reconfigured by a plugin that also changes process-wide environment.
- A default-on service consumes credentials, network access and background compute on every installation. That is a product decision, not a packaging detail.
- The repository is explicitly research code. Shipping it switched on would make its defects look like desktop defects.

## Options considered

| Option | What ships | Advantages | Costs and risks |
| --- | --- | --- | --- |
| Documentation-only | A page describing manual installation and the compatibility patch | No package growth, no default risk, fastest | People must build the bundle and edit a profile; the deb stays unchanged |
| Offline add-on | The built bundle in resources, plus a Settings action and service setup | Works without registry access; still opt-in; no default surface | Adds optional dependencies and a background process; needs uninstall and upgrade handling |
| First-class optional bundle | The bundle in the runtime package set and the plugin manager's optional list | Best discovery and one-click enablement | Requires upstream-style metadata, icons, locale and product-isolation exceptions; co-hosting caveats remain |
| Vendor the source as a patch | A large patch under `patches/` | Reproducible from this repository alone | Hundreds of files of research code, upstream drift, review and security burden; not recommended |

## Consequences

- The Linux package gains an opt-in surface, not a default feature. Release notes must say that installing the add-on does not create a GitHub account or start a service.
- The add-on must keep its state outside the deb, under the user profile, and must not write credentials into the package or the repository.
- Uninstall and upgrade must stop the service, preserve or remove state deliberately, and leave other profiles untouched.
- A compatibility check against the pinned base becomes a maintenance task for every upstream migration.
- Support boundaries must be explicit: upstream owns the prototype, the port owns packaging and compatibility, and the operator owns accounts, credentials and isolation.
- The desktop's mandatory update policy and single-instance ownership must not be bypassed by the add-on.

## Implementation plan

| Phase | Deliverable | Exit gate |
| --- | --- | --- |
| 1 | A documentation page with manual installation, the two API repairs and the service requirements | Commands work against the pinned base and a fresh profile |
| 2 | A compatibility job that builds the prototype against the pinned base and runs its tests | The job fails on an API drift instead of discovering it after a release |
| 3 | An offline add-on tarball, a Settings install action and a service script | Install, start, status, stop and uninstall work on a clean Ubuntu 24.04 host |
| 4 | Optional promotion to a first-class bundle | Upstream supplies metadata, locale, icons, isolation exceptions and an owner |

Each phase requires its own evidence. A successful build of the prototype is not evidence that GitHub, Feishu or a model credential works, and neither is a screenshot of the panel.

## Risks

- The prototype runs with full access as the desktop user and can read the home directory. A misconfigured allow list turns a chat message into a code change.
- An agent GitHub account with write access to a repository is a supply-chain credential. It must not be shared with the human account.
- Background execution and GitHub polling can consume quota and compute without a visible window, which is contrary to the desktop's local-first expectations.
- The prototype's API surface can drift on any Harness release; the compatibility check must gate the add-on, not the desktop release.
- A separate profile duplicates model configuration and storage, which may confuse a person who expects one Desktop profile.

## Open questions

- Should the add-on create the `superagent` profile and write its patch, or only print the commands?
- Which service manager is authoritative on Linux: a systemd user unit, a desktop autostart entry, or the provided tmux script?
- Does the panel need a desktop menu entry and window, or is opening the loopback URL in the browser enough?
- Is a Linux identity for the update policy a prerequisite for any long-running add-on, or can the add-on follow the desktop update channel?

## References

- [Prototype repository](https://github.com/deepseek-ai/dsh-superagent-prototype)
- [Plugin and connector architecture](ADR-0001-plugin-and-connector-architecture.md)
- [Desktop follow-up](../DESKTOP-FOLLOWUP.md)
- [Pinned upstream base](../../ci/upstream-base-tag)
