---
id: "ADR-50-knowledge-extraction-pipeline"
title: "ADR 5020 knowledge extraction pipeline"
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
# ADR-5020: Knowledge Database Extraction Pipeline (50-core)

## Status: active
## Date: 2026-08-11
## Source: Grok raw "NixOS Wissensdatenbank: Datenextraktion Pipeline" (18 msgs, 90K chars)

## Context
User wants a complete data-extraction pipeline: from GitHub repos + chat exports to
a clean, vectorizable structure for an AI assistant / searchable knowledge base.

## Decision
Pipeline (already implemented as skills):
1. **GitHub extraction**: clone repos, `github-pattern-miner` extracts patterns
2. **Chat extraction**: stream JSON (ijson), chunk 900c, embed bge-base-en-v1.5
3. **Vector store**: `embeddings.npy` + `chunks.json` (no Chroma/SQL-server)
4. **Query**: vec-mcp (StreamableHTTP) + sqlite-mcp (FTS5) on unified store
5. **ADR extraction**: `medinix-knowledge-extraction` skill (quality-filtered)

## Consequences
- ✅ No external vector DB (keep-it-stupid-simple)
- ✅ Reproducible: re-run extraction on new data
- ✅ Gold-standards flow into `/opt/data/50-mediNix/docs/ADR-*.md`

## Gold-Standard (from Grok)
> "Vom ersten Durchsuchen deiner GitHub-Repositories bis zur sauberen Struktur für
> die Vektorisierung." → Pipeline is the SSoT for knowledge ingestion.
