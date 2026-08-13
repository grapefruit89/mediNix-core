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
- **Single Source of Truth (ADMIN-HANDOFF.md)**: Alle Host-Pflichten (Binary-Cache, Impermanence,
  Storage-Mounts, VPN, ACME, TPM-Secrets, SSH, nftables, Checkliste, Fallstricke) in genau einer
  MD-Datei konsolidiert. Flake ist 100% portabel ohne q958-Annahmen (q958-Referenzen aus Code/AGENTS entfernt).
- **Legacy-Bereinigung**: 57-maintenance/jellyfin.nix, profiles.nix, prowlarr.nix, seerr.nix, settings.nix gelöscht
  (inert, kein NNN-Präfix → nicht auto-importiert; veraltete Arrangement-Logik vor der Factory-Umstellung)
- **574-provisioning.nix**: `after =`-Unit-Namen korrigiert (waren `sonarr-5320.service` etc.,
  echte Factory-Units sind `sonarr.service` — Port steckt nur in StateDirectory, nicht im Unit-Namen)

## Phase 5 — Quick-Wins (SQLite/Timer/Cleanup)
- **542-sqlite-wal.nix**: zu `maintenance.sqliteOptimize` umgebaut (Optionen enable/schedule/services).
  Erweitert um PRAGMA optimize/ANALYZE/incremental_vacuum (WAL-Pragmas bleiben). StateDirs aus
  Registry abgeleitet (kein Hardcoding), timer-getrieben (weekly default). Robust gegen gesperrte DBs.
- **578-orphan-cleanup.nix** (NEU): SABnzbd incomplete + leere Fragmente unter mediaRoot/downloads
  entfernen (age > minAgeDays). Hart: nur Pfade unter storage.mediaRoot, nie Library.
- **577-drift-detection.nix**: Secret-Datei-Check ergänzt (konfigurierte Pfade, Inhalt nicht geloggt).
- **541-sabnzbd.nix**: network-online.target → network.target (Konsistenz). RuntimeDirectory (tmpfs)
  für incomplete/temp bereits vorhanden.
- **551-jellyfin.nix**: TemporaryFileSystem=/transcode (tmpfs) + RuntimeDirectory bereits vorhanden.
- **B2 RuntimeDirectory**: SABnzbd (`/run/sabnzbd-tmp`) + Jellyfin (`/transpile-transcode` tmpfs)
  bereits implementiert — dokumentiert, kein Neu-Bau nötig.

## Phase 6 — Encrypted DNS + VPN-Kill-Switch (fail-closed)
- **dnsMode Option** (`vpn.dnsMode` = vpn-plain / encrypted-hint): Modul implementiert keinen DoT-Client,
  Host liefert encrypted DNS (Variante A/B/C in ADMIN-HANDOFF §4a).
- **INV-VPN-01**: confinement → vpn.interface ≠ "" (Build-Bruch).
- **INV-VPN-03**: confinement → mindestens ein betroffener Dienst enable (sabnzbd || prowlarr).
- **INV-VPN-04**: dnsServers IPv4/IPv6-sauber (getrennte Mengen, kein hasInfix "." mehr).
- **INV-VPN-05**: POLICY — keine Public-Resolver in Sandbox (bewusste Policy, nicht nur Leak-Schutz).
- **525-usenet-confinement.nix**: RestrictNetworkInterfaces=[lo,vpnIf] + BindReadOnlyPaths (eigene resolv.conf)
  + InaccessiblePaths=[/sys/class/net] + echter IP-Leak-Check (Host-IP vs VPN-Interface via ipify) bereits vorhanden.
- **ADMIN-HANDOFF**: §4 netns-Formulierung korrigiert (UID-Routing + routeTables, KEIN NetworkNamespacePath),
  §4b Verify/ipify als Ergänzung (nicht Ersatz) eingeordnet, dnsMode-Semantik geklärt.

## Phase 7 — Policy-Routing ins Modul gezogen (ADMIN-HANDOFF auf Minimum)
- **526-vpn-policy-routing.nix** (NEU): UID-basiertes Policy-Routing deklarativ im Modul.
  Tabellen (UID=5410/5360) + routingPolicyRules (uidrange → lookup) + Default-Route
  `dev ${vpn.interface}` + fail-closed `unreachable`. Kein netns, kein Host-ip-rule-Kochrezept.
  Parametrisiert durch vpn.interface + Registry-UIDs. mkIf confinement.enable && vpn.interface != "".
- **ADMIN-HANDOFF §4**: von "baue dir uid rules" reduziert auf "Interface existiert + Name + DNS + Test".
  Host liefert nur noch WireGuard-Interface + Keys + vpn.interface/dnsServers + enable-Flags.

