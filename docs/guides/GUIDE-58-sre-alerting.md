---
id: "GUIDE-58-sre-alerting"
title: "GUIDE 5800 sre alerting"
domain: 58
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - alerting
  - observability
  - sre
links:
  adr: ""
  repo-harvest: ""
---
# 💬 SRE Alerting: Der Matrix-Standard

Ein Aviation-Grade System meldet sich selbstständig, wenn etwas schiefläuft. Wir nutzen Matrix als zentralen Kommunikationskanal.

## 🚀 Das Webhook-Prinzip
Wir nutzen `matrix-hook`, um einfache HTTP-POST Anfragen in Matrix-Nachrichten umzuwandeln.
- **Vorteil:** Jedes Script (Bash, Python, Nix) kann Alarme senden.

## 🛠️ Einsatzszenarien (Layer 80)
1.  **Backup-Status:** Bestätigung über erfolgreiche Backups oder Fehlermeldungen.
2.  **SRE-Audits:** Monatliche Berichte über die Systemreinheit (SRE Tor 6).
3.  **Sicherheit:** Benachrichtigung bei SSH-Logins oder Sops-Zugriffen.

## 🧩 Implementierung
Der `matrix-hook` Dienst wird in `modules/80-monitoring/notifications.nix` definiert und via Sops-Secrets (Token) abgesichert.