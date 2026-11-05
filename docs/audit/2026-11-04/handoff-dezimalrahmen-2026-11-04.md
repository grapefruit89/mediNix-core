# Handoff — Dezimalrahmen-Nacharbeit (Batch A)

**Stand:** 2026-11-04, HEAD `85b9a4c` = `origin/main`, CI 5/5 grün, Working Tree clean.
**Quelle:** Batch A (read-only Vorarbeit), durchgeführt auf Nobara-PC.
**Zweck:** Dieses Dokument ist die einzige Änderung aus Batch A. Es hält die Messungen
fest, damit Batch B und C nicht neu explorieren müssen.

---

## 0. Befund vorweg — drei von fünf geplanten Punkten sind bereits umgesetzt

Die Auftragsreihenfolge (ADR-0000 §14 → nixmeta-Zonen → `packages/medinix-cli/default.nix`
→ CONVENTIONS §4 → M5-Sweep) ist teilweise überholt. Beleg pro Punkt:

| Geplant | Ist-Zustand | Beleg |
|---|---|---|
| ADR-0000 §14 anfügen | **existiert vollständig** | `docs/adr/ADR-0000-dezimalrahmen-verfassung.md:259-401`, Abschnitte §14.1–§14.7, 143 Zeilen |
| nixmeta §14-Zonen | **implementiert** | `scripts/nixmeta_check.py:41-93`: `ROOT_FILES`, `ENGINE_FILES`, `TOOLING_FILES`, `MODULE_RE`, `LIBRARY_RE`, `PACKAGE_RE`, `TEST_RE`, `classify()`, `KIND_OF`, Zonenregeln `zone:example`/`zone:template` |
| `packages/medinix-cli/default.nix` | **existiert** | 742 Bytes, angelegt 2026-11-04 13:27; `flake.nix:291` und `default.nix:1306` rufen bereits `callPackage ./packages/medinix-cli` — kein direkter `cli.nix`-Pfad mehr |
| CONVENTIONS §4 auf Ist-Zustand | **überwiegend erledigt** | §4 nennt `50-core/`, `packages/`, `tests/`; **kein** `lib/` mehr. Lücke: `skills-lock.json` fehlt in der Wurzel-Liste |
| M5-Sweep `lib/`-Referenzen | **offen** | siehe Abschnitt 2 |
| R1–R6-Dedup | **offen** | siehe Abschnitt 3 |

Konsequenz: Batch B schrumpft auf **CONVENTIONS-Nachtrag (1 Zeile)** und **M5-Sweep**.
Der §14-Teil von Batch B entfällt. `nixmeta_check.py` ist der Constitution bereits
einen Schritt voraus — nicht umgekehrt.

Ist-Verteilung laut `classify()` (69 Dateien, alle konform):

| Kategorie | Anzahl |
|---|---:|
| `module` | 45 |
| `library` | 9 |
| `zone:example` | 4 |
| `package` | 3 |
| `engine` | 2 |
| `root-config` | 2 |
| `test` | 2 |
| `tooling` | 1 |
| `zone:template` | 1 |

---

## 1. A1 — .nix außerhalb 50–59 (12 Dateien, alle mit YAML-Header)

| # | Pfad | Kategorie | Header | `status:` | `kind:` |
|---|---|---|---|---:|---|
| 1 | `default.nix` | Root-Config | ja | `active` | `root-config` |
| 2 | `flake.nix` | Root-Config | ja | `active` | `root-config` |
| 3 | `packages/arr-provision/default.nix` | Package | ja | `active` | `package` |
| 4 | `packages/medinix-cli/cli.nix` | Package | ja | `active` | `package` |
| 5 | `packages/medinix-cli/default.nix` | Package | ja | `active` | `package` |
| 6 | `tests/smoke-test.nix` | Test | ja | `active` | `test` |
| 7 | `tests/vm-smoke-test.nix` | Test | ja | `active` | `test` |
| 8 | `docs/examples/5xx-service.example.nix` | Zone `example` | ja | `example` | *verboten* (korrekt) |
| 9 | `docs/examples/mergerfs-tiering.nix` | Zone `example` | ja | `example` | *verboten* (korrekt) |
| 10 | `docs/examples/simple.nix` | Zone `example` | ja | `example` | *verboten* (korrekt) |
| 11 | `docs/examples/vpn-confinement.nix` | Zone `example` | ja | `example` | *verboten* (korrekt) |
| 12 | `docs/agents/07-patterns-misc/nixos-dotnet-env-config/templates/arr-settings.nix` | Zone `template` | ja | `template` | *verboten* (korrekt) |

