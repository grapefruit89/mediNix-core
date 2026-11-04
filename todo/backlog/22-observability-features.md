# Gruppe 3 — Observability-Features

Stand: 2026-11-04 · zusammengeführt aus `ROADMAP.md`, `docs/TODO.md`

> **Was hier steht:** Feature-Wünsche im Beobachtungsbereich. Kein aktueller Bedarf —
> der Betrieb läuft ohne sie. `ROADMAP.md` bleibt Quelle.

| ID | Punkt | Aufwand | Charakter | Belege |
|---|---|---|---|---|
| **R75** | **Prometheus-Scraper fehlt — Exporter ohne Konsument.** `532–536` setzen `metrics.type = "exportarr"`, `585-exporters.nix` erzeugt die Exporter, aber niemand liest sie. Entweder Store ergänzen (Prometheus / VictoriaMetrics / vmagent) **oder** die Exporter abschalten (YAGNI). | MITTEL | **Observability / toter Code** | `ROADMAP.md:75` · `docs/TODO.md:29` |
| **R80** | **Vector + Loki + Grafana.** Journal + Caddy-JSON-Logs, 7 Tage Retention, Storage auf Tier B, Grafana hinter Caddy am Unix-Socket. | GROSS | Observability | `ROADMAP.md:80` · `docs/TODO.md:31` |
| **R99** | **`medinix gather <symptom>`.** Die 7 geordneten Abschnitte (WAS · WER · IST · LOGS · PFADE · DIFF · FIX) aus Registry + systemd, redigiert + token-gekappt. | MITTEL | Tooling / Observability | `ROADMAP.md:99` · `docs/TODO.md:42` |

## Empfehlung

**R75 vor R80.** Exporter, die niemand liest, sind kein Feature, sondern Last. Entweder
einen Konsumenten hinstellen oder die Exporter abschalten — beides ist besser als der
heutige Zustand.

R80 (Loki-Stack) ist erst sinnvoll, wenn es etwas zu durchsuchen gibt. Solange `journalctl`
lokal reicht, ist es Infrastruktur ohne Problem.

## Nicht Teil dieser Gruppe

- Gatus/ntfy sind aktiv und funktionieren → kein Punkt.
- Alarme/Policy → `docs/RUNBOOK.md`.
