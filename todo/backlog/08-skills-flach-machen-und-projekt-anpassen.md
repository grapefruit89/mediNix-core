# Aufgabe 8 — Skills flach machen und projekt-anpassen

> [!CAUTION]
> **STATUS: GEPLANT — NICHT AUTOMATISCH AUSFÜHREN!**

---

## Problem

`agent/skills/` ist ein Wrapper mit nur einem Kind (`skills/`). `agent/` selbst hat keinen anderen Inhalt. Die Doppel-Ebene ist unnötig.

Innerhalb der Skills: `nix-packaging/` ist für dieses Projekt irrelevant. Du baust NixOS-Module, keine Package-Derivationen. Der Skill ist 600+ Zeilen „wie schreibe ich eine Derivation" — für den täglichen Gebrauch toter Ballast. Der einzige Fall, wo du ihn gebraucht hättest (`speedport-api` inline packen), ist erledigt.

`nixos-ecosystem/references/cross-platform.md` beschreibt nix-darwin, Nix-on-Droid, macOS, non-NixOS-Linux. Du hast einen Linux-Host. Irrelevant.

Was **fehlt**: eine Reference `medinix-project.md` mit den projekt-spezifischen Regeln, die der Agent aktuell raten muss. Der Agent hat beim `513-ddns`-Umbau die 5xx-Regeln, YAML-Header-Konventionen und Pflicht-Validierungen aus `AGENTS.md` gezogen — nicht aus einem Skill. Das ist eine Lücke. Wenn der Agent einen neuen Skill lädt, weiß er nicht, dass `id:` = Dateiname und `folder:` = Ordnername sein muss.

Zusätzlich: `.claude/skills/` enthält zwei nicht getrackte Symlinks auf `agent/skills/nixos-ecosystem` und `agent/skills/nix-packaging`. Sobald `agent/skills/` verschoben wird, sind diese tot.

---

## Ziel

`skills/` als Top-Level-Ordner (kein `agent/`-Wrapper mehr). Nur `nixos-ecosystem/` als aktiver Skill. `nix-packaging` archiviert (nicht gelöscht). `cross-platform.md` archiviert. Neue `medinix-project.md` mit den Projekt-Regeln. Alle vier Referenzdateien (`skills-lock.json`, `link-skills.sh`, `check_skills.py`, `skills-exclude.txt`) angepasst. `.claude/skills/`-Symlinks zeigen auf die neuen Pfade.

---

## Aktionen

### Vorarbeit — nur kartieren, keine Änderung:

- Alle Referenzen auf `agent/skills/` finden: in `.nix`-Dateien (falls packaged), `flake.nix`, Skripten, `docs/`, `AGENTS.md`, `CLAUDE.md`, `opencode.json`, `.claude/`. Vollständige Liste.
- Alle Referenzen auf `nix-packaging` finden (außer den Dateien innerhalb des Skills selbst).
- Alle Referenzen auf `cross-platform.md` finden.
- Den aktuellen Inhalt von `skills-lock.json`, `scripts/link-skills.sh`, `scripts/check_skills.py`, `scripts/skills-exclude.txt` lesen und auflisten, welche Einträge auf `agent/skills/` oder `nix-packaging` zeigen.
- `.claude/skills/` — die exakten Symlink-Ziele auflisten.

### Move 1 — `agent/skills/` → `skills/`:

- Ordner per `git mv` verschieben.
- `agent/` ist danach leer → löschen.
- Alle Referenzen aus der Vorarbeit umstellen.

### Move 2 — `nix-packaging` archivieren:

- `skills/nix-packaging/` per `git mv` nach `docs/audit/2026-11-03/agent-skills-archive/nix-packaging/` verschieben.
- Ordner `docs/audit/2026-11-03/` anlegen, falls noch nicht existent.

### Move 3 — `cross-platform.md` archivieren:

- `skills/nixos-ecosystem/references/cross-platform.md` per `git mv` nach `docs/audit/2026-11-03/agent-skills-archive/cross-platform.md`.

### Neu anlegen — `skills/nixos-ecosystem/references/medinix-project.md`:

Inhalt (auf Basis der Vorgaben strukturiert):

