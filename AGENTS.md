# mediNix-core — AGENTS.md (Verhalten & Invarianten)

> **Navigation:** Inventar, Matrix und O(1)-Einstieg in `map.md`. Diese Datei ist
> die Verfassungsquelle; `CLAUDE.md` und `GEMINI.md` sind reine Zeiger.
> Budget: ≤ 70 Z. / ≤ 500 W. / ≤ 4000 B. (`scripts/check_ai_cockpit.py`).

## 1. Reine lokale Entwicklung (absolut)
- **Kein Remote:** Zugriff auf Q958 oder externe Hosts ist verboten (kein SSH/rsync/ping).
  Builds, `nix flake check`, Tests und AST-Checks laufen ausschließlich lokal.
- Kein `--impure`, keine unreinen Quellen. Kein Push/Deploy ohne Freigabe.

## 2. Single Source of Truth für Arbeit
- **Scratchboard-Pflicht (R0):** Befunde immer zuerst in `SCRATCHBOARD.md` erfassen – kein ungefragtes Direkt-Patching.
- **Offene Arbeit lebt in `todo/tasks.json` (SSoT).**
- Befunde als Task erfassen (`id`, `title`, `kind`, `status`, `priority`, `effort`, `wave`, `source.ref` + `why`/`steps_open`), danach Validierung (`check_tasks.py`).
- Aufgaben abrufen via `medinix` CLI oder direkt in `todo/tasks.json`.
- Ideen/Erweiterungen gehören ins Feld `why` — nie spekulativ in den Code.

## 3. Lokale Verifikations-Leiter (vor jedem Commit)
- `bash scripts/verify.sh` — 14 Prüfungen inkl. `nix flake check` mit Builds.
  Muss grün sein vor jedem Commit (auch bei reiner Doku).
- `--fast` überspringt Builds und ist nicht commit-fähig; `--no-build` ersetzt es nicht.
- Rotes Gate = Ursache beheben, nie umgehen.
- CI-Beweis: `gh run list --limit 12 --json name,conclusion,headSha` prüfen.

## 4. Architektur-Invarianten (ADR-0000/0002/0003 — nicht verhandelbar)
- **Dezimalrahmen (UPG):** `Port = UID = Primär-GID = ServiceNum × 10`. Gruppe `media`
  (GID 5000) nur supplementär (`extraGroups`), nie Primärgruppe. Geteilte Ablagen:
  `2775 root:media` (SetGID). Flache Struktur: `XX-domain/NNN-dienst.nix`.
- **systemd-first:** journald, systemd.timer/-tmpfiles/-creds/-resolved, Socket-Activation,
  cgroup v2, nftables, oomd, `WatchdogSec`. Kein Wrapper, wo systemd reicht.
- **Zero Docker:** keine Container-Engine, kein `netns`. VPN-Confinement über
  `meta skuid` + Policy-Routing. Backends binden strikt an `127.0.0.1`.
- **Fail-closed:** Assertions brechen Build ab (`throw`), nie stille Warnungen.
- **Keine Inline-Secrets:** nur `LoadCredentialEncrypted` oder `EnvironmentFile`.
- **Chameleon Caddy:** globales Caddy aktiv → inject; sonst dedizierter `caddy-media`.
- **Zugangsmodell:** Hauptbenutzer strikt `medinix` — passwordless sudo, kein Root-SSH,
  TTY-Autologin. Konten-Assertion bricht Build ohne Konto ab (kein Lockout).

## 5. Arbeitsdisziplin
- **Pre-Check:** `.agent-state.json` und `docs/adr/llm-index.json` lesen.
  **Post-Record:** Fix/Refactor in `.agent-state.json` und `docs/UPSTREAM-SOURCES.md`.
- **Deklariert ≠ wirkt:** jede Option braucht einen Leser.
- **Maschinenlesbar:** NixOS-Optionen via `nix eval`, Units via `systemctl show`/`busctl` prüfen.
- **Finden statt Suchen:** bekannten Pfad gezielt lesen; `grep`/`find` nie ungerichtet über `/`.
  Nach 3 Calls ohne Ergebnis: stoppen und fragen.
- **Etablierte Begriffe:** Semantic Anchors aus `docs/TERMINOLOGY.md` / `docs/NIXOS-ANCHORS.md`.
- **Neue `.nix`-Dateien:** nixmeta-v3-Header (ADR-00); `scripts/nixmeta_check.py` erzwingt ihn.

## 6. Abschluss
- Antwort nennt am Ende: `RECHERCHE-CALLS: n | EXTERN: n`.
- Ein Auftrag ist fertig, wenn jedes Teilziel einzeln belegt ist — Teillücken nennen.
