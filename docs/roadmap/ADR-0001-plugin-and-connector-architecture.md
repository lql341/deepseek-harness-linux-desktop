English | [中文](ADR-0001-plugin-and-connector-architecture.zh-CN.md)

# ADR-0001: Separate plugins and platform connectors

- Status: `accepted`
- Date: 2026-10-09
- Owner: SCNet integration maintainers
- Scope: `dsh-scnet`, Linux Desktop, Android, iOS, HarmonyOS and domestic Linux platforms

## Decision

Keep `dsh-scnet` as the desktop/server Bundle in the Node/Cordis runtime and define a platform-neutral SCNet connector protocol. Android, iOS, HarmonyOS and restricted Linux clients use native connectors or controlled local services, without requiring the existing plugin's Python, Bash, SSH and `execFile` execution.

OAuth2 uses Authorization Code + PKCE. DeepSeek credentials are not sent to SCNet. Only after explicit user consent does a client obtain a SCNet access token from SCNet's authorization endpoint and link accounts through SCNet's supported API. Refresh tokens stay in OS secure storage; short-lived access tokens are supplied only to connector services that need SCNet access.

## Context

The current `dsh-scnet` index.mjs depends on Node subprocesses and invokes python3, Bash and SSH/SCP. Linux Desktop has an extensible Desktop profile and dsh runtime, but mobile platforms have different process, filesystem and network permissions. Copying the existing plugin to mobile would make permissions, credentials and artifacts difficult to control.

## Reasons

1. Share OAuth2, account state, region/scheduler selection, errors and token lifecycle through a common protocol.
2. Preserve deterministic tools, Skills and SSH on desktop.
3. Allow mobile to provide only SCNet OpenAPI, without promising local Bash, SSH or compute-node probes.
4. Replace authentication adapters without embedding Node/Python on every platform.
5. Keep authorization explicit: the model cannot read refresh tokens; plugins cannot approve high-risk actions for users.

## Rejected approaches

- Do not submit a DeepSeek API key, session cookie or OAuth access token as SCNet credentials.
- Do not hardcode user accounts, client secrets, internal URLs or default clusters in cordis.patch.yml.
- Do not execute arbitrary desktop-plugin shell commands directly on iOS, Android or HarmonyOS.
- A preinstalled plugin is installed/loadable software, not automatic SCNet account authorization.

## Consequences

- Maintain a versioned SCNet OAuth2/API description: issuer, authorization/token endpoints, scopes, PKCE requirements, redirect URI and account-linking API.
- Implement secure storage, callbacks and network policy separately for Desktop, Android, iOS and HarmonyOS.
- Maintain compatibility between dsh-scnet and connector versions; incompatible protocols must show actionable errors rather than silently degrade.
