---
id: "ADR-554"
title: "Feishin als statische SPA (kein eigener Daemon)"
status: active
complexity: 1
last_reviewed: 2026-10-16
links:
  adr: ADR-553 (Navidrome), ADR-518 (Landingpage), ADR-511 (Ingress)
---

# ADR-554: Feishin als statische SPA

## Kontext
Navidrome (553) liefert die Musik, braucht aber eine Weboberflaeche. Feishin ist ein
Web-Player (SPA) ohne Serveranteil.

## Entscheidung
- Feishin wird als **statische SPA** ausgeliefert: **kein** eigener systemd-Dienst, **kein** Port.
- Registry-Eintrag `mkNoPort "feishin" 554 "network" "none"`; Manifest-Eintrag
  `medinix.manifest.feishin` (Titel, Zugriffsgruppe, vhost) - die Auslieferung uebernimmt der
  Ingress (511), wie bei der Landingpage (518).
- Die Anbindung an Navidrome passiert im Browser; es gibt **keine** serverseitigen Secrets und
  damit nichts zu rotieren.

## Begruendung
- Ein statisch ausgeliefertes Bundle braucht keinen Prozess, keinen Port und kein eigenes
  Hardening - systemd-first heisst hier: gar kein Dienst (ADR-0002).
- Der Dienst bleibt trotzdem im Manifest, damit Ingress, Gatus (582) und Backup-Klassifikation
  ihn kennen.

## Konsequenzen
- Ein Dienst weniger zu harden und zu ueberwachen; Updates sind ein Datei-Austausch (PWA-Cache im
  Browser beachten).
- Feishin erbt die Ingress-Zugangsregeln (`accessGroup`); eine eigene Auth gibt es nicht.
