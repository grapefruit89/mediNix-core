# mediNix-project — Projekt-Konventionen & Tooling-Referenz

> **Zweck:** Schnelle Orientierung und verbindliche Arbeitsregeln für mediNix-core. Vor jedem explorativen Suchen (grep/find) hier nachschlagen.
> **Stand:** 2026-11-04
> **Prinzip:** 80/20 — bei Änderungen am Repository stets aktuell halten.

---

## 1. Pflicht aktualisieren (Referenz-Kategorien)

Alle Dateien und Ordner, die bei einer Referenz-Migration (z. B. Ordner-Umbenennung, Modul-Verschiebung) zwingend mitgezogen werden müssen:

| Pfad-Muster | Enthält | Bei Migration |
|---|---|---|
| `5*-*/*.nix` | Modul-Code (Dienste, Ingress, Security, Storage etc.) | Importe, Pfad-Referenzen, YAML-Header (`folder:`, `domain:`, `id:`) anpassen |
| `50-core/*.nix` | Zentrale Libraries (`derive`, `registry`, `service-contract`, `hardening-profiles` etc.) | Pfad-Referenzen, Typverträge, Registry-Einträge anpassen |
| `flake.nix`, `default.nix` | Root-Flake & Modul-Aggregation | Paket-Optionen, dynamische Modul-Imports, Checks prüfen |
| `mkdocs.yml` | Dokumentations-Navigation | Navigationslinks bei Doku- oder Modulverschiebungen anpassen |
| `README.md`, `AGENTS.md` (alle Ebenen) | Repo-Root, Domain-Ordner (`5*-*/`), `50-core/` | Tabellen, Mermaids, Folder-Beschreibungen, Tooling-Referenzen anpassen |
| `docs/INDEX.md`, `docs/RUNBOOK.md` | Service-Katalog, Triage-Playbooks | Dienstnamen, Pfade, Triage-Commands anpassen |
| `docs/guides/*.md`, `docs/concepts/*.md` | Architektur-Leitfäden, Speicherkonzepte, VPN | Dateipfade, Modulreferenzen anpassen |
| `docs/adr/*.md` | Architektur-Entscheidungen (**Zielzustand, keine Historie!**) | Modulnummern, Dateinamen, Quellenpfade (`Source:`) zwingend mitziehen |
| `scripts/*.py`, `scripts/*.sh`, `scripts/*.txt` | Generatoren, Audit-Linter, Allowlists (`corridor-allowlist.txt`, `check-nixmap.py` etc.) | Pfade in `SCAN_DIRS`, Allowlist-Dateinamen anpassen |
| `.github/scripts/*.sh` | CI-Helper (`export-folders.sh`) | Ordnernamen, Beschreibungen anpassen |
| `.agents/skills/*/SKILL.md` | mediNix-Core-relevante Skills (`medinix-core/SKILL.md`) | Domain-Ordner, Dienstnummern aktualisieren |
| `.claude/skills/*` | Symlink-Spiegel der Skills | Symlink-Ziele bei Skill-Restrukturierung mitziehen |

---

## 2. Nicht anfassen (historisch)

Dateien und Ordner, die einen fest datierten Stand dokumentieren und bei Migrationen unverändert bleiben:

| Pfad-Muster | Warum historisch |
|---|---|
| `docs/audit/**` | Audit-Berichte sind unveränderliche Momentaufnahmen zu einem festen Zeitpunkt |
| `CHANGELOG.md` | Reines Änderungsprotokoll, alle Einträge sind chronologisch datiert |
| `docs/AUDIT-LEDGER.md` | Ledger-Einträge sind historisch datiert und mit festen Commit-Hashes versehen |
| `todo/_archive/**` | Chat-Exzerpte, Rohdaten und historische Wissensablage |
| `docs/UPGRADE-MATRIX-uebernehmen-vs-aussenvor.md` | Historisches Vergleichsdokument aus Salvage-Audits (Stand 2026-07-30) |

---

## 3. Melden, nicht ändern (Grenzfälle)

> 🚨 **REGEL:** Wenn eine Datei aus der Kategorie **„Nicht anfassen"** (z. B. `docs/audit/`, `CHANGELOG.md`, `docs/UPGRADE-MATRIX-...`) bei einer Suche nach alten Pfaden Treffer liefert, wird dieser Treffer im Report als Befund aufgelistet, aber **niemals eigenmächtig geändert**.
>
> Der User entscheidet pro Fall. Niemals ungefragt historische Dokumente „mitziehen" oder manipulieren.

---

## 4. Tooling-Tabelle

Prüfskripte aus `scripts/`, die bei jeder Arbeit am Repository ausgeführt werden:

