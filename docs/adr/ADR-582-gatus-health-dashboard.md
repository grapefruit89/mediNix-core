---
id: "ADR-582"
title: "Gatus als Health-Dashboard (Manifest-Konsument, nicht services.gatus)"
status: active
complexity: 2
last_reviewed: 2026-10-16
links:
  adr: ADR-0002 (Grundfunktionen), ADR-5050 (systemd-Hardening-Baseline)
---

# ADR-582: Gatus als Health-Dashboard

## Kontext
Ein Ueberblick "welcher Dienst antwortet wirklich?" - HTTP und TCP, aus dem Manifest abgeleitet,
ohne Handpflege und ohne Zusatzprogramme (systemd-first, ADR-0002).

## Entscheidung
- Gatus laeuft als **eigene Unit ueber die Service-Factory** (Hardening-Profil und StateDirectory
  an einer Stelle) - bewusst **nicht** ueber `services.gatus`.
- Die Checks werden **generiert**: aus `medinix.manifest` entstehen HTTP-Endpunkte und
  TCP-Socket-Pings; nur aktive, ueberwachbare Dienste werden beruecksichtigt.
- Gatus ueberwacht **sich selbst nicht rekursiv** und hat einen **eigenen** Manifest-Eintrag (582).
- Der Account gehoert der **Engine** (`ownsAccount = false`): `users.users.gatus`, UPG-Gruppe und
  StateDirectory kommen aus dem Dezimalrahmen (UID = Port = 5820).
- **Kein ICMP:** Ping-Checks braeuchten `CAP_NET_RAW` (AmbientCapabilities + CapabilityBoundingSet) -
  das wird bewusst nicht vergeben.

## Begruendung
- Das Upstream-Modul `services.gatus` setzt `DynamicUser = true` (verletzt die locked_invariants
  `DynamicUser = false`) und bindet standardmaessig Port **8080** statt **5820** - beides
  inakzeptabel.
- Generierte Checks statt gepflegter Liste: eine Quelle (`lib/registry.nix` + Manifest), kein Drift.

## Konsequenzen
- Neue Dienste sind ohne Zutun sichtbar; Dienste ohne Port erscheinen nicht als HTTP-Check.
- Alarme laufen ueber die interne Benachrichtigung (Dienst 581, ntfy).
