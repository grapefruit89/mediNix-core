#!/usr/bin/env python3
"""Scan a mediNix boilerplate tree for decimal-framework inconsistencies.

Run:  python3 scan_inconsistencies.py [ROOT]
Default ROOT = /opt/data/50-mediNix

Detects:
  - filename number not a valid Dienstnummer (must be 500-599, or 50-59 domain block)
  - ports: header not equal to filename number * 10 (and not a legit non-service port)
  - 4-digit / non-zero-ending ports (verfassungswidrig)
  - domain blocks outside 50-59
False positives (legit, NOT reported as issues):
  - default.nix, flake.nix, lib/*.nix  (Fundament, no Dienstnummer)
  - 57-maintenance provisioning modules (no own port)
  - SSH/Firewall ports 22/2222/443/80 (not service ports)
"""
import os, re, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "/opt/data/50-mediNix"
issues = []

for dirpath, dirs, files in os.walk(ROOT):
    if "/.git" in dirpath or dirpath.endswith("/docs") or "/lib/" in dirpath:
        continue
    for f in files:
        if not f.endswith(".nix"):
            continue
        full = os.path.join(dirpath, f)
        rel = os.path.relpath(full, ROOT)
        m = re.match(r"(\d{2,3})-", f)
        if not m:
            continue  # Fundament / provisioning — legit
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
            issues.append(f"SUSPICIOUS 5x0 (not a base): {num} in {rel}")
        try:
            with open(full) as fh:
                head = "".join(fh.readlines()[:25])
            pm = re.search(r"# ports: \[([^\]]*)\]", head)
            if pm:
                ports = [int(x) for x in re.findall(r"\d+", pm.group(1))]
                for p in ports:
                    if p % 10 != 0:
                        issues.append(f"PORT not *10: {p} in {rel}")
                    elif p // 10 != num and p != 0:
                        issues.append(f"PORT {p} != file num {num}*10 in {rel}")
        except Exception as e:
            issues.append(f"READ ERROR {rel}: {e}")

print("=== INKONSISTENZEN ===")
if not issues:
    print("(keine gefunden)")
else:
    for i in sorted(set(issues)):
        print(i)
print(f"\nTotal: {len(set(issues))} unique issues")
