---
id: "ADR-55-navidrome-music-streaming"
title: "ADR 5530 navidrome music streaming"
domain: 55
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - navidrome
  - playback
links:
  adr: ""
  repo-harvest: ""
---
# ADR-5530: Navidrome — Music Streaming (55-playback, Dienst 553)

## Status: active
## Date: 2026-08-11
## Source: Claude gold_final.json + Grok raw "Nix-Grok Review" + ADR-0000
## Related: ADR-5510 (Jellyfin), ADR-5520 (Audiobookshelf)

## Decimalrahmen (ADR-0000 §4)
- Dienstnummer: **553** (55-playback, _3 Mitte)
- Port: **5530** | UID: **5530** | GID: **5000**

## Context
Navidrome streams music. Needs `extraGroups` (mkAfter `["media"]`) for library
access — CLACDE.md gold-standard for *arr-like services.

## Decision
- Navidrome native NixOS service, UID 5530, GID 5000
- `extraGroups = mkAfter ["media"]` (not before, to avoid override conflicts)
- OIDC via Caddy forward_auth (ADR-5110/5120)
- SQLite WAL (ADR-5700): `cache_size=-20000`, `temp_store=MEMORY`

## Consequences
- ✅ Isolated UID 5530, GID 5000 (music library)
- ✅ extraGroups mkAfter prevents media group loss
- ✅ WAL tuning for metadata performance

## Gold-Standard (from CLAUDE.md)
> "Navidrome extraGroups mkAfter[\"media\"]" — ordering matters, mkAfter wins.

> **Stiller Fehler:** Ohne media-Gruppe läuft Navidrome, findet aber **keine
> Musik** — keine Fehlermeldung, nur leere Bibliothek. Bewiesen per Gegentest
> (`chmod o-rx` auf Musikverzeichnis bricht Zugriff, mit Gruppe nicht).
> → Ein Dienst, der läuft, beweist nicht, dass deine Änderung ihn zum Laufen
> gebracht hat. Nimm die Bedingung weg und prüfe, ob es bricht.

## Operational Notes (migrated from CLAUDE.md, ports corrected 5530)
- **Feishin-Kopplung:** `554-feishin` spricht Navidrome-API. Wer hier Port/Adresse
  ändert, muss `serverUrl` in Feishin mitziehen (siehe ADR-5530/5540).
- **OIDC:** via EnvironmentFile `ND_OIDC_CLIENT_ID_FILE` (ADR-5000: keine inline secrets).
- **Music read-only:** BindReadOnlyPaths für mediaRoot/music reicht (Navidrome schreibt
  nur Metadata in StateDir).
