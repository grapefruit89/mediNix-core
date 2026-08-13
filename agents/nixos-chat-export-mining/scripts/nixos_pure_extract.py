#!/usr/bin/env python3
"""
NixOS Chat-Export Miner (pure stdlib — no numpy/sklearn/torch).
Extracts NixOS-related chunks from a large conversations.json and groups
them by topic into Markdown files under output_dir.

Usage:
    python3 nixos_pure_extract.py [json_path] [output_dir]

Defaults:
    json_path  = /opt/data/cache/documents/extracted_batch/conversations.json
    output_dir = /opt/data/docs/nixos-topics
"""
import json
import re
import sys
from pathlib import Path

DEFAULT_JSON = "/opt/data/cache/documents/extracted_batch/conversations.json"
DEFAULT_OUT = "/opt/data/docs/nixos-topics"

TOPICS = {
    "Caddy-Ingress": r"caddy|ingress|reverse_proxy|tls|domain|m7c5\.de",
    "Media-Stack": r"jellyfin|sonarr|radarr|sabnzbd|prowlarr|readarr|lidarr|audiobookshelf|navidrome|feishin",
    "Storage-ABC": r"mergerfs|tier|storage|disk|mount|hdd|ssd|nvme|zfs",
    "Security-AntiLockout": r"anti-lockout|ssh|assertion|firewall|nftables|fail2ban|sovereign",
    "Dezimalrahmen-SSoT": r"dezimalrahmen|isomorphie|registry|uid|port|sso|nms",
    "Proxmox-NixOS": r"proxmox|q958|nixos|flake|module|systemd|rollout",
}

def main():
    json_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_JSON
    out_dir = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_OUT

    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    results = {t: [] for t in TOPICS}
    results["General-NixOS"] = []
    total = 0

    for conv in data:
        conv_uuid = conv.get("uuid", "unknown")
        for msg in conv.get("chat_messages", []):
            text = msg.get("text", "") or ""
            if len(text) > 50:
                total += 1
                tl = text.lower()
                matched = False
                for topic, pat in TOPICS.items():
                    if re.search(pat, tl):
                        results[topic].append((conv_uuid, msg.get("sender"), text))
                        matched = True
                        break
                if not matched and ("nixos" in tl or "nix" in tl):
                    results["General-NixOS"].append((conv_uuid, msg.get("sender"), text))

    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)

    for topic, items in results.items():
        fn = out / f"{topic}.md"
        with open(fn, "w", encoding="utf-8") as f:
            f.write(f"# Topic: {topic}\n\n**Chunks:** {len(items)}\n\n---\n\n")
            for conv_uuid, sender, text in items[:50]:
                f.write(f"### {sender} ({conv_uuid[:8]})\n\n{text}\n\n---\n\n")

    print(f"Scanned {total} chunks")
    for t, items in results.items():
        print(f"  {t}: {len(items)}")
    print(f"→ {out_dir}")

if __name__ == "__main__":
    main()
