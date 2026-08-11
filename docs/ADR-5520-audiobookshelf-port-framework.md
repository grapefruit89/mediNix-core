# ADR-5520: Audiobookshelf — Port Conflicts & Decimal Framework (55-playback)

## Status: active
## Date: 2026-08-11
## Source: Claude gold_final.json (550-playback/audiobookshelf, 11 chunks)

## Context
Audiobookshelf had conflicting ports: Port 2001 in `apps/audiobookshelf.nix` vs 8000
in `media/audiobookshelf.nix`. User flagged port-chaos as a recurring pain.

## Decision
- Audiobookshelf port = **5520** (decimal framework: 55-playback × 10 + service offset)
- Single source of truth in `55-playback/552-audiobookshelf.nix`
- No duplicate module definitions (apps/ vs media/ conflict resolved)

## Consequences
- ✅ Port chaos eliminated (isomorphism ADR-5043)
- ✅ One module per service
- ✅ Fits 55-playback layer

## Gold-Standard (from CLAUDE.md + chat)
> "Audiobookshelf hat Port 2001 in apps/ aber Port 8000 in media/ — welcher ist
> richtig? Ich hasse Port-Chaos." → Decimal framework fixes this (ADR-5043).

> **seccomp-Fehler, der wortlos tötet:** `SystemCallFilter` killt per SIGSYS ohne
> Log. Fix: `SystemCallErrorNumber = "EPERM"` → Kernel gibt EPERM zurück statt zu
> töten. **Diese Zeile gehört in jede seccomp-Härtung** (ADR-5050).

## Operational Notes (migrated from CLAUDE.md, ports corrected 5520)
- **HTTP-Code 200 erwartbar:** ABS liefert SPA direkt aus, ohne Login-Redirect.
  Bei *arr wäre 200 verdächtig, bei ABS ist es korrekt.
- **RW-Pfade:** metadata + media (ABS schreibt Cover/Metadata) müssen rw sein,
  StateDir ebenfalls. `PORT=5520` via Environment (Docker-Port 8080 → 5520).
