# mediNix-core Changelog

Struktur-konformer, portabler NixOS-Mediastack (10-Domain-Architektur, systemd-native, kein Docker).
Alle Änderungen seit dem Initial Commit, gruppiert nach Phasen.

## Phase 1 — Foundation
- **flake.nix**: `nixosModules.default` Export + `checks.nixos-check` (dummy hardware, stateVersion 24.11)
- **default.nix**: vollständiges `options.grapefruitMedia` API (services, storage, security, observability, maintenance)
- **lib/registry.nix**: SSoT für Port/UID/GID aller Dienste (Port = folder×10, UID = Port, GID = 5000)
- **lib/service-factory.nix**: `mkService` + `mkNoPort` (execStart + stateDir + mkPeerIsolation + hardeningProfile)
- **lib/hardening-profiles.nix**: zentrale Profile (base, dotnet, dotnet-gpu, python, nodejs, network, script, client)
- **lib/abc-tiering.nix**: Tier-A/B/C aus `storage.mediaRoot`

## Phase 2 — Services
- **51-ingress**: Chameleon Caddy (caddyClass stream/internal/public/none), Pocket-ID, Cloudflare-DDNS
- **52-security**: nftables, Kernel-Hardening, SSH-Anti-Lockout, systemd-credentials (LoadCredentialEncrypted)
- **53-acquisition**: Arr-Stack (532-536: Sonarr/Radarr/Readarr/Lidarr/Prowlarr, native .NET)
- **54-transfer**: SABnzbd (541, `-b 0` no-daemon), SQLite-WAL-Tune (542), Tier-B-Cleanup-Mover (543)
- **55-playback**: Jellyfin (551) + Audiobookshelf (552) + Navidrome (553) + Feishin (554, static SPA)
- **56-requests**: Jellyseerr (561)
- **57-maintenance**: SQLite-Optimize (571), Recyclarr (572), Exportarr (573), Provisioning (574), Update-Notifier (575),
  Backup/Restic (576), Drift-Detection (577)
- **58-observability**: ntfy (581), CrowdSec native (582), Runtime-Guard (583), Post-Boot-Watchdog (584)
- **59-guardrails**: Assertions (591), Rollout (592), Emergency-User (593), No-Password-Auth (594), Backup-SSH (595),
  Security-Assertions (596), Forbidden-Tech (5A3), Ingress-Enforcement (5A4), Assertion-Quality (5043)

## Phase 3 — Hardening + Bugfixes (audit-driven)
- **Hardening-Profile**: UMask=0027 (base), networkPolicy, InaccessiblePaths, mkPeerIsolation
- **Jellyfin (551)**: render-Gruppe + DeviceAllow=/dev/dri + VA-API-Env + adminPasswordFile
- **Caddy (511) CrowdSec-Plugin**: `hslatman/caddy-crowdsec-bouncer` (korrekt benannt)
- **P0-Fixes (DeepSeek/Antigravity Audit)**:
  - pocketId-Registry-Key (`services."pocket-id"` statt `.pocketId`) — P0
  - secrets-Pfade (`cfg.secrets.*` statt `cfg.services.*.apiKeyFile`) — P0
  - dotnet UMask=0002 (Arr brauchen Gruppen-Schreibrecht) — P0
  - Jellyfin BindAddress 127.0.0.1 via Env (INV-BIND-01) — P1
  - API-Key-Leak in 574 (Header-File statt cmdline) — P0
  - Caddy global TLS-Direktive (INV-TLS-02) — P0
- **Neue Invarianten**: INV-VPN-02, TLS-02, UMASK-01, BIND-01, SEC-01, TECH-01/02/03, INGRESS-01
- **Hardening-Round-3**: SystemCallArchitectures=native, ProtectClock, ProtectHostname, RemoveIPC,
  OOMScoreAdjust (base 500 / network -500), journal-logging, network.target statt network-online.target

## Phase 4 — Architecture Upgrade (Shift-Left, devNIX-Pattern)
- **flake.nix**: Ratsche (nixos-check) + Decimal-Enforcer (ADR-0000 50-59) + Linting (nixfmt/statix/deadnix)
  + devShell + formatter (nixfmt-rfc-style)
- **lib/arr-settings.nix**: .NET Env-Vars Helper (mkArrEnv → {APP}__{SECTION}__{KEY})
- **Arr-Module (532-536, 561)**: deklarative .NET Env-Vars (server.port/bindAddress, auth.method, update.mechanism)
- **lib.pipe Auto-Import**: idiomatischer Modul-Loader
- **542-sqlite-wal.nix**: writeShellApplication (ShellCheck beim Build)
- **7 Quality Gates** in medinix-pre-commit skill (Community-Gold, API-Accuracy, SSoT, SRE, Dendritic, Hygiene, Traceability)
- **ADR-5043**: Assertion Quality Standard (was/warum/fix, fail-closed, jeder Bug → Invariante)
- **ADMIN-HANDOFF.md**: saubere Trennung Host-Verantwortung vs. Modul (Binary-Cache, Impermanence, Tier-HW, SSH/TPM)
- **Legacy-Bereinigung**: 57-maintenance/jellyfin.nix, profiles.nix, prowlarr.nix, seerr.nix, settings.nix gelöscht
  (inert, kein NNN-Präfix → nicht auto-importiert; veraltete Arrangement-Logik vor der Factory-Umstellung)
- **574-provisioning.nix**: `after =`-Unit-Namen korrigiert (waren `sonarr-5320.service` etc.,
  echte Factory-Units sind `sonarr.service` — Port steckt nur in StateDirectory, nicht im Unit-Namen)

## Offen (vor erstem Deploy)
- **CrowdSec-Plugin-Hash**: `lib.fakeHash` in 511-caddy.nix — vor Build via `nix build` ersetzen.
  Nur im Build-Pfad wenn `observability.crowdsec.enable = true` (default: false). Siehe docs/CROWDSEC-HASH.md
- **nix flake check auf q958**: noch nicht ausgeführt (q958 AUS, Warte auf Freigabe)
- **Provisioning-Automatisierung für Ntfy-Connections**: aktuell manuell (Settings → Connect → Ntfy)
- **INV-STORE-xx**: State-Pfad-Whitelist als Guardrail (Roadmap, Impermanence-Whitelist-Ansatz)

## Statistik
- 46 Commits (Initial → a4f4839)
- 9 Domains, ~42 Service/Infra-Module (inkl. Guardrails)
- 29 ADRs (docs/) + ADR-5043 (assertion-quality)
- Audit: Num-dupes 0, keine hardcoded IPs, keine TODO/FIXME, fakeHash nur bei CrowdSec (bewusster Platzhalter)
