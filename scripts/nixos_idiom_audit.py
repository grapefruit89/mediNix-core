#!/usr/bin/env python3
"""Auditiert ein NixOS-Repo auf klassische-Distro-Reflexe (Schicht 1: Signale, KEINE Urteile).

Dreischichtig (siehe docs/CONVENTIONS.md § Audit):
  1. dieses Skript  -> grep-bare Kandidaten (schnell, Fehlalarme moeglich)
  2. Mensch/LLM     -> Kontext lesen: Build-Zeit? Laufzeit? dokumentiert? (Signal != Fund)
  3. `nix` selbst   -> `nix flake check` OHNE --impure beweist Reinheit (nur auf der Nix-Maschine)

Aufruf:
  python3 scripts/nixos_idiom_audit.py            # Report (stdout)
  python3 scripts/nixos_idiom_audit.py --json     # maschinenlesbar
  python3 scripts/nixos_idiom_audit.py --p0-only   # nur P0 (CI-Modus, Exit 1 bei Fund)

Eingelagertes (docs/audit/, docs/archive/) wird bewusst NICHT gescannt.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXTS = (".nix", ".sh", ".md", ".yml", ".yaml", ".py")
SKIP_DIRS = {".git", "node_modules", "__pycache__", ".direnv", ".devenv"}
# Importierte Wissensbasis (Fremd-Patterns) + Archiv: NICHT unser Code -> kein Signalrauschen.
SKIP_PATH_PREFIXES = (
    "docs/patterns",
    "docs/learn",
    "docs/concepts",
    "docs/arch",
    "docs/audit",
    "docs/archive",
)
# `#!/usr/bin/env …` ist auf NixOS idiomatisch (env-Shim) -> kein FHS-Verstoss.

# (Eigenschaft, P-Level, Regex, Endungen)  — 15-20 Signale reichen (sonst Rauschen).
SIGNALS: list[tuple[str, str, str, tuple[str, ...]]] = [
    # Deterministisch / Rein (harte Fehler ohne --impure)
    ("deterministisch", "P0", r"\bbuiltins\.currentTime\b", (".nix",)),
    ("deterministisch", "P0", r"\bbuiltins\.getEnv\b", (".nix",)),
    ("deterministisch", "P0", r"\bimport\s*<\s*nixpkgs", (".nix",)),
    ("deterministisch", "P0", r"\bfetchTarball\s+(?!.*\bhash)", (".nix",)),
    ("rein-funktional", "P0", r"\bbuiltins\.currentSystem\b", (".nix",)),
    ("rein-funktional", "P0", r"--impure\b", (".sh", ".yml", ".yaml")),
    # Immutabel / Store
    ("immutabel", "P0", r"(chmod|chown|rm|mv|>)\s+/nix/store/", (".nix", ".sh")),
    ("store-versionen", "P0", r"\bln\s+-sf?\s+/usr/", (".sh", ".nix")),
    ("store-versionen", "P1", r"(?<!/nix/store/[a-z0-9]{32}-)/usr/(bin|lib|local)/", (".nix", ".sh")),
    # Deklarativ vs. imperativ (Kandidaten -> Kontext!)
    ("deklarativ", "P1", r"system\.activationScripts.*>\s*/etc/", (".nix",)),
    ("deklarativ", "P2", r"(ExecStartPre|postStart|preStart|preStop)\s*=.*\b(sed\s+-i|cp\s|mv\s|rm\s)", (".nix",)),
    # Reproduzierbar / Rollback
    ("reproduzierbar", "P1", r"\bnix-channel\b|\bnix-env\s+-i", (".md", ".sh", ".yml")),
    ("reproduzierbar", "P2", r"\b(manually|by hand|run this once|TODO: automate)\b", (".md", ".sh")),
    ("rollback", "P2", r"\btimeshift\b|\betckeeper\b", (".md", ".nix", ".sh")),
    # Explizite Abhaengigkeiten (Laufzeit-Netzwerk = legitim, aber dokumentieren)
    ("explizit", "P2", r"(ExecStart|script|text)\s*=.*\b(curl|wget|git\s+clone)\b", (".nix",)),
    # Lazy / Debug
    ("lazy", "P2", r"\bbuiltins\.trace\b", (".nix",)),
    # FHS-Reflexe
    ("fhs", "P1", r'"/(usr|sbin)/[a-z]', (".nix", ".sh")),
]


def walk():
    for dp, dns, fns in os.walk(ROOT):
        dns[:] = [d for d in dns if d not in SKIP_DIRS]
        rel = os.path.relpath(dp, ROOT)
        if (
            any(rel == p or rel.startswith(p + "/") for p in SKIP_PATH_PREFIXES)
            or "/references" in rel
        ):
            continue
        for fn in fns:
            if fn.endswith(EXTS):
                yield Path(dp) / fn


def scan() -> list[dict[str, object]]:
    out: list[dict[str, object]] = []
    compiled = [(p, lvl, re.compile(rx), exts) for (p, lvl, rx, exts) in SIGNALS]
    for path in walk():
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        rel = str(path.relative_to(ROOT))
        for prop, level, cre, exts in compiled:
            if not path.name.endswith(exts):
                continue
            for i, line in enumerate(lines, 1):
                if line.lstrip().startswith("#!"):
                    continue  # Shebang (#!…/usr/bin/env) ist idiomatisch, kein FHS-Verstoss
                if cre.search(line):
                    out.append(
                        {
                            "prop": prop,
                            "level": level,
                            "file": rel,
                            "line": i,
                            "text": line.strip()[:160],
                        }
                    )
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="NixOS-Idiom-Audit (Schicht 1: Signale)")
    ap.add_argument("--json", action="store_true", help="JSON statt Text")
    ap.add_argument("--p0-only", action="store_true", help="nur P0, Exit 1 bei Fund (CI)")
    args = ap.parse_args()

    findings = scan()
    if args.p0_only:
        findings = [f for f in findings if f["level"] == "P0"]

    if args.json:
        print(json.dumps(findings, ensure_ascii=False, indent=2))
    else:
        by_level: dict[str, list[dict[str, object]]] = {}
        for f in findings:
            by_level.setdefault(str(f["level"]), []).append(f)
        for lvl in ("P0", "P1", "P2"):
            hits = by_level.get(lvl, [])
            if not hits:
                continue
            print(f"── {lvl} ({len(hits)}) ──")
            for f in hits:
                print(f"  {f['prop']:<16} {f['file']}:{f['line']}  {f['text']}")
            print()
        print(f"Gesamt: {len(findings)} Signale — SIGNAL != FUND (Schicht 2: Kontext lesen).")

    if args.p0_only and findings:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
