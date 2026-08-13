---
id: "CHANGELOG"
title: "CHANGELOG"
domain: 50
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - general
links:
  adr: ""
  repo-harvest: ""
---
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
- **57-maintenance**: SQLite-Optimize (571), Recyclarr (572), Exportarr (573), Provisioning (574), Update-Notifier (575)
- **58-observability**: ntfy (581), CrowdSec native (582)
- **59-guardrails**: Assertions (591), Rollout (592), Emergency-User (593), No-Password-Auth (594), Backup-SSH (595), Security-Assertions (596)

## Phase 3 — Hardening + Bugfixes
- **Hardening-Profile**: UMask=0027 (base), networkPolicy (loopback/internet/proxy), InaccessiblePaths (/root /home /boot /etc/shadow /etc/ssh /run/secrets), mkPeerIsolation (fremde State-Dirs unsichtbar)
- **StateDirectoryMode = "0750"** (Vektor-DB Finding NIXH-40-MED: State-Dirs waren world-readable durch systemd-Default)
- **Jellyfin (551)**: render-Gruppe + DeviceAllow=/dev/dri renderD128 + VA-API-Env (LIBVA_DRIVER_NAME aus cfg.hardware.accel abgeleitet) + adminPasswordFile (LoadCredentialEncrypted, ADR-5510 First-Run)
- **Caddy (511) CrowdSec-Plugin**: falscher Plugin-Name korrigiert — `crowdsecurity/caddy-cs-bouncer` → `hslatman/caddy-crowdsec-bouncer` (Vektor-DB Sweep: Build-Blocker mit withPlugins)
- **Caddy Log-Format**: CrowdSec-Bouncer braucht Apache CLF (JSON-Logs nicht nativ parsebar) — Hinweis in 582
- **Recyclarr (572)**: Profil script → client (braucht Loopback für Arr-API)
- **Provisioning (574)**: Flag-Datei in eigenes StateDirectory=/var/lib/mediNix-state (0750, beschreibbar + isoliert)
- **Update-Notifier (575)**: client-Profil + nix-Daemon-Socket durchreichen (BindReadOnlyPaths)
- **Guardrails 593/594**: Präfix-Kollision behoben (593-no-password-auth → 594, 594-backup-ssh → 595)
- **524-systemd-credentials**: LoadCredentialEncrypted-Kompatibilität mit ProtectSystem=strict verifiziert (/run/credentials ist tmpfs)

## Offen (Phase 2)
- **Backup-Strategie Tier 1 State-Dirs**: 595-backup-ssh ist Basis, vollständige Backup-Rotation fehlt
- **CrowdSec-Plugin-Hash**: `lib.fakeHash` in 511-caddy.nix — vor erstem Build via `nix build` ersetzen (Build-Fehler zeigt korrekten Hash)
- **nix flake check auf q958**: noch nicht ausgeführt (q958 aus, Warte auf Freigabe)
- **Vollständige cross-service InaccessiblePaths für Playback-Module**: base.InaccessiblePaths (System-Pfade) drin, service-übergreifend nur bei Arr/SABnzbd
- **Provisioning-Automatisierung für Ntfy-Connections**: aktuell manuell (Settings → Connect → Ntfy)
- **Vektor-DB Grok-Chunks**: zu 5 Themen-Pivots verdichtet (granulare Suche limitiert), Chat-Chunks (4003) haben vollen Body

## Statistik
- 31 Commits (Initial → 70c43d9)
- 9 Domains, 37 Service/Infra-Module
- 28 ADRs (docs/)
- Audit: Num-dupes 0, keine hardcoded IPs, keine TODO/FIXME, fakeHash nur bei CrowdSec
