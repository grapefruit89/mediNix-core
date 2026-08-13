---
id: "GUIDE-52-hardening-secrets"
title: "GUIDE 5200 hardening secrets"
domain: 52
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - hardening
  - secrets
  - security
links:
  adr: ""
  repo-harvest: ""
---
# 🛡️ SRE-Hardening: Secrets & Security

In einem Aviation-Grade System liegen keine Geheimnisse im Klartext. Wir nutzen `sops-nix` und `age`.

## 🔑 Der Age-Key (Identität)
Deine Identität ist dein Age-Key (`/home/mynixos/secrets/age-key.txt`). Er ist der einzige Schlüssel zum Tresor.

## 📂 Der Tresor: secrets.yaml
Alle Token und Passwörter liegen verschlüsselt in `secrets/secrets.yaml`.

### Workflow:
1.  **Editieren:** `nix run nixpkgs#sops -- secrets/secrets.yaml`
2.  **Referenzieren:** In Nix-Modulen via `config.sops.secrets."github/token".path`.

## 🛡️ Hardening von systemd-Units
Jeder Dienst muss mit minimalen Berechtigungen laufen. 
- **ProtectSystem=strict**
- **ProtectHome=true**
- **PrivateTmp=true**
