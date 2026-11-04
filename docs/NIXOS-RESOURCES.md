# NixOS-Ressourcen (allgemein, nicht projektspezifisch)

Stand: 2026-11-04. Übernommen aus dem ehemaligen `docs/learn/LEARN-50-gold-nuggets.md`
(Projekt „mynixos", 2026-03). Keine dieser Quellen ist eine Abhängigkeit von
mediNix-core; es ist eine Referenz-Sammlung für den Fall, dass ein Konzept
nachgelesen werden soll.

## Standard-Dokumentation

- [nix.dev](https://github.com/NixOS/nix.dev) — offizielle Nix-Dokumentation (CC-BY-SA-4.0)
- [nixpkgs](https://github.com/NixOS/nixpkgs) — das Nix-Paket-Repository (MIT)
- [nixfmt](https://github.com/NixOS/nixfmt) — offizieller Nix-Formatter (MPL-2.0).
  In mediNix-core als `nixfmt-rfc-style` im devShell und als Check aktiv.

## Hardware

- [nixos-hardware](https://github.com/NixOS/nixos-hardware) — Hardware-Quirks für
  NixOS (CC0). Aktuell **nicht** als Flake-Input genutzt; relevant, wenn
  hardware-spezifische Kernel-Module oder Firmware nötig werden.

## Sicherheit

- [nix-security-tracker](https://github.com/NixOS/nix-security-tracker) — Web-Service
  für CVE-Tracking in nixpkgs. Nützlich, falls mediNix-core je CVE-Monitoring für
  seine Dienst-Pakete machen will. Aktuell keine Integration.

## NixOS-Org-Infrastruktur (nicht projektspezifisch)

Diese Repositories sind die interne Infrastruktur von nixos.org. Sie haben mit
mediNix-core nichts zu tun, sind aber als Referenz für CI-/Deployment-Muster
aufbewahrt:

- [nixops](https://github.com/NixOS/nixops) — offizielles Nix-Deployment-Tool
  (inaktiv seit Feb 2025)
- [nixops-dashboard](https://github.com/NixOS/nixops-dashboard)
- [nixops-hetzner](https://github.com/NixOS/nixops-hetzner)
- [nixops-aws](https://github.com/NixOS/nixops-aws)
- [nixos-status](https://github.com/NixOS/nixos-status)
- [nixos-wiki-infra](https://github.com/NixOS/nixos-wiki-infra)
- [infra](https://github.com/NixOS/infra) — NixOS-Org-Server
- [ofborg](https://github.com/NixOS/ofborg) — NixOS-CI-Bot
- [ofborg-infrastructure](https://github.com/NixOS/ofborg-infrastructure)
- [amis](https://github.com/NixOS/amis) — NixOS-AMI-Automation
- [nixpkgs-merge-bot](https://github.com/NixOS/nixpkgs-merge-bot)
- [first-time-contribution-tagger](https://github.com/NixOS/first-time-contribution-tagger)
- [security](https://github.com/NixOS/security) — NixOS-Security-Team
- [reproducible.nixos.org](https://github.com/NixOS/reproducible.nixos.org)

## Nicht in dieser Liste

Die ursprüngliche Datei enthielt keinen Link zu einer konkreten
mediNix-core-Abhängigkeit. Projekt-spezifische Upstream-Quellen stehen in
[`UPSTREAM-SOURCES.md`](UPSTREAM-SOURCES.md).
