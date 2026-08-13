# mediNix Repo-Harvester Findings (kondensiert, 2026-08-11)

Quelle: GitHub-Issues + Docker/README der Upstream-Repos, extrahiert via
`nixos-repo-harvester` Skill vor dem Schreiben der mediNix-core Module.

## Sonarr (532)
- **Harvester:** `sonarr.service` nutzt `-data=/var/lib/sonarr`, `UMask=002`, User=sonarr
- **Issues:** #7442/.NET6 EOL → nixpkgs `permittedInsecurePackages` nötig bei EOL-.NET
- #7686 remote-path Perms: GID 5000 auf Import-Ordner
- #8633 Import-Pfad-Rechte
- **NixOS:** State `/var/lib/sonarr-5320`, UID 5320, `ProtectSystem=strict`
- **.NET-EOL-Warnung:** Assertion in 591-assertions.nix (Host-Entscheidung, kein Modul-Default)

## Prowlarr (536)
- **Harvester:** Issues #2506 (.NET9 Migration), #2608 (Open-Redirect CVE CVSS 6.1 —
  inbound only via Caddy, nicht exposed), #1614 (SQLite WAL `cache size=-20000;
  journal mode=Wal` → bestätigt ADR-5700)
- **Basis für alle anderen Arr-Dienste** (Prowlarr zuerst schreiben)

## SABnzbd (541)
- **Harvester:** Kein Unix Socket (nur TCP), `-b 0` statt `-d` für systemd
  (Issue #1283/#992: `--daemon` bricht fork → `Type=simple` + `-b 0`),
  TimeoutStopSec=30 (#992: Kill-Loop bei Stop), Python-basiert (kein .NET-EOL)
- **State:** `/var/lib/sabnzbd-5410`, braucht `par2`+`unrar`
- **VPN-Confinement:** NetworkNamespacePath + BindReadOnlyPaths (systemd-native)

## Jellyfin (551)
- **Harvester:** VA-API/H.264 HW-Decode context reinit (#17133) → GPU-Passthrough
- **NixOS-Pflicht:** `PrivateDevices=false` (sonst /dev/dri nicht sichtbar),
  `tmpfs /transcode:size=4G` via TemporaryFileSystem, `SupplementaryGroups=["video"]`
- **3 Tiers:** SSD state/metadata, HDD media read-only
- **Port:** 5510 (NICHT 5410 wie in alter CLAUDE.md falsch stand)

## Recyclarr (572, Port 560)
- **Harvester:** .NET 10 (kein EOL-Problem), `recyclarr.yml` Config,
  `recyclarr sync` pro Instanz
- **Issue #911:** multi-instance split bug → per-instance sync via `-i` flag
- **State:** `/var/lib/recyclarr-5600`, Config `recyclarr.yml`

## Audiobookshelf (552) — aus CLAUDE.md Gold (nicht GitHub)
- **Port:** 5520 (NICHT 5420 wie in alter CLAUDE.md falsch stand)
- **seccomp-Fix:** `SystemCallErrorNumber="EPERM"` (verhindert stillen SIGSYS-Kill)
- **Tiers:** metadata rw, media (audiobooks) rw (ABS schreibt Cover)

## Navidrome (553) — aus CLAUDE.md Gold
- **Port:** 5530 (NICHT 5430 wie in alter CLAUDE.md falsch stand)
- **media-group:** `extraGroups = mkAfter ["media"]` (sonst stille leere Bibliothek)
- **OIDC:** via EnvironmentFile

## Feishin (554) — aus CLAUDE.md Gold
- **Kein Prozess:** statische SPA, Caddy `file_server` + `try_files {path} /index.html`
- **Port:** 5540 (3× falsch beurteilt historisch — ist statisch, nicht eigenständig)

## Allgemein (CLAUDE.md Gold, in ADRs migriert)
- Timing-Bug: Vorgaben erst nach 1. Start (DB-Marker statt Config-File)
- Jellyfin: `/var/cache/jellyfin` via tmpfiles
- "200 expected not 302" (ABS liefert SPA ohne Redirect)
- Ein Dienst der läuft beweist nicht dass deine Änderung ihn zum Laufen brachte
