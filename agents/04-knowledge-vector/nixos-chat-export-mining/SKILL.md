---
name: nixos-chat-export-mining
description: Mine NixOS Gold-Standards from chat-export JSONs.
---

# nixos-chat-export-mining

## Trigger
- "Durchsuche den Claude/DeepSeek/Grok Export nach NixOS Patterns"
- "Alles finden was mit NixOS zu tun hat, gute Patterns raussieben"
- A 50–70 MB `conversations.json` (or *.zip batch export) from a chat assistant

## Why this skill exists
A 50–70 MB `conversations.json` export is too big for `grep` (truncated output,
misses most matches). The validated WORKING method is BERTopic semantic
clustering on a remote host with Python+pip (Unraid Tower: root@192.168.2.250:53844,
key /tmp/hermes_key). The Hermes container itself has no pip/numpy/sentence-transformers.
The previous pure-stdlib regex approach (nixos_pure_extract.py) is a weak fallback
only — BERTopic with bge-base embeddings finds real semantic clusters, not keyword bags.

## Environment
- Remote venv on Tower: /mnt/user/data/hermes_knowledge/nixos_vectors/venv
- Source JSON: /mnt/user/data/hermes_knowledge/nixos_vectors/conversations.json
- Working scripts live on Tower under the same dir (scp from /opt/data/scripts/)
- Tower has Intel HD Graphics 630 (iGPU) — NO CUDA, so embeddings run on CPU
  (~12s/batch, 250 batches ≈ 25–50 min for ~4000 chunks). Do NOT expect GPU speedup.

## Workflow (the real one — used 2026-08-10, validated)
1. If export is a `.zip`: scp to Tower, extract there with `zipfile`.
2. On Tower, inside the venv:
   a. **bertopic_volltext.py** — loads JSON, keyword-prefilters NixOS chunks
      (broad list incl nixos, caddy, traefik, nftables, ingress, mergerfs, btrfs,
      ssh, sops, jellyfin, sabnzbd, wireguard, pocket, etc.), embeds with
      BAAI/bge-base-en-v1.5 (CPU), UMAP(5d,cosine) + HDBSCAN(min_cluster_size=12),
      exports FULL TEXT per cluster to UEBERGABE_VOLLTEXT/*.md + _MOC.md.
   b. **bertopic_embed_save.py** — re-embeds the SAME prefiltered chunks and
      SAVES `embeddings.npy` (shape [N,768]) + `chunks.json` (text,conv,sender,topic).
      THIS SAVE STEP IS MANDATORY — without it the query DB is unusable.
3. Write `query.py` (~30 lines, numpy only): embed query with same model,
   cosine-top-K against embeddings.npy, print matching chunks. NO Chroma/SQL —
   user rejects heavy vector DBs ("keep it stupid simple", "kein Sprit").

## CRITICAL SAVE RULE (learned the hard way, twice)
- The embedding + chunk→topic mapping MUST be persisted to disk at script end:
  `np.save("embeddings.npy", emb)` and `json.dump(chunks_with_topic, "chunks.json")`.
- After ANY embed run, VERIFY: embeddings.npy exists with shape [N,768],
  chunks.json has N entries. Do NOT report "done" until both checks pass.
- Never rely on a manual post-run save step — bake it into the script.

## HARD FOCUS RULE
Only extract for mediNix (50-media). Mining 00-core/10-network/70-forge is out
of scope — pull strengths FROM other layers but integrate ONLY into 50-media.

## Memory offload
When memory > ~90%, WRITE Gold-Standards to `/opt/data/docs/OPS/` files
instead of cramming memory. User mandate: "Wenn dein memory wieder voll ist
dann schreib den doch sauber in die passende datei!"

## Pitfalls
- Do NOT re-run embedding without saving .npy+.json — wasted 25 min twice (2026-08-10).
- Do NOT grep the raw 50 MB+ JSON — truncated output, misses most matches.
- Do NOT propose Chroma/sqlite-vec — user explicitly rejects heavy vector DBs.
- Chat exports are messy: filter chunk len>80 before embedding.
- Keyword prefilter must be BROAD — nftables/ingress/mergerfs/btrfs were nearly
  missed when only caddy/jellyfin were in scope.
- Tower CPU embedding is slow (~25-50 min) — run in background, notify_on_complete.

## Output
- /mnt/user/data/hermes_knowledge/nixos_vectors/UEBERGABE_VOLLTEXT/*.md (full text clusters)
- /mnt/user/data/hermes_knowledge/nixos_vectors/embeddings.npy + chunks.json (query DB)
- query.py for semantic search
