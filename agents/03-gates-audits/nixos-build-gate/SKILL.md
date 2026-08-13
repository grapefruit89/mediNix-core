---
name: nixos-build-gate
description: Pre-commit gate for NixOS/mediNix module authoring.
---

# nixos-build-gate

Class-level workflow for authoring NixOS modules in the mediNix-core family. Encodes hard-won corrections from Aufgaben 5–12. Partner skills `nixos-context7-gate`, `nixos-repo-harvester`, `nixos-decimal-audit` are currently user-owned — adopt them via `hermes curator adopt <name>` so the curator can patch; this skill carries the corrected patterns meanwhile.

## 1. Context7 API — the param that bites
- Param is **`libraryId`**, NOT `libraryName`. Wrong param → empty result. Always:
  `query_docs(libraryId="/websites/nixos_manual_nixos_unstable", query="...")`
- Libraries: `/websites/nixos_manual_nixos_unstable`, `/nixos/nixpkgs`, `/websites/wiki_nixos_wiki`.
- "No documentation matched" → rephrase shorter, or conclude option isn't in that library.

## 2. Community `services.*` modules → 0 hits on the manual
`services.sonarr/jellyfin/radarr/ntfy-sh` are NOT in the NixOS manual. Fallback:
1. Package attrpath → `query_docs(libraryId="/nixos/nixpkgs", query="services.ntfy-sh enable port settings")`.
2. systemd hardening keys (`ProtectSystem`, `StateDirectory`, `ReadWritePaths`, `TemporaryFileSystem`, `SupplementaryGroups`, `LoadCredential*`, `EnvironmentFile`, `NetworkNamespacePath`, `BindReadOnlyPaths`, `Type=oneshot`, `ConditionPathExists`) → query GENERIC `systemd.services` family; applies to any native service.
3. Caddyfile directives (`flush_interval`, `remote_ip private_ranges`, `file_server`, `try_files`) are NOT NixOS options — injected via `services.caddy.virtualHosts.<host>.extraConfig`; syntax on caddyserver.com.

## 3. GitHub harvester — `label:nixos` fails for Servarr/Jellyfin/Prowlarr
Use `in:title,body` queries instead:
- Sonarr: `nixos in:title,body` → .NET EOL (#7442 → `permittedInsecurePackages`), remote-path perms (GID 5000).
- Jellyfin: `nixos OR gpu OR vaapi in:title,body` → VA-API context-reinit → `PrivateDevices=false` for `/dev/dri`.
- Prowlarr: `nixos OR dotnet in:title,body` → Open-Redirect CVE (inbound-only), SQLite WAL `cache_size=-20000`.
- SABnzbd: `nixos OR systemd in:title,body` → NO unix socket (TCP only), `-b 0` not `-d`, `TimeoutStopSec=30`, Python (no .NET EOL).
- Recyclarr: `nixos OR config in:title,body` → multi-instance split bug (#911: sync each `-i` separately), config `recyclarr.yml`.

## 4. Portability K.O. rules (portable modules)
- NEVER hardcode LAN IPs/CIDRs (e.g. `192.168.2.0/24`). Fix: empty file (`mkIf cfg.enable {}`) or option (`cfg.ssh.allowedLanCidr = nullOr str, default null`).
- No module may opine on the consumer's LAN. SSH hardening → HOST, not module.
- No inline secrets — `LoadCredentialEncrypted` / `EnvironmentFile` only.

## 5. Storage-tier correction
- Tier B (SSD) = working, Tier C (HDD) = library. *arr import B→C themselves; mover does NOT `mv`.
- SSD↔HDD hardlinks impossible → copy, so Tier B holds copy until cleanup.
- Mover = Tier-B cleanup: `find <complete> -mtime +retentionDays -delete` (default 7d), via `cfg.maintenance.mover.retentionDays`.

## 6. decimal-audit gap
- `nixos-decimal-audit` Both scripts are located in `../../shared/scripts/`. Run both.
- After every commit: audit. Num-dupes ~5–7 = known false-positives (service numbers in text); ignore.

## 7. patch-tool newline corruption (general)
When using `patch`, NEVER embed `\n` inside `old_string`/`new_string` for newlines — it inserts literal backslash-n. Use real line breaks. Avoid re-using the same `old_string` after a failed attempt in a loop; re-read the region and use a longer unique anchor.
