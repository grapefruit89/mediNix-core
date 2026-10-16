#!/usr/bin/env python3
"""ADR-Formregel (verbindlich) - CI-Check, fail-closed bei echten Regelverstoessen.

ID-Schema, konsistent zu /home/moritz/repos/mediNix-core/docs/adr/llm-index.json:
  - Dienst-ADR:      ADR-<dienstnummer>            z. B. ADR-511, ADR-551, ADR-576
  - Meta/Thema-ADR:  ADR-<domain><slot> (4-stellig) z. B. ADR-0000, ADR-0010, ADR-5043, ADR-5050
  - Fundament:       ADR-00xx (reserviert)

Datei:   ADR-<id-ohne-praefix>-<slug>.md
Inhalt:  Front-Matter `id:` = die ID;  Ueberschrift `# ADR-<id>: <Titel>`
Index:   jede Datei steht in docs/adr/llm-index.json (canonical | duplicates | reviews)

FEHLER (Exit 1): fehlende/doppelte `id`, Dateiname passt nicht zur `id`,
Datei nicht im Index registriert.
ZUSATZ (Kette Code -> ADR, 2026-10-16): jeder ADR-Verweis aus einem Modul-Header
(`adr:` / `links.adr`) muss auf eine EXISTIERENDE ADR-ID zeigen. Ein Verweis, der den
DATEINAMEN statt der ID nennt, ist immer ein Fehler; neue tote Verweise ebenso.
Der Altbestand steht mit Begruendung in scripts/adr-refs-allowlist.txt.

HINWEIS (Exit 0): Legacy-Slug-ids (Bestand) und allowlistete Alt-Verweise.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ADR_DIR = ROOT / "docs/adr"
INDEX = ADR_DIR / "llm-index.json"
FRONT_MATTER = re.compile(r"^---\n(.*?)\n---\n", re.S)
HEADING = re.compile(r"^#\s+(.+)$", re.M)
FM_ID = re.compile(r'^id:\s*"?(.+?)"?\s*$', re.M)
NIX_REF = re.compile(r'^(?:[ \t]*(?:adr|repo-harvest)\s*:|[ \t]*-[ \t]+)(ADR-[A-Za-z0-9-]+)', re.M)
NUMERIC_ID = re.compile(r"^ADR-\d{3,4}$")
ALLOWLIST = ROOT / "scripts/adr-refs-allowlist.txt"
REF = re.compile('^\\s*#?\\s*adr:\\s*"?(.+?)"?\\s*$', re.M)  # Domain-only (ADR-52-*) ist Legacy (siehe llm-index.naming)


def ref_allowlist() -> dict[str, str]:
    """{ADR-id: Begruendung} aus scripts/adr-refs-allowlist.txt."""
    if not ALLOWLIST.is_file():
        return {}
    out: dict[str, str] = {}
    for line in ALLOWLIST.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        ref, _, why = line.partition("|")
        out[ref.strip()] = why.strip()
    return out


def module_refs(known, filenames):
    """(Fehler, Hinweise) der Kante Code -> ADR."""
    allowed = ref_allowlist()
    errors = []
    hints = []
    for nix in sorted(ROOT.glob("**/*.nix")):
        if ".git" in nix.parts:
            continue
        rel = str(nix.relative_to(ROOT))
        for match in REF.finditer(nix.read_text(encoding="utf-8")):
            for raw in match.group(1).split(","):
                ref = raw.split("(")[0].strip()
                if not ref.startswith("ADR-"):
                    continue
                if ref in filenames and filenames[ref] != ref:
                    errors.append(f"{rel}: nennt den DATEINAMEN '{ref}' statt der ID '{filenames[ref]}'")
                elif ref not in known:
                    if ref in allowed:
                        hints.append(f"{rel}: Verweis '{ref}' offen - {allowed[ref]}")
                    else:
                        errors.append(f"{rel}: Verweis '{ref}' zeigt auf keine existierende ADR"
                                      " (neu -> ADR anlegen; Altfall -> scripts/adr-refs-allowlist.txt)")
    return errors, hints


def index_registered() -> set[str]:
    if not INDEX.is_file():
        return set()
    raw = INDEX.read_text(encoding="utf-8")
    return set(re.findall(r"ADR-[A-Za-z0-9-]+\.md", raw))


def main() -> int:
    errors: list[str] = []
    hints: list[str] = []
    registered = index_registered()
    ids: dict[str, Path] = {}
    numeric_ids: set[str] = set()

    files = sorted(ADR_DIR.glob("ADR-*.md"))
    if not files:
        print("FEHLER: keine ADR-Dateien gefunden - Pfad falsch?")
        return 1

    for adr in files:
        rel = adr.relative_to(ROOT)
        text = adr.read_text(encoding="utf-8")

        fm = FRONT_MATTER.match(text)
        found = FM_ID.search(fm.group(1)) if fm else None
        if not found:
            errors.append(f"{rel}: Front-Matter mit 'id:' fehlt")
            continue
        adr_id = found.group(1).strip()

        if adr_id in ids:
            errors.append(f"{rel}: id '{adr_id}' doppelt (auch in {ids[adr_id].name})")
        ids[adr_id] = adr

        key = adr_id[len("ADR-"):]
        if not adr.name.startswith(f"ADR-{key}"):
            errors.append(f"{rel}: Dateiname passt nicht zur id '{adr_id}'")

        head = HEADING.search(text)
        if head and head.group(1).startswith("ADR-"):
            head_text = head.group(1).strip()
            head_id = head_text.split(":")[0].strip()
            slug_num = re.match(r"^ADR-(\d{3,4})-", str(adr_id))
            if not re.match(r"^ADR-[A-Za-z0-9-]+: \S", head_text):
                errors.append(
                    f"{rel}: Ueberschrift muss '# ADR-<id>: <Titel>' sein "
                    f"(gefunden: '# {head_text[:48]}')"
                )
            elif NUMERIC_ID.match(adr_id) and head_id != adr_id:
                errors.append(f"{rel}: Ueberschrift '{head_id}' != id '{adr_id}'")
            elif re.match(r"^\d{3,4}$", str(adr_id)) and head_id != f"ADR-{adr_id}":
                errors.append(f"{rel}: Ueberschrift '{head_id}' != id 'ADR-{adr_id}'")
            elif slug_num and head_id != f"ADR-{slug_num.group(1)}":
                hints.append(f"{rel}: Ueberschrift '{head_id}' != Slug-id-Ziel 'ADR-{slug_num.group(1)}'")
            if head_id.startswith("ADR-") and NUMERIC_ID.match(head_id):
                numeric_ids.add(head_id)

        if NUMERIC_ID.match(adr_id) or re.match(r"^\d{3,4}$", adr_id):
            numeric_ids.add(adr_id)
        elif re.match(r"^ADR-\d{1,2}-", adr_id):
            hints.append(
                f"{rel}: Domain-only-id '{adr_id}' (Legacy, llm-index.naming) -> auf die Inhalts-ID umbenennen"
            )
        elif re.match(r"^ADR-\d{3,4}-", adr_id):
            hints.append(f"{rel}: id '{adr_id}' traegt einen Slug -> Ziel: id: ADR-<nummer>")
        else:
            hints.append(f"{rel}: Legacy-Slug-id '{adr_id}' -> Ziel: numerische ID oder Index-Eintrag")

        if adr.name not in registered:
            errors.append(f"{rel}: nicht in docs/adr/llm-index.json registriert")

    # Kante Code -> ADR
    filenames = {}
    known = set(ids)
    for adr in files:
        text = adr.read_text(encoding="utf-8")
        fm = FRONT_MATTER.match(text)
        fm_id = FM_ID.search(fm.group(1)).group(1).strip() if fm else adr.name[:-3]
        filenames[adr.name[:-3]] = fm_id
        known.add(fm_id)
        head = HEADING.search(text)
        if head:
            known.add(head.group(1).split(":")[0].split(" ")[0].strip())
    known |= numeric_ids | {f"ADR-{i}" for i in ids}
    ref_errors, ref_hints = module_refs(known, filenames)
    errors += ref_errors
    hints += ref_hints

    if hints:
        print("HINWEISE (Kurationsliste, CI bleibt gruen):")
        for hint in hints:
            print(f"  - {hint}")
    for error in errors:
        print(f"FEHLER: {error}")

    print(f"\n{len(files)} ADR-Dateien, {len(ids)} ids, {len(errors)} Fehler, {len(hints)} Hinweise.")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
