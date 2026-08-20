---
id: "ADR-50-native-services-over-docker"
title: "ADR 5000 native services over docker"
domain: 50
status: active
complexity: 2
last_reviewed: 2026-08-20
tags:
  - core
links:
  adr: ""
  repo-harvest: ""
---
# ADR-5000: Prefer Native NixOS Services

## Context
For the home server (Tower), we are looking for the most efficient and easily maintainable deployment method.

## Decision
We primarily rely on **native NixOS modules** and avoid Docker/Podman wherever a native alternative exists.

## Rationale
- **Declarativity:** NixOS modules allow controlling every config option via Nix.
- **Resources:** Lower RAM/CPU overhead by eliminating the container runtime.
- **Maintenance:** Updates happen centrally via `nix flake update`. No more "zombie containers".