**Library, Engine und Tooling liegen INNERHALB 50–59** und werden dort über `kind:`
bestimmt, nicht über den Pfad:

| Datei | `kind:` |
|---|---|
| `50-core/501-decimal-engine.nix` | `engine` |
| `50-core/service-contract.nix` | `engine` |
| `50-core/repl.nix` | `tooling` |
| `50-core/derive.nix`, `hardening-profiles.nix`, `manifest.nix`, `memory-policy.nix`, `registry.nix`, `service-factory.nix` | `library` |
| `50-core/500-host-baseline.nix`, `502-host-settings.nix`, `503-host-integration.nix` | *kein `kind:`* (NNN-Präfix ⇒ `module`) |

### 1b — Konfliktprüfung

**Import-Regex passt.** `default.nix:58` verlangt Ordner `^[0-9]{2}-.*`, `:67` Dateien
`^[0-9]{3}-.*\.nix$`. Konsequenz, die §14 bereits abbildet: die sechs `library`-Dateien
in `50-core/` werden **nicht** automatisch importiert, sondern explizit (z. B.
`default.nix:80`: `imports = moduleFiles ++ [ ./50-core/service-contract.nix ]`).
`repl.nix` ist ebenfalls nicht auto-importiert. Kein Widerspruch, sondern Absicht.

**`cli.nix`-Pfad-Konflikt existiert nicht mehr.** `flake.nix:291` und `default.nix:1306`
rufen `pkgs.callPackage ./packages/medinix-cli { … }` — `callPackage` löst auf
`default.nix` auf. Ein direktes `./packages/medinix-cli/cli.nix` gibt es nicht mehr.

**Keine unzuordenbare Datei.** Alle 69 Dateien bekommen von `classify()` eine Kategorie.

**Kategorie vs. `kind:` — kein Widerspruch.** Zonen (`docs/examples/**`,
`docs/**/templates/**`) tragen `status: example|template` und **kein** `kind:`;
das erzwingt `nixmeta_check.py:184-196` beidseitig. Die vier `library`-Dateien mit
`status: active` sind Bibliotheken, keine Dienste — kein Test-Modul trägt `active`.

---

## 2. A2 — Sweep-Liste `lib/`-Referenzen

Suchmuster: `(?<!var/)lib/` — schließt `/var/lib/` aus (das ist kein Alt-Pfad).

| Gruppe | Dateien | Treffer | Aktion |
|---|---:|---:|---|
| **1 — aktiv** | 32 | 90 | korrigieren in Batch C, **aber** siehe Klassifikation unten |
| **2 — ADRs** | 3 | 18 | **nicht anfassen** (dokumentieren Historie; §14.7 ist die Konkordanz) |
| **3 — historisch** | 54 | 326 | **nicht anfassen** |

Gruppe 2 im Detail: `docs/adr/ADR-0000-…md` (11), `ADR-040-…md` (4),
`ADR-5030-…md` (3).
Gruppe 3: `docs/audit/*`, `docs/archive/*`, `todo/*`, `CHANGELOG.md`,
`.agent-state.json`.

### Gruppe 1, in drei Unterklassen zerlegt — **nur 2a wird geändert**

#### 2a — echte Alt-Pfade (Batch C)

