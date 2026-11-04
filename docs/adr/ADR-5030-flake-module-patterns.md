---
id: "ADR-5030"
title: "ADR 5030 flake module patterns"
domain: 50
status: deprecated
complexity: 2
last_reviewed: 2026-08-12
tags:
  - core
  - flakes
links:
  adr: ""
  repo-harvest: ""
---
# ADR-5030: Flake & Module Patterns — Declarative Structure (50-core)

> **Deprecated 2026-11-04.** Superseded by ADR-0000 §1 (Two-Level Tree), ADR-040 (Gerichtete Abhängigkeiten) und `docs/CONVENTIONS.md`. Die 6-Layer-Architektur (machines/, users/, mcp/, lib/) wurde nie implementiert.

## Status: deprecated
## Date: 2026-08-11
## Source: Claude gold_final.json (50-core/flake 25, 50-core/module 20 chunks)

## Context
mediNix follows a 6-layer flake architecture. Reusable patterns for flake inputs,
module options, and host composition must be captured.

## Decision
- Flake: `flake.nix` → `machines/<host>/` → `users/` → `modules/` → `mcp/` → `lib/`
- Modules: `mkOption` with strict types, `config` via `mkIf`/`mkMerge`
- Host composition: `imports = [ ./modules/50-media ]` (decimal framework)
- No `nix-env -i`, no imperative package installs

## Consequences
- ✅ Reproducible, typed config
- ✅ Clear separation of concerns
- ✅ Fits Nix-Grok architecture (ADR-5001)

## Gold-Standard (from chat)
> "6-Layer-Architektur mit klarer Trennung (flake.nix → machines/mediahost/ → users/
> → modules/ → mcp/ → lib/)" — confirmed by Nix-Grok review (ADR-5001).
