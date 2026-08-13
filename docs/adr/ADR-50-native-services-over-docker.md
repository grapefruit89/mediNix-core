---
id: "ADR-50-native-services-over-docker"
title: "ADR 5000 native services over docker"
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
# 🏛️ ADR-002: Native NixOS Services bevorzugen

## Kontext
Für den Home-Server (Tower) suchen wir die effizienteste und am einfachsten zu wartende Deployment-Methode.

## Entscheidung
Wir setzen primär auf **native NixOS-Module** und vermeiden Docker/Podman, wo es eine native Alternative gibt.

## Begründung
- **Deklarativität:** NixOS Module erlauben die Steuerung jeder Config-Option via Nix.
- **Ressourcen:** Weniger RAM/CPU Overhead durch Wegfall der Container-Laufzeit.
- **Wartung:** Updates erfolgen zentral über `nix flake update`. Keine "Zombie-Container" mehr.
