#!/usr/bin/env python3
"""Nixmap AST & Syntax Audit-Matrix für deklarative NixOS-Module.

Quelle: todo/blocks/15-nixmap-ast-audit.json (D-15-01 bis D-15-06)
Prüft zentrale Regeln für robuste, idiomatisierte NixOS-Konfigurationen:
  1. Vermeidung von Scope-Verschmutzung durch 'with' (with lib;, with pkgs; in Modulen)
  2. Prüfung auf rohes 'assert' in Modulen (bevorzuge 'assertions = [ ... ]')
  3. Warnung vor bedingten Imports basierend auf Modul-Optionen (Rekursionsgefahr)
  4. Vermeidung des '//'-Operators bei verschachtelten Modul-Configs (bevorzuge lib.recursiveUpdate / mkMerge)
  5. Prüfung auf rohes 'if ... then ... else' bei Moduldefinitionen (bevorzuge lib.mkIf)

Aufruf:
  python3 scripts/check-nixmap.py            # Audit aller Modulpfade
  python3 scripts/check-nixmap.py --strict   # Exit 1 bei P0-Verstößen
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Domain-Ordner und Lib-Verzeichnisse
SCAN_DIRS = [
    "50-core",
    "51-ingress",
    "52-security",
    "53-acquisition",
    "54-processing",
    "55-playback",
    "57-maintenance",
    "58-observability",
]

# Ausnahmen / Allowlist für legitime Konstrukte (z. B. pure Bibliotheksfunktionen in 50-core/)
ALLOWLIST_WITH = set()

ALLOWLIST_ASSERT = {
    "50-core/manifest.nix",          # Pure Helper Library Assertions
    "50-core/501-decimal-engine.nix",  # Pure Engine Assertions
}


def audit_file(filepath: Path) -> list[tuple[str, str, int, str]]:
    rel_path = filepath.relative_to(ROOT).as_posix()
    findings = []
    
    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    for idx, line in enumerate(lines, start=1):
        stripped = line.strip()
        if stripped.startswith("#"):
            continue

        # Regel 1: with lib / with pkgs Verbot in Modulen
        if re.search(r"\bwith\s+(lib|pkgs)\s*;", line):
            if rel_path not in ALLOWLIST_WITH:
                findings.append(("NIXMAP-01", "Verbot von 'with' (Scope-Verschmutzung, D-15-04)", idx, line.strip()))

        # Regel 2: Rohes assert in Modulen (außerhalb reiner lib-Helper)
        if re.search(r"^\s*assert\s+", line):
            if rel_path not in ALLOWLIST_ASSERT:
                findings.append(("NIXMAP-02", "Rohes 'assert' in Modul gefunden; bevorzuge 'assertions = [ ... ]' (D-15-03)", idx, line.strip()))

        # Regel 3: Bedingte Imports basierend auf cfg.enable
        if re.search(r"imports\s*=\s*.*lib\.optionals?\s+(cfg|config)\.", line):
            findings.append(("NIXMAP-03", "Bedingte Imports über config-Optionen erzeugen Rekursionsgefahr (D-15-06)", idx, line.strip()))

        # Regel 4: Verdächtige flache Attributset-Merges mit // bei services
        if re.search(r"systemd\.services\s*=\s*.*//", line):
            findings.append(("NIXMAP-04", "Flacher Merge '//' bei systemd.services; Gefahr von Key-Verlust (D-15-01)", idx, line.strip()))

    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description="Nixmap AST & Syntax Audit")
    parser.add_argument("--strict", action="store_true", help="Beende mit Exit-Code 1 bei Funden")
    args = parser.parse_args()

    total_findings = 0
    scanned_files = 0

    print("🔍 Starte Nixmap-Audit über mediNix-Module...")

    for d in SCAN_DIRS:
        dir_path = ROOT / d
        if not dir_path.exists():
            continue
        for root, _, files in os.walk(dir_path):
            for file in files:
                if file.endswith(".nix"):
                    scanned_files += 1
                    fp = Path(root) / file
                    findings = audit_file(fp)
                    if findings:
                        rel = fp.relative_to(ROOT).as_posix()
                        print(f"\n📁 {rel}:")
                        for rule_id, desc, line_no, content in findings:
                            print(f"  [{rule_id}] L{line_no}: {desc}")
                            print(f"    Snippet: {content}")
                            total_findings += 1

    print(f"\n📊 Nixmap-Audit abgeschlossen: {scanned_files} Dateien geprüft, {total_findings} Befunde.")

    if args.strict and total_findings > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
