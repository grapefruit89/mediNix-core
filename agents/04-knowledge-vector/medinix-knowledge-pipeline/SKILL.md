# medinix-knowledge-pipeline

This is a consolidated skill merging the capabilities of: json-to-vector-db, ram-aware-vector-index, vector-db-enrichment, nixos-repo-harvester

## --- Inherited from json-to-vector-db ---

---
name: json-to-vector-db
description: Convert any large JSON (chat export, logs, structured data) into an appendable local vector store (.npy + .json) for semantic search. No Chroma/SQL.
---

# json-to-vector-db

## Trigger
- "Mach diese JSON in eine Vektordatenbank"
- "Zerleg diese fette JSON und speicher sie vektorisiert"
- Any large JSON chat-export / structured dump to be made semantically searchable

## Why
Large JSON (>50MB) can't be grepped effectively (truncated output). BERTopic/sentence-transformers
on a remote host with pip (Unraid Tower) embeds + clusters. The store is plain numpy .npy + json —
no heavy vector DB ("keep it stupid simple", user explicitly rejects Chroma/sqlite-vec).

## Environment
- Remote host: root@192.168.2.250:53844, key /tmp/hermes_key
- venv: /mnt/user/data/hermes_knowledge/nixos_vectors/venv
- Store files: /mnt/user/data/hermes_knowledge/nixos_vectors/embeddings.npy + chunks.json
- Model: BAAI/bge-base-en-v1.5 (768d, CPU embed ~12s/batch, NO CUDA on Tower iGPU)

## Workflow
1. scp the JSON to Tower (or reuse existing conversations.json).
2. On Tower, in venv, run extractor:
   - Parse JSON, chunk messages (len>80).
   - Optional broad keyword prefilter (for NixOS domain use the big list: nixos, caddy,
     traefik, ingress, nftables, mergerfs, btrfs, ssh, sops, jellyfin, sabnzbd, wireguard,
     pocket, q958, dezimalrahmen, isomorphie, systemd, ...).
   - Embed with bge-base (CPU).
   - **APPEND** to unified store:
     ```python
     emb = model.encode(texts)
     old = np.load("embeddings.npy")
     np.save("embeddings.npy", np.concatenate([old, emb]))
     chunks = json.load(open("chunks.json"))
     for t in texts:
         chunks.append({"text": t, "source": <src>, "topic": -1,
                        "conv": <id>, "ts": datetime.now().isoformat()})
     json.dump(chunks, open("chunks.json", "w"))
     ```
3. Re-cluster (BERTopic) ONLY for MOC/navigation, NOT for search. Infrequent.

## CRITICAL SAVE RULE (learned twice the hard way, 2026-08-10)
- The .npy + .json MUST be written at script end. Bake np.save/json.dump INTO the script.
- After run, VERIFY: embeddings.npy shape [N,768], chunks.json len == N.
  Do NOT report done before both pass.
- Never a manual post-run save step — that is exactly what failed twice.

## Unified Store schema (single store for chat + github)
- embeddings.npy : float32 [N, 768]
- chunks.json    : [ {text, source:"chat"|"github", conv, topic, ts} ]

## Pitfalls
- Do NOT propose Chroma/sqlite-vec (user rejects heavy vector DBs).
- Hermes container has no pip/numpy — must run on Tower.
- CPU embed is slow (~25-50 min for ~4000 chunks) — run in background, notify_on_complete.
- Always set source tag so github + chat live in ONE store (no second silo).

## Output
Unified vector store appendable by github-pattern-miner and queryable by vec-knowledge-mcp.

## --- Inherited from ram-aware-vector-index ---

---
name: ram-aware-vector-index
description: Build vector store from big JSON on low-RAM host safely.
---

# ram-aware-vector-index

Build a semantic-search vector store from a large JSON (chat export, logs) on a host
with little free RAM. This is the memory-constrained variant of the JSON->vector-db
pipeline: same goal (plain .npy + json, no Chroma/SQL), but explicit steps to avoid
OOM when the host already runs many containers.

## Trigger
- Indexing a 50MB+ JSON on a small host (16GB or less) that runs Docker/services.
- "Tower has only 1.9GB free, can we still embed this?"
- Any vector-store build where `free -h` shows <3GB available AND containers are running.

## Why
On the Unraid Tower (15.5GB total) the default setup already eats RAM: hermes-agent
~1.3GB, vec-mcp ~0.6GB (holds the bge-base embedding model in RAM), *arr stack,
grafana/netdata/loki. Free RAM is ~1.9GB. Loading a 99MB JSON + embeddings + BERTopic
(UMAP/HDBSCAN) OOM-kills the host. The fix is to free model RAM, stream the file, and
skip clustering entirely (FAISS-flat is enough for search).

