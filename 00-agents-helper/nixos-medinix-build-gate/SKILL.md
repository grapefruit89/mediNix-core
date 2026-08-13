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
