---
id: "GUIDE-50-container-symbiose"
title: "GUIDE 50 — Zero-Container: systemd-native statt Arion/Docker"
domain: 50
status: active
complexity: 2
last_reviewed: 2026-10-17
tags:
  - core
links:
  adr: ""
  repo-harvest: ""
---
# 🚫 Zero-Container: systemd-native statt Arion/Docker

**Entscheidung:** mediNix-core nutzt ausschließlich NixOS-native systemd-Dienste.
Docker, Podman, OCI-Runtimes und netns-Wrapper sind ausgeschlossen.

## 🛡️ Begründung
- Der **Nix Store** ist der Container-Ersatz: reproduzierbar, isoliert,
  rollback-fähig.
- **systemd-Hardening** (`ProtectSystem`, `PrivateTmp`, `IPAddressDeny`) ersetzt
  Netzwerk-Isolation.
- Kein Daemon = weniger Angriffsfläche, RAM und Komplexität.

Als Assertion verankert: `50-core/500-host-baseline.nix` verbietet
`virtualisation.docker.enable = true`.

## 🧩 Folge für Module
Ein Dienst ist ein `NN-domain/NNN-<name>.nix` (native systemd-Unit über
`lib/service-factory.nix`), kein Compose-Stack. Es gibt **kein** `arion.enable` und
**kein** `mynixos.services.arion`.

## 🔭 Ausnahme (Zukunft)
Falls ein Dienst nicht in nixpkgs verfügbar ist: erst eigenes Paket bauen
(`fetchFromGitHub` + Builder), nur als letzter Ausweg OCI via `systemd-nspawn`
(kein Docker). Beispiel-Placeholder: `57-maintenance/573-maintainerr.placeholder.md`.

Quellen: `docs/NO-CONTAINERS.md`, `50-core/500-host-baseline.nix`,
Root-`README.md`, `docs/TERMINOLOGY.md` („Keine Container/netns, systemd-native").
