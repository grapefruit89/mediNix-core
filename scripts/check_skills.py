#!/usr/bin/env python3
"""Repo-seitige Pruefung der Agenten-Skills (CI-tauglich, fail-closed).

Regel (siehe AGENTS.md + docs/CONVENTIONS.md): Projekt-Skills leben unter
docs/agents/<kategorie>/<skill>/SKILL.md und tragen YAML-Front-Matter mit
`name` (== Ordnername, eindeutig) und `description` (Trigger-Beschreibung).

Nicht in der CI pruefbar: die lokalen Symlinks in
~/.config/opencode/skills/ (CI laeuft auf einer anderen Maschine) - dafuer
gibt es scripts/link-skills.sh.

Exit 0 = alle Skills formal in Ordnung (kurze Beschreibungen sind Hinweise,
kein Fehler), Exit 1 = Regelverstoss.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FRONT_MATTER = re.compile(r"^---\n(.*?)\n---\n", re.S)
NAME = re.compile(r'^name:\s*"?(.+?)"?\s*$', re.M)
DESC = re.compile(r"^description:\s*(.+?)(?=\n[a-z_]+:|\Z)", re.S | re.M)
SHORT_DESC = 80

errors: list[str] = []
hints: list[str] = []
names: list[str] = []


def main() -> int:
    for skill_file in sorted((ROOT / "docs/agents").glob("*/*/SKILL.md")):
        rel = skill_file.relative_to(ROOT)
        expected = skill_file.parent.name
        match = FRONT_MATTER.match(skill_file.read_text(encoding="utf-8"))
        if not match:
            errors.append(f"{rel}: YAML-Front-Matter (--- ... ---) fehlt")
            continue
        front_matter = match.group(1)

        found_name = NAME.search(front_matter)
        if not found_name:
            errors.append(f"{rel}: 'name' fehlt im Front-Matter")
            continue
        name = found_name.group(1).strip()
        names.append(name)
        if name != expected:
            errors.append(f"{rel}: name '{name}' != Ordnername '{expected}'")

        found_desc = DESC.search(front_matter)
        if not found_desc or not found_desc.group(1).strip():
            errors.append(f"{rel}: 'description' fehlt (Trigger-Beschreibung ist Pflicht)")
            continue
        desc = " ".join(found_desc.group(1).split())
        if len(desc) < SHORT_DESC:
            hints.append(f"{rel}: description nur {len(desc)} Zeichen -> {desc}")

    duplicates = sorted({n for n in names if names.count(n) > 1})
    for dup in duplicates:
        errors.append(f"doppelter Skill-name: '{dup}' (Namen muessen eindeutig sein)")

    if hints:
        print("Hinweise (kein Fehler, aber Trigger schwaecher als 80 Zeichen):")
        for hint in hints:
            print(f"  - {hint}")
    for error in errors:
        print(f"FEHLER: {error}")

    if errors:
        print(f"\n{len(errors)} Regelverstoss/Verstoesse, {len(names)} Skills geprueft.")
        return 1
    print(
        f"OK: {len(names)} Projekt-Skills formal in Ordnung "
        f"({len(hints)} mit kurzer Beschreibung)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
