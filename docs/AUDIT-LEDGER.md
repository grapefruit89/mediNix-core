# mediNix-core — AUDIT-LEDGER

**Zweck:** ein Gedächtnis für jeden Befund. Nichts wird „im Kopf" gefixt.
**Regel pro Zeile:** Backup → **eine** Änderung → messen → Rollback bereithalten.
**Quelle** = die *Messung* (Befehl/Tool), nicht die Vermutung.

Legende Spur: `BUG` · `BERG` (Bergung Alt→Neu) · `ARCH` · `SEC` · `OPT`
Status: `OPEN` · `WIP` · `DONE` · `WONTFIX` · `BLOCKED`

| ID | Spur | Datei:Zeile | Befund | Quelle (Messung) | Fix / Entscheidung | Status | Rollback |
|---|---|---|---|---|---|---|---|
| L-001 | BUG | `50-core/500-host-baseline.nix:107` | `services.journald.extraConfig` auf `nixos-unstable` entfernt (nur noch `settings.Journal`) | `nixos_info` (Index `latest-52-nixos-unstable`), `flake.lock` rev `ec2d622de0` (2026-08-17) | → `environment.etc."systemd/journald.conf.d/10-mediNix.conf"` (Drop-in, gilt alt+neu) | DONE | `…/mediNix-backup/500-host-baseline.nix.orig` |
| L-002 | BERG | `51-ingress/518-landingpage.nix` | `legacyTiles`/`legacyNormalized` (Alt-1255) entfernt — **kein Bug** | `diff`; `grep '\.landing'`=0 Leser außer Test; `551:97 manifest.jellyfin.accessGroup="stream"` ⇒ rendert via `wanTiles` | WONTFIX — durch manifest-basierte `wanTiles`/`lanTiles` ersetzt | WONTFIX | Archiv `mediNix-core-bergung/51-ingress_alt-20251013-1255/…` |
| L-003 | BERG | `51-ingress/511-caddy.nix` | Header + `.local`-Spoofing-Notiz (Alt-1255) | `diff` | Doku/Rationale → archiviert | DONE | Archiv `…/511-caddy.nix` |
| L-004 | BERG | `51-ingress/513,514` | `pruneFqdns`-Kommentar; `credPath`/`credRuntime` (Alt-1255) | `diff` | archiviert | DONE | Archiv `…/513,514` |
| L-005 | BERG | `51-ingress/55x-service.example.nix` | `svcNum`/`accessGroup` (Alt-1255) | `diff` | archiviert | DONE | Archiv `…/55x-service.example.nix` |
| L-006 | ARCH | repo-weit | **Doppel-Engine:** `lib/registry.nix` (26) + `lib/service-factory.nix` (11) neben `lib/decimal-framework.nix` → `users.users.<svc>` widersprüchlich | `grep -rl` | Entscheidung nötig; Beweis nur per `nix`-Eval | OPEN | – |
| L-007 | SEC | ABS `server-settings`, Pocket-ID | `tokenSecret` + `authOpenIDClientSecret` im Verlauf sichtbar | `sqlite3` über `uh` | **rotieren** | OPEN | – |
| L-008 | BUG | `51-ingress/513-cloudflare-dns.nix` | `shellcheck` SC2154 | `shellcheck` | Nix-Interpolation → kein Fix | WONTFIX | – |
| L-009 | BUG | `51-ingress/*` | `nixfmt -c` alle 8 sauber | `nixfmt -c` | keiner | DONE | – |
| L-010 | BERG | `52-security/*` | 2 Alt-Exporte vs Ist: kein Verlust; `526:130` `chain mark`→`vpn_mark` (14.10.) = Verbesserung | `diff` | keine Aktion | DONE | Archiv `52-security_alt-20251014-1143/` |
| L-011 | BERG | Voll-Dump 25.09. (314 Dateien) | `195` identisch / `117` evolviert / **2 „nur-Dump"**: `555-seerr.nix`→`561-seerr.nix` (umbenannt), `573-exportarr.nix`→`58-observability/585-exporters.nix` (verschoben+generalisiert) | basename-Abgleich + `diff` | **kein Code-Verlust**; nur Doku-Index stale (→ L-013) | DONE | Archiv `full-0925/` |
| L-012 | BUG | `flake.nix:824` | `shellcheck` **SC2164** (`cd docs` ohne Guard im `buildPhase`) | `shellcheck` auf extrahiertem Block | → `cd docs \|\| exit 1` | DONE | `…/mediNix-backup/flake.nix.orig` |
| L-013 | BUG | `*/AGENTS.md` (repo-weit) | auto-gen. Index stale (7×) + **fehlend** (3×: 54-transfer, 58-observability, 59-guardrails); `57` listete `573-exportarr`, obwohl nach `585` verschoben | `medinix-meta.py check-docs` (dry, read-only) + `ls` | `medinix-meta.py generate-docs` → 10 Dateien neu/aktualisiert; `check-docs` = „up to date" | DONE | `…/mediNix-backup/agents-md-before.tgz` |
| L-015 | OPT | 17 × `NNN-*.nix` | unvollständiges Frontmatter: `complexity:` fehlt bei **17**, `status:` bei **6** (`551–554`,`561`,`574`) → Index zeigt `unknown`/`-/5` | `grep`-Scan + `medinix-meta.py check-docs` | `status` = `active` könnte setzbar sein; **`complexity`-Werte = Autoren-Wissen**, nicht ratbar | OPEN | – |
| L-016 | OPT | repo-weit (Ordnung) | Ordner-Spam-Risiko („1 Ordner pro Datei"); lokale `__pycache__` (6); überflüssige `.gitkeep` (2); 2 Migrations-Docs im Root | `nixcheck folders`, `find` | **erledigt:** pycache weg (6→0), `.gitkeep` weg, `ROADMAP-DEZIMALRAHMEN-MIGRATION.md`+`UPGRADE-MATRIX-…md` → `docs/`; **neu:** `docs/CONVENTIONS.md`, `docs/agents/shared/scripts/folder_lint.sh`, `.github/workflows/order-lint.yml`, Tool `~/bin/nixcheck`. Repo-Lint = **0** | DONE | `…/order-backup/` |
| L-017 | OPT | `lib/` | **Korrektur:** 4 Module (`_helpers`,`abc-tiering`,`wait-for-api`,`mk-secure-curl`) hatten 0 Importeure → ich hatte sie **vorschnell archiviert**. Nach Analyse: **nie verdrahtete Utilities** (in keinem Export je referenziert) — kein toter Müll, sondern ungenutzte Lib-API | `grep` über Repo + Alt-Exporte | **REVERTIERT** (alle 4 zurück in `lib/`). Entscheidung nötig → L-019 | REVERTED | – |
| L-018 | OPT | `lib/default.nix` | fehlender Single-Entry (`medinixLib`; Meisterstück nutzt `inherit (medinixLib) …`) | `lib/README.md` | Entwurf bereit; nicht angelegt (braucht Nix-Eval) | OPEN | – |
| L-019 | OPT | `lib/abc-tiering.nix` | **überlappt** mit kanonischem `cfg.storage.backends.hot/cold` (`default.nix:221,230`) + `registry.stateDir` (= tierA) → ältere Parallel-Konvention | `grep mediaRoot`, `cat` | **Verdikt: überholt** → bewusst ablegen oder im ADR-5043 vermerken (NICHT verdrahten) — Entscheidung offen | OPEN | – |
| L-020 | OPT | `lib/mk-secure-curl.nix`, `lib/wait-for-api.nix` | Provisioning nutzt **Python** (`arr-provision/*.py`, `X-Api-Key` in-process) + `wait_for_url` → **kein argv-Leak**, Readiness vorhanden | `grep`, `arr_keys_sync.py:47` | **Verdikt: aktuell nicht benötigt** → behalten als „Werkzeug für später" oder ablegen — Entscheidung offen | OPEN | – |
| L-021 | OPT | `lib/_helpers.nix` | `recursiveMergeAttrs`, generisch, nie genutzt | `cat` | trivial → behalten oder ablegen — Entscheidung offen | OPEN | – |
| L-014 | BUG | `57-maintenance/578-orphan-cleanup.nix:44` | `shellcheck` SC2206 (`KNOWN_DIRS=(${knownDirsArray})`) | `shellcheck`; `knownDirsArray` liefert bereits quotierte Elemente (`"dir"`) | **Artefakt**, kein Fix nötig | WONTFIX | – |

## Bergungs-Archiv
`/storage/emulated/0/Obsidian/mediNix-core-bergung/` → `51-ingress_alt-20251013-1255/`, `52-security_alt-20251014-1143/`

## Spur-Status
- **Spur 1 (Bergung): ✅ abgeschlossen** — 51-ingress, 52-security, 59-guardrails, lib/, arr-provision, Voll-Dump 25.09., 551-jellyfin. **Kein echter Verlust**, nur Verschiebungen/Umbenennungen.
- **Spur 2 (Bugs): ✅ abgeschlossen** — nixfmt/shellcheck/MCP-Options/py_compile gelaufen. **1 echter Fix (L-001)**, **1 Nit gefixt (L-012)**; SC2154/SC2206 = Artefakte; offene Kleinigkeit L-013 (stale auto-gen Index).
