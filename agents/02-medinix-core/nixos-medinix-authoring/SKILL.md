---
name: nixos-medinix-authoring
description: "Constitution + service map for 50-mediNix. Load hub for any mediNix task."
---

# 50-mediNix — Constitution Hub

This is the SSoT constitution for the 50-mediNix media-stack module. The
operational workflows have been split into three focused skills — load the
relevant one for the task:

- **`medinix-module-author`** — creating a new service module (number, path,
  hardening, portability checklist).
- **`medinix-pre-commit`** — the gate before `git commit` / "fertig"
  (decimal scans, structural dup check, portability grep, git safety net).
- **`medinix-debug-nix`** — when `nix flake check` / `nixos-rebuild` fails
  (deployment order, assertions, known self-inflicted bugs).

Shared reference files (read directly, do not duplicate) live in
`references/` and `scripts/` of this skill dir:
- `references/dezimalrahmen-naming.md` — Verfassung ADR-0000: derivation,
  service map, anchors, session errors, Grok raw extraction.
- `references/hardening-profiles.md` — central systemd profiles
  (base/dotnet/dotnet-gpu/python/nodejs/network/script) + GOTCHAS.
- `references/boilerplate-gotchas.md` — condensed pitfalls.
- `references/nixos-module-bugs.md` — three self-inflicted Hermes bugs +
  build-time embedding pattern.
- `references/audit-cross-validation.md` — verified P0 bugs (pocketId, secrets
  path), DeepSeek phantom (vpn.dns), P0/P1/P2 levels.
- `templates/boilerplate-tree.md` — canonical directory tree.
- `../../shared/../../shared/scripts/scan_inconsistencies.py` / `../../shared/../../shared/scripts/scan_duplicates.py`.

## Pfad-Disziplin (hart)
- NEVER write to `/opt/data/knowledge/` (external docs, read-only).
- NEVER write to `/opt/data/github_repos/` unasked.
- Own files: `/opt/data/docs/{ADR,OPS,nix}/`, `/opt/data/50-mediNix/`
  (boilerplate SSoT in `lib/`).
- q958 configs land via scp under `/home/jarvis/mediNix/` ON THE SERVER.

## Dezimalrahmen (Verfassung ADR-0000 — einzige Wahrheit)
Jede Zahl aus der **dreistelligen Dienstnummer** abgeleitet:
- **Port = Nummer×10** · **UID = Nummer×10** (= Port, isomorph) ·
  **GID = Projekt×1000** (mediNix=5000).
- Immer auf `0` endend. 4-stellige Zahl die NICHT auf 0 endet = verfassungswidrig.
- **Anker:** `_0` Fundament · `_1` Zugang (511=Caddy!, 512=Pocket ID) ·
  `_2` Sicherheit · `_9` Leitplanken.
- **ADR-Präfix = Port** (ADR-5510). KEINE Laufnummern (ADR-5001 INVALID).
- **Flach:** `55-playback/551-jellyfin.nix` — KEIN Verschachteln.
- **Eine Datei pro Dienst** (dendritisch). Caddy = EINE Datei `511-caddy.nix`.

### Service-Map (UID/GID/ADR — immer alle 4 Felder)
| Service | Dienst | Port | UID | GID | ADR |
|---------|--------|------|-----|-----|-----|
| Caddy | 511 | 5110 | 5110 | 5000 | ADR-5110 |
| Pocket ID | 512 | 5120 | 5120 | 5000 | ADR-5120 |
| SABnzbd | 541 | 5410 | 5410 | 5000 | ADR-5410 |
| Sonarr | 532 | 5320 | 5320 | 5000 | ADR-5320 |
| Jellyfin | 551 | 5510 | 5510 | 5000 | ADR-5510 |
| Audiobookshelf | 552 | 5520 | 5520 | 5000 | ADR-5520 |
| Navidrome | 553 | 5530 | 5530 | 5000 | ADR-5530 |
| Jellyseerr | 561 | 5610 | 5610 | 5000 | ADR-5610 |
Isomorphie: Port=UID=ADR-Präfix, GID=5000. 511=Caddy (nie Pocket ID).

### Portabilität K.O. (hart)
Keine hardcoded IPs/CIDRs/Hostnamen in portablen Modulen. Kein `192.168.x`,
`10.0.0.0/8`, `q958`, `jarvis`, `moritz`. LAN-Ranges/Host-Pfade →
`nullOr`-Optionen (default null) in der Host-Config.

### Sprache
Chat Deutsch. Alle `.nix`, Inline-Kommentare, ADRs auf **Englisch**.

### q958-Regel
"Halt! Der q958 wird heute nicht gestartet" = ABSOLUTER Stop. Kein Deployment,
kein Reboot. Auf Planung/Docs/Boilerplate wechseln.

### Module-Kontext vs. Container-Kontext (HART — Portabilität)
Ein portables Modul läuft auf dem ZIEL-HOST (q958), NICHT im Hermes-Container.
- Dienste die lokal auf q958 laufen (ntfy, die *arr via Caddy) sind unter
  `127.0.0.1` erreichbar — das ist KORREKT und darf NICHT auf eine Tower-/LAN-IP
  geändert werden.
- Hardcoded `192.168.2.250` / Tower-IP in einem portablen Modul verletzt das
  Portabilitäts-K.O. (siehe oben) und ist ein echter Fehler, kein Fix.
- Hermes-Watchdog-Cron (läuft im Container) und 575-update-notifier.nix
  (systemd-Service auf q958) sind ZWEI VERSCHIEDENE Konstrukte — nicht
  verwechseln. Cron-URLs können Tower-IP zeigen; Modul-URLs nicht.

### AI-Audit Cross-Validation (HART — Phantom-Bugs)
Audit-Tools (DeepSeek/Grok/Antigravity) liefern Phantom-Bugs. VOR jeder
Audit-Übernahme: grep die zitierte Zeile, öffne die PRIMÄRQUELLE
(`default.nix`, `lib/registry.nix`, `lib/hardening-profiles.nix`), bestätige
dass die Option/der Attribut-Name wörtlich existiert. Existiert er nicht →
Phantom, ignorieren. Beispiele aus 2026-08-12:
- ECHT (P0): `512-pocket-id.nix` nutzt `.pocketId` — registry heißt
  `.services."pocket-id"` (Bindestrich). `nix flake check` bricht sofort.
- ECHT (P0): `524-systemd-credentials.nix` liest `cfg.services.*.apiKeyFile`
  (existiert nicht) → alle Secrets null → Dienste ohne Credentials.
  Richtig: `cfg.secrets.*` (sonarrApiKeyFile etc.; Jellyfin =
  jellyfinAdminPasswordFile).
- PHANTOM: DeepSeek "vpn.dnsServers → vpn.dns" — `vpn.dnsServers` ist KORREKT
  (default.nix ~Z494); `vpn.dns` existiert nicht.
Siehe `references/audit-cross-validation.md` für die vollständige Liste +
P0/P1/P2-Definition des Projekts.

### Projekt-Prioritäten (Google/Jira-Konvention)
- **P0** = `nix flake check` scheitert ODER Dienste starten ohne Credentials.
- **P1** = Dienste starten, aber SSO/Auth/Provisioning kaputt.
- **P2** = läuft, aber Architektur nicht sauber (Tech-Debt).
