---
id: adr-index
title: Architecture decisions
lang: en
---

# ADRs — read `llm-index.json` first

This folder is for **decisions**, not chat exports.

1. Open [`llm-index.json`](llm-index.json). It lists canonical files, duplicates, and what to ignore.
2. Open at most one markdown per service id (`511`, `551`, …).
3. If two files cover the same id, the JSON `duplicates` array is the source of truth.

## Language

English only from here. The German constitution twin is removed; use `ADR-00-dezimalrahmen-verfassung-en.md`.

## Do not treat as ADRs

Reviews, harvest pipelines, and "we should use native services" one-liners. Those belong in `docs/learn/` or the root README.
