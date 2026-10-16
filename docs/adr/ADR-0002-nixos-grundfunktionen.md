---
id: "ADR-0002"
title: "NixOS-Grundfunktionen (bindend)"
status: active
complexity: 2
last_reviewed: 2026-10-16
links:
  adr: ADR-0000 (Verfassung), ADR-040 (gerichtete Abhaengigkeiten), ADR-5000 (native services over docker), ADR-5050 (systemd hardening)
---

# ADR-0002: NixOS-Grundfunktionen (bindend)

## Status
active - **verbindlich** fuer jede Aenderung in diesem Repo (Nix-Code, Doku, Checks).
Dieses ADR sagt nicht *was* gebaut wird (das macht ADR-0000), sondern *wie*.

## Entscheidung
Fuenf Eigenschaften sind Regeln, keine Empfehlungen:

1. **Deklarativ.** Jeder Zustand entsteht aus einer Option. Keine imperativen Schritte, keine
   "einmal ausgefuehrten" Befehle, kein Zustand ausserhalb der Konfiguration.
2. **Deterministisch und reproduzierbar.** Gleicher Input -> gleicher Output. Keine Zeit, kein
   Zufall, kein Host-Zustand, keine ungemessenen Umgebungsvariablen im Eval. Netzwerkzugriff nur
   zur Build-Zeit ueber Pins (Flake-Lock), nie zur Laufzeit-Auswertung.
3. **Faul und eval-zeit-sicher.** Werte sind Ausdruecke, keine Skripte. Gueltige Abhaengigkeiten
   sind gerichtet (ADR-040): Guardrails lesen **Quellen**, Pruefungen des **abgeleiteten**
   Ergebnisses sind Checks - nie Assertions waehrend der Config-Auswertung.
4. **Fail-closed.** Verletzungen brechen ab (Assertion/Check/`throw`), sie warnen nicht und
   liefern keinen stillen Default. Kein `or true`, kein "best effort"-Fallback in Invarianten.
5. **systemd-native, ohne Container.** Dienste sind systemd-Units. Eine Container-Laufzeit wird
   nicht eingesetzt (ADR-5000). Eine Ausnahme braucht ein eigenes ADR - nicht einen stillen
   Sonderweg.

## Durchsetzung
- **Pruef-Leiter** (`docs/CONVENTIONS.md`): `nix flake check` mit Builds, Ratschen, Doku-Gates.
- **Checks statt Prosa:** `scripts/check_grundfunktionen.py` (in `order-lint`) erzwingt das
  mechanisch pruefbare Stueck: keine aktivierte Container-Engine, keine unreinen Eval-Quellen.
- **Korridor:** AB-042 (Assertions lesen nur Quellen) und AB-043 (diese fuenf Funktionen) in
  `.agent-state.json`.
- **Formregel fuer ADRs:** siehe `scripts/check_adrs.py` + `docs/adr/llm-index.json`.

## Siehe auch
- `docs/NO-CONTAINERS.md` (bestehende Begruendung) und die verbietenden Assertions in
  `50-core/500-host-baseline.nix` + `59-guardrails/591-cross-domain.nix`
  (`!(config.virtualisation.docker.enable or false)`).

## Konsequenzen
- Ein neuer Dienst wird als NixOS-Modul + systemd-Unit gebaut - nicht als Compose-Datei.
- Wo eine native Loesung fehlt, wird zuerst geprueft, ob es sie doch gibt (Upstream/Packaging),
  und erst dann eine begruendete Ausnahme entschieden.
- Nicht-Ziel: dieses ADR wiederholt nicht ADR-0000 (Nummern/Identitaeten) und nicht ADR-5050
  (Hardening) - es verweist darauf.
