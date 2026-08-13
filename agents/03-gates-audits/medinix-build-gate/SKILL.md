# medinix-build-gate

This is a consolidated skill merging the capabilities of: nixos-build-gate, nixos-medinix-build-gate

## --- Inherited from nixos-build-gate ---

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

## --- Inherited from nixos-medinix-build-gate ---

---
name: nixos-medinix-build-gate
description: mediNix-core .nix gate harvest Context7 portability audit
---

# nixos-medinix-build-gate

**MANDATORY workflow for all mediNix-core `.nix` work (Aufgaben 5–12 and beyond).**
Encodes the proven gate sequence from the 2026-08-11 session. Load this alongside
`nixos-context7-gate`, `nixos-repo-harvester`, and `nixos-decimal-audit`.

## The Gate Sequence (in order, every file)

1. **REPO-HARVEST FIRST** (if writing a module for an external service):
   Load `nixos-repo-harvester`. Read README + `distribution/debian/*.service` +
   search issues for NixOS-relevant breakage (`.NET` runtime EOL, state-dir perms,
   CVEs). Extract: default port, state dir, user, UMask, known NixOS incompat.
   → No line of code before harvest.

2. **CONTEXT7-GATE** (every option you use):
   Load `nixos-context7-gate`. For each NixOS option run `query_docs` and paste
   the query + first snippet as proof. **No commit without evidence.**
   - Pitfall: `services.sonarr` / `services.radarr` / etc. are NOT in
     `/websites/nixos_manual_nixos_unstable` (community modules, not core manual).
     Query `/nixos/nixpkgs` for the package attr, and
     `/websites/nixos_manual_nixos_unstable` for `systemd.services.<name>.serviceConfig.*`
     (ProtectSystem, StateDirectory, ReadWritePaths, BindPaths). Native services
     use `systemd.services.X` directly, not `services.X`.

3. **PORTABILITY-CHECK** (HARD — K.O. criterion):
   NEVER hardcode network specifics in a portable module: no LAN IPs
   (192.168.x.x), no CIDRs (/24), no hostnames. A consumer would inherit the
   author's home-network rules. Fix: add a `nullOr str` option in `default.nix`
   (default null) OR leave empty (`mkIf cfg.enable {}` — host is responsible).
   SSH hardening, nftables rules, DNS, WireGuard endpoints are all affected.
   See ADR-21 (SSH port 22 is SSoT, host-scope).

4. **WRITE + CODE**:
   - UID = Port = ServiceNum × 10, GID = 5000 (ADR-0000 §4, isomorphism).
   - Bind 127.0.0.1:{port} only — never 0.0.0.0.
   - State: `/var/lib/{service}-{port}/`.
   - AUTH__METHOD = "External" if `cfg.authProxyPresent` else "Forms".
   - API key via EnvironmentFile / LoadCredentialEncrypted, never inline.
   - OnDemand socket if `cfg.onDemand.enable` (listenStreams 127.0.0.1:{port}).

5. **DECIMAL-AUDIT** (after every commit, before push):
   Load `nixos-decimal-audit`. Run both scanners. Fix real violations
   (wrong port in header, missing service number). Ignore known false positives
   (default.nix dup, port 22/443/80, 57-maintenance submodules).
   HARDCODED IP/CIDR in a module = ERROR, not false positive.

6. **COMMIT + PUSH** with Context7 proof + harvest summary in message.

## Why this exists
Session 2026-08-11: a hardcoded `192.168.2.0/24` Match-block in `523-ssh.nix`
was caught by the user as a portability K.O. — every consumer would get SSH
rules for the author's LAN. The gate sequence prevents this class of error and
the "option from training memory" drift that Context7-gating catches.

## References
- `references/context7-routing.md` — which Context7 library-ID for which option type (Arr services NOT in core manual).

## Companion skills (load together)
- `nixos-context7-gate` — option verification
- `nixos-repo-harvester` — external repo extraction
- `nixos-decimal-audit` — decimal-framework + portability audit
- `medinix-dezimalrahmen` — ADR-0000 number schema

