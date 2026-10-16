---
name: nixos-idiom-audit
description: "Audit-Methodik für NixOS-Repos/Module: prüft systematisch auf Klassische-Distro-Reflexe (imperativ, mutabel, eager, FHS-Annahmen). Drei Schichten (Signal → Kontext → harter Beweis), Werkzeug scripts/nixos_idiom_audit.py. Laden beim Auditieren, Reviewen oder Vorführen eines Moduls/Repos."
---

# NixOS-Idiom-Audit

## Grundregel: Signal ≠ Fund

Ein `curl` in einem Skript ist **kein** Fund. Ein `curl`, das **zur Build-Zeit**
läuft, **ist** einer. Deshalb **drei Schichten** — in dieser Reihenfolge:

| Schicht | Was | Werkzeug |
|---|---|---|
| 1 — Signal | Kandidaten sammeln (viele Fehlalarme, erlaubt) | `python3 scripts/nixos_idiom_audit.py` (`--p0-only`, `--json`) |
| 2 — Kontext | Jeden Kandidaten **lesen** und urteilen (Build-Zeit? Laufzeit? dokumentiert?) | Augen + `git log` |
| 3 — Beweis | Harter Nachweis von Reinheit/Determinismus | `nix flake check` **ohne** `--impure`, Checks **bauen** |

## Anti-Signale (Auszug; vollständig im Report des Skripts)

| Eigenschaft | Anti-Signal | P |
|---|---|---|
| Deterministisch | `builtins.currentTime`, `builtins.getEnv`, `import <nixpkgs>`, `--impure` | P0 |
| Immutabel | Schreibzugriff auf `/nix/store/` | P0 |
| FHS-Annahme | `/usr/bin`, `/usr/lib`, `/bin/bash` als Pfad | P1 |
| Deklarativ | `> /etc/…`, `sed -i` in `ExecStartPre`, `system.activationScripts` | P1–P2 |
| Reproduzierbar | `nix-channel`, `nix-env -i` | P1–P2 |
| Explizit | `curl`/`git clone` in Units ohne Begründung/Kommentar | P2 |
| **Ableitung** | Modul liest eine Quelle (`manifest`) und schreibt daraus Ableitungen, die ein Guardrail prüft (**ADR-040**) | P1 |
| Staging | Neue `.nix`-Datei ohne `git add -N` messen (**AB-032**) | Arbeitsschritt |

## Klassifikation

| P | Bedeutung | Aktion |
|---|---|---|
| P0 | Konstitutionsbruch (ADR-0000) | CI rot, sofort beheben |
| P1 | Idiom-Bruch (funktioniert, aber un-NixOS) | Report, Mensch entscheidet |
| P2 | Grenzfall | Report, Kontext prüfen |
| P3 | dokumentierte Ausnahme | kein Fund |

## Was **nicht** grepbar ist (Kontextarbeit — P1-Kandidaten)

1. `mkForce` gegen eine plain-Definition auf derselben Option?
2. Liegt ein echter **Datenzyklus** vor (Quelle ↔ Ableitung, ADR-040)?
3. `types.enum` auf einem Feld, das **niemand** liest?
4. Deploy-/Provisioning-Skript mit mehr als einem manuellen Schritt?
5. Doku mit nummerierten Hand-Schritten (statt deklariert)?

## Regel für den Report

Pro Fund: `Datei:Zeile` · Signal · **Urteil nach Kontext** · Vorschlag · Kontext
(Build-/Laufzeit/dokumentiert). **Kein Auto-Fix** — ein `curl` im DDNS-Skript ist
legitim; ein „Fix", der es umbaut, zerstört die Funktion.

## Prüf-Leiter (Kurzform)

| Stufe | Befehl |
|---|---|
| 0 | `nixfmt -c` · `actionlint` · `yamllint` · `folder_lint.sh` |
| 0a | `nixos_idiom_audit.py --p0-only` (Kandidat für CI, fail-closed) |
| 0b | Lint-Checks **bauen** (`nixfmt/statix/deadnix/nixmeta/unit-scripts`) |
| 1 | `nix flake check --no-build` |
| 1a | `nix flake check` **ohne** `--impure` — der harte Beweis |
| 2 | `nix build .#packages.x86_64-linux.docs` + Generator-Checks (`gen_todo`, `gen_service_map`) |

## Referenzen

- `docs/concepts/nixos-eigenschaften.md` · `docs/adr/ADR-040-*.md`
- `scripts/nixos_idiom_audit.py` · `docs/RUNBOOK.md`
