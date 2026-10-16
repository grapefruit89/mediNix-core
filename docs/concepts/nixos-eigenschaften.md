---
id: "nixos-eigenschaften"
title: "NixOS-Eigenschaften — Denkrahmen (korrigiert, mit Belegen aus diesem Repo)"
domain: 50
status: active
complexity: 2
last_reviewed: 2026-10-16
links:
  adr: ADR-040 (gerichtete Abhängigkeiten), ADR-0000 (Verfassung)
  skill: nixos-mental-model
---

# NixOS-Eigenschaften

> Einordnungsrahmen — **kein** Regelwerk. Regeln stehen in `ADR-0000`,
> `ADR-040` und im Korridor (`.agent-state.json`).
> Diese Datei erklärt, **warum** die Regeln so aussehen.

## Was NixOS ist (und was nicht)

| NixOS | Klassische Distribution | Konkret |
|---|---|---|
| Deklarativ | Imperativ | Zielzustand beschreiben, keine Schritte |
| Deterministisch | „kommt drauf an" | gleiche Eingabe → gleiches Ergebnis |
| Reproduzierbar | „bei mir läuft's" | Store-Pfad = Hash über alle Inputs |
| Rein funktional | gemischt | nur Ausdrücke, keine Seiteneffekte während der Auswertung |
| **Faul (lazy)** | eager | Werte entstehen erst, wenn sie **gelesen** werden |
| Hermetisch | Netz & FS offen | Sandbox: nur deklarierte Inputs (kein Netz, kein `/etc`) |
| Atomar | halb-fertig möglich | `switch` ist alles-oder-nichts, je Generation |
| Rollback-fähig | Backup zurückspielen | jede Generation adressierbar |
| Idempotent | „nochmal drüberbügeln" | dieselbe Config → derselbe Zustand |
| Immutabel | mutabel | `/nix/store` ist read-only |
| Konfiguration als Code | `/etc` von Hand | versioniert, diffbar, reviewbar |
| Explizite Abhängigkeiten | „irgendwas hat das mitinstalliert" | was nicht deklariert ist, existiert nicht |

## Die fünf Fallen — mit dem echten Beleg aus diesem Repo

| Falle | Was wirklich passiert | Beleg |
|---|---|---|
| **Faul** | Ein `types.enum` feuert erst, wenn der Wert **gelesen** wird — ohne erzwungene Auswertung bleibt der Guardrail stumm. | Ankreuzbogen-Fund (Schicht 2): Enum + erzwingende Assertion |
| **Zyklische Ableitung** (nicht „pure"!) | Ein Modul liest eine Quelle **und** schreibt daraus Ableitungen, während ein Guardrail die Ableitung prüft und dieselbe Quelle liest → `infinite recursion`. **Lazy-Verschiebung hilft nicht** — es ist ein echter Datenzyklus. | `L-045`/`L-046`, `ADR-040`, Korridor `AB-040` |
| **Nicht rein** (im engeren Sinn) | `builtins.currentTime`/`getEnv`, `import <nixpkgs>`, `--impure` → Determinismus weg. | `nixos_idiom_audit.py` P0-Signale |
| **Hermetisch** | `git+file`-Flakes sehen **untracked** Dateien nicht → „Datei geschrieben, Build sieht sie nicht". | Korridor `AB-032` (46 vs. 50 Checks) |
| **Zweistufig (Eval ≠ Build)** | `nix flake check --no-build` prüft nur die **Auswertung**; Shellcheck/`writeShellApplication` laufen erst beim **Bauen**. | `L-036` (SC2050: lokal „grün", CI rot) |

## Drei Fragen vor dem Tippen

1. **Welche Eigenschaft ist hier relevant?** (faul / zyklisch / rein / hermetisch / zweistufig)
2. **Welcher Klassische-Distro-Reflex zieht gerade an mir?** (imperativ, „mal eben in `/etc`", hoffen statt beweisen)
3. **Was wäre der Beweis?** — `nix flake check` **ohne** `--impure`, Checks **bauen**, Negativtest mit Grund.

## Referenzen

- `docs/adr/ADR-040-*.md` — gerichtete Abhängigkeiten (Quelle → Ableitung)
- `.agent-state.json` → `corridor.blacklist` (`AB-0xx`, u. a. AB-032/AB-037/AB-038/AB-040)
- `scripts/nixos_idiom_audit.py` — Signal-Scan (Schicht 1; **Signal ≠ Fund**)
- `docs/RUNBOOK.md` — Betriebs-/Diagnosewege
