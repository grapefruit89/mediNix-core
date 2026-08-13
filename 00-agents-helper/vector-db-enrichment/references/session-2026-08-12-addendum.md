# Session 2026-08-12 — Addendum to retrieval-enrichment.md

## skim Priority-A gold first
`extracted_gold.json` / `gold_final.json` / `gold_strict.json` (dicts, 7 keys) are
already-extracted Priority-A gold from the 27k corpus. Read these BEFORE SSH-grepping
`chunks.json` — they answer most "what config does service X need" questions directly
without the noise-filter step.

## store finding caught a real build-blocker
The Caddy/CrowdSec chunks corrected a WRONG plugin name in the module:
`crowdsecurity/caddy-cs-bouncer` → `hslatman/caddy-crowdsec-bouncer`.
Context7 has no Caddy-plugin catalog. When a module needs a Caddy plugin, verify the
EXACT upstream repo name against github.com (search "caddy crowdsec bouncer") — the
vector store's conversation fragments are the only source that caught this error.
`lib.fakeHash` in the module is then replaced with the `nix build ... 2>&1 | grep "got:"`
hash before first build.

## Block-structured sweep that worked (mediNix-core)
Divide services into blocks (Jellyfin / Arr / SABnzbd / Caddy / etc.), run tech-keyword
SSH-grep per block, compare each finding against the CURRENT local module, verify the
option via Context7, then patch. Commit per block, show findings before bulk-commit.
All 6 blocks swept this session; only Caddy plugin-name was a real bug — the rest were
already correctly implemented (good signal the modules were solid).
