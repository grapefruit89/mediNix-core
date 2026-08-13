---
name: medinix-knowledge-extraction
description: Extract mediNix gold from vector indexes into ADRs.
---

# mediNix Knowledge Extraction

Extract actionable NixOS/mediNix gold-standards from a vector index (Claude `chunks.json` or Grok `grok_index_v2/chunks.json`) and write them as ADRs.

## When to use
- After a chat-export / Grok-index build completes (embeddings + chunks.json with `text` field exist).
- When the user asks to "extract gold", "pull patterns from the DB", or "write ADRs from the knowledge store".

## Hard rules (from user feedback)
1. NEVER write ADRs from keyword-only matches — require **hard NixOS syntax signal** (`services.`, `mkIf`, `systemd.`, `.nix`, `nftables`, `caddy.`, `jellyfin`, `sabnzbd`, `sops`, `seccomp`, etc.).
2. ALWAYS exclude off-topic first (Next.js, Traefik-docker-smalltalk, CSS, Userscripts, Bookmarks, PowerShell, Miet/Jobcenter, Fitness, DIN-Brief).
3. NEVER write to `/opt/data/knowledge/` (read-only). Write ADRs to `/opt/data/50-mediNix/docs/ADR-XXXX-*.md`.
4. Group by mediNix layer (510-ingress, 520-security, 530-acquisition, 540-transfer, 550-playback, 570-maintenance, 50-core).

## Extraction workflow
1. Load `chunks.json` from the index dir on Tower (`/mnt/user/data/hermes_knowledge/nixos_vectors/`).
2. Two-stage filter (see reference filter below).
3. Group survivors by layer.
4. For each Priority-A pivot topic, read the best 2-3 chunks, synthesize a concise ADR (Context/Decision/Consequences/Gold-Standard quote).
5. Mark the item `[x]` in `/opt/data/docs/EXTRACTION_PLAN.md`.

## Reference filter (Python, run on Tower venv)
```python
import json, re
from collections import defaultdict
c = json.load(open("chunks.json"))
HARD = [r"\bMKIf\b", r"\bmkMerge\b", r"services\.", r"systemd\.", r"environment\.etc",
        r"config\.nix", r"flake\.nix", r"configuration\.nix", r"nixos", r"\.nix\b",
        r"nftables", r"impermanence", r"mergerfs", r"wireguard", r"sops", r"seccomp",
        r"caddy\.", r"jellyfin", r"sabnzbd", r"sonarr", r"radarr", r"prowlarr",
        r"oidc", r"pocket-id", r"sqlite", r"postgresql", r"hardening", r"lockout"]
EXCLUDE = ["next.js","webpack","autoprefixer","userscript","tampermonkey","bookmark",
           "powershell","windows 11","ebay","thumbnail","css hover","css-first",
           "css scale","fossify","gallery","image toolbox","apple tv","reconciliation",
           "pewdiepie","odysseus","harness engineering","jobcenter","miethorror",
           "din brief","din-brief","din 5008","fitness","hover effekt","cross-hover",
           "traefik","docker run","docker inspect","docker-compose","# 🔥","# 🤔"]
def is_gold(t):
    tl = t.lower()
    if any(e in tl for e in EXCLUDE): return None
    if not any(re.search(s, t, re.I) for s in HARD): return None
    for layer, kws in LAYERS.items():
        if any(k in tl for k in kws): return layer
    return "50-core"
```

## Pitfalls
- Keyword-only filters catch Traefik-docker-configs and frontend-CSS as "gold" — always require HARD NixOS syntax.
- The vec-mcp merge (Claude + Grok) is buggy: search returns only Grok titles. Extract directly from `chunks.json` on Tower, do NOT rely on vec-mcp for Claude content.
- Grok v1 index has NO text field (only metadata) — wait for v2 (`grok_index_v2/`) before extracting Grok content.
- 1354 gold chunks from Claude index is the realistic number after strict filtering (not 2669 from loose keyword match).
