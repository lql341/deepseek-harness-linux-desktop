English | [中文](README.zh-CN.md)

# SCNet platform roadmap

Planning and handoff for SCNet authentication, the fixed `dsh-scnet` Bundle and platform clients around Linux Desktop. English is the default; each document links its Chinese version.

| Document | Purpose and maintenance |
| --- | --- |
| [Development plan](SCNET-PLATFORM-DEVELOPMENT-PLAN.md) | Phases A–G, dependencies, milestones and exit gates; update when scope or release requirements change |
| [Development handoff](SCNET-DEVELOPMENT-HANDOFF.md) | Current implementation, release evidence, limits and prioritized TODOs; update at milestone or repository handoff |
| [Handoff prompt](SCNET-HANDOFF-PROMPT.md) | Copy-ready starting instructions; refresh when base, workflow or release gate changes |
| [ADR-0001](ADR-0001-plugin-and-connector-architecture.md) | Desktop/server plugin versus mobile/native connectors; later decisions need a new ADR |
| [ADR-0002](ADR-0002-dsh-superagent-bundle.md) | Opt-in packaging decision for the dsh-superagent prototype, with compatibility evidence and phases |
| [ADR-0003](ADR-0003-file-drag-backport.md) | Staged backport of native file drag, starting with a Wayland/X11 feasibility spike |

## Status vocabulary

- `proposed`: not approved for implementation.
- `ready`: dependencies and owners known.
- `in progress`: implementation or verification active.
- `blocked`: named external dependency prevents progress.
- `done`: exit criteria and release evidence complete.

Every phase needs entry criteria, deliverables and an exit gate. Record protocol assumptions as dependencies. Credentials, account identifiers and private endpoints must not enter the repository. OAuth2 scope, callback, storage or capability-policy changes require an ADR update. Plans describe intent; behavior belongs to source and release pipelines. Update both languages together.

| Area | Source of truth |
| --- | --- |
| Linux Desktop patches, packaging and release | This repository |
| Bundle/Skill distribution | `dsh-scnet`, synchronized from canonical `scnet-hpc` |
| Shared Harness runtime and client APIs | Upstream checkout selected by `apply.sh` |
| OAuth2 and account linking | SCNet authorization service and externally versioned formal contract |
