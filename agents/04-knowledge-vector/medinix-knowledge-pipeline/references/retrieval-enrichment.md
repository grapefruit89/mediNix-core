# Vector-DB Retrieval & Gold-Enrichment (learned 2026-08-12, updated 2026-08-12)

The store built by medinix-knowledge-pipeline is queried in TWO ways.
They are NOT equivalent.

## 1. The MCP `nixos_vec` path (convenient, INCOMPLETE)
`nixos_vec__search` / `list_sources` are live and fast:
- `list_sources` → `{"chat":4003,"grok":23081}` (chunk counts per corpus).
- `search(query)` → returns `[{text, source, score}]`.

**PITFALL (cost a wasted turn):** the `text` field in search results is the chunk TITLE /
topic label, NOT the conversation body. You cannot extract code patches or config gold
from MCP search output — you only get "Jellyfin Kiosk USB & Network Fix" style titles.
Do not author module patches from MCP search hits; they are noise.

Wrong loop: `search → read text → patch`.
Right loop: `search to find RELEVANT TOPICS → SSH to Tower → grep the actual body → extract gold`.

## 2. The SSH-to-Tower path (authoritative, FULL TEXT)
The real bodies live on the Unraid Tower, not in the Hermes container.

- Host: `root@192.168.2.250:53844` (NOT :22 — standard SSH refused; Tower uses 53844).
  Key: `/tmp/hermes_key` (on Hermes container). Mount `/mnt/user/...` is NOT reachable
  from the container — must SSH.
- Store dir: `/mnt/user/data/hermes_knowledge/nixos_vectors/`
- Corpus files (verified 2026-08-12):
  - `chunks.json` — 4003 CHAT chunks. Each: `{text, conv, sender, topic, source}`.
    `text` HERE is the FULL body (not a title). `topic` groups by conversation theme
    (e.g. topic 21 = Jellyfin Intel QSV exhaustion; topic 8 = architecture/network).
  - `grok_pivots_raw.json` — list of 5 grok topic pivots, each `{title, n_msgs, text}`
    (text is the condensed body). This is where the 23081 grok chunks are condensed.
  - `extracted_gold.json` / `gold_final.json` / `gold_strict.json` — dicts (7 keys each)
    of already-extracted Priority-A gold. Skim these FIRST for known answers.
  - `conversations.json` (67MB) + `grok-export.zip` (229MB) — raw sources, not indexed.

### Enrichment extraction snippet (run via ssh on Tower)
```bash
ssh -i /tmp/hermes_key -p 53844 root@192.168.2.250 'cd /mnt/user/data/hermes_knowledge/nixos_vectors/ && python3 -c "
import json, re
chat = json.load(open(\"chunks.json\"))
grok = json.load(open(\"grok_pivots_raw.json\"))
texts = [c[\"text\"] for c in chat if isinstance(c,dict)] + [p[\"text\"] for p in grok if isinstance(p,dict)]
tech = [\"dev/dri\",\"vaapi\",\"hwaccel\",\"transcode\",\"DeviceAllow\",\"StateDirectoryMode\"]
hits = [t for t in texts if any(k in t.lower() for k in tech)]
for t in sorted(hits, key=lambda x:-len(x))[:3]:
    for l in t.split(chr(10)):
        if any(k in l.lower() for k in tech):
            print(\"  |\", l.strip()[:160])
"'
```
**Noise filter:** broad service-name hits are mostly false positives. Filter on TECH
keywords (dev/dri, vaapi, hwaccel, transcode, DeviceAllow, UMask, StateDirectoryMode,
hardlink, AUTH__METHOD) — NOT bare service names.

## The enrichment loop that worked (mediNix-core)
1. SSH-grep the store for a service's tech keywords → get real body fragments.
2. Read the CURRENT module (local file in /opt/data/50-mediNix, NOT GitHub MCP).
3. Compare finding vs module; verify the option exists via Context7 BEFORE patching.
4. Patch the module. Never hardcode hardware values — derive from a cfg option
   (cfg.hardware.accel → LIBVA_DRIVER_NAME; cfg.hardware.renderDevice → DeviceAllow).
5. Use `StateDirectoryMode = "0750"` on every service (0755 default = hardening hole).
6. Commit per-block, push, show findings before bulk-committing.

## Real bugs this workflow caught (do not regress)
- Jellyfin: missing `render` group + `DeviceAllow=/dev/dri/renderD128` + `LIBVA_DRIVER_NAME`
  → VA-API transcode would have failed on q958.
- All services: `StateDirectoryMode` unset → state dirs 0755 (world-readable).
- Caddy-CrowdSec plugin name WRONG: `crowdsecurity/caddy-cs-bouncer` → CORRECT
  `hslatman/caddy-crowdsec-bouncer`. `pkgs.caddy.withPlugins` with old name fails.
- Caddy-CrowdSec: bouncer needs Apache CLF logs, not JSON.

## TOOLING PITFALL — `patch` escape-drift on .nix script blocks
When you `patch` a `.nix` module whose `script = ''...''` block contains shell-escaped
quotes (`\"`, `''${...}`), the patch tool FAILS with "Escape-drift detected". This hit
repeatedly on `57-maintenance/574-provisioning.nix` (the Prowlarr curl `-d '[{...}]'`
line with embedded `\"`).
**WORKAROUND:** use `skill_manage`/`write_file` (or terminal heredoc) to rewrite the WHOLE
file instead of `patch` — the escape-drift matcher cannot disambiguate the backslashes.
Read the file first if you need current content, then write the complete new version.
Faster than fighting the matcher.
