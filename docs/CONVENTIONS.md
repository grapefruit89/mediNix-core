# CONVENTIONS — mediNix-core Ordnung

Diese Datei ist die **verbindliche Ordnungs-Regel** des Repos. Ziel: **kein
„ein Ordner pro Datei"-Wildwuchs**, sondern vorhersagbare Struktur.

## 1. Ordner-Regel (maschinell geprüft)

> **Ein Ordner existiert erst ab ≥ 3 Dateien.**

**Ausnahmen** (dürfen 1–2 Dateien, weil strukturell *vorgeschrieben*):

| Ausnahme | Warum |
|---|---|
| `NN-…/` (z. B. `51-ingress/`) | Domain-Ordner des Decimal-Frameworks (ADR-0000); `default.nix` **auto-importiert** sie. |
| Ordner mit `default.nix` | Nix-Paket-Layout (Einstiegspunkt + Code) |
| Ordner mit `SKILL.md` | Agent-Skill: pro Skill **ein** Ordner mit `SKILL.md` (+ `references/`). |
| `tests` · `scripts` · `references` · `templates` | Konventions-Orte |
| alles unter `.agents/` · `.github/` · `.git/` | Tooling-/CI-Struktur |

### Prüfen
```bash
# lokal
bash docs/agents/shared/scripts/folder_lint.sh .
```
Läuft zusätzlich in CI (`.github/workflows/order-lint.yml`) — Verstöße brechen den Build.

## 2. Weitere Ordnungs-Regeln

- **Keine losen Skripte im Repo-Root.** Dauerhafte Werkzeuge → `scripts/`
  (bzw. `docs/agents/shared/scripts/`). Wegwerf-Skripte → `scratch/` oder sofort löschen.
- **`*/AGENTS.md` ist generiert.** Nur **oberhalb** von
  `<!-- AUTO-GENERATED, DO NOT EDIT BELOW -->` von Hand editieren.
  Neu erzeugen: `python 50-core/medinix-meta.py generate-docs`
  Prüfen:        `python 50-core/medinix-meta.py check-docs`
- **Dokumentation nach `docs/`**, nicht ins Root (Root = nur Nix-Pflicht
  (`flake.nix`, `default.nix`, `flake.lock`, `repl.nix`, `statix.toml`), die
  Doku-Build-Konfiguration `mkdocs.yml` (sie muss neben `docs/` liegen, weil
  mkdocs ≥ 1.6 `docs_dir` == Konfig-Verzeichnis verbietet) + wenige Meta-Docs
  wie `README.md`, `CHANGELOG.md`, `LICENSE`).
- **Keine Build-Artefakte im Repo** (`__pycache__/`, `*.pyc` sind in `.gitignore`).

## 3. Wenn eine Ausnahme doch zu klein wirkt

Nicht flachlegen — **füllen** oder bewusst als Ausnahme dokumentieren. Ordner,
die nur wegen fehlenden Inhalts „spam" sind, gehören gefüllt (z. B. `scripts/`
ist für mehrere Werkzeuge gedacht) oder entfernt.