| Befehl | Arbeitsverzeichnis | Prüft was | Exit 0 bedeutet |
|---|---|---|---|
| `python3 scripts/nixmeta_check.py` | Repo-Root | YAML-Header (`id = Dateiname`, `folder = Ordnername`, Pflichtfelder) | Alle `.nix`-Header konform (0 Fehler) |
| `python3 scripts/medinix-meta.py check-docs` | Repo-Root | Ordner-`AGENTS.md`-Tabellen und Mermaids gegen Realität | Alle 10 `AGENTS.md` up-to-date |
| `python3 scripts/medinix-meta.py generate-docs` | Repo-Root | Schreibt `AGENTS.md`-Tabellen neu aus NIXMETA-Headern | Generator (schreibt 10 `AGENTS.md`) |
| `python3 scripts/check-nixmap.py` | Repo-Root | Modul-Abhängigkeiten, Import-Validität, UPG-Konformität | Keine unzulässigen Importe oder AST-Befunde |
| `python3 scripts/check_manifest_edge.py` | Repo-Root | Konsistenz zwischen `registry.nix` und `manifest` | 0 Fehler, Übereinstimmung Port/Dienst |
| `python3 scripts/gen_runbook.py --check` | Repo-Root | Prüft ob `RUNBOOK.md` synchron mit Modulen/Playbooks ist | `RUNBOOK.md` aktuell |
| `python3 scripts/gen_service_map.py --check` | Repo-Root | Prüft ob `docs/INDEX.md` Service-Map synchron mit Registry ist | `INDEX.md` aktuell |
| `nix flake check --no-build` | Repo-Root | Voll-Stack-Evaluation aller Checks, Formatter, Module | Alle Flake-Checks fehlerfrei (*Hinweis: prüft keine Doku-Vollständigkeit*) |

> ⚠️ **WICHTIGER AUFRUF-HINWEIS:** Prüfskripte immer mit `cd /home/moritz/repos/mediNix-core && python3 scripts/...` aufrufen, **nie** mit absolutem Pfad wie `python3 /pfad/zu/scripts/skript.py` aus einem fremden Arbeitsverzeichnis. Skripte wie `nixmeta_check.py` nutzen `os.getcwd()` und schlagen bei abweichendem Arbeitsverzeichnis mit `FileNotFoundError` fehl.

### Quellen (externe Referenzen)

