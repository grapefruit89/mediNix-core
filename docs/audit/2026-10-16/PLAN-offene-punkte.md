# PLAN — offene Punkte (Stand 2026-10-16)

> **Momentaufnahme** der geplanten, noch offenen Arbeit. Die *Quellen* bleiben
> `ROADMAP.md` (Backlog) + `.agent-state.json` (Korridor) → `docs/TODO.md` (generiert).
> Dieser Plan ergänzt je Punkt **Stand jetzt · Lücke · Ziel · Schritte · Dateien · Erfolg**.
> (Archiv/Ort für Snapshots; **kein** zweiter Roadmap-Ort, AB-015.)

## C — CONVENTIONS §Audit + Korridor-Regeln
- **Stand:** `CONVENTIONS.md` §§1–5 (Ordner/Ordnung/Whitelist/Blacklist), **kein §Audit**. Korridor: 36 Blacklist-Regeln (`AB-001…036`), aber **ohne** die harten Nix-Reflexe. Scanner `scripts/nixos_idiom_audit.py` existiert, wird aber nirgends referenziert.
- **Lücke:** Die Methode (drei Schichten, „Signal ≠ Fund") ist nirgends verbindlich; die harten Reflexe (`--impure` im Code, `nix-env -i`/`nix-channel`, Schreiben nach `/nix/store/`, `/usr/`-Pfade) sind **keine** Regel → sie können wieder einschleichen.
- **Ziel:** §Audit (NixOS-Audit) festschreiben + 4 **NixOS**-Reflexe als **`AB-039…AB-042`** (`AB-037`/`AB-038` sind an die **Arbeitsweise** vergeben — siehe `CONVENTIONS §6`).
- **Schritte:** §Audit schreiben · `corridor.blacklist` +4 · `gen_todo.py` · Checks.
- **Dateien:** `docs/CONVENTIONS.md`, `.agent-state.json`, `docs/TODO.md`.
- **Erfolg:** §Audit vorhanden; Blacklist **40**; `gen_todo --check` grün. · **S · niedrig**

## A — `docs/AUDIT-NIXOS-IDIOMS.md`
- **Stand:** existiert **nicht**; das Scan-Ergebnis (0 P0 / 2 P1 / 5 P2) lebt nur im Chat.
- **Lücke:** nicht nachvollziehbar/reproduzierbar.
- **Ziel:** Methodik (3 Schichten) + Signal-Tabelle P0/P1/P2 + **datierter** Lauf + Schicht-3-Beweis (`nix flake check` **ohne `--impure`**, host/CI).
- **Schritte:** Datei schreiben · aus `CONVENTIONS §Audit` + AGENTS-Landkarte verlinken.
- **Erfolg:** verlinkt `scripts/nixos_idiom_audit.py` + `§Audit`, datiert. · **S · niedrig** *(abhängig: C)*

## B — CI-Stufe 0a
- **Stand:** `order-lint.yml` läuft 3 Dinge: `folder_lint`, `gen_todo --check`, `gen_service_map --check`. **Kein** Idiom-Scan.
- **Lücke:** Ein neuer P0-Reflex würde die **CI nicht** brechen.
- **Ziel:** Step `python3 scripts/nixos_idiom_audit.py --p0-only` (fail-closed).
- **Schritte:** Step in `.github/workflows/order-lint.yml` · lokal `--p0-only` = 0.
- **Erfolg:** CI grün; bei P0 **rot**. · **S · niedrig** *(abhängig: A/C)*

## F — `scripts/systemd-facts.sh`
- **Stand:** Nur die Text-CLI `medinix ids/show/logs/triage` (`systemctl show`, `ss`, `stat`, `journalctl`) — **kein JSON-Bundle**, kein `--output=json`, kein `systemd-analyze security`, kein `busctl`.
- **Lücke:** Eine KI bekommt den Systemzustand nicht **maschinenlesbar gebündelt** → Felderwahl selbst = token-teuer + fehleranfällig.
- **Ziel:** ein JSON: `list-units --output=json`, `list-unit-files --output=json`, je Unit `show -p …`, `systemd-analyze security --json=short`, `busctl introspect … --json=short` — **redigiert** (kein `Environment`), **Token-gekappt**.
- **Schritte:** bash+jq · Redaction · Kappe · `bash -n`/`shellcheck` · RUNBOOK §0-Eintrag.
- **Dateien:** `scripts/systemd-facts.sh`, `docs/RUNBOOK.md`.
- **Erfolg:** valides JSON, keine Secrets; läuft **nur** auf NixOS (hier nur Syntax-Check). · **M · niedrig**

## H — `docs/HOST-INTERFACE.md`
- **Stand:** Host-Schnittstelle existiert als Optionen — `host.*` (502), `hostIntegration.*` (503), `secrets.*`/`recommended.*`/`storage.*` (`default.nix`) — aber verstreut, nirgends an einem Ort erklärt.
- **Lücke:** Ein Host-Betreiber/Agent weiß nicht, welche Knöpfe es gibt + was `managed|external|off` je bedeutet → Fehlkonfiguration.
- **Ziel:** eine Seite: jede host-beeinflussende Option + Ownership-Semantik + „was gehört NICHT in den Flake".
- **Dateien:** `docs/HOST-INTERFACE.md` (+ AGENTS-Landkarte, `CONVENTIONS §4`).
- **Erfolg:** jede host-beeinflussende Option an einem Ort, verlinkt. · **S · keine**

## I — arr-provision bündeln
- **Stand:** `lib/arr-provision/default.nix` baut **8** Einzel-Wrapper (`arr-sync-keys/settings/download-clients/prowlarr/locale/profiles/jellyfin/seerr`, generierte Shell-Wrapper); `574` ruft 8 Binaries sequenziell.
- **Lücke:** 8 Entry-Points = 8 Wrapper + 8 Aufrufe + 8 Fehlerquellen; kein gemeinsames `--help`; Auswahl-/Reihenfolge-Logik im `574`-Shell (ungetestet).
- **Ziel:** ein `arr-provision <subcommand>` (argparse) + Subcommand `provision`, der die Sequenz anhand der `SYNC_*`-Env in Python fährt (testbar); `574` ruft **1** Binary.
- **Schritte:** `arr_provision/__main__.py` · per-Modul `main()` behalten · `default.nix` → 1 Wrapper · `574` → `arr-provision provision` · `ast.parse`/Tests.
- **Erfolg:** 1 Binary, 1 `--help`; Verhalten identisch. · **M · niedrig**

## G — `medinix gather <symptom>`
- **Stand:** `medinix triage <symptom>` gibt die Kette (`show`+`logs`) — aber nicht die geordneten 7 Abschnitte; kein SOLL↔IST-Diff.
- **Lücke:** kein einheitlicher, geordneter Befund → die KI sucht selbst.
- **Ziel:** 7 Abschnitte **WAS · WER · IST · LOGS · PFADE · DIFF · FIX**, redigiert + Token-gekappt; Quellen Registry (SOLL) + systemd (IST) + `lib/runbook.json`.
- **Dateien:** `lib/cli.nix` (`cmd_gather`), ggf. `lib/runbook.json`.
- **Erfolg:** ein Knopf → ein geordneter Befund. · **M · mittel** *(abhängig: F)*

## N — Doc-Nit
- **Stand:** `docs/agents/07-patterns-misc/nixos-llm-first-workflow/SKILL.md:183` empfiehlt `ssh mediahost@192.168.0.10` + `nix-env -iA nixpkgs.nixos-mcp`.
- **Lücke:** stale (fremder Host; imperativer Install) + widerspricht `systemd-first`; lokal gibt es den `nixos`-MCP.
- **Ziel:** Zeile auf lokalen MCP/Setup umstellen.
- **Erfolg:** kein `nix-env -i`/`mediahost` mehr in der Skill. · **S · keine**

## D-06 — 515 mDNS-Refresh (Entscheidung)
- **Stand:** 3 Units (`aliases.service` + `refresh.path` + `restart.service` mit `systemctl restart`).
- **Lücke:** keine — der `systemctl`-Wrapper ist ein anerkannter Idiom; `.path` ist systemd-native.
- **Ziel:** **so lassen**. Die Optionen (A `reload`, B Poll/1 Unit, C self-watch) sind als lateral/verworfen in **`AB-034`** dokumentiert.
- **Erfolg:** Entscheidung im Korridor auf `entschieden: so lassen` setzen. · **— · —**

---

## Reihenfolge
1. **C → A → B** (Audit festzurren) · 2. **N** · **H** · 3. **F** · **I**/**G** · **D-06** schließen.

## Schon erledigt (nicht mehr offen)
`systemd-first` · Semantic-Anchors-Lexikon (28 Anker) · Runbook-SSoT · RAM-SSoT · 4 lib-Module archiviert · Port/UID/GID-SSoT + reserviertes 5xxx-Band · Nix-Idiom-Scanner (Schicht 1) · Friedhof `AB-033…036` · B6 (in der Roadmap) · `CONVENTIONS §6` Methodenwahl + `AB-037`/`AB-038` (Teil von C).