## Phase 7 — Policy-Routing ins Modul gezogen (ADMIN-HANDOFF auf Minimum)
- **526-vpn-policy-routing.nix** (NEU): UID-basiertes Policy-Routing deklarativ im Modul.
  Tabellen (UID=5410/5360) + routingPolicyRules (uidrange → lookup) + Default-Route
  `dev ${vpn.interface}` + fail-closed `unreachable`. Kein netns, kein Host-ip-rule-Kochrezept.
  Parametrisiert durch vpn.interface + Registry-UIDs. mkIf confinement.enable && vpn.interface != "".
- **ADMIN-HANDOFF §4**: von "baue dir uid rules" reduziert auf "Interface existiert + Name + DNS + Test".
  Host liefert nur noch WireGuard-Interface + Keys + vpn.interface/dnsServers + enable-Flags.

## Phase 8 — Private Benennungen bereinigt (portabel, keine Hausnamen als Default)
- **default.nix**: `vpn.interface` example `privado` → `wg0`; Domain example `m7c5.de` → `example.com`.
- **mediNix-cli/default.nix**: VPN-Heuristic `privado|wg|vpn` → `wg|vpn` (privado aus Code entfernt).
- **README.md**: Quickstart-Beispiel `m7c5.de` → `example.com`.
- **AGENTS.md**: q958-Kontext als "physischer Deploy-Host, aber portabel" neutralisiert.
- **rg-Scan**: `*.nix` sauber (kein privado/q958/m7c5/192.168). Nur generische Examples (wg0, 10.8.0.1, example.com).
- Bewusst unverändert: docs/*.md ADRs (historische m7c5.de-Entscheidungen bleiben), docs/ONBOARDING.md
  (q958-spezifisches Deploy-Handoff, bewusst host-spezifisch).

## Phase 9 — 576-backup gehärtet (Unit-Namen + enge Pfade + Retention)
- **576-backup.nix**: Unit-Namen in Pre/Post korrigiert (`sonarr-5320` → `sonarr.service`, plain).
  `paths` aus Registry-StateDirs abgeleitet (nur Media-StateDirs + secretsDir, nicht blind `/var/lib`).
  `pruneOpts` (7daily/4weekly/6monthly) + excludes (Transcodes/Caches/incomplete).
- **ADMIN-HANDOFF §2a**: Restic-Restore-Hinweis (init/snapshots/restore einzelnes StateDir).

## Phase 10 — Assertions konsolidiert (Doppelungen weg, Messages scharf)
- **599-cross-domain.nix**: INV-04 entfernt (redundant mit INV-VPN-01+02). INV-UMASK-01 Unit-Namen
  korrigiert (`sonarr-5320` → `sonarr.service`, plain). INV-VPN-05 → `[POLICY]-INV-VPN-05` (Label).
- **592-security.nix**: INV-BIND-01 entfernt (Duplikat zu INV-02 in 599). SSoT = 599.
- **590-registry.nix**: INV-04/INV-BIND-01 Messages entfernt. INV-VPN-01/03/04/05 + [POLICY]-INV-VPN-05
  Messages ergänzt (Deutsch: was kaputt + was setzen + ADMIN-HANDOFF-Verweis).

## Phase 11 — Timer/IO-Staffelung + Journal-Rate-Limits
- **543-mover.nix**: `*:0/15` → `*:0/30` (halbe Frequenz, IO-Schonung auf Tier-B).
- **571/577/578/542**: `RateLimitBurst=5` + `RateLimitIntervalSec=30s` in serviceConfig
  (Journal-Drossel bei Fehlerschleifen — kein Log-IO-Sturm). 577 auf mkMerge umgestellt.

## Phase 12 — Mover ondemand (kein Timer, HDD schläft)
- **543-mover.nix**: komplett umgebaut. Kein Calendar-Timer (OnCalendar/*:0/30 entfernt).
  systemd oneshot `mediNix-mover` mit df-Füllstand-Check + Extension-Whitelist + move nach Tier-C.
- **default.nix mover-Options**: `mode` (ondemand/off, default ondemand), `minFreeGb` (20),
  `mediaExtensions`, `stagingDir`, `archiveDir`, `action` (move/copy, default move).
  `retentionDays` entfernt.
- **ADMIN-HANDOFF §3a/§3b**: Mover-Handoff (Trigger, Whitelist, Playback-darf-HDD-lesen) +
  mergerfs-Beispiel (Host-seitig, NICHT im Modul — Portabilität).

## Phase 12b — Mover find-Fix + mediaRoot-Defaults + Hook-Handoff
- **543-mover.nix**: find-Logik geklammert (`-size +50M \( -name … -o … \)` — Precedence-Fix,
  sonst matchten alle Whitelist-Dateien egal Größe). Überflüssiges `rm` nach `mv` entfernt.
- **default.nix**: `stagingDir`/`archiveDir` Defaults an `storage.mediaRoot` angedockt
  (`/data/downloads`, `/data/library` statt `/var/lib/mediNix-*`).
- **ADMIN-HANDOFF §3a**: Hook-Pflicht (SABnzbd ExecPost → systemctl start mediNix-mover)
  + Library-Pfad-Warnung (ohne mergerfs neu scannen nötig).

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