Wenn eine Frage **nicht** lokal beantwortet werden kann (Option existiert nicht, Paket
fehlt, „wie machen es andere?"), steht die kuratierte Sammlung in:

- `/home/moritz/repos/mediNix-core/docs/NIXOS-RESOURCES.json` — maschinenlesbar
  (51 Einträge, 8 Kategorien, je `relevance`/`use_cases`/`why`/`banned_in_medinix`).
  Filtern mit `jq`, z. B. `jq '.entries[] | select(.relevance=="high")'`.
- `/home/moritz/repos/mediNix-core/docs/NIXOS-RESOURCES.md` — generierte Ansicht
  derselben Daten (nicht per Hand editieren; Generator ist
  `scripts/nixos-resources.py`).

**Reihenfolge bleibt: lokal messen → Sammlung → externe Quelle.** Die Sammlung ist
eine Referenz, keine Abhängigkeit; die projekt-spezifischen Upstream-Quellen stehen in
`docs/UPSTREAM-SOURCES.md`.

---

## 5. Modul-Anatomie

### Pflichtfelder im YAML-Header
- `id:` — Dateiname ohne `.nix` (Pflicht, `nixmeta_check.py` prüft)
- `folder:` — Ordnername der Dekade (Pflicht, `nixmeta_check.py` prüft)
- `domain:` — Dekade-Ziffer `0`–`9` (Pflicht)
- `title:` — Prägnante Kurzbeschreibung des Moduls (Pflicht)
- `status:` — `active` oder `draft` (Pflicht)
- `complexity:` — Komplexitätsstufe `1`–`5` (Pflicht für Dienstmodule)
- `last_reviewed:` — Datum im Format `YYYY-MM-DD` (Pflicht)
- `links.adr:` — Referenzierte ADR-Nummer (z. B. `ADR-537`) (Pflicht für Dienstmodule)

### Optionale Felder
- `provides:` / `requires:` — Bereitgestellte bzw. benötigte Module/Libraries
- `upstream_github:`, `upstream_docs:`, `nixpkgs_attr:` — Upstream-Quellen

### Was NICHT im Modul-Code steht
- `num` — steht primär in `50-core/registry.nix` bzw. `50-core/derive.nix`, nicht im Modul-Header (außer als interne Konstante, falls kein Registry-Daemon).
- `port`, `uid`, `stateDir` — strikt abgeleitet (`port = num * 10`, `uid = num * 10`, `stateDir = /var/lib/<name>`), niemals manuell im Modul hartkodiert.

---

## 6. Dekaden-Taxonomie

Definiert in `50-core/derive.nix` (`decadeNames`):

| Dekade | Ordner | Framework-Name | Rolle & Inhalt |
|:---:|---|---|---|
| `0` | `50-core` | `foundation` | Host-Baseline, Dezimal-Engine, Typverträge, Hardening-Profile |
| `1` | `51-ingress` | `access` | Caddy Reverse Proxy, Pocket-ID, DDNS, ACME, Landingpage |
| `2` | `52-security` | `security` | nftables Firewall, systemd-creds (sealed), VPN-Killswitch |
| `3` | `53-acquisition` | `ingestion` | *arr-Stack (Sonarr, Radarr, Lidarr, Prowlarr), Recyclarr (537), Provisioning (538) |
| `4` | `54-processing` | `processing` | SABnzbd Usenet-Downloader (541), Ondemand SSD→HDD Mover (543) |
| `5` | `55-playback` | `core-app` | Jellyfin Medienserver (551), Audiobookshelf (552), Navidrome (553) |
| `6` | `56-exposition` | `exposition` | Seerr Request-Management (561) |
| `7` | `57-maintenance` | `maintenance` | Storage/SetGID (570), SQLite-WAL (571), Restic Backup (576), Drift (577) |
| `8` | `58-observability` | `observability` | ntfy (581), Gatus (582), Exporter (585), Update-Notifier (588) |
| `9` | `59-guardrails` | `guardrails` | Cross-Domain-Assertions (591) |

> 💡 **Kern vs. Zulieferer:** Die drei Dienste in `55-playback` (Jellyfin, Audiobookshelf, Navidrome) sind der funktionale Kern des Systems. Alle anderen Dekaden existieren, um diesen Kern mit Content, Sicherheit, Netzwerk und Wartung zu versorgen.

---

## 7. Session-Start-Regel

Bei Start jeder Arbeit an mediNix-core:
1. Lies `/home/moritz/repos/mediNix-core/todo/README.md` (`## Aktueller Fokus`) und `/home/moritz/repos/mediNix-core/todo/backlog/<aktuelle>.md`.
2. Prüfe `git status` im Repo-Root (`/home/moritz/repos/mediNix-core`).
3. Bei Referenz-Migration: erst Kategorie aus Block 1/2/3 bestimmen, **DANN** grep. Nicht erst unstrukturiert suchen und dann raten.

---

## 8. NixOS-Geist (Philosophie & Architektur-Invarianten)

- **Deklarativ vor Imperativ:** Zustand existiert nur im Nix-Code. Keine manuellen Host-Eingriffe (`systemctl edit`, `useradd`), die beim nächsten Rebuild verpuffen.
- **Reproduzierbarkeit & Pure Functions:** Keine unspezifizierten Umgebungsvariablen oder versteckten Abhängigkeiten. Flakes und Lockfiles sind SSOT.
- **Systemd-First & Isolation:** Jeder Dienst läuft als gehärteter Systemd-Service via `service-factory.nix` (DynamicUser/statische UID, `ProtectSystem=strict`, `CapabilityBoundingSet`).
- **Minimale Overlays & Upstream-Treue:** Upstream-Pakete aus nixpkgs bevorzugen. Overlays nur wenn zwingend nötig.

---

## 9. Anti-Patterns (Was strikt verboten ist)

- **Keine Ad-hoc-Container / Docker-Bypässe:** Dienste laufen nativ unter NixOS oder in deklarierten Containern — niemals `docker run` manuell auf dem Host.
- **Keine Store-Mutationen:** Niemals versuchen, Dateien in `/nix/store` manuell zu bearbeiten oder mit `chmod +w` aufzubrechen.
- **Keine Hardcoded-Ports/UIDs außerhalb von Registry/Derive:** Alle IDs und Ports müssen durch `50-core/registry.nix` und die Dezimal-Engine (`num * 10`) abgeleitet werden.
- **Keine Vermischung von Code und Daten:** Appdata gehört nach `/var/lib/<name>`, Medien nach `/mnt/media`, Konfiguration in den Nix-Store.

---

## 10. Exploration — Finden statt Suchen

Die Regeln R1–R6 (lesen statt suchen, ein Tool-Call pro Frage, Ambiguität → STOP,
Tool-Kosten-Hierarchie, 3-Call-Budget, Dead Signals) stehen in der Repo-Verfassung:
**`AGENTS.md` §Regel 11**. Dort ist die einzige Quelle — diese Datei führt sie nicht
doppelt (Zeiger-Regel, `docs/CONVENTIONS.md` §4).
