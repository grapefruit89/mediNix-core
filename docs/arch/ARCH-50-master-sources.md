---
id: "ARCH-50-master-sources"
title: "ARCH 5000 master sources"
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
# 👑 MASTER-SOURCES: Die Aviation-Grade Goldkammer (Server-Only)
Diese Datei ist die ultimative Single Source of Truth für alle Architektur-Links und Repositories deines Systems.

## 🏛️ NixOS Official (The Core)
- [nixpkgs](https://github.com/NixOS/nixpkgs) - The heart of the ecosystem.
- [nix.dev](https://github.com/NixOS/nix.dev) - Official guide for "Getting Things Done" (Aviation-Grade Docs).
- [infra](https://github.com/NixOS/infra) - Reference server configurations for nixos.org.
- [nixops](https://github.com/NixOS/nixops) - Professional network deployment tool.
- [nixos-hardware](https://github.com/NixOS/nixos-hardware) - Server-optimized hardware profiles.
- [ofborg](https://github.com/NixOS/ofborg) - Automation and CI infrastructure.
- [nix-security-tracker](https://github.com/NixOS/nix-security-tracker) - Vulnerability management.

## 🌳 hercules-ci (Automation & Structure)
- [flake-parts](https://github.com/hercules-ci/flake-parts) - The framework for your Dendritic architecture.
- [arion](https://github.com/hercules-ci/arion) - The bridge between Nix and Docker-Compose.
- [hercules-ci-agent](https://github.com/hercules-ci/hercules-ci-agent) - The engine for remote builds.
- [effects](https://github.com/hercules-ci/effects) - Declarative side-effects and deployment.

## 🛡️ nix-community (SRE-Hardening)
- [disko](https://github.com/nix-community/disko) - Declarative disk partitioning (ZFS/LUKS).
- [impermanence](https://github.com/nix-community/impermanence) - Ephemeral root strategy (M1 Abrams Hygiene).
- [home-manager](https://github.com/nix-community/home-manager) - Reproducible user environments.
- [sops-nix](https://github.com/Mic92/sops-nix) - Atomic secrets management (via Mic92).
- [nix-index](https://github.com/nix-community/nix-index) - Global file search for nixpkgs.

## 🧩 mightyiam & Victor Borja (Dendritic Masters)
- [dendritic](https://github.com/mightyiam/dendritic) - The original pattern blueprint.
- [infra](https://github.com/mightyiam/infra) - Reference for modular IT infrastructure.
- [import-tree](https://github.com/vic/import-tree) - Automatic nix file discovery (Critical Engine).
- [den](https://github.com/vic/den) - Aspect-oriented, context-driven configurations.
- [denful](https://github.com/vic/denful) - Reusable, cherry-pickable Dendritic modules.
- [checkmate](https://github.com/vic/checkmate) - Flake checker using nix-unit and treefmt.

## 🔐 Identity & Security (Ingress & Auth)
- [pocket-id](https://github.com/pocket-id/pocket-id) - OIDC provider with Passkey authentication.
- [jailed-agents](https://github.com/andersonjoseph/jailed-agents) - Secure Nix sandboxing using bubblewrap.
- [caddy](https://github.com/caddyserver/caddy) - Fast web server with automatic HTTPS.
- [certmagic](https://github.com/caddyserver/certmagic) - Powerhouse behind Caddy's TLS.

## 🏢 Determinate Systems (Enterprise Nix)
- [nix-installer](https://github.com/DeterminateSystems/nix-installer) - The modern Nix installer.
- [flake-checker](https://github.com/DeterminateSystems/flake-checker) - Automated health checks for flakes.
- [magic-nix-cache](https://github.com/DeterminateSystems/magic-nix-cache) - Zero-config binary cache for CI.

## 🔍 SRE Audit & Visualization
- [NixoScope](https://github.com/giomf/NixoScope) - Dependency visualizer for Dendritic Nix.

## 🛡️ nix-community (Server-Infrastructure & Ops)
- [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) - Install NixOS everywhere via SSH (Critical for Remote Ops).
- [lanzaboote](https://github.com/nix-community/lanzaboote) - Secure Boot for NixOS (Aviation-Grade Security).
- [srvos](https://github.com/nix-community/srvos) - Optimized NixOS profiles for servers (High-Level Hardening).
- [authentik-nix (RESOURCES-HEAVY)](https://github.com/nix-community/authentik-nix) - NixOS module for Authentik (Identity Management).
- [harmonia](https://github.com/nix-community/harmonia) - High-performance Nix binary cache (Infrastructure Speed).
- [nixos-facter](https://github.com/nix-community/nixos-facter) - Declarative hardware configuration discovery.
- [vulnix](https://github.com/nix-community/vulnix) - Vulnerability scanner for NixOS (SRE Tor 4).

## 🔩 Native NixOS Modules (The "Stick-Ready" Core)
- [srvos](https://github.com/nix-community/srvos) - High-level server profiles (Aviation-Grade Hardening).
- [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) - Seamless SSH-based installation.
- [haumea](https://github.com/nix-community/haumea) - Filesystem-based Nix module management.
- [dns.nix](https://github.com/nix-community/dns.nix) - Declarative DNS management in pure Nix.
- [nixos-cli](https://github.com/nix-community/nixos-cli) - Unified CLI for NixOS operations.
- [nixos-facter](https://github.com/nix-community/nixos-facter) - Automatic hardware detection for NixOS.

## 🎨 Nix Architectural Masterpieces (Pattern Mining Only)
- [nix-community/infra](https://github.com/nix-community/infra) - Reference for production fleet management (SSoT Patterns).
- [disko](https://github.com/nix-community/disko) - Data-driven hardware abstraction (Complex Data Structures).
- [home-manager](https://github.com/nix-community/home-manager) - The blueprint for modular option definitions.
- [poetry2nix](https://github.com/nix-community/poetry2nix) - Advanced dependency graph mapping in pure Nix.
- [nixos-facter](https://github.com/nix-community/nixos-facter) - Dynamic-to-static hardware mapping patterns.

## ⚙️ giomf (Modular Configs & Templates)
- [nixos-config](https://github.com/giomf/nixos-config) - Base NixOS configuration for multiple hosts (Efficiency Patterns).
- [nix-templates](https://github.com/giomf/nix-templates) - Ready-to-use Nix project templates.

## 🎬 Media Infrastructure Masterpieces (Pattern Mining)
- [nixarr](https://github.com/nix-media-server/nixarr) - The gold standard for NixOS media servers (VPN & Hardening patterns).
- [nixflix](https://github.com/kiriwalawren/nixflix) - Modern Flake-based media stack implementation.

## 🧙 Mic92 (The Nix Virtuoso)
- [adios-flake](https://github.com/Mic92/adios-flake) - High-performance flake module system.
- [attic](https://github.com/Mic92/attic) - Self-hosted Nix binary cache (Infrastructure Speed).
- [cntr](https://github.com/Mic92/cntr) - Container debugging tool (SRE Operations).
- [alejandra](https://github.com/Mic92/alejandra) - Uncompromising Nix code formatter (Purity Tool).
- [nixos-shell](https://github.com/Mic92/nixos-shell) - Lightweight NixOS VM spawner (SRE Testing).
- [dotfiles-mic92](https://github.com/Mic92/dotfiles) - High-level server configurations and patterns.
- [retiolum](https://github.com/Mic92/retiolum) - Tinc-based mesh VPN patterns.
- [dream2nix-ha](https://github.com/Mic92/dream2nix-home-assistant) - Home Assistant packaging patterns.
- [userborn-impermanence](https://github.com/Mic92/userborn-with-impermanence) - User management with ephemeral root.
- [nixos-generators](https://github.com/Mic92/nixos-generators) - Multi-format image builder (ISO, VM, Cloud).
- [microvm.nix](https://github.com/Mic92/microvm.nix) - Lightweight Micro-VM framework for NixOS.
- [nixcfg](https://github.com/Mic92/nixcfg) - Advanced server & laptop flake configuration (Reference).
- [not-os](https://github.com/Mic92/not-os) - Minimal read-only SquashFS system patterns.
- [matrix-hook](https://github.com/Mic92/matrix-hook) - Lightweight webhook for Matrix notifications (SRE Alerting).
- [dotnix](https://github.com/kiriwalawren/dotnix) - NixOS, HomeManager and Nixvim configurations (Developer Experience).
- [hydra](https://github.com/NixOS/hydra) - The official continuous build system (CI/CD Masterpiece).
- [nixos-metrics](https://github.com/NixOS/nixos-metrics) - Performance and system health tracking.
- [ofborg-infrastructure](https://github.com/NixOS/ofborg-infrastructure) - Reference for production-grade NixOS infrastructure.
- [images](https://github.com/NixOS/images) - Image building patterns for various platforms.
- [rfcs](https://github.com/NixOS/rfcs) - The architectural reasoning behind the Nix ecosystem.

## 👑 ironicbadger (Media Infrastructure King)
- [pms-wiki](https://github.com/ironicbadger/pms-wiki) - The Perfect Media Server Wiki (Architecture Bible).
- [nix-config-ironic](https://github.com/ironicbadger/nix-config) - Advanced NixOS configurations for media and homelab.
- [infra-ironic](https://github.com/ironicbadger/infra) - Infrastructure as code patterns for self-hosters.

## 🤖 Home Automation & IoT (SRE Services)
- [quicksync_calc](https://github.com/ironicbadger/quicksync_calc) - Resource calculation for Intel QuickSync (Transcoding Optimization).
- [awesome-home-assistant](https://github.com/ironicbadger/awesome-home-assistant) - Curated list of high-quality HA resources.
- [ansible-role-caddy](https://github.com/ironicbadger/ansible-role-caddy) - Professional Caddy patterns (Referenz für Ingress-Logik).

## 💎 Misterio77 (Architecture & Persistence Guru)
- [nix-config-misterio](https://github.com/Misterio77/nix-config) - Reference for opt-in persistence and BTRFS snapshotting.
- [nix-starter-configs](https://github.com/Misterio77/nix-starter-configs) - Best-practice templates for NixOS + Flakes.
- [nix-colors](https://github.com/Misterio77/nix-colors) - Declarative color schemes (Logic abstraction masterpiece).

## 🏭 numtide (Industrial Nix Standards)
- [treefmt](https://github.com/numtide/treefmt) - Unified formatting for all source files (Purity Standard).
- [nix-filter](https://github.com/numtide/nix-filter) - Efficient source filtering for fast builds.
- [blueprint](https://github.com/numtide/blueprint) - Opinionated folder structure for Nix projects.
- [system-manager](https://github.com/numtide/system-manager) - Manage any Linux distribution with Nix.

## 🏛️ The Nix Architects (Gründerväter & SRE-Köpfe)
- [direnv](https://github.com/direnv/direnv) - Shell extension for auto-loading Nix environments (Automation).
- [devenv](https://github.com/cachix/devenv) - Fast, composable developer environments (Modern Standard).
- [nix-serve](https://github.com/edolstra/nix-serve) - The reference binary cache server (Infrastructure).
- [nix-index](https://github.com/nix-community/nix-index) - (Originally by bennofs, maintained by community) - SRE File Discovery.

## 💬 Matrix Communications (Collaboration Core)
- [dendrite](https://github.com/matrix-org/dendrite) - Second-generation Matrix homeserver in Go (Efficiency King).
- [matrix-spec](https://github.com/matrix-org/matrix-spec) - The official technical specification of the Matrix protocol.
- [conduit](https://github.com/girlbossceo/conduit) - Ultralight Matrix homeserver in Rust (Aviation-Grade Peak).
