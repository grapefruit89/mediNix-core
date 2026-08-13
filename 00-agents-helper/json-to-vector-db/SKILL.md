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
