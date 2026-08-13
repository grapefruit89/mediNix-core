# Working extractor skeleton (Tower venv, 2026-08-11)

Verified approach for a 99MB Grok JSON (`{"conversations":[{conversation,responses:[{response:{message}}]}]}`)
on a 16GB host. Run inside the venv on the Tower, not in Hermes.

```python
# venv: /mnt/user/data/hermes_knowledge/nixos_vectors/venv
# before: docker stop vec-mcp  (free model RAM — needs user approval)
# pip install ijson faiss-cpu  (inside venv)
import ijson, json, numpy as np, faiss
from sentence_transformers import SentenceTransformer

SRC = "grok_extracted/.../prod-grok-backend.json"
model = SentenceTransformer("BAAI/bge-base-en-v1.5")
chunks, emb_buf = [], []
BATCH = 32

with open(SRC, "rb") as f:
    for conv in ijson.items(f, "conversations.item"):
        cid = conv["conversation"]["id"]
        for resp in conv.get("responses", []):
            msg = resp.get("response", {}).get("message", "")
            if not isinstance(msg, str) or len(msg) < 80:
                continue
            chunks.append({"text": msg, "source": "chat", "conv": cid,
                           "topic": -1, "ts": ""})
            emb_buf.append(msg)
            if len(emb_buf) >= BATCH:
                v = model.encode(emb_buf, normalize_embeddings=True)
                # append to growing .npy on disk
                if np.exists("embeddings.npy"):
                    old = np.load("embeddings.npy")
                    np.save("embeddings.npy", np.concatenate([old, v]))
                else:
                    np.save("embeddings.npy", v)
                emb_buf.clear()
# flush remainder
if emb_buf:
    v = model.encode(emb_buf, normalize_embeddings=True)
    old = np.load("embeddings.npy") if np.exists("embeddings.npy") else np.zeros((0,768),"f4")
    np.save("embeddings.npy", np.concatenate([old, v]))

json.dump(chunks, open("chunks.json", "w"))

# FAISS-flat (cosine via normalized IP)
e = np.load("embeddings.npy").astype("float32")
idx = faiss.IndexFlatIP(e.shape[1])
idx.add(e)
faiss.write_index(idx, "faiss.index")
print("chunks:", len(chunks), "emb:", e.shape)
# after: docker start vec-mcp
```

Notes:
- `normalize_embeddings=True` makes IndexFlatIP == cosine similarity.
- For a unified store, APPEND to existing embeddings.npy/chunks.json instead of overwriting.
- Run in background (notify_on_complete) — CPU embed of ~thousands of chunks takes 25-50 min.
