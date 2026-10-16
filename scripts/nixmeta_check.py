#!/usr/bin/env python3
"""nixmeta-Check — prueft den YAML-Header JEDER .nix-Datei gegen ADR-00-nixmeta-v3.

Regeln (docs/adr/ADR-00-nixmeta-v3-header.md):
  - Header beginnt in Zeile 1, ist in `# `-Kommentare gefasst und mit `# ---`
    eingefasst; nach Entfernen der `# `-Praefixe muss es gueltiges YAML sein.
  - Pflichtfelder: id, title, domain, folder, status, complexity, last_reviewed,
    links.adr.

RATSCHE (bewusster, dokumentierter Scope — 2026-10-15): erzwungen werden der
Header, die YAML-Gueltigkeit und die KERNfelder id/title/domain/last_reviewed
plus die objektiv ableitbaren Regeln (id == Dateiname; domain == Ordnerpraefix
in `NN-*`-Ordnern; Wertebereiche von status und complexity, sofern vorhanden).

NICHT erzwungen (steht als Roadmap-Punkt): dass folder/status/complexity/links.adr
*ueberall* stehen. Deren Werte brauchen Urteilsvermoegen je Modul (complexity 1-5,
primaerer ADR) — sie werden hier nur geprueft, wenn sie da sind.
"""
import os
import re
import sys

import yaml

CORE = ("id", "title", "domain", "last_reviewed")
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
STATUS = {"active", "deprecated", "draft"}
FENCE = "# ---"


def nix_files():
    out = []
    for dirpath, dirnames, filenames in os.walk(os.getcwd()):
        dirnames[:] = [d for d in dirnames if d != ".git"]
        rel = os.path.relpath(dirpath, os.getcwd())
        # Eingelagertes (Ausgemustertes) wird NICHT gegated: docs/audit/, docs/archive/.
        if rel.startswith("docs/audit") or rel.startswith("docs/archive"):
            continue
        out += [
            os.path.relpath(os.path.join(dirpath, fn), os.getcwd())
            for fn in filenames
            if fn.endswith(".nix")
        ]
    return sorted(out)


def header_of(path):
    """Liefert (yaml-block, fehler) — genau eines von beiden ist None."""
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().splitlines()
    if not lines or lines[0].strip() != FENCE:
        return None, f"Header fehlt: Zeile 1 muss `{FENCE}` sein"
    for i, line in enumerate(lines[1:], start=1):
        if line.strip() == FENCE:
            return [re.sub(r"^# ?", "", x) for x in lines[1:i]], None
    return None, f"Header nicht geschlossen: die zweite `{FENCE}`-Zeile fehlt"


def as_int(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def check(path):
    """Liefert eine Liste von Verstoessen fuer diese Datei."""
    bad = []
    block, err = header_of(path)
    if err:
        return [err]
    try:
        data = yaml.safe_load("\n".join(block))
    except yaml.YAMLError as exc:
        first = str(exc).splitlines()[0]
        return [f"Header ist kein gueltiges YAML: {first}"]
    if not isinstance(data, dict):
        return ["Header ist kein YAML-Mapping (Schluessel: Wert)"]

    for key in CORE:
        if data.get(key) in (None, ""):
            bad.append(f"Pflichtfeld `{key}:` fehlt")

    stem = os.path.basename(path)[:-4]
    # Regel: bei `NNN-service.nix` MUSS die id dem Dateinamen entsprechen (der
    # Dezimalrahmen macht sie eindeutig). Bei anderen Dateien (default.nix,
    # flake.nix, Beispiele) gibt es keinen eindeutigen Dateinamen - dort ist die
    # id ein sprechender Bezeichner (z. B. "arr-provision" fuer
    # lib/arr-provision/default.nix), nur nicht leer.
    if re.match(r"^\d{3}-", stem):
        if data.get("id") not in (None, "") and str(data["id"]) != stem:
            bad.append(f"`id: {data['id']}` != Dateiname `{stem}`")

    reviewed = str(data.get("last_reviewed", ""))
    if reviewed and not DATE.match(reviewed):
        bad.append(f"`last_reviewed: {reviewed}` ist kein YYYY-MM-DD")

    status = data.get("status")
    if status is not None and str(status) not in STATUS:
        bad.append(f"`status: {status}` nicht in {sorted(STATUS)}")

    if data.get("complexity") is not None:
        complexity = as_int(data["complexity"])
        if complexity is None or not 1 <= complexity <= 5:
            bad.append(f"`complexity: {data['complexity']}` nicht im Bereich 1..5")

    domain = data.get("domain")
    if domain is not None:
        parent = os.path.dirname(path)
        prefix = re.match(r"^(\d{2})-", os.path.basename(parent)) if parent else None
        if prefix is None:
            if as_int(domain) is None:
                bad.append(f"`domain: {domain}` ist keine 2-stellige Zahl")
        elif as_int(domain) != int(prefix.group(1)):
            bad.append(
                f"`domain: {domain}` != Ordnerpraefix {int(prefix.group(1))} ({parent}/)"
            )
    return bad


def main():
    files = nix_files()
    violations = [(p, check(p)) for p in files]
    violations = [(p, v) for p, v in violations if v]
    if violations:
        total = sum(len(v) for _, v in violations)
        print(f"nixmeta: {total} Verstoss/Verstoesse in {len(violations)}/{len(files)} Dateien\n")
        for path, msgs in violations:
            print(f"  {path}")
            for msg in msgs:
                print(f"      {msg}")
        print("\nRegeln: docs/adr/ADR-00-nixmeta-v3-header.md")
        sys.exit(1)
    print(f"nixmeta: {len(files)} .nix-Dateien konform")


main()
