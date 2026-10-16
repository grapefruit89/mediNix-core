#!/usr/bin/env python3
"""Katalog-Lint fuer docs/NIXOS-ANCHORS.md (Semantic Anchors, NixOS-Teil).

Prueft den KATALOG, nicht die Semantik: die Anker sind Begriffe (Deterministic
Builds, Pet Server, ...) - ob ein Modul sie "einhaltet", ist nicht maschinell
entscheidbar. Maschinell entscheidbar ist dagegen:

  1. jeder Anker hat alle acht Felder (Details, Kernkonzepte, Wann nutzen,
     Missverstaendnisse, Kritik, Status, Quelle, Durchsetzung),
  2. die Quelle ist identifizierbar (Jahr, Version, ADR-Bezug oder "o. J."),
  3. die Durchsetzungs-Angabe zeigt auf etwas EXISTIERENDES: eine Datei unter
     scripts/|lib/|docs/, eine Korridor-Regel AB-xxx (oder ausdruecklich "manuell"),
  4. die drei Gruppen (A/B/C) und mindestens 25 Anker sind vorhanden.

Exit 1 = Katalog verfallen.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOC = ROOT / "docs/NIXOS-ANCHORS.md"
STATE = ROOT / ".agent-state.json"
FIELDS = (
    "Details",
    "Kernkonzepte",
    "Wann nutzen",
    "Missverstaendnisse",
    "Kritik",
    "Status",
    "Quelle",
    "Durchsetzung",
)
GROUPS = ("## A)", "## B)", "## C)")
ANCHOR = re.compile(r"^### \d+\.\s+(.+)$", re.M)
AB_ID = re.compile(r"AB-\d{3}")
SCRIPT_REF = re.compile(r"scripts/[A-Za-z0-9_.-]+\.(?:py|sh)")
# Quelle muss identifizierbar sein: Jahr, Version (z. B. 26.11) oder ADR-Bezug.
SOURCE_ID = re.compile(r"\b(?:19|20)\d{2}\b|\b\d+\.\d+\b|ADR-\d{3,4}|o\.\s?J\.")
# Durchsetzung darf auf existierende Dateien (scripts/|lib/|docs/) zeigen.
FILE_REF = re.compile(r"(?:scripts|lib|docs)/[A-Za-z0-9_./-]+\.(?:py|sh|nix|md)")
MIN_ANCHORS = 25


def corridor_ids() -> set[str]:
    if not STATE.is_file():
        return set()
    data = json.loads(STATE.read_text(encoding="utf-8"))
    return {entry["id"] for entry in data["corridor"]["blacklist"]}


def main() -> int:
    if not DOC.is_file():
        print(f"FEHLER: {DOC.relative_to(ROOT)} fehlt")
        return 1
    text = DOC.read_text(encoding="utf-8")
    errors: list[str] = []
    hints: list[str] = []
    known_ab = corridor_ids()

    for group in GROUPS:
        if group not in text:
            errors.append(f"Gruppe '{group} …' fehlt")

    parts = ANCHOR.split(text)
    titles = parts[1::2]
    blocks = parts[2::2]
    if len(titles) < MIN_ANCHORS:
        errors.append(f"nur {len(titles)} Anker gefunden (erwartet >= {MIN_ANCHORS})")

    for title, block in zip(titles, blocks):
        label = title.strip()
        for field in FIELDS:
            if not re.search(rf"^-\s+\*\*{re.escape(field)}:\*\*\s*\S", block, re.M):
                errors.append(f"Anker '{label}': Feld '{field}' fehlt oder ist leer")
        quelle = re.search(r"^-\s+\*\*Quelle:\*\*\s*(.+)$", block, re.M)
        if quelle and not SOURCE_ID.search(quelle.group(1)):
            errors.append(
                f"Anker '{label}': Quelle ohne Jahr/Version/ADR-Bezug -> '{quelle.group(1)[:60]}'"
            )
        durch = re.search(r"^-\s+\*\*Durchsetzung:\*\*\s*(.+)$", block, re.M)
        if not durch:
            continue
        value = durch.group(1)
        if "manuell" in value.lower():
            continue
        refs = AB_ID.findall(value) + FILE_REF.findall(value)
        if not refs:
            errors.append(
                f"Anker '{label}': Durchsetzung nennt weder eine Datei (scripts/|lib/|docs/) "
                f"noch eine AB-Regel noch 'manuell' -> '{value[:60]}'"
            )
        for ab in AB_ID.findall(value):
            if ab not in known_ab:
                errors.append(f"Anker '{label}': Durchsetzung verweist auf unbekannte Regel '{ab}'")
        for ref in FILE_REF.findall(value):
            if not (ROOT / ref).is_file():
                errors.append(f"Anker '{label}': Durchsetzung verweist auf fehlendes '{ref}'")

    for hint in hints:
        print(f"HINWEIS: {hint}")
    for error in errors:
        print(f"FEHLER: {error}")
    if errors:
        print(f"\n{len(errors)} Katalog-Verstoss/Verstoesse ({len(titles)} Anker geprueft).")
        return 1
    print(f"OK: {len(titles)} NixOS-Anker vollstaendig (8 Felder, Quelle identifizierbar, "
          f"Durchsetzung verifiziert; Korridor kennt {len(known_ab)} Regeln).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
