---
id: "GUIDE-58-seven-quality-gates"
title: "GUIDE 5000 seven quality gates"
domain: 58
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - observability
  - quality
links:
  adr: ""
  repo-harvest: ""
---
# ⚙️ Die 7 Qualitäts-Tore (Aviation-Grade Purity Protocol)

Jedes Modul und jede Konfiguration in mynixos muss diese Tore durchlaufen, um den Status "Veredelt" zu erhalten.

## 🚪 Tor 1: Community-Goldstandard
Abgleich mit `nixpkgs/pkgs` und `nixos/modules`. Nutzen wir die besten bekannten Patterns?
*Referenz: [best-of-nix.md](./best-of-nix.md)*

## 🚪 Tor 2: API-Accuracy
Prüfung via `context7` auf Deprecations und Best-Practices. Keine veralteten Optionen.

## 🚪 Tor 3: SSoT-Compliance
Strikte Bindung an lokale `configs.nix` (Hardware-IDs) und `ports.nix`. Keine Hardcoded-Werte.

## 🚪 Tor 4: SRE-Hardening
Maximaler Schutz der systemd-Units. Isolation und minimalste Berechtigungen.
*Referenz: [sops-nix.md](./sops-nix.md)*

## 🚪 Tor 5: Dendritische Integrität
"One Service, One File". Keine Zirkelbezüge. Saubere `flake-parts` Kompatibilität.
*Referenz: [dendritic-blueprint.md](./dendritic-blueprint.md)*

## 🚪 Tor 6: Hygiene & Purity
Ausschluss von totem Code und redundanten Imports.

## 🚪 Tor 7: Traceability
Jedes Modul muss seine Quellen im Header referenzieren.
