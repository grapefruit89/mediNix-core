---
name: medianix-integrator
description: Take knowledge-store query results / gold standards and integrate them into the 50-mediNix boilerplate (decimal framework, YAML header, isomorphism, systemd-native).
---

# medianix-integrator

## Trigger
- "Baue das in mediNix ein"
- After github-pattern-miner / json-to-vector-db produced patterns
- Cherry-pick from reference repos into 50-mediNix

## HARD FOCUS RULE
Only integrate into 50-media (mediNix). Pull strengths FROM other layers (00-core, devNIX,
Nix-Grok, NixmitGROK) but write ONLY into /opt/data/50-mediNix/. Never deploy from obsidian copy.

## Conflict rule (github vs chat vs grok)
When sources disagree on a pattern:
1. Nix-Grok gold standard WINS (production SSoT, ADR-5000).
2. Then known-good NixOS github repo pattern (e.g. grapefruit89/mediNix).
3. Then chat-export (user's own history) — but chat may be outdated (iptables vs nftables).
   PREFER nftables / systemd-native / fail-closed.
4. Never import docker-based or netns patterns — mediNix is systemd-native isolation.

## Workflow
1. Query vec-knowledge-mcp (tool mcp_nixos_vec_search) or query.py for the target pattern.
2. Extract concrete Nix code blocks from results.
3. Rewrite my.* refs -> config.grapefruitMedia.* (or mediNix registry reference).
4. Add YAML header (id, domain:50-media, status, layer, purpose, tags).
5. Follow decimal framework: 51-ingress, 52-security, 53-acquisition, 54-transfer,
   55-playback, 56-requests, 57-maintenance, 59-guardrails.
   Port = Number*10, UID = 5000+Number, GID = 5000, UMask 0002.
6. Write to /opt/data/50-mediNix/...
7. Validate with nixos-repo-audit skill (build-check) BEFORE declaring done.

## Pitfalls
- Don't import docker-based patterns — mediNix is systemd-native.
- Keep decimal framework complete (no missing layer).
- No legacy cron / iptables / bash wrappers (ADR-509 assertions).
- Reference repos are gold-standard sources, NOT deploy targets.

## Output
Integrated, audited mediNix module in /opt/data/50-mediNix/.
