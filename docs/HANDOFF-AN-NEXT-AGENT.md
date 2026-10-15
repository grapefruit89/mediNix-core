# HANDOFF AN DEN NÄCHSTEN AGENT — mediNix-core Audit (Branch `audit-2026-10-15`)

> **Lies dieses Dokument zuerst.** Es fasst alles zusammen, was in der Session
> vom 2026-10-14/15 gemacht, geprüft und entschieden wurde — inklusive der
> Fallen, die schon einmal Zeit gekostet haben.

---

## 0. TL;DR

- **Repo:** `mediNix-core` — deklarative NixOS-Homelab-Konfiguration (Flake, ADR-0000 „Dezimalrahmen").
- **Arbeitszweig:** `audit-2026-10-15` (dieser Branch). `main` ist unberührt.
- **Ergebnis:** Optionen-/Shell-/Format-Checks über das ganze Repo, **1 echter Fix**, Ordnung + Governance, `lib/`-Index, Bergung der Alt-Exporte (Ergebnis: **kein Wissensverlust**).
- **Größte offene Baustelle:** **L-006 — zwei konkurrierende Engines** (siehe §5). Braucht echten `nix`-Eval.
- **Harte Regel:** *messen → verstehen → erst dann (mit Backup) ändern.* Kein „Tabula rasa".

---

## 1. Umgebung (wichtig!)

- **Gerät:** Google Pixel 9, **Termux** (Android, aarch64). Pfade unter `/data/data/com.termux/files/home`.
- **KEIN Nix vorhanden:** `nix`/`nixd`/`nil` fehlen. → Wir können **Syntax, Optionen, Shell, Python** prüfen, aber **nichts evaluieren/bauen**.
  Alles, was „evaluiert das?" oder „baut das?" braucht, ist **nur auf einer Nix-Maschine** beweisbar.
- **Repo-Klon:** `/storage/emulated/0/Obsidian/mediNix-core` (Git, Remote `https://github.com/grapefruit89/mediNix-core.git`).
- **Keine schweren Builds** (Rust/Cargo/CMake/Gradle/Go) — ausdrücklich verboten.
- **SSH/SCP sind durch ein opencode-Plugin GESPERRT** — Host-Zugriffe nur über Wrapper (`uh`, `unraid-state`, `tower-cli`, `vl`, …). Nicht umgehen.

---

## 2. Werkbank (Tools, die hier funktionieren)

| Tool | Zweck |
|---|---|
| **`nixos`-MCP** | Live-Optionen/Pakete/Versionen (siehe §3) — 5 Tools |
| `~/bin/nixfmt` | Der **richtige** Formatter (nixfmt-rs). **Formatiert in-place; `-w` = Width, nicht „write"** |
| `~/bin/alejandra` | **FALSCHER** Formatter für dieses Repo (anderer Stil) — nicht benutzen |
| `shellcheck`, `shfmt` | Shell-Prüfung/Formatierung |
| `~/bin/nixcheck` | `nixcheck folders <repo>` (Ordner-Spam-Lint) + `nixcheck nixfmt <repo>` |
| noogle (lokal: `~/.local/share/noogle/noogle-data.json`) | Nix-Funktions-Signaturen |
| `ctx7`, `docs` | Doku-Abruf (Context7 / Jina) |

---

## 3. Der `nixos`-MCP (selbst gebaut, hier nötig)

`mcp-nixos` (PyPI) ist auf Termux **nicht installierbar** (zog `pydantic-core` → Rust-Build, verboten).
Ersatz: eigener **Node-MCP** unter `~/.local/share/nixos-mcp/` (reines JS, kein Build), registriert in
`~/.config/opencode/opencode.jsonc` als Server `nixos`.

**Tools:** `nixos_search`, `nixos_info`, `nixos_versions`, `noogle_search`, `wiki_search`.

**Wie es funktioniert (entscheidend fürs Nachvollziehen):** Es nutzt die **öffentlichen Read-only-Creds**
des NixOS-Search-Frontends (stehen im MIT-Repo `utensils/mcp-nixos`) gegen
`https://search.nixos.org/backend/<index>/_search`. Kanäle werden dynamisch über `_cat/aliases` aufgelöst
(z. B. `latest-52-nixos-unstable`).

```bash
# Beispiel (Token im Tool gekapselt):
nixos_search query="jellyfin" type="options" limit=5
nixos_info   name="services.jellyfin.enable" type="option"
nixos_versions package="hello" limit=5
```

> **Rollback MCP:** Eintrag `"nixos"` aus `opencode.jsonc` entfernen + `rm -rf ~/.local/share/nixos-mcp`.

---

## 4. Arbeitsweise (die Regeln, die diese Session geprägt haben)

1. **Quelle vor Behauptung.** Jede Aussage braucht eine Messung (Befehl/Aufruf). „vermutlich/sollte" = ungeprüft.
2. **Verstehen vor Ändern.** *Erst lesen* (was tut die Datei, wer benutzt sie), **dann** Befund + Optionen zeigen.
   Fragen sind **kein** Auftrag.
3. **Kein „Tabula rasa".** Nichts löschen/verschieben ohne Analyse + ausdrückliche Freigabe. Wenn, dann
   **verschieben mit Backup**, nie löschen. (In dieser Session wurde genau das einmal falsch gemacht und revertiert.)
4. **Backup → eine Änderung → messen → Rollback bereithalten.**
5. Nach **2** Fehlversuchen am selben Punkt: **STOPP**, Rohausgabe zeigen, fragen.
6. Secrets **nie** im Klartext ausgeben (Config-Dateien nur feldweise lesen).

---

## 5. Größter offener Punkt: **L-006 — Zwei Engines für dasselbe**

`lib/` enthält **zwei** Identitäts-/Unit-Systeme, die **dieselben** Optionen schreiben → potenziell
`conflicting definition values` (Eval-Abbruch):

| | **ALT (läuft überall)** | **NEU (halbfertig)** |
|---|---|---|
| Identität | `lib/registry.nix` (24 Nutzer) | `lib/decimal-framework.nix` (1 Nutzer) |
| Unit-Bau | `lib/service-factory.nix` (10) | (in decimal-framework) |
| Vertrag | `lib/service-contract.nix` (`medinix.manifest.*`) | liest `config.decimalFramework.manifest or config.mediNix.manifest` |
| `stateDir` | `/var/lib/<name>-<num*10>` (registry + contract) | `/var/lib/<name>` |
| `group` | `"media"` | `<name>` (UPG, GID=UID=num*10) |
| `home` | `stateDir` | `stateDir` |

**Konsequenz:** `decimal-framework` erzeugt `users.users.<name>`/`systemd.services.<name>` mit
**anderen** `stateDir`/`group` als die alte Kette → Widerspruch.
**Nur mit `nix flake check`/Eval auf einer Nix-Maschine auflösbar.** Vorher: **nicht** anfassen.

**Empfehlung für den nächsten Agent:** Mit einer Nix-Maschine zuerst
`nix flake check --print-build-logs` laufen lassen und feststellen, ob es bereits bricht. Dann **eine**
Richtung wählen (alte Kette behalten ODER decimal-framework zu Ende migrieren) — nicht beides.

---

## 6. Was in dieser Session konkret gemacht wurde

### 6.1 Bugs / Checks (deterministisch, repo-weit)
- **`nixfmt -c`** über alle `.nix` → sauber (bis auf das eine unten, gefixt).
- **Shell-Blöcke → `shellcheck`:** 29 echte Blöcke extrahiert. **Nur 1 realer Nit gefixt**:
  - `flake.nix` `buildPhase`: `cd docs` → **`cd docs || exit 1`** (SC2164).
  - `SC2154` (`513-cloudflare-dns.nix`) und `SC2206` (`578-orphan-cleanup.nix`) sind **Artefakte**:
    Nix-Interpolationen (`${…}`) sind kein Shell → **nicht** „fixen".
- **Optionen → `nixos`-MCP:** 99 Options-Pfade gegen `nixpkgs-unstable` geprüft. **1 echter Fund:**
  - `50-core/500-host-baseline.nix`: `services.journald.extraConfig` existiert auf **unstable nicht mehr**.
    **Fix:** Ersetzt durch einen **versionsunabhängigen Drop-in**
    `environment.etc."systemd/journald.conf.d/10-mediNix.conf"` (wirkt mit alter *und* neuer nixpkgs-API).
- **`.py` → `py_compile`:** alle OK.

### 6.2 Bergung (Alt-Exporte → Ist)
Alle Ordner bestände aus `~/…/Download/grapefruit89-medinix-core-*.txt` (Ordner-Dumps) gegen das Ist geprüft:
51-ingress, 52-security, 59-guardrails, `lib/`, `arr-provision/`, 551-jellyfin, **Voll-Dump 25.09. (314 Dateien)**.

**Ergebnis: KEIN Wissensverlust.** Die Exporte sind **ältere** Stände; das Repo ist überall **weiter**.
- 25.09.-Dump: 195 Dateien identisch, 117 evolviert, **2 „nur-Dump"** = beide **umbenannt/verschoben**:
  - `555-seerr.nix` → `56-anfragen/561-seerr.nix`
  - `573-exportarr.nix` → `58-observability/585-exporters.nix` (manifest-getrieben, generalisiert; wird via
    **Auto-Import** (`default.nix`, Regex `^[0-9]{3}-.*\.nix$`) geladen)
- Skills wurden nach `docs/agents/**` verschoben (nicht gelöscht).
- Archiv: `/storage/emulated/0/Obsidian/mediNix-core-bergung/`

### 6.3 Ordnung / Governance
- **`docs/CONVENTIONS.md`** — die Ordnungs-Regel (Ordner erst ab ≥3 Dateien, mit Allowlist).
- **`docs/agents/shared/scripts/folder_lint.sh`** — prüft die Regel (CI-tauglich, Exit≠0 bei Verstoß).
- **`.github/workflows/order-lint.yml`** — bindet den Lint in CI ein.
- Root aufgeräumt: 2 Migrations-Docs → `docs/`; überflüssige `.gitkeep` entfernt; lokale `__pycache__` weg.
- **`*/AGENTS.md` regeneriert** via `python 50-core/medinix-meta.py generate-docs`
  (7 aktualisiert, 3 neu: 54-transfer, 58-observability, 59-guardrails). **Niemals von Hand editieren** —
  nur oberhalb von `<!-- AUTO-GENERATED, DO NOT EDIT BELOW -->`.

### 6.4 `lib/`
- **`lib/README.md`** — Modul-Index (Zweck, Signatur, Nutzer-Zahl).
- `lib/decimal-framework.nix` nixfmt-formatiert; `scripts/migrate-uids.sh` shellcheck-clean.
- **4 nie verdrahtete Module** identifiziert (in *keinem* Export je referenziert) — **noch NICHT entfernt**,
  Entscheidung offen: `_helpers.nix`, `abc-tiering.nix`, `mk-secure-curl.nix`, `wait-for-api.nix`.
  - `abc-tiering` ist **überholt** von `cfg.storage.backends.hot/cold` (`default.nix`).
  - `mk-secure-curl`/`wait-for-api` waren für Shell-Provisioning gedacht; heutiges Provisioning ist **Python**
    (`lib/arr-provision/…`, Header in-process → kein argv-Leak) → aktuell nicht nötig.

---

## 7. Fallen & wichtige Fakten (spart dem nächsten Agent Stunden)

- **Nix-`''`-Blöcke ≠ Shell.** Inline-Shell in `.nix` ist gemischt mit Nix-Interpolation → `shellcheck`
  meldet oft **Artefakte** (`SC1073/1072/1036/1088`, `SC2154`, `SC2206`). Erst prüfen, ob es echte Shell ist.
- **`default.nix` auto-importiert** nur `NN-`-Ordner + Dateien `^[0-9]{3}-.*\.nix$`. `lib/` wird **nicht** auto-importiert.
- **`AGENTS.md` ist generiert** (siehe 6.3).
- **Zwei Smoke-Tests:** `lib/smoke-test.nix` (Eval-Assertions) + `tests/medinix-smoke.nix` (QEMU-VM-Test).
- **Stdout-Disziplin:** `.pyc`/`__pycache__` sind gitignored — nicht ins Repo.
- **`unraid`-MCP** war in dieser Umgebung „failed", `homeassistant` „disabled" — nicht relevant für die Repo-Arbeit.

---

## 8. Offene Punkte (Priorität)

| ID | Was | Braucht |
|---|---|---|
| **L-006** | Doppel-Engine auflösen | **Nix-Maschine** (Eval) |
| **L-007** | **Secrets rotieren** (ABS `tokenSecret`, Pocket-ID Client-Secret wurden in einem Log sichtbar) | Konsole/UI |
| L-015 | 17 Module ohne `complexity:`-Frontmatter (Index zeigt `unknown`) | Autoren-Wissen (Werte nicht ratbar) |
| L-018 | `lib/default.nix` als Single-Entry (`medinixLib`) — Entwurf steht in `lib/README.md` | Nix-Eval |
| L-019/20/21 | Entscheidung zu den 4 nie verdrahteten Modulen | Menschen-Entscheid |

**Vollständiges Ledger:** `docs/AUDIT-LEDGER.md` (L-001 … L-021).

---

## 9. Nützliche Befehle

```bash
R=/storage/emulated/0/Obsidian/mediNix-core

# Formatter
~/bin/nixfmt -c "$R"/lib/*.nix

# Ordner-Regel + nixfmt gebündelt
~/bin/nixcheck folders "$R"
bash "$R/docs/agents/shared/scripts/folder_lint.sh" "$R"

# AGENTS.md prüfen/neu erzeugen
python3 "$R/50-core/medinix-meta.py" check-docs
python3 "$R/50-core/medinix-meta.py" generate-docs

# Git (Android braucht safe.directory pro Aufruf)
git -c safe.directory="$R" -C "$R" status
```

---

## 10. Datei-Landkarte (was in diesem Branch neu/geändert ist)

- **Fix:** `50-core/500-host-baseline.nix` (journald-Drop-in), `flake.nix` (SC2164)
- **Neu:** `docs/CONVENTIONS.md`, `docs/AUDIT-LEDGER.md`, `docs/HANDOFF-AN-NEXT-AGENT.md`,
  `docs/agents/shared/scripts/folder_lint.sh`, `.github/workflows/order-lint.yml`, `lib/README.md`
- **Verschoben:** `ROADMAP-DEZIMALRAHMEN-MIGRATION.md`, `UPGRADE-MATRIX-uebernehmen-vs-aussenvor.md` → `docs/`
- **Regeneriert:** 10 × `*/AGENTS.md`
- **Ermittelt (nicht geändert):** die 4 nie verdrahteten `lib/`-Module; die Doppel-Engine (L-006)

---

*Erstellt am 2026-10-15 auf Branch `audit-2026-10-15`. Bei Unsicherheit gilt §4: messen, verstehen, fragen.*
