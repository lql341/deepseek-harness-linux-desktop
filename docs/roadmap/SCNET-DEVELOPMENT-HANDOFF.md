English | [中文](SCNET-DEVELOPMENT-HANDOFF.zh-CN.md)

# SCNet development handoff

Updated 2026-11-01. Status: `in progress`. Repositories: Linux Desktop and `dsh-scnet`, with canonical shared behavior in `scnet-hpc`. This current handoff replaces contradictory older snapshots; Git history retains their full release and migration logs. See the [plan](SCNET-PLATFORM-DEVELOPMENT-PLAN.md) for phase exit gates.

## Current source and release

| Item | Recorded evidence |
| --- | --- |
| Upstream base | `dsh-v0.2.1-rc.5`, read from `ci/upstream-base-tag` |
| Bundle | `dsh-scnet@0.6.13`; connector vocabulary `0.1.0` |
| Last merged desktop backport | PR #6, main commit `c23d3cb6c849307d6eaaa2640016ec9b26436c8c` |
| PR verification | Run `41278271808`: ten suites/268 tests, full typecheck, build, deb audit and installed Xvfb session passed |
| Main verification | Run `41274912984`: passed |
| Verified public prerelease | `v0.2.1-rc.5-linux.1`, built from `b860c05d4f771aa105290394e5d05fd2311e571f` |
| Publish verification | Run `41269979995`: passed |
| Released deb SHA-256 | `8ee9616ee40db44330c4b77dbae24173d0a48665a3478d075ff7c168422888c6` |

The published prerelease does not contain patches 0007/0008/0009. Patch 0008 repairs Configure SCNet and passed the PR verification above. Patch 0009 adds local plugin operation history as a new candidate; its full CI and packaged producer/Worker acceptance remain pending. Query GitHub before treating this snapshot as latest. Use the [release page](https://github.com/lql341/deepseek-harness-linux-desktop/releases/tag/v0.2.1-rc.5-linux.1) and [Actions](https://github.com/lql341/deepseek-harness-linux-desktop/actions).

## Implemented behavior

- Fixed offline Bundle/Skill with version, license, integrity and runtime-descriptor audit. Desktop activates it by default; upgrade reconciliation preserves explicit disable and custom profile state. Web installation remains explicit.
- Local Bundle/Python/backend/credential-readiness diagnostics; isolated renderer IPC exposes no secret values. The settings-owned Configure SCNet action invokes the local setup wizard.
- Offline Authorization Code + PKCE S256, state/nonce/issuer/redirect checks, exchange/refresh request construction, token lifecycle and deduplicated refresh, structured errors, secure-storage adapters and one-time callback sessions in the connector.
- Protocol-neutral loopback listener with bounded lifetime, fixed callback path and generic browser responses. Offline `dsh://auth/scnet` parsing consumes registered state once and routes second-launch arguments; it does not perform token exchange.
- Linux Secret Service lookup/store/clear with fixed application/profile attributes and secret values passed through stdin; no plaintext fallback in the connector storage interface. Python injection respects `DSH_SCNET_PYTHON` then `SCNET_PYTHON`; OpenAPI and SSH readiness stay distinct.
- Settings-owned updates deliver Desktop and Harness together. Patch 0007 adds visible DevTools, report retrieval and owner-attached update views; [desktop follow-up](../DESKTOP-FOLLOWUP.md) lists remaining platform differences.
- Android/HarmonyOS provide source interfaces and offline conformance only, not APK/HAP applications or real authentication.

## Configure SCNet repair

The old launcher handed `app.asar/dsh/.../scnet.py` to external Python. Electron can read that virtual path, but Python cannot. Patch 0008 unpacks the entire SCNet Bundle, maps to the physical `app.asar.unpacked` path, requires an executable interpreter/terminal, waits for the terminal spawn result and retains completion/error output. Shell arguments preserve paths and localized text without interpolation.

Source tests cover packaged/development paths, archived-only rejection, missing prerequisites, asynchronous spawn failure and visible nonzero wizard exit. Package acceptance additionally compares every physical SCNet file with the archive and executes the packaged wizard's help through external Python. This establishes local script availability, not successful authentication or all desktop-terminal behavior.

## Historical evidence retained for reference

| Area | Historical runs |
| --- | --- |
| Ubuntu base install/session and Debian offline acceptance | `38233490072`, `38233720311` |
| Candidate upgrade and default/disabled/custom profiles | `38336572137`, `38660453246` |
| bwrap/Landlock and keyless smoke after launcher-build ordering repair | `38343669703` |
| Full preflight, draft build and exact draft-byte verification | `38506728139`, `38516862762`, `38521128578` |
| Old public release preflight/publish/independent verification | `38709921855`, `38729878217`, `38731899365` |
| Clean-runner host build ordering | `39201850282` |

Those checks apply to their historical inputs. The archived topic patches and old 0.2.0 results do not describe the current active series. Canonical `0.6.10` synchronization was recorded historically; current `0.6.13` canonical-to-consumer release evidence still needs its own record. Current artifact audits derive file counts from the actual package rather than hardcoding older 55-file claims.

## External dependency and security limits

The SCNet OAuth2/API agreement, approved issuer/endpoints/scopes/redirect/client registration and sandbox credentials are still missing. Do not invent endpoints or send DeepSeek API keys/cookies as SCNet credentials. No real login/refresh/revoke/link/OpenAPI result is claimed. Local status must not display authenticated solely because files exist.

An unpublished server-integration manual received on 2026-10-12, version `1.0.0`, describes HTTPS server-side handoff using appId/appSecret and account fields to obtain a redirect link. It is a candidate server protocol, distinct from public-client PKCE. Confirm required-field minimization, privacy, error/version semantics, link expiration/single-use/replay and allowed destinations in writing. Do not copy its example credentials, hosts or user data into this repository or directly call it from public clients.

Refresh tokens, access tokens, DeepSeek credentials, private endpoints and account identifiers must not enter releases, model context, session logs or ordinary configuration. Linux OpenAPI login does not establish SSH/cluster authorization.

## Prioritized next work

1. Finish candidate packaging/installed-session validation for the SCNet setup repair, including physical Python imports and terminal failure visibility. Verify real X11/Wayland click behavior separately.
2. Keep English/Chinese documentation paired and distinguish source, CI candidate and published release. Query exact commit/run/release/checksum before publishing; no unclassified failure may be ignored.
3. Continue complete feature backports with their providers, consumers and lifecycle tests; see desktop follow-up for CUA, file actions and plugin history dependencies.
4. Obtain M0 formal service contract and sandbox; then implement M2 real connector and M3 Linux login, keyring/lock/no-session/cleanup tests.
5. Extend mobile/distribution coverage after the connector gates, using [ADR-0001](ADR-0001-plugin-and-connector-architecture.md).

Shared SCNet changes start at canonical `scnet-hpc`, synchronize to `dsh-scnet` and `codex-scnet-hpc`, then reach Desktop. Do not treat Desktop patches or a downstream package as the canonical source. Store upstream modifications as new `patches/NNNN-*.patch` files, replay the complete series on a clean base, and merge only after relevant checks pass.
