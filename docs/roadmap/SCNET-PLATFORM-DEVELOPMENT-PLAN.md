English | [中文](SCNET-PLATFORM-DEVELOPMENT-PLAN.zh-CN.md)

# SCNet integration and platform development plan

Status: `in progress`. Updated 2026-11-01. Scope: Linux x64 Desktop first, then mobile clients and additional distributions. This current-state plan supersedes earlier snapshots; historical commits and run IDs remain in Git history and the [handoff](SCNET-DEVELOPMENT-HANDOFF.md).

## Progress

| Milestone | Complete | Remaining |
| --- | --- | --- |
| M0 | Unpublished server handoff manual reviewed separately from OAuth2 | Formal OAuth2/API/security agreement, issuer/endpoints/scopes/callbacks, client registration and sandbox credentials |
| M1 | Fixed `dsh-scnet@0.6.13`, offline Bundle/Skill, default activation, preserved disable/custom profiles, local diagnostics and package audit | Verify SCNet setup repair in candidate bytes and record current canonical synchronization evidence |
| M2 | Offline PKCE, callback validation/one-time consumption, structured errors, credential adapters and loopback listener | Real login, refresh, revocation, account linking and read-only OpenAPI against the formal sandbox |
| M3 | Local readiness, Secret Service interface, offline `dsh://auth/scnet` parsing and single-instance forwarding | Login/refresh/logout/link/unlink UI/IPC, locked or absent keyring and credential cleanup acceptance |
| M4–M6 | Contract-first Android/HarmonyOS scaffold with offline conformance | Native applications, additional CPU/distribution matrix, security response and stable release evidence |

Do not mark real SCNet authentication complete while M0 is blocked. An installed Bundle grants no account permission. OpenAPI authentication and SSH keys/cluster configuration are independent states.

## A. Scope and governance

**Entry:** identify maintainers and the external service owner. **Deliverable:** versioned service/capability/security agreement. **Exit:** written SCNet agreement, security review, registered client IDs, redirect URIs and scopes required by the following phases.

SCNet must supply issuer, authorization/token/revoke endpoints, JWKS or introspection, PKCE support, scope semantics, token lifetimes, account linking, regions/schedulers, errors, rate limits and service/privacy terms. DeepSeek must define permitted account identity access, third-party linking, client/callback policy and protected credential fields.

Authentication changes need an ADR and compatibility matrix; credential changes need migration, revocation and rollback instructions. Ship docs/tests/packages/install instructions at matching versions. Do not host a private SCNet backend in public clients, bypass quotas, or imply SSH/compute-node access on every platform.

## B. Fixed desktop Bundle

**Entry:** pinned package, dependency inventory and legal distribution rights. **Deliverable:** offline production package set and profile reconciliation. **Exit:** no-network startup with active Bundle/Skill, actionable unauthenticated state and no credentials in the artifact.

Desktop initializes a fixed Bundle and preserves explicit disable/custom profile choices across upgrades. Loading failures must be visible and prevent acceptance; enterprise deployments can disable it. Record versions, integrity and licenses. First startup must not download npm packages. Web keeps explicit installation through `dsh plugin --profile web add dsh-scnet`.

Validate PATH, Python, Bash, SSH/SCP, proxies and certificate chains. Respect configured Python paths rather than assuming a system `python3`. The SCNet setup wizard must use physical unpacked files when invoked outside Electron; package tests must execute external Python without a network login.

## C. OAuth2 and connector

**Entry:** M0 agreement and sandbox credentials. **Deliverable:** versioned connector and platform secure-storage adapters. **Exit:** sandbox login/refresh/revoke/link plus replay, concurrency, scope and redaction tests.

Use Authorization Code + PKCE S256, state, verifier and nonce, a system browser, and validated issuer/redirect/code. No implicit flow or public-client secret. Account linking is explicit user-approved linking through SCNet's documented API; never send a DeepSeek API key/session cookie as SCNet credentials. Without a linking API, provide separate login or a controlled backend flow.

Desktop uses Linux Secret Service, macOS Keychain or Windows Credential Manager; Android uses Keystore-protected encryption, iOS Keychain and HarmonyOS system secure storage or a controlled backend session. Keep access tokens short-lived and in memory. Refresh tokens must not reach Skills, model context, shell environment or ordinary logs/config. Support expiry, deduplicated concurrent refresh, revocation, unlink and complete cleanup.