- Der 5xx-Rahmen: `num × 10 = port = uid = primaryGid`. `stateDir = /var/lib/<name>`. ADR-0000 als Konstitution.
- YAML-Header-Regeln: `id:` muss Dateiname ohne `.nix` sein, `folder:` muss Ordnername sein, `domain:` muss Dekade-Ziffer sein. `nixmeta_check.py` prüft das.
- Auto-Import: `default.nix` zieht alle `^[0-9]{3}-.*\.nix$` in `NN-*`-Ordnern automatisch ein. Dateien ohne 3-Ziffern-Prefix (z. B. `derive.nix`, `arr-settings.nix`) werden nur explizit importiert, nie automatisch registriert.
- Pflicht-Validierung vor Commit: `scripts/nixmeta_check.py`, `scripts/medinix-meta.py check-docs`, `scripts/check-nixmap.py`, `nix flake check --no-build`.
- Bau-SSOT: `50-core/service-factory.nix` (Systemd-Unit-Bau), `50-core/hardening-profiles.nix` (Hardening), `50-core/memory-policy.nix` (OOM/Cgroup), `50-core/registry.nix` (SSoT für Services/Ports/UIDs).
- Manifest-Vertrag: `medinix.manifest.<name>` mit `num`, `accessGroup`, `role` etc. (ADR-0010).
- Kebab-case-Pflicht: keine Großbuchstaben, keine Unterstriche in Moduldateinamen. Ausnahme: keine.
- Die Dekaden-Semantik: `0 foundation`, `1 access`, `2 security`, `3 ingestion`, `4 processing`, `5 core-app`, `6 exposition`, `7 maintenance`, `8 observability`, `9 guardrails`. 55 (playback) ist der Kern, alle anderen versorgen ihn.
- Kern vs. Zulieferer: Jellyfin, Audiobookshelf, Navidrome sind der Grund, warum das System existiert. Arr, SABnzbd, Seerr existieren, damit der Kern Content hat.

### `SKILL.md` ergänzen:

- In der Routing-Tabelle von `skills/nixos-ecosystem/SKILL.md` einen Eintrag ergänzen: medinix-spezifische Arbeit → `references/medinix-project.md`.

### Referenzdateien anpassen:

- `skills-lock.json`: Einträge auf `skills/` umstellen, `nix-packaging`-Einträge entfernen.
- `scripts/link-skills.sh`: Quell-Pfade auf `skills/` umstellen.
- `scripts/check_skills.py`: Suchpfad auf `skills/` umstellen, falls `nix-packaging` erwartet wurde: Erwartung entfernen.
- `scripts/skills-exclude.txt`: falls `nix-packaging` darin steht: entfernen.

### `.claude/skills/`-Symlinks fixen:

- Die zwei Symlinks auf `skills/nixos-ecosystem` und (falls noch vorhanden) `skills/nix-packaging` umstellen. `nix-packaging` ist archiviert — den Symlink entweder auf das Archiv umstellen oder entfernen, je nachdem was `.claude/skills/` erwartet.

### Validierung:

- `python3 skills/nixos-ecosystem/scripts/validate-skill.py skills/nixos-ecosystem/` — grün
- `python3 scripts/check_skills.py` — grün
- `bash scripts/link-skills.sh` — läuft durch
- `python3 scripts/nixmeta_check.py` — grün
- `python3 scripts/medinix-meta.py check-docs` — grün
- `nix flake check --no-build` — 61/61 grün
- `git status` sauber
- `find . -type l` — nur noch `todo/`-Symlinks, keine `.claude/skills/`-Toten

---

## Was nicht zu tun ist

- **Unterordner `references/`, `evals/`, `scripts/` innerhalb der Skills nicht anfassen.** Die sind Format-Vorgabe für Progressive Disclosure — nicht zusammenlegen, nicht umsortieren.
- **Skill-Inhalte nicht inhaltlich ändern** außer der `SKILL.md`-Routing-Tabelle.
- **Keine neuen Skills hinzufügen.** Nur die bestehenden bewegen, archivieren, ergänzen.
- **`nix-packaging` nicht löschen.** Archivieren, damit er bei Bedarf zurückgeholt werden kann.
- **Keine `.claude/skills/`-Symlinks löschen**, nur umstellen oder bewusst entfernen — die Entscheidung beim Agenten melden, nicht eigenmächtig treffen.
- **Kein Commit ohne Rückmeldung.**

---

## Akzeptanzkriterien

- `skills/` existiert als Top-Level, `agent/` weg.
- Nur `nixos-ecosystem/` in `skills/`.
- `nix-packaging` in `docs/audit/2026-11-03/agent-skills-archive/nix-packaging/`, vollständig erhalten.
- `cross-platform.md` in `docs/audit/2026-11-03/agent-skills-archive/`.
- `medinix-project.md` in `skills/nixos-ecosystem/references/`, mit allen oben genannten Stichpunkten.
- `SKILL.md`-Routing-Tabelle ergänzt.
- Alle vier Referenzdateien konsistent.
- `.claude/skills/`-Symlinks zeigen auf existierende Ziele.
- Alle sechs Validierungen grün.
- Kein Commit — auf Freigabe warten.

---

## Vorgesehene Commit-Nachricht

```
refactor(skills): flatten agent/skills to skills/, archive unused skills

- agent/skills → skills (drop agent/ wrapper)
- nix-packaging archived (project builds modules, not packages)
- cross-platform.md archived (single Linux host)
- new reference medinix-project.md: 5xx frame, YAML rules, validation gates
- SKILL.md routing updated
- skills-lock.json, link-skills.sh, check_skills.py, skills-exclude.txt updated
- .claude/skills symlinks retargeted
```
