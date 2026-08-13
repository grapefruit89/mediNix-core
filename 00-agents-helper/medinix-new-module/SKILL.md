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