Version operations `login`, `status`, `refresh`, `logout`, `listRegions`, `listSchedulers`, `listQueues`, `submitJob`, `getJob`, `cancelJob`, `listFiles`, `transferFile`. Declare scopes, remote mutation, dry-run and platform requirements for each. Test wrong issuer/redirect, reused state, expired/revoked token, refresh races and excessive scopes.

## D. Linux Desktop

**Entry:** fixed Bundle plus accepted connector. **Deliverable:** settings/IPC integration and Debian package. **Exit:** Ubuntu 24.04/Debian 13 install/upgrade/uninstall, no-credential startup, Bundle loading, real login/refresh/logout, keyring and callback tests.

Keep user profiles, credentials and custom clusters during upgrades. Bind `dsh://auth/scnet` or loopback `127.0.0.1` callbacks to the current user's one-time session; reject cross-profile token writes. Offline callback parsing currently does not exchange tokens.

Expose dependencies for OpenAPI, SSH, Slurm, files and Notebook: network, Python/Bash, keys, cluster profile and user authorization. Start with deb; AppImage/RPM need their own glibc, X11/Wayland, Secret Service, CPU and protocol-registration acceptance. Do not write tokens into ordinary `~/.dsh` JSON/YAML or session logs.

## E. Android

**Entry:** stable OAuth2/connector and Android toolchain. **Deliverable:** native HTTPS OpenAPI connector. **Exit:** supported OS/ARM64 builds and weak-network, process-death, replay, refresh-race, clock-skew, account-switch and uninstall-cleanup tests.

Use Custom Tabs/AppAuth-compatible PKCE, app links and Keystore-protected storage. First release covers OAuth2 and HTTPS regions/queues/jobs/files, not local Bash, SSH, arbitrary Python or compute-node probes. Remote DSH Host use must explicitly define data residency, session binding, reconnection and confirmation. High-risk actions require explicit user confirmation.

## F. iOS, HarmonyOS and more Linux targets

**Entry:** shared connector and supported toolchains. **Deliverable:** platform adapters and a three-state capability matrix: `supported`, `unsupported`, `requires-remote-host`. **Exit:** platform install/upgrade/uninstall, login/revoke, minimal API, cleanup, recovery and rollback evidence.

Use ASWebAuthenticationSession/system browser and Keychain on iOS; address App Store privacy, encryption-export and background rules. Arbitrary shells and persistent background processes are unsupported or remote-host capabilities. HarmonyOS uses system authentication, ArkUI/networking and secure storage; validate TLS, links, callbacks and account switching before adding a local connector. Do not copy the Node/Python/Bash desktop runtime.

Expand from Debian/Ubuntu deb to RPM/domestic distributions and x86_64/ARM64/LoongArch only with measured glibc, sandbox, X11/Wayland, Secret Service, Python, SSH and installer compatibility. Put unsupported capabilities in release notes and omit unsupported UI entries.

## G. Verification, security and release

**Entry:** owners and compatibility matrix across repositories. **Deliverable:** automated checks, rollback artifacts and operational documentation. **Exit:** M6 stable evidence for every advertised platform/capability.

Canonical `scnet-hpc` owns shared behavior; synchronize to `dsh-scnet` and `codex-scnet-hpc`, then update Desktop/mobile consumers. Record source commits, package versions and minimum compatibility. Desktop patches are maintained here; shared Harness APIs remain upstream.

Test Bundle contents/Cordis/peer dependencies/Skill versions; OAuth2 state/PKCE/scopes; connector read/write/dry-run/timeout/retry/idempotency; Desktop profile/deep-link/keyring/package upgrades; mobile callbacks/storage/lifecycle/network/account switching. Credentials and private endpoints must never enter releases, sessions or logs. Minimize telemetry and exclude account IDs, cluster hosts, job IDs and private paths.

Progress `alpha -> beta -> stable`: offline desktop and OAuth2 sandbox, then Linux public testing, then mobile/distribution expansion. Retain rollback packages, data/credential migration instructions, license inventory, threat model and vulnerability response. Only completion evidence warrants `done`.

## Delivery order

1. Continue offline Desktop repairs and bilingual documentation while M0 is blocked.
2. Freeze the formal service agreement and sandbox; do not use unpublished example endpoints.
3. Complete M2 real connector, then M3 Linux login and secure storage.
4. Complete M4 Android, M5 additional platforms and M6 operational/stable gates.

Current source and release distinctions are in [desktop follow-up](../DESKTOP-FOLLOWUP.md); practical build/acceptance steps are in the [Linux guide](../../LINUX-DESKTOP.md).
