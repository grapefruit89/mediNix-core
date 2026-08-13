---
id: "GUIDE-52-media-hardening"
title: "GUIDE 5200 media hardening"
domain: 52
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - hardening
  - media
  - security
links:
  adr: ""
  repo-harvest: ""
---
# 🎬 Media-Stack: Aviation-Grade Entertainment

In mynixos wird der Medien-Stack (Layer 40) nicht einfach nur "ausgeführt", sondern gehärtet und optimiert.

## 🛡️ VPN-Confinement (The Nixarr Pattern)
Kritische Dienste (SABnzbd, Prowlarr) werden physisch auf einen VPN-Namespace beschränkt.
- **Ziel:** Kein Paket verlässt den Tower am VPN vorbei (Killswitch nativ in Nix).
- **Vorteil:** Keine "Lecks" der IP-Adresse.

## ⚡ Hardware-Transcoding (Intel QuickSync)
Dein Fujitsu Q958 nutzt die Intel UHD 630 GPU.
- **Treiber:** Wir nutzen konsequent den `intel-media-driver` (iHD).
- **Konfiguration:** `nixpkgs.config.packageOverrides = pkgs: { vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; }; };` (oder neuer Standard).

## 🧩 Modul-Integration
Jeder ARR-Dienst wird als Dendrit in `modules/40-media/` angelegt und injiziert seine eigenen Caddy-Ressourcen.