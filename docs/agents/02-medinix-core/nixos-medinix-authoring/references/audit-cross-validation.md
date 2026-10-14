# Audit Cross-Validation + Project Priority Levels (mediNix-core)

## Why this exists
Multiple AI audits (DeepSeek, Grok, Antigravity) were run on the 50-mediNix
codebase. Cross-validation against PRIMARY SOURCES (`default.nix`,
`lib/registry.nix`, `lib/hardening-profiles.nix`) showed audits contain
PHANTOM BUGS — suggestions wrong because the auditor misread the code.
Verify against the primary source before applying any audit finding.

## Verified real P0 bugs (apply these fixes)
1. **512-pocket-id.nix registry key mismatch** (Antigravity, P0)
   - Bug: `svc = (import ../lib/registry.nix { inherit lib; }).pocketId;`
   - Reality: `lib/registry.nix` defines `services."pocket-id"` (hyphen), NOT
     `pocketId` (camelCase).
   - Effect: `attribute 'pocketId' missing` → `nix flake check` aborts instantly.
   - Fix: `.services."pocket-id"`.

2. **524-systemd-credentials.nix wrong secret path** (Antigravity, P0 — WORST)
   - Bug: `secretMap` read `cfg.services.<name>.apiKeyFile or null` for all.
   - Reality: those options DO NOT EXIST. Secrets live under `cfg.secrets.*`:
     `sonarrApiKeyFile`, `radarrApiKeyFile`, `prowlarrApiKeyFile`,
     `lidarrApiKeyFile`, `readarrApiKeyFile`, `sabnzbdApiKeyFile`,
     `seerrApiKeyFile`, and **Jellyfin uses `jellyfinAdminPasswordFile`**
     (no `apiKeyFile`).
   - Effect: `secretMap` always `null` → NO service gets API keys mounted →
     all *arr start with empty credentials.
   - Fix: point every entry at `cfg.secrets.<name>ApiKeyFile`; Jellyfin →
     `cfg.secrets.jellyfinAdminPasswordFile`.
   - NOTE: `cfg.services.<name>.enable` (filter line) IS correct — only the
     PATH options were wrong.

3. **Feishin in registry as mkService** (Antigravity, P2)
   - Feishin is a static SPA served via Caddy, no own port. Use `mkNoPort`
     not `mkService`. Works but semantically wrong.

## Phantom bug (DO NOT apply — DeepSeek was wrong)
- **`vpn.dnsServers` → `vpn.dns`**: DeepSeek claimed drift. PRIMARY SOURCE
  (`default.nix` ~line 494) defines `vpn.dnsServers` under `vpn = { ... }`.
  There is NO `vpn.dns`. The three consumers (`525-usenet-confinement.nix`,
  `594-transfer.nix`, `599-cross-domain.nix`) all use `cfg.vpn.dnsServers`
  consistently. DeepSeek confused `cfg.dns` (DNS config, line ~369) with
  `vpn.dns`. Correct invariant: INV-VPN-02 = `vpn.dns` (without Servers) must
  NOT exist.

## Project priority levels (user-defined, Google/Jira convention)
- **P0** = `nix flake check` fails OR services start without credentials.
  No deploy possible. Examples: missing attribute (pocketId), empty secrets map.
- **P1** = services start but SSO/auth/provisioning broken. Fix soon after
  first deploy. Example: Pocket-ID on wrong port → SSO dead.
- **P2** = runs but architecture not clean (tech debt). Can wait.
  Example: Feishin mkService vs mkNoPort.

## Workflow
Given an audit: grep the exact lines it cites, open the primary source file,
confirm the option/attribute name literally exists, THEN patch. If the audit's
claimed option does not exist in the primary source, it is a phantom — note it
and move on. Never rename an option because an auditor said so.
