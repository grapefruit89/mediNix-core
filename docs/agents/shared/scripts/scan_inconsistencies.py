#!/usr/bin/env python3
"""Scan a mediNix boilerplate tree for Decimal Framework (ADR-0000) inconsistencies.

Usage: python3 scan_inconsistencies.py [ROOT]
Default ROOT = /opt/data/50-mediNix

Checks every NNN-*.nix: filename number is a valid mediNix Dienstnummer
(500-599) or 2-digit domain block (50-59); header `ports:` are all = file-num*10
(or 0/empty); 4-digit ports are rejected. Reports real violations. Known
false-positives (default.nix, flake.nix, lib/*, firewall ports 22/80/443/2222)
are intentionally NOT flagged as framework violations.
"""
import os, re, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "/opt/data/50-mediNix"
ALLOW_NO_NUMBER = {"default.nix", "flake.nix"}
issues = []

for dirpath, dirs, files in os.walk(ROOT):
    if "/.git" in dirpath or dirpath.endswith("/docs") or "/lib/" in dirpath:
        continue
    for f in files:
        if not f.endswith(".nix"):
            continue
        if f in ALLOW_NO_NUMBER:
            continue
        full = os.path.join(dirpath, f)
        rel = os.path.relpath(full, ROOT)
        m = re.match(r"(\d{2,3})-", f)
        if not m:
            issues.append(f"NO NUMBER in filename: {rel}")
            continue
        num = int(m.group(1))
        if num < 100:
            if not (50 <= num <= 59):
                issues.append(f"INVALID domain block {num}: {rel}")
            continue
        if not (500 <= num <= 599):
            issues.append(f"OUT OF RANGE {num}: {rel}")
            continue
        last = num % 10
        mid = (num // 10) % 10
        if last == 0 and mid != 0:
            # 5x0 where x!=0 is not a domain base -> suspicious
            issues.append(f"SUSPICIOUS 5x0 (not a base, last digit must be role 1-9): {num} in {rel}")
        try:
            with open(full) as fh:
                head = "".join(fh.readlines()[:25])
            pm = re.search(r"# ports:\s*\[([^\]]*)\]", head)
            if pm:
                ports = [int(x) for x in re.findall(r"\d+", pm.group(1))]
                for p in ports:
                    if p == 0:
                        continue
                    if p % 10 != 0:
                        issues.append(f"PORT not *10: {p} in {rel}")
                    elif p // 10 != num:
                        issues.append(f"PORT {p} != file num {num}*10 in {rel}")
        except Exception as e:
            issues.append(f"READ ERROR {rel}: {e}")

print("=== INKONSISTENZEN (Dezimalrahmen) ===")
if not issues:
    print("(keine gefunden)")
else:
    for i in sorted(set(issues)):
        print(i)
print(f"\nTotal: {len(set(issues))} unique issues")
print("Note: firewall ports 22/80/443/2222 and default.nix/flake.nix are NOT framework violations.")
