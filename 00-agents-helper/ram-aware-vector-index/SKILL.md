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
