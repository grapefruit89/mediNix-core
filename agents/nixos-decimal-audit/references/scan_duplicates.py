#!/usr/bin/env python3
"""Full duplicate + triplicate scan of mediNix boilerplate.
Checks: (1) filename collisions, (2) content-identical files, (3) same service
configured in multiple files, (4) same decimal number used for different services.
"""
import os, hashlib, re

ROOT = "/opt/data/50-mediNix"
GIT = os.path.join(ROOT, ".git")

# 1. Filename -> list of paths (collisions across dirs)
by_name = {}
# 2. Content hash -> list of paths
by_hash = {}
# 3. Service number -> list of files claiming it
by_num = {}
# 4. NIXMETA id -> files
by_id = {}

for dp, dirs, files in os.walk(ROOT):
    if dp.startswith(GIT):
        continue
    for f in files:
        full = os.path.join(dp, f)
        rel = os.path.relpath(full, ROOT)
        # filename
        by_name.setdefault(f, []).append(rel)
        try:
            data = open(full, 'rb').read()
            h = hashlib.sha256(data).hexdigest()
            by_hash.setdefault(h, []).append(rel)
        except Exception:
            pass
        # number from filename
        m = re.match(r"(\d{2,3})-", f)
        if m:
            by_num.setdefault(int(m.group(1)), []).append(rel)
        # NIXMETA id from header
        if f.endswith(".nix"):
            try:
                head = data[:1500].decode('utf-8', 'ignore')
                im = re.search(r'# id:\s*"([^"]+)"', head)
                if im:
                    by_id.setdefault(im.group(1), []).append(rel)
            except Exception:
                pass

print("=== 1. EXAKTE DATEINAMEN-DUPPLIKATE (verschiedene Pfade, gleicher Name) ===")
dup_names = {k:v for k,v in by_name.items() if len(v) > 1}
print(f"Gefunden: {len(dup_names)}")
for k,v in sorted(dup_names.items()):
    print(f"  {k}: {v}")

print("\n=== 2. INHALT-IDENTISCHE DATEIEN (sha256 gleich) ===")
dup_hash = {k:v for k,v in by_hash.items() if len(v) > 1}
print(f"Gefunden: {len(dup_hash)}")
for k,v in sorted(dup_hash.items()):
    print(f"  {v}")

print("\n=== 3. GLEICHE DIENSTNUMMER IN MEHREREN DATEIEN ===")
dup_num = {k:v for k,v in by_num.items() if len(v) > 1}
print(f"Gefunden: {len(dup_num)}")
for k,v in sorted(dup_num.items()):
    print(f"  {k}: {v}")

print("\n=== 4. GLEICHE NIXMETA id IN MEHREREN DATEIEN ===")
dup_id = {k:v for k,v in by_id.items() if len(v) > 1}
print(f"Gefunden: {len(dup_id)}")
for k,v in sorted(dup_id.items()):
    print(f"  {k}: {v}")

print("\n=== 5. CADDY-SPECIFIC CHECK (wer konfiguriert services.caddy?) ===")
for dp, dirs, files in os.walk(ROOT):
    if dp.startswith(GIT):
        continue
    for f in files:
        if not f.endswith(".nix"):
            continue
        full = os.path.join(dp, f)
        txt = open(full, errors='ignore').read()
        if "services.caddy.enable" in txt or "services.caddy.virtualHosts" in txt:
            print(f"  caddy-config: {os.path.relpath(full, ROOT)}")

print("\n=== 6. SABNZBD-SPECIFIC CHECK (wer konfiguriert sabnzbd?) ===")
for dp, dirs, files in os.walk(ROOT):
    if dp.startswith(GIT):
        continue
    for f in files:
        if not f.endswith(".nix"):
            continue
        full = os.path.join(dp, f)
        txt = open(full, errors='ignore').read()
        if "sabnzbd" in txt.lower():
            print(f"  sabnzbd-mention: {os.path.relpath(full, ROOT)}")

total_files = sum(len(v) for v in by_name.values())
print(f"\n=== SUMMARY: {total_files} files total, no .git ===")
print(f"Name-dupes: {len(dup_names)} | Content-dupes: {len(dup_hash)} | Num-dupes: {len(dup_num)} | Id-dupes: {len(dup_id)}")
