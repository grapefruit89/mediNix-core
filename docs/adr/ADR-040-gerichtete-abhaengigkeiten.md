---
id: "ADR-040"
title: "Gerichtete Abhängigkeiten: Quelle → Ableitung (Guardrails lesen nie das Abgeleitete)"
domain: 50
status: active
complexity: 3
last_reviewed: 2026-10-16
tags:
  - governance
  - modul-system
  - guardrails
links:
  adr: ADR-0000 (Verfassung, §4 Ableitung), ADR-5043 (Assertion-Qualität)
  skill: nixos-mental-model, nixos-idiom-audit
---

# ADR-040: Gerichtete Abhängigkeiten im Modul-System

## Kontext

NixOS-Module lesen und schreiben `config.*`. Das ist normal — aber nur solange die
Abhängigkeiten **gerichtet** bleiben. Am 2026-10-16 brach der Branch mit
`error: infinite recursion encountered` (`nix flake check` 13/50, CI `Flake Check`
failure auf `3fc4d54`/`e46359a`). Der belegte Zyklus:

```
config.medinix.manifest  ──(585-exporters liest)──▶  users.users / factoryUnits (585 schreibt)
        ▲                                                              │
        └────────────(591-cross-domain liest)──────────────────────────┘
```

`585` liest also eine **Quelle** und schreibt daraus **Ableitungen**; `591` prüft
diese Ableitungen und liest dabei **dieselbe Quelle** — der Kreis schließt sich.
Beide Änderungen einzeln waren grün (`822a0d2` = 50 ✅).

## Entscheidung

1. **Zwei Klassen von Werten:**
   - **Quellen** (Absicht/Deklaration): `50-core/registry.nix` (statisch), `medinix.manifest`
     (Deklaration der Dienste), Absichts-Optionen (`medinix.<bereich>.<dienst>.*`,
     `medinix.factoryUnits` als deklarierte Fabrik-Absicht).
   - **Ableitungen** (berechnet): `50-core/derive.nix`-Werte, `users.users`/`users.groups`,
     `systemd.services`, `medinix.knownStateDirs`.
2. **Kanten zeigen nur `Quelle → Ableitung`.** Kein Modul darf von einer Ableitung
   auf eine Quelle **zurücklesen**, die es (oder ein Modul mit derselben Ableitung)
   selbst verbraucht.
3. **Guardrails/Checks prüfen das Abgeleitete, lesen aber nur Quellen.**
   `591` liest deshalb die statische SSoT (`svcReg.services`) und die Absicht
   (`medinix.factoryUnits`) — nicht `config.medinix.manifest`.
   Fehlt für eine Prüfung eine Absicht, wird sie als **Option** deklariert
   (z. B. `reservedAccounts`), nicht aus dem Ergebnis erraten.
4. **Reihenfolge der Prüf-Leiter:** Nach jeder Änderung die **volle** Leiter fahren
   (auch die Checks bauen). Ein einzelner grüner Check beweist nichts über die
   Verträglichkeit zweier Änderungen.

## Konsequenzen

- Kein Zyklus mehr über `manifest ↔ users.users`/`factoryUnits`; `nix flake check`
  ist wieder 50/0 (Beleg: L-046).
- Die Regel ist maschinenlesbar im Korridor hinterlegt (**AB-040**) und wird von
  `scripts/nixos_idiom_audit.py` als Signal geführt.
- **Endform (Roadmap):** Identitäten **einmal** ableiten. Wer heute in einem Modul
  eine Quelle liest, um daraus Accounts zu schreiben (Ordner `58`), verlagert das
  langfristig in die Engine (`50-core/derive.nix` + Manifest-Absicht) — dann baut das
  Modul nur noch `systemd.services`.

## Import-Konventionen (lib/ vs. Modulbaum)

*Quelle: `todo/done/2026-10-25_1bad3cc7_arch-vs-nixos/blocks/13-lib-vs-50-core.json` (D-13-01, D-13-02)*

1. **Expliziter Import von Bibliotheksfunktionen:**
   - Module importieren Funktionen aus `lib/` stets direkt und explizit (z. B. `let df = import ../50-core/derive.nix { inherit lib; }; in ...`), niemals über unbestimmte Pfade wie `<nixpkgs/lib>` oder implizite Glob-Lookups.
2. **`lib/` ist querschnittliche Infrastruktur:**
   - Dateien in `lib/` sind pure Hilfsfunktionen oder statische SSoT-Daten und besitzen keine NixOS-Modul-Signatur (`{ config, lib, pkgs, ... }`). Sie stellen keine eigene Domäne dar und werden daher in `default.nix` nicht automatisch importiert.
3. **Verbot von `with lib;` in Moduldefinitionen:**
   - Zur Wahrung von deterministischem Scoping und zur Vermeidung von Shadowing-Konflikten ist `with lib;` im gesamten Modulbaum untersagt. Alle Funktionen werden explizit als `lib.<fn>` aufgerufen.
