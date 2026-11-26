#!/usr/bin/env python3
# ---
# id: "check-markdown-links"
# title: "Mechanischer Link-Konsistenz-Checker fuer alle Markdown-Dokumente"
# domain: 50
# folder: "scripts"
# status: active
# kind: tooling
# complexity: 1
# last_reviewed: 2026-11-26
# links:
#   adr: ADR-0000
# ---
"""Prueft alle relativen und file:// Links in Markdown-Dateien auf Existenz.

Verhindert Dokumentations-Verwesung, veraltete Modulnamen und tote Pfade
(LLM-ordnerstruktur Baustein B).

Exit: 0 gruen, 1 bei mindestens einem toten Link.
"""
from __future__ import annotations

import re
import sys
import urllib.parse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
WIKI_RE = re.compile(r"\[\[([^\]]+)\]\]")

EXCLUDED_PARTS = {".git", ".gemini", "result", "_input", "historie", ".system_generated"}


def main() -> int:
    errors: list[tuple[str, str, str]] = []
    total_links = 0

    for md_file in sorted(ROOT.rglob("*.md")):
        rel_md = md_file.relative_to(ROOT)
        if any(p in EXCLUDED_PARTS or p.startswith(".") for p in rel_md.parts):
            continue

        text = md_file.read_text(encoding="utf-8", errors="ignore")

        # Standard Markdown Links: [label](target)
        for m in LINK_RE.finditer(text):
            target = m.group(2).strip()
            if not target or target.startswith(
                ("http://", "https://", "mailto:", "#", "{")
            ):
                continue

            path_part = target.split("#")[0]
            if not path_part:
                continue

            total_links += 1
            if path_part.startswith("file://"):
                resolved = Path(
                    urllib.parse.unquote(urllib.parse.urlparse(path_part).path)
                )
            else:
                resolved = (md_file.parent / path_part).resolve()

            if not resolved.exists():
                errors.append((str(rel_md), target, str(resolved)))

        # WikiLinks: [[target]]
        for m in WIKI_RE.finditer(text):
            target = m.group(1).strip()
            if not target or target.startswith(
                ("http://", "https://", "mailto:", "#", "{")
            ):
                continue

            path_part = target.split("#")[0].split("|")[0].strip()
            if not path_part:
                continue

            total_links += 1
            resolved_local = (md_file.parent / path_part).resolve()
            resolved_root = (ROOT / path_part).resolve()

            if not resolved_local.exists() and not resolved_root.exists():
                errors.append((str(rel_md), target, str(resolved_local)))

    if errors:
        print(f"FEHLER: {len(errors)} tote Links in {total_links} geprueften Links:")
        for rel_file, target, resolved in errors:
            print(f"  {rel_file}: '{target}' -> {resolved} nicht gefunden")
        return 1

    print(f"OK    check_markdown_links ({total_links} Links valide)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
