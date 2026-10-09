# SCNet Platform Roadmap

This directory is the planning source of truth for integrating SCNet authentication,
the `dsh-scnet` bundle, and platform-specific clients around the Linux Desktop port.
The primary planning document is written in Chinese because the product requirements and
operational users are currently Chinese-speaking.

## Documents

| Document | Purpose | Update rule |
|---|---|---|
| [`SCNET-PLATFORM-DEVELOPMENT-PLAN.zh-CN.md`](SCNET-PLATFORM-DEVELOPMENT-PLAN.zh-CN.md) | A-G staged delivery plan, feasibility assessment, milestones, risks, and acceptance gates | Update when scope, dependencies, or release gates change |
| [`ADR-0001-plugin-and-connector-architecture.zh-CN.md`](ADR-0001-plugin-and-connector-architecture.zh-CN.md) | Decision record separating the desktop/server plugin from mobile/native connectors | Append a new ADR instead of rewriting the decision after implementation starts |

## Status vocabulary

- `proposed`: planned but not approved for implementation.
- `ready`: dependencies and owners are known; implementation may start.
- `in progress`: implementation or verification is active.
- `blocked`: a named external dependency prevents progress.
- `done`: acceptance criteria and release evidence are complete.

## Maintenance rules

1. Every phase has one entry criterion, one deliverable set, and one exit gate.
2. External protocol assumptions must be recorded as dependencies, never implied by examples.
3. Credentials, tokens, account identifiers, and private endpoints must not enter this repository.
4. Changes to OAuth2 scopes, redirect URIs, token storage, or cross-platform capability policy require an ADR update.
5. The roadmap describes implementation intent; executable behavior remains owned by the respective source repository and release pipeline.

## Repository ownership

| Area | Current source of truth |
|---|---|
| Linux Desktop packaging and runtime patches | `deepseek-harness-linux-desktop` |
| SCNet DSH bundle and Skill packaging | sibling `dsh-scnet` repository |
| Upstream Harness runtime and client APIs | `deepseek-harness` checkout used by `apply.sh` |
| OAuth2 authorization and account linking | SCNet authorization service; endpoint contract must be versioned externally |
