# medinix-module-author

This is a consolidated skill merging the capabilities of: medinix-integrator, medinix-new-module

## --- Inherited from medinix-integrator ---

---
name: medianix-integrator
description: Take knowledge-store query results / gold standards and integrate them into the 50-mediNix boilerplate (decimal framework, YAML header, isomorphism, systemd-native).
---

# medianix-integrator

## Trigger
- "Baue das in mediNix ein"
- After github-pattern-miner / json-to-vector-db produced patterns
- Cherry-pick from reference repos into 50-mediNix

## HARD FOCUS RULE
Only integrate into 50-media (mediNix). Pull strengths FROM other layers (00-core, devNIX,
Nix-Grok, NixmitGROK) but write ONLY into /opt/data/50-mediNix/. Never deploy from obsidian copy.

## Conflict rule (github vs chat vs grok)
When sources disagree on a pattern:
1. Nix-Grok gold standard WINS (production SSoT, ADR-5000).
2. Then known-good NixOS github repo pattern (e.g. grapefruit89/mediNix).
3. Then chat-export (user's own history) — but chat may be outdated (iptables vs nftables).
   PREFER nftables / systemd-native / fail-closed.
4. Never import docker-based or netns patterns — mediNix is systemd-native isolation.

## Workflow
1. Query vec-knowledge-mcp (tool mcp_nixos_vec_search) or query.py for the target pattern.
2. Extract concrete Nix code blocks from results.
3. Rewrite my.* refs -> config.grapefruitMedia.* (or mediNix registry reference).
4. Add YAML header (id, domain:50-media, status, layer, purpose, tags).
5. Follow decimal framework: 51-ingress, 52-security, 53-acquisition, 54-transfer,
   55-playback, 56-requests, 57-maintenance, 59-guardrails.
   Port = Number*10, UID = 5000+Number, GID = 5000, UMask 0002.
6. Write to /opt/data/50-mediNix/...
7. Validate with nixos-repo-audit skill (build-check) BEFORE declaring done.

## Pitfalls
- Don't import docker-based patterns — mediNix is systemd-native.
- Keep decimal framework complete (no missing layer).
- No legacy cron / iptables / bash wrappers (ADR-509 assertions).
- Reference repos are gold-standard sources, NOT deploy targets.

## Output
Integrated, audited mediNix module in /opt/data/50-mediNix/.

## --- Inherited from medinix-new-module ---

---
name: medinix-new-module
description: "Use when creating a new 50-mediNix .nix service module."
version: 1.0.0
author: Hermes
license: MIT
---

# mediNix New Module — Creation Checklist

## Trigger
Use this skill the moment a NEW service module file is to be created under
`/opt/data/50-mediNix/`. Covers: number assignment, file placement, header,
hardening, portability. For pre-commit checks use `medinix-pre-commit`; for
build failures use `medinix-debug-nix`.

## 0. Constitution (load hub `nixos-medinix-authoring` first)
Read the canonical constitution there: decimal-framework derivation, the full
service map (Port=UID=ADR-prefix, GID=5000), the `511=Caddy` anchor rule, flat
structure rule, and the portability K.O. rule (no hardcoded IPs/machine-names).
This skill assumes you already know those.

## 1. Choose the Dienstnummer (3 digits, 500–599)
- Must be FREE — check `lib/registry.nix` AND the existing files. Two files
  with the same 3-digit prefix in different folders is a COLLISION (illegal).
- Derive: Port = Num×10, UID = Num×10 (= Port, isomorph), GID = 5000.
- ADR prefix = Port (e.g. ADR-5510 for Jellyfin). NEVER a Laufnummer (ADR-5001
  is INVALID).
- Anchors: `_0` fundament, `_1` zugang (511=Caddy, 512=Pocket ID), `_2`
  sicherheit, `_9` leitplanken. Free middle (559) = cross-service tuning, no
  own port → `ports: []`.

## 2. Place the file (flat, ONE file per service)
- Path: `<domain>/<NNN>-<service>.nix` e.g. `55-playback/551-jellyfin.nix`.
- NEVER nest deeper (`55-wiedergabe/...` breaks auto-import).
- NEVER split one service across two files (Caddy is ONE file: `511-caddy.nix`).
- `default.nix` (per-domain loader), `lib/*.nix` are legitimate exceptions
  (logic containers, not services).

## 3. NIXMETA header
Every module carries a metadata header (`# id:`, header comment, `requires:`)
consumed by the scan scripts. Match the prefix to the file number.

## 4. Bind hardening — DO NOT duplicate
- Pull the profile from `lib/hardening-profiles.nix`, never write your own block.
- Profile via `mkService` 4th arg:
  `network`(caddy/pocket-id/feishin/ntfy) · `dotnet`(sonarr..jellyseerr) ·
  `dotnet-gpu`(jellyfin) · `python`(sabnzbd) · `nodejs`(audiobookshelf/navidrome) ·
  `script`(cloudflare-dns + 57-maintenance timers).
- Pattern: `serviceConfig = lib.mkMerge [ profiles.<profil> { service-specific } ]`.
- GOTCHAS (read `references/hardening-profiles.md`): Jellyfin needs
  `PrivateDevices=false` (GPU/VA-API), .NET/Node JIT needs
  `MemoryDenyWriteExecute=false`, SABnzbd `TimeoutStopSec=30`,
  script profile needs `PrivateNetwork` override for localhost curl,
  LoadCredentialEncrypted + ProtectSystem=strict compatibility.
- Container isolation MUST be a list: `lib.mkMerge [ [ isolation ] {…} ]`,
  else it does not apply in the systemd unit.
- Loopback: `RestrictNetworkInterfaces = [ "lo" ]` is RIGHT;
  `IPAddressDeny = [ "any" ]` is WRONG (blocks 127.0.0.1 inter-service talk).

## 5. Caddy 3-way ingress (only for 511-caddy.nix)
Auto-generates from `lib/registry.nix`: `{svc}.local` (mDNS, avahi
`userServices=true`!), `{svc}.m7c5` (LAN), `{svc}.m7c9.de` (only if
`wan`/`stream=true`).

## 6. Context7 gate for ANY new NixOS option
Before writing/committing, verify each new NixOS option via Context7
(`nixos-context7-gate`): param `libraryId` (not `libraryName`), snippets from
`/websites/nixos_manual_nixos_unstable` or `/nixos/nixpkgs`. `services.sonarr`
etc. are NOT in core manual → verify via `systemd.services.*` patterns.
Noogle.dev has NO API — do not use.

## 7. Portability K.O. (final check)
No hardcoded IPs/CIDRs/hostnames in the portable module. No `192.168.x`,
`10.0.0.0/8`, `q958`, `jarvis`, `moritz`. LAN ranges / host paths belong in the
HOST config, exposed as `nullOr` options (default null) if needed.

## References
- `../nixos-medinix-authoring/references/dezimalrahmen-naming.md` (constitution)
- `../nixos-medinix-authoring/references/hardening-profiles.md` (profiles + GOTCHAS)
- `../nixos-medinix-authoring/templates/boilerplate-tree.md` (canonical tree)
- `../nixos-medinix-authoring/references/boilerplate-gotchas.md`

