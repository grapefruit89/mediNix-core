---
id: "ADR-583"
title: "Runtime-Guard — hourly check of the running machine"
domain: 58
status: active
complexity: 3
last_reviewed: 2026-10-16
tags:
  - observability
  - guardrails
  - nftables
  - vpn
links:
  adr: ""
  repo-harvest: ""
---
# ADR-583: Runtime-Guard — stündliche Prüfung der laufenden Maschine (58-observability, Dienst 583)

## Status: active
## Date: 2026-10-16
## Source: 58-observability/583-runtime-guard.nix
## Related: ADR-5210 (nftables-Baseline), ADR-526 (VPN-Killswitch), ADR-0000 (Dezimalrahmen)

## Decimalrahmen (ADR-0000 §4)
- Dienstnummer: **583** (58-observability, Slot 3)
- Kein eigener Listener: **Timer** `mediNix-runtime-guard`
- Benötigt `CAP_NET_ADMIN` (für `nft list`, read-only)

## Context
Die Konfiguration ist deklarativ, aber die **laufende** Maschine kann abweichen:
fehlende nftables-Regeln, ein Dienst, der auf `0.0.0.0` lauscht, oder ein
ausgefallenes VPN-Interface. Solche Abweichungen fallen sonst erst spät auf.

## Decision
- Ein **stündlicher Timer** prüft den Ist-Zustand: (1) nftables-Regelsatz,
  (2) keine ungewollten `0.0.0.0`-Listener, (3) VPN-Interface.
- Die Prüfung **fällt geschlossen aus** (fail-closed): eine nicht durchführbare
  Socket-Inspektion gilt als Fehler, nicht als OK.
- Verzweigung passiert **Nix-seitig** statt über konstante Shell-Vergleiche —
  ein konstanter `[ "0" = "1" ]` ist `SC2050` und bricht den Unit-Build
  (genau das passierte in der CI am 2026-10-15).

## Consequences
- ✅ Drift zwischen Repo und laufender Maschine wird sichtbar (stündlich)
- ✅ Rein lesende Prüfungen; `CAP_NET_ADMIN` eng begrenzt
- ⚠️ Meldet nur, behebt nicht — Remediation bleibt beim Menschen/Deploy
