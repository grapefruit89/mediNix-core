---
id: "GUIDE-50-aviation-grade"
title: "GUIDE 5000 aviation grade"
domain: 50
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - core
links:
  adr: ""
  repo-harvest: ""
---
# ⚖️ Aviation-Grade Efficiency: Der Binary Standard

In mynixos wird jede architektonische Entscheidung durch das Prisma der Ressourceneffizienz betrachtet. Wir bauen ein System für einen Home-Server, kein unbegrenztes Rechenzentrum.

## 🚀 Das Go/Rust/C Mandat
Wir bevorzugen konsequent Dienste, die in performanten, nativ kompilierten Sprachen geschrieben sind.
- **Goldstandard:** Go, Rust, C, C++.
- **Minimale Laufzeit:** Wir vermeiden Python, Java oder Node.js, wo immer eine binäre Alternative existiert.

## 🛡️ Begründung
1. **Memory Footprint:** Native Binaries benötigen oft nur einen Bruchteil des RAMs von VM-basierten Sprachen.
2. **Kaltstart:** Dienste müssen sofort einsatzbereit sein (Aviation-Grade Response).
3. **Deklarative Integrität:** Binäre Dienste lassen sich oft sauberer als einzelne statische Files in Nix integrieren.

## 🧩 Anwendung im System-Design
Bei der Auswahl neuer Dendriten (Dienste) wird zuerst nach einer binären Lösung gesucht.
- *Beispiel:* PocketID (Go) gewinnt gegen Authentik (Python/Postgres Stack).
- *Beispiel:* Caddy (Go) gewinnt gegen Nginx (C, aber Caddy ist in Nix einfacher zu härten).
