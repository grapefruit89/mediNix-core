#!/usr/bin/env python3
"""Full duplicate + collision scan for mediNix boilerplate.
Run from anywhere: python3 /opt/data/skills/devops/nixos-medinix-authoring/scripts/scan_duplicates.py
(adjust ROOT below or pass path as argv[1]).

Checks:
  1. filename collisions across dirs
  2. content-identical files (sha256)
  3. same Dienstnummer in >1 file
  4. same NIXMETA # id in >1 file
  5. which files configure services.caddy / sabnzbd (service-ownership check)
Prints a summary; exits 0 always (caller decides what's a real violation).
"""
import os, hashlib, re, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "/opt/data/50-mediNix"
GIT = os.path.join(ROOT, ".git")

by_name, by_hash, by_num, by_id = {}, {}, {}, {}

for dp, dirs, files in os.walk(ROOT):
    if dp.startswith(GIT):
        continue
    for f in files:
        full = os.path.join(dp, f)
        rel = os.path.relpath(full, ROOT)
        by_name.setdefault(f, []).append(rel)
        try:
            data = open(full, 'rb').read()
            by_hash.setdefault(hashlib.sha256(data).hexdigest(), []).append(rel)
        except Exception:
            pass
        m = re.match(r"(\d{2,3})-", f)
        if m:
            by_num.setdefault(int(m.group(1)), []).append(rel)
        if f.endswith(".nix"):
            try:
                head = data[:1500].decode('utf-8', 'ignore')
                im = re.search(r'# id:\s*"([^"]+)"', head)
                if im:
                    by_id.setdefault(im.group(1), []).append(rel)
            except Exception:
                pass

def show(title, d, filt=lambda v: len(v) > 1):
    print(f"\n=== {title} ===")
    hits = {k: v for k, v in d.items() if filt(v)}
    print(f"Gefunden: {len(hits)}")
    for k, v in sorted(hits.items(), key=lambda x: str(x[0])):
        print(f"  {k}: {v}")

show("1. EXAKTE DATEINAMEN-DUPPLIKATE", by_name)
show("2. INHALT-IDENTISCH (sha256)", by_hash)
show("3. GLEICHE DIENSTNUMMER >1 DATEI", by_num)
show("4. GLEICHE NIXMETA id >1 DATEI", by_id)

print("\n=== 5. SERVICE-OWNERSHIP (wer konfiguriert caddy/sabnzbd?) ===")
for dp, dirs, files in os.walk(ROOT):
    if dp.startswith(GIT):
        continue
    for f in files:
        if not f.endswith(".nix"):
            continue
        txt = open(os.path.join(dp, f), errors='ignore').read()
        if "services.caddy.enable" in txt or "services.caddy.virtualHosts" in txt:
            print(f"  caddy: {os.path.relpath(os.path.join(dp,f), ROOT)}")
        if "services.sabnzbd" in txt or 'nixpkgs_attr: "services.sabnzbd"' in txt:
            print(f"  sabnzbd: {os.path.relpath(os.path.join(dp,f), ROOT)}")

total = sum(len(v) for v in by_name.values())
print(f"\n=== SUMMARY: {total} files (no .git) ===")
print(f"Name-dupes:{len([1 for v in by_name.values() if len(v)>1])} | "
      f"Content-dupes:{len([1 for v in by_hash.values() if len(v)>1])} | "
      f"Num-dupes:{len([1 for v in by_num.values() if len(v)>1])} | "
      f"Id-dupes:{len([1 for v in by_id.values() if len(v)>1])}")
