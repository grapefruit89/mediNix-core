---
id: "ADR-581"
title: "ntfy — internal notification backend"
domain: 58
status: active
complexity: 3
last_reviewed: 2026-10-16
tags:
  - observability
  - notifications
  - ntfy
links:
  adr: ""
  repo-harvest: ""
---
# ADR-581: ntfy — Internes Benachrichtigungs-Backend (58-observability, Dienst 581)

## Status: active
## Date: 2026-10-16
## Source: 58-observability/581-ntfy.nix
## Related: ADR-5050 (Hardening-Baseline), ADR-511 (Caddy), ADR-0000 (Dezimalrahmen)

## Decimalrahmen (ADR-0000 §4)
- Dienstnummer: **581** (58-observability, Slot 1)
- **UID = Port = 5810** (UPG-Account `ntfy`)
- Unit: `ntfy` · Caddy-Klasse: `internal`

## Context
Benachrichtigungen (Timer-Fehler, `OnFailure`, Gatus) brauchen ein internes
Ziel. Das Upstream-Modul `services.ntfy-sh` erzwingt jedoch `DynamicUser = true`
und `ProtectSystem = "full"` — das **verletzt** unsere gelockten Invarianten
(`DynamicUser = false`, `UID = Port`).

## Decision
- **Eigene**, gehärtete Unit über die Service-Factory statt des Upstream-Moduls:
  UPG-Benutzer `ntfy`, `media` als Zusatzgruppe, Hardening-Profil `network`.
- **Nur Loopback**; veröffentlicht wird ausschließlich über Caddy mit
  `accessGroup = internal` — Caddy ist die Wand, ntfy selbst bleibt read-write.
- Der Unit-Name ist **`ntfy`** (nicht `ntfy-sh`), damit Unit, Manifest-Schlüssel
  und Systembenutzer **identisch** heißen.
- `alert-ntfy@` als `OnFailure`-Notifier-Template für alle Dienste.

## Consequences
- ✅ Invarianten-konform (`DynamicUser = false`, `UID = Port = 5810`)
- ✅ Kein öffentlicher Port; Zugriff nur über Caddy (intern)
- ✅ Ein Namensraum: Unit = Manifest-Key = Benutzer
- ⚠️ Wir pflegen das Rendering selbst (Upstream-Modul nicht nutzbar) → bei
  ntfy-Änderungen mitziehen
