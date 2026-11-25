# mediNix-core — Roadmap (Aktive Zukunfts-Meilensteine)

Zukunftsorientierte Meilensteine und Entwicklungsphasen.

> **Regel:** Offene Einzelaufgaben leben ausschließlich in `todo/tasks.json`
> (Sichten `docs/TODO.md` / `docs/PLAN.md`). Erledigte Meilensteine und historische
> Roadmaps sind archiviert in `historie/2026-Q4-roadmap-alt.md`.
> Budget: ≤ 50 Zeilen (0x `[x]`).

---

## Phase 1 — Host-Integration & Flotten-Rollout (Welle 1)
- Host-Belegung `fujitsuq958` vollständig verifizieren und deployen.
- VM-Smoke-Test und Service-Verträge auf physischer Hardware abnehmen.
- Ingress-Routing (`511-caddy`), SSO (`512-pocket-id`) und Blocky (`515`) im LAN testen.

## Phase 2 — Backup-Härtung & Drift-Erkennung (Welle 2)
- Automatisierte Backup-Routinen (`576-backup`) mit Offline-Restore-Verifikation.
- Drift-Erkennung (`577-drift`) und verwaiste Datenbereinigung (`578-orphan-cleanup`).
- Key-Rotation und sealed Credential-Lifecycle automatisieren.

## Phase 3 — Observability & Alerting-Ausbau (Welle 3)
- Gatus-Dashboards (`582-gatus`) und Push-Benachrichtigungen (`581-ntfy`) schärfen.
- Runtime-Guard (`583`) und Boot-Watchdog (`584`) mit automatischer Selbstheilung.
- Langzeit-Metriken und Exporter-Audit (`585-exporters`).

## Phase 4 — Vollständige Autonomie
- Zero-Docker-Produktivbetrieb im 24/7-Homelab.
- Vollständig deklaratives Flake-Deployment ohne Host-Drift.
