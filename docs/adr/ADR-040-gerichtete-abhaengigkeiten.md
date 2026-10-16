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
   - **Quellen** (Absicht/Deklaration): `lib/registry.nix` (statisch), `medinix.manifest`
     (Deklaration der Dienste), Absichts-Optionen (`medinix.<bereich>.<dienst>.*`,
     `medinix.factoryUnits` als deklarierte Fabrik-Absicht).
   - **Ableitungen** (berechnet): `lib/derive.nix`-Werte, `users.users`/`users.groups`,
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
  langfristig in die Engine (`lib/derive.nix` + Manifest-Absicht) — dann baut das
  Modul nur noch `systemd.services`.