| Datei | Zeile | alt | neu |
|---|---:|---|---|
| `README.md` | 103 | ``- `lib/` — registry, service-factory`` | ``- `50-core/` — registry, service-factory`` |
| `AGENTS.md` | 160 | Tabellenzeile `` `lib/` `` | `` `50-core/` `` |
| `51-ingress/README.md` | 166 | `lib/service-factory`, `lib/registry` | `50-core/service-factory`, `50-core/registry` |
| | 167 | dito | dito |
| | 168 | `lib/service-factory` | `50-core/service-factory` |
| | 170 | `lib/registry` | `50-core/registry` |
| | 192 | `REG["lib/registry"]` | `REG["50-core/registry"]` |
| | 198 | `FAC["lib/service-factory"]` | `FAC["50-core/service-factory"]` |
| | 643 | `lib/cli.nix` | `packages/medinix-cli/cli.nix` |
| `54-processing/README.md` | 31 | `lib/hardening-profiles` | `50-core/hardening-profiles` |
| | 32 | `lib/registry` | `50-core/registry` |
| | 36 | `hardening_profiles["lib/hardening-profiles"]` | `…["50-core/hardening-profiles"]` |
| | 37 | `registry["lib/registry"]` | `registry["50-core/registry"]` |
| | 38 | `hardening_profiles["lib/hardening-profiles"]` | `…["50-core/hardening-profiles"]` |
| `56-exposition/README.md` | 32 | `lib/hardening-profiles (nodejs)` | `50-core/hardening-profiles (nodejs)` |
| | 33 | `registry["lib/registry"]` | `registry["50-core/registry"]` |
| `docs/TERMINOLOGY.md` | 74 | Überschrift `## lib/ (Hilfsbibliotheken)` | `## 50-core/ (Hilfsbibliotheken)` |
| | 92 | `52-security + lib/ (diese Datei)` | `52-security + 50-core/ (diese Datei)` |
| `docs/arch/ARCH-50-architecture-blueprint.md` | 69 | `├── lib/` im Baum | `├── 50-core/` |
| | 93 | `` `flake.nix`, `lib/`, `51-ingress/` `` | `` `flake.nix`, `50-core/`, `51-ingress/` `` |
| `docs/guides/GUIDE-50-aspect-oriented.md` | 33 | ``- `lib/*` — Engine, Registry, Contract, Hardening-Profile.`` | ``- `50-core/*` — Engine, Registry, Contract, Hardening-Profile.`` |
| `docs/RUNBOOK.md` | 9 | ``**`lib/runbook.json`**`` | ``**`packages/medinix-cli/runbook.json`**`` |
| `docs/agents/01-discipline/medinix-change-pipeline/SKILL.md` | 105 | `lib/cli.nix` `lib` were passed by callers | `packages/medinix-cli/cli.nix` … |
| `docs/agents/02-medinix-core/medinix-dezimalrahmen/SKILL.md` | 74 | `` `lib/*` `` | `` `50-core/*` `` |
| `docs/agents/02-medinix-core/nixos-medinix-authoring/SKILL.md` | 37 | `boilerplate SSoT in `lib/`` | `… in `50-core/`` |
| `docs/agents/02-medinix-core/nixos-medinix-authoring/references/flat-structure-autoimport-push.md` | 36 | `` `lib/*.nix` (no number) `` | `` `50-core/*.nix` (no number) `` |
| `docs/agents/02-medinix-core/nixos-medinix-authoring/templates/boilerplate-tree.md` | 8 | `├── lib/` | `├── 50-core/` |
| `docs/agents/03-gates-audits/medinix-pre-commit/SKILL.md` | 23 | `` `lib/*.nix` `` | `` `50-core/*.nix` `` |
| `docs/agents/07-patterns-misc/nixos-dotnet-env-config/templates/arr-settings.nix` | 20 | `# Drop into lib/ and import…` | `# Drop into 50-core/ and import…` |
| `docs/agents/shared/scripts/scan_inconsistencies.py` | 10 | False-Positive-Liste mit `lib/*` | `50-core/*` |
| | 20 | `"/lib/" in dirpath` (Skip-Regel) | `"/50-core/" in dirpath` |
| `scripts/gen_runbook.py` | 2, 5, 6 | Docstring nennt `lib/runbook.json`, `lib/cli.nix` | `packages/medinix-cli/runbook.json`, `packages/medinix-cli/cli.nix` |
| `scripts/check_nixos_anchors.py` | 12, 42, 92 | Hinweistext `scripts/\|lib/\|docs/` | `scripts/\|50-core/\|docs/` |
| `scripts/medinix-meta.py` | 325-326 | `if req.startswith("lib/")` → `lib/…nix` | toter Zweig: auf `50-core/` umstellen oder entfernen |

#### 2b — nixpkgs-`lib`, **nicht ändern** (Fehlalarm)

