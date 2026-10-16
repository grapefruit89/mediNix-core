---
id: "ADR-574"
title: "Arr API provisioning (oneshot)"
domain: 57
status: active
last_reviewed: 2026-10-16
tags:
  - maintenance
  - arr-stack
  - provisioning
links:
  adr: ""
  repo-harvest: ""
---
# ADR-574: Arr API Provisioning — Oneshot (57-maintenance, Dienst 574)

## Status: active
## Date: 2026-10-16
## Source: 57-maintenance/574-provisioning.nix + lib/arr-provision
## Related: ADR-0010 (API vs. Filesystem), ADR-040 (gerichtete Abhängigkeiten), ADR-521 (Secrets)

## Decimalrahmen (ADR-0000 §4)
- Dienstnummer: **574** (57-maintenance, Slot 4)
- Kein eigener Listener: **oneshot** `mediNix-provision.service`
- Ausführung als `User = media`, `StateDirectory = mediNix-state` (0750)

## Context
Vieles am arr-Stack ist **nicht** über die Dienst-Konfiguration erreichbar,
sondern nur über die **API**: Download-Clients, die Registrierung der Apps in
Prowlarr samt Indexern, und der `[categories]`-Block in SABnzbd. Das per Hand
zu klicken ist nicht reproduzierbar.

## Decision
- **Ein** gehärteter Oneshot fährt die API-Einrichtung idempotent über einen
  Flag-File (`/var/lib/mediNix-state/provisioned`).
- Rollen werden **aus `medinix.manifest` abgeleitet** (SSoT / ADR-0010), nicht
  hartkodiert: `media-manager` usw. bestimmen die Ziele dynamisch.
- Credentials kommen über **systemd-Credentials** (`/run/credentials/…`), **nie**
  als Klartext-Env (ADR-521).
- SABnzbd-`[categories]` wird nur angelegt, wenn die Sektion **fehlt** — eine
  konfigurierte Kategorie-Schematik wird nie überschrieben.

## Consequences
- ✅ Frischinstallation konvergiert in **einem** Lauf
- ✅ Keine Secrets im Store/Env (systemd-Credentials)
- ✅ Least Privilege (`media` statt root)
- ⚠️ Erneuter Lauf erfordert das Zurücksetzen des Flag-Files (bewusst, Idempotenz)