## Environment (Tower)
- Host: root@192.168.2.250:53844, key /tmp/hermes_key
- venv: /mnt/user/data/hermes_knowledge/nixos_vectors/venv
- Model: BAAI/bge-base-en-v1.5 (768d, CPU embed, NO CUDA)
- Store: embeddings.npy + chunks.json (+ faiss.index) in nixos_vectors/

## Workflow
1. **Free the embedding model RAM** (requires user approval — destructive container stop):
   `docker stop vec-mcp` (it loads bge-base permanently). Restart after with
   `docker start vec-mcp`. If user declines, shrink embed batch size and accept OOM risk.
2. **Install missing libs in venv**: `pip install ijson faiss-cpu` (NOT preinstalled).
3. **Unzip if needed**: a 229MB ZIP may hold a 99MB JSON + tiny stubs.
   `unzip -q f.zip -d out && find out -name "*.json" -ls` → pick the big one.
4. **Stream + chunk + batch-embed to disk** (never accumulate all embeddings in RAM):
   iterate with `ijson`, chunk each message (len>80), embed batches of ~32, append
   each batch's vectors to a growing `embeddings.npy` on disk.
5. **FAISS-flat index** (no BERTopic/UMAP/HDBSCAN — those are the RAM killers and only
   needed for MOC navigation, not search): normalize vectors, `faiss.IndexFlatIP`.
6. Save embeddings.npy + chunks.json + faiss.index. vec-mcp reuses the same .npy/.json.

See references/working-snippet.md for the ijson+FAISS extractor skeleton.
See references/robust-background-wrapper.md for the detached-launch wrapper that
keeps multi-hour builds alive across SSH sessions and immune to `pkill -f`.

## CRITICAL SAVE RULE
- Write .npy + .json INSIDE the script at the end (bake np.save/json.dump in).
- After run, VERIFY: embeddings.npy shape [N,768], chunks.json len == N.
- Never a manual post-run save step.

## Pitfalls
- vec-mcp stop is destructive → ask user first.
- ijson/faiss-cpu not in venv by default → pip install inside venv.
- CPU embed is slow (~25-50 min / 4000 chunks) → run in background, notify_on_complete.
- Do NOT propose Chroma/sqlite-vec (user rejects heavy vector DBs).
- Hermes container has no pip/numpy — run on the target host, not in Hermes.
- Unzipped asset stubs (auth-mgmt, billing JSONs of a few KB) are NOT the data — find
  the real big .json.

## Output
A queryable store: embeddings.npy (float32 [N,768]) + chunks.json
([{text, source, conv, topic, ts}]) + faiss.index. Reuseable by vec-knowledge-mcp.

## --- Inherited from vector-db-enrichment ---

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

## --- Inherited from nixos-repo-harvester ---

---
name: nixos-repo-harvester
description: Harvest NixOS patterns and issues from a GitHub repo.
---

# nixos-repo-harvester

Extract NixOS-relevant knowledge from any GitHub repo before writing a mediNix module for that service.

## Trigger
- "Ernte das Repo X aus für Dienst Y"
- Before writing a module for Sonarr/Radarr/Prowlarr/SABnzbd/Jellyfin/Navidrome/Audiobookshelf
- "Gibt es bekannte NixOS-Inkompatibilitäten in Repo X?"

## Input
GitHub repo URL + target service name (e.g. "Sonarr", "Jellyfin").

## Workflow (via GitHub MCP — no git clone needed)
1. `get_file_contents` to read README, root `.nix` files, and any `nix/` or `packaging/` subdirectory.
2. `search_issues` with query `repo:owner/name is:issue label:nixos` — extract known breakage patterns.
3. Extract: declarative config options, default ports, state directories, known NixOS incompatibilities.
4. Output as structured Markdown: **Patterns** / **Known Issues** / **Recommended serviceConfig**.

## Output format
```
## <Service> — Repo Harvest (<repo-url>)
### Patterns (from README/packaging)
- ...
### Known NixOS Issues (from labeled issues)
- issue #N: <problem> → <workaround>
### Recommended serviceConfig
- ...
```

## Pitfalls
- Noogle.dev has NO working API (returns SPA HTML, not JSON) — use Context7 `/nixos/nixpkgs` for lib.* signatures instead.
- Focus on packaging/ directory and any `.nix` in root — that's where NixOS-relevant config lives.
- GitHub MCP search_issues: use `repo:owner/name label:nixos` query syntax.

