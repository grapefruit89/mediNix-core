---
id: "ADR-51-lightweight-identity-pocketid"
title: "ADR 5120 lightweight identity pocketid"
domain: 51
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - ingress
  - pocketid
links:
  adr: ""
  repo-harvest: ""
---
# 🏛️ ADR-001: PocketID als Lightweight Identity Provider

## Kontext
Wir benötigen einen zentralen OIDC-Provider für mTLS und Forward-Auth auf dem Tower (Layer 40/60).

## Optionen
1. **Authentik:** Feature-reich, aber extrem ressourcenfressend (PostgreSQL, Redis, Workers).
2. **PocketID:** Schlank, Go-basiert, nativer Passkey-Fokus.

## Entscheidung
Wir wählen **PocketID**.

## Begründung
- **Effizienz:** Authentik ist für ein Single-Server Setup (Tower) zu schwerfällig.
- **Sicherheit:** PocketID fördert den passwortlosen Aviation-Grade Standard.
- **Wartbarkeit:** Weniger Abhängigkeiten (keine externe DB zwingend nötig).

## Status
Authentik-Nuggets bleiben in der Knowledge-Base nur als **Referenz für komplexe Nix-Module** erhalten, werden aber im System-Design ignoriert.
