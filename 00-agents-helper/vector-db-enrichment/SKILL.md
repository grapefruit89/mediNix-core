---
name: vector-db-enrichment
description: Query a local vector store to extract gold and patch code.
---

# vector-db-enrichment

Extract actionable gold from a pre-built local vector store and feed it into code
(modules, configs, docs). This is the RETRIEVAL half of the vector pipeline — the
BUILD half lives in `json-to-vector-db` / `ram-aware-vector-index`.

## Trigger
- "Durchsuche die Vektor-DB für Dienst X und patch das Modul"
- "Enrich mediNix / mein Repo mit Wissen aus den Chat-Exporten"
- Any task that says "query the knowledge base", "gold extraction", "was wissen wir über X"
- Especially after `json-to-vector-db` / `ram-aware-vector-index` built the store.

## CRITICAL: two retrieval paths, NOT equivalent

### Path A — `nixos_vec` MCP (convenient, INCOMPLETE — trap)
`mcp__nixos_vec__search(query)` and `mcp__nixos_vec__list_sources` are live.
- `list_sources` → `{"chat":4003,"grok":23081}` (chunk counts, correct).
- `search(query)` → `[{text, source, score}]`.

**PITFALL (cost a wasted turn):** the `text` field in MCP search results is the chunk
TITLE / topic label, NOT the conversation body. You CANNOT extract code patches or
config gold from MCP hits — they are "Jellyfin Kiosk USB & Network Fix" style titles.
Never author patches from MCP search output alone.

### Path B — SSH to Tower (authoritative, FULL TEXT)
The real bodies are on the Unraid Tower, not in the Hermes container.
- Host: `root@192.168.2.250:53844` (NOT :22 — standard SSH refused; Tower uses 53844).
  Key on container: `/tmp/hermes_key`. `/mnt/user/...` is NOT mounted in the container —
  you MUST SSH.
- Store dir: `/mnt/user/data/hermes_knowledge/nixos_vectors/`
- Corpus files (verified 2026-08-12):
  - `chunks.json` — 4003 CHAT chunks: `{text, conv, sender, topic, source}`. Here `text`
    is the FULL body. `topic` groups by conversation theme (e.g. 21 = Jellyfin Intel QSV
    exhaustion; 8 = architecture/network; -1 = misc).
  - `grok_pivots_raw.json` — list of 5 grok pivots, each `{title, n_msgs, text}` (text =
    condensed body). Where the 23081 grok chunks are condensed.
  - `extracted_gold.json` / `gold_final.json` / `gold_strict.json` — dicts (7 keys) of
    already-extracted Priority-A gold. SKIM THESE FIRST.
  - `conversations.json` (67MB) / `grok-export.zip` (229MB) — raw, not indexed.

See `references/retrieval-enrichment.md` for the exact SSH extraction snippet and the
full noise-filter + bug list.

## The loop that worked (mediNix-core, 2026-08-12)
1. SSH-grep the store for a service's TECH keywords (dev/dri, vaapi, hwaccel, transcode,
   DeviceAllow, UMask, StateDirectoryMode, hardlink, AUTH__METHOD) — NOT bare service names.
2. Read the CURRENT module from the local working copy (e.g. /opt/data/50-mediNix/...) —
   NOT GitHub MCP; the local copy already has your latest edits.
3. Compare finding vs module: what does the gold demand, what does the module have?
4. VERIFY the option exists via Context7 BEFORE patching (DeviceAllow, StateDirectoryMode,
   SupplementaryGroups, Environment, LoadCredentialEncrypted are all valid systemd keys).
5. Patch. NEVER hardcode hardware values — derive from an existing cfg option
   (e.g. `cfg.hardware.accel` enum → LIBVA_DRIVER_NAME map; `cfg.hardware.renderDevice`
   → DeviceAllow path). Do NOT hardcode "iHD".
6. Use `StateDirectoryMode = "0750"` on every service (systemd default 0755 = world-readable
   state dir = real hardening hole, found as NIXH-40-MED).
7. Commit per-block, push, show findings before bulk-committing.

## Noise filter (essential)
Broad service-name hits are ~90% false positives (package-list mentions, docker container
status logs). Filter on TECH keywords, not service names. That cut 685 → 44 real Jellyfin
chunks.

## Pitfalls
- MCP `search` returns titles only — use it to DISCOVER relevant topics, then SSH for bodies.
- Tower SSH is :53844, not :22.
- `chunks.json` only has the 4003 chat chunks; grok bodies are in `grok_pivots_raw.json`.
- Do NOT propose Chroma/sqlite-vec (user rejects heavy vector DBs — store is .npy + .json).
- Context7 has no Caddy-plugin catalog; verify plugin names against the actual upstream
  repo (the store's "CrowdSec" findings were the only source that corrected a wrong name).