| Datei | Zeile | Grund |
|---|---:|---|
| `50-core/service-contract.nix` | 243 | `lib/modules.nix` = nixpkgs-Modulsystem, nicht unser Alt-Pfad |
| `docs/NIXOS-ANCHORS.md` | 123 | dito |
| `docs/UPSTREAM-SOURCES.md` | 15, 34 | `nixpkgs lib/modules.nix`, `nixos/lib/testing` |
| `docs/patterns/PATTERN-50-nix-colors.md` | 234 | `lib/contrib/default.nix` = nixpkgs |
| `docs/patterns/PATTERN-50-arch-direnv.md` | 114 | `~/.config/direnv/lib/*.sh` = Anwender-Datei |
| `docs/HANDOFF-AN-NEXT-AGENT.md` | 83 | `lib/modules.nix:670` = nixpkgs |
| `.gitattributes` | 8 | Kommentar über *entfernte* Globs, beschreibt Vergangenheit |
| `51-ingress/513-router-adapter-speedport.nix` | 45 | „kein externes `lib/speedport-api.nix` **mehr**" — korrekte Negativ-Aussage |

#### 2c — historische bzw. Planungs-Aussagen, **Einzelfallentscheidung**

| Datei | Zeilen | Problem |
|---|---:|---|
| `docs/AUDIT-LEDGER.md` | 30-67 (21) | Findings vom Zeitpunkt des Fundes; Pfade waren damals korrekt. Umschreiben hieße Geschichte fälschen |
| `docs/UPGRADE-MATRIX-uebernehmen-vs-aussenvor.md` | 14, 24, 28, 31, 33, 120 | beschreibt „mediNix **besaß** einen Motor: `lib/registry.nix`" — Vergangenheit, korrekt |
| `ROADMAP.md` | 29, 50-52, 59, 65, 137 | `[x]`-Einträge = erledigte Fixes mit damaligem Pfad. **Aber** `:72` und `:86` planen `lib/gpu.nix`, `lib/network-cidrs.nix` → künftiger Pfad, muss `50-core/` heißen |
| `docs/TODO.md` | 26 | **generiert** aus ROADMAP — nicht direkt editieren, sondern ROADMAP korrigieren + `gen_todo.py` laufen lassen |
| `docs/HANDOFF-AN-NEXT-AGENT.md` | 114, 146, 252 | teils Planung (`lib/gpu.nix`), teils erledigt (`lib/mk-secure-curl.nix` deprecated) |

**Regel für Batch C:** Eine Referenz wird nur geändert, wenn sie den **aktuellen oder
künftigen** Zustand beschreibt. Beschreibt sie den **damaligen** Zustand (Finding,
Changelog-Eintrag, `[x]`-Roadmap-Punkt), bleibt sie stehen.

---

## 3. A3 — R1–R6: AGENTS.md Regel 11 vs. `medinix-project.md` Block 10

| | AGENTS.md | `medinix-project.md` |
|---|---|---|
| Stelle | `AGENTS.md:45-51` (Regel 11) | `docs/agents/07-patterns-misc/nixos-ecosystem/references/medinix-project.md:157-183` (Block 10) |
| Umfang | 7 Zeilen (1 Kopf + 6 Regeln, je 1 Zeile) | 27 Zeilen (1 Kopf + 6 Unterabschnitte) |
| Format | komprimierte Aufzählung, `$\rightarrow$` | Fließtext + Bullet-Listen, `→` |
| SSoT-Anspruch | Root-Verfassung, immer geladen | Skill-Referenz, nur bei Skill-Nutzung geladen |

### Abweichungen — Block 10 ist die **detailreichere** Fassung, kein reines Duplikat

Vier Informationen existieren **nur** in `medinix-project.md`:

| # | Detail | Nur in | Zeile |
|---|---|---|---:|
| 1 | `git log -S` als Suchwerkzeug für aktuelle Bugs = falsches Werkzeug | Block 10, R6 | 182 |
| 2 | `git log -S` in der SUCHEN-Kategorie von R4 | Block 10, R4 | 172 |
| 3 | `nixmeta_check` namentlich in der VERIFIZIEREN-Kategorie | Block 10, R4 | 174 |
| 4 | `grep <file>` in der LESEN-Kategorie | Block 10, R4 | 171 |

Zusätzlich: AGENTS.md verwendet `$\rightarrow$` (LaTeX-Reste, die in Markdown als
`$\rightarrow$` erscheinen statt als Pfeil). Das ist ein Darstellungsfehler.

Gemeinsam (inhaltlich identisch): R1 (lesen statt suchen), R2 (ein Call pro Frage),
R3 (Ambiguität → STOP), R5 (Budget 3 Calls), die SUCHEN/TESTEN/VERIFIZIEREN-Hierarchie.

### Dedup-Vorschlag

