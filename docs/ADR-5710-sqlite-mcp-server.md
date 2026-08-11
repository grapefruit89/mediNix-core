# ADR-5710: SQLite MCP Server — FTS5 + Vector Capabilities (57-maintenance)

## Status: active
## Date: 2026-08-11
## Source: Grok raw "SQLite MCP Server mit FTS5 und Vector Search" (178 msgs, 339K chars)

## Context
User needs an MCP server for SQLite with mandatory FTS5 (full-text) + vector
(sqlite-vec) capabilities — not raw SQL where extensions must be loaded manually.

## Decision
Use `neverinfamous/db-mcp` (formerly sqlite-mcp-server) as the reference MCP server:
- Bundles FTS5 + sqlite-vec, no manual extension loading
- Connects to the unified NixOS knowledge store (`embeddings.npy` + `chunks.json`)
- Runs as a native systemd service (no docker), ADR-5000 compliant

## Consequences
- ✅ FTS5 + vector search in one server
- ✅ Feeds the vec-mcp pipeline (unified store)
- ✅ No separate vector DB (keep-it-stupid-simple, no Chroma/SQL-server)

## Gold-Standard (from Grok)
> "neverinfamous/db-mcp (früher sqlite-mcp-server) — stärkster Kandidat, bringt
> FTS5 + sqlite-vec fest mit, kein manuelles Extension-Loading."
> → Our vec-mcp already follows this: numpy + .npy, no external DB.