**Reihenfolge: erst Delta einarbeiten, dann kürzen.** Würde Block 10 direkt auf drei
Zeilen reduziert, gingen die vier Details oben verloren.

1. **AGENTS.md:45-51** um die vier Details ergänzen (`grep <file>`, `git log -S`
   in SUCHEN und in R6, `nixmeta_check` als Beispiel) und `$\rightarrow$` → `→`.
   Ergebnis: Regel 11 bleibt 7 Zeilen, ist aber vollständig.
2. **`medinix-project.md:157-183`** (27 Zeilen) ersetzen durch:

   ```markdown
   ## 10. Exploration — Finden statt Suchen

   Die Regeln R1–R6 (lesen statt suchen, ein Tool-Call pro Frage, Ambiguität → STOP,
   Tool-Kosten-Hierarchie, 3-Call-Budget, Dead Signals) stehen in der Repo-Verfassung:
   **`AGENTS.md` §Regel 11**. Dort ist die einzige Quelle — diese Datei führt sie nicht
   doppelt (Zeiger-Regel, `docs/CONVENTIONS.md` §4).
   ```

3. Netto: −24 Zeilen in der Skill-Referenz, +0 Zeilen in AGENTS.md (Ergänzung im
   vorhandenen Zeilenraster).

**Risiko, das der Auftrag nicht nennt:** `medinix-project.md` gehört zum Skill
`nixos-ecosystem`, der laut `description` auch außerhalb von mediNix greift. Nach dem
Dedup braucht ein Agent in einem **anderen** Repo die R1–R6-Regeln aus einer Datei,
die dort nicht existiert. Gegenmaßnahme: Der Zeiger muss den Regeltext nicht enthalten
— aber der Skill darf dann nicht als „self-contained" beworben werden. Alternative:
Dedup umdrehen (Block 10 bleibt Quelle, AGENTS.md zeigt darauf) — dann ist die
Verfassung nicht mehr vollständig lesbar. **Empfehlung: Zeiger auf AGENTS.md**, weil
die Verfassung immer geladen wird und `medinix-project.md` explizit mediNix-spezifisch ist.

---

## 4. Restarbeit für Batch B/C

| # | Aufgabe | Aufwand | Datei(en) |
|---|---|---|---|
| B1 | CONVENTIONS §4: `skills-lock.json` in die Wurzel-Liste | 1 Zeile | `docs/CONVENTIONS.md` |
| B2 | `ROADMAP.md:72,86` + `docs/TODO.md` (generiert) auf `50-core/` für geplante Module | 2 Zeilen + Generator | `ROADMAP.md`, `scripts/gen_todo.py` |
| C1 | M5-Sweep Abschnitt 2a (29 Stellen in 22 Dateien) | mechanisch | siehe Tabelle |
| C2 | `scripts/medinix-meta.py:325-326`: toten `lib/`-Zweig entfernen oder auf `50-core/` umstellen | 2 Zeilen | `scripts/medinix-meta.py` |
| C3 | R1–R6-Dedup (Abschnitt 3, 4 Schritte) | klein | `AGENTS.md`, `medinix-project.md` |
| C4 | Entscheidung 2c treffen (AUDIT-LEDGER, UPGRADE-MATRIX, HANDOFF) | Entscheidung | — |

Nach jeder Phase: volle Leiter, inklusive `nix flake check` **ohne** `--no-build`.

---

## 5. Offene Entscheidungen

1. **2c:** Bleiben die historischen `lib/`-Nennungen in `docs/AUDIT-LEDGER.md`,
   `docs/UPGRADE-MATRIX-…md` und `docs/HANDOFF-AN-NEXT-AGENT.md` stehen (Empfehlung:
   ja, sie beschreiben den damaligen Zustand) — oder werden sie mit
   „(heute `50-core/`)" ergänzt?
2. **`scan_inconsistencies.py`:** Die Skip-Regel `"/lib/" in dirpath` ist nach dem
   lib/-Abbau wirkungslos. Ersetzen durch `50-core` oder ganz entfernen?
3. **R1–R6-Richtung:** Zeiger von `medinix-project.md` auf `AGENTS.md` (Empfehlung)
   oder umgekehrt?

---

## 6. Nicht Teil dieses Handoffs

- Syncthing (separater Auftrag).
- `docs/audit/`, `docs/archive/`, `todo/_archive/` — unangetastet.
- ADR-Inhalte außer der in §14.7 bereits dokumentierten Pfad-Konkordanz.
