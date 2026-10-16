#!/usr/bin/env python3
"""sources-Check — jedes Dienst-Modul nennt seine Upstream-Quellen.

EISERNE REGEL (docs/UPSTREAM-SOURCES.md): Wer Code, Logik oder Architektur aus
einem externen Repo / NixOS-Modul / einer Doku uebernimmt, muss die Quelle
nennen. Mechanisch pruefbar ist das Manifest-Feld `sources`: verlangt werden
`sources.upstream` (offizielle Doku) UND `sources.repo` (Quellcode-Repo), beide
nicht-null (`lib/service-contract.nix`).

Geprueft werden **Dienst-Module**: `NNN-*.nix`, die einen Manifest-Eintrag
registrieren (`medinix.manifest.<name> = {`). Reine Infrastruktur-Dateien ohne
Manifest (z. B. 501-decimal-engine) sind nicht betroffen.

RATSCHE (wie nixmeta, ADR-0002): Module, die es noch nicht tragen, stehen in
`scripts/sources-baseline.txt` — die Liste darf **nur schrumpfen**. Ein Eintrag,
der konform geworden ist, wird als Hinweis gemeldet. Neu erzeugen mit
`python3 scripts/check_sources.py --write-baseline`.

Exit 1 = Verstoss (Dienst-Modul ohne `upstream`/`repo`, das NICHT auf der Ratsche steht).
"""

import os
import re
import sys

BASELINE_FILE = "scripts/sources-baseline.txt"
SERVICE_FILE = re.compile(r"^\d{3}-.*\.nix$")
REGISTER = re.compile(r"medinix\.manifest\.(?:[A-Za-z0-9_-]+|\"[A-Za-z0-9_-]+\")\s*=\s*\{")
SOURCES_OPEN = re.compile(r"\bsources\s*=\s*\{")
FIELDS = {
    "upstream": re.compile(r"\bupstream\s*=\s*\"[^\"]+\""),
    "repo": re.compile(r"\brepo\s*=\s*\"[^\"]+\""),
}


def service_modules():
    """5xx-Dateien auf oberster NN-*-Ebene (kein Eingelagertes)."""
    out = []
    for dirpath, dirnames, filenames in os.walk(os.getcwd()):
        dirnames[:] = [d for d in dirnames if d != ".git"]
        rel = os.path.relpath(dirpath, os.getcwd())
        if rel.startswith("docs/audit") or rel.startswith("docs/archive"):
            continue
        if not (rel == "." or re.match(r"^\d{2}-", rel)):
            continue
        out += [
            os.path.relpath(os.path.join(dirpath, fn), os.getcwd())
            for fn in filenames
            if SERVICE_FILE.match(fn)
        ]
    return sorted(out)


def missing_of(path):
    """Fehlende Pflichtfelder dieser Datei oder None (kein Dienst-Modul)."""
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    if not REGISTER.search(text):
        return None  # kein Manifest-Traeger -> nicht pruefen
    match = SOURCES_OPEN.search(text)
    if not match:
        return list(FIELDS)
    # `sources` ist flach (nur String-Optionen) -> bis zum naechsten `};`.
    end = text.find("};", match.end())
    block = text[match.end() : end if end != -1 else match.end() + 1500]
    return [name for name, rx in FIELDS.items() if not rx.search(block)]


def baseline():
    path = os.path.join(os.getcwd(), BASELINE_FILE)
    if not os.path.exists(path):
        return set()
    with open(path, encoding="utf-8") as fh:
        return {line.split("#")[0].strip() for line in fh if line.split("#")[0].strip()}


def backlog_of(files):
    return [(p, m) for p in files if (m := missing_of(p))]


def main():
    files = [p for p in service_modules() if missing_of(p) is not None]

    if "--write-baseline" in sys.argv:
        rows = backlog_of(files)
        with open(BASELINE_FILE, "w", encoding="utf-8") as fh:
            fh.write(
                "# sources-Ratsche: Dienst-Module ohne `sources.upstream` + `sources.repo`.\n"
                "# Liste darf nur schrumpfen - konform gewordene Eintraege entfernen.\n"
                + "".join(f"{p}\n" for p, _ in rows)
            )
        print(f"{BASELINE_FILE} geschrieben ({len(rows)} Eintraege)")
        return

    base = baseline()
    violations, backlog, stale = [], [], []
    for path in files:
        miss = missing_of(path)
        if not miss:
            if path in base:
                stale.append(path)
        elif path in base:
            backlog.append((path, miss))
        else:
            violations.append((path, miss))

    if violations:
        print(f"sources: {len(violations)} Dienst-Modul(e) ohne Upstream-Quelle (nicht auf der Ratsche)\n")
        for path, miss in violations:
            print(f"  {path}: fehlt {'/'.join(miss)}  -> sources = {{ upstream = \"…\"; repo = \"…\"; }}")
        print("\nRegel: docs/UPSTREAM-SOURCES.md · Ausnahmen: " + BASELINE_FILE)
        sys.exit(1)

    print(f"sources: {len(files)} Dienst-Module geprueft, alle mit `upstream` + `repo` (oder auf der Ratsche)")
    if backlog:
        print(f"Ratsche-Backlog ({len(backlog)} Datei(en), Liste {BASELINE_FILE}):")
        for path, miss in backlog:
            print(f"  {path}: fehlt {'/'.join(miss)}")
    if stale:
        print(
            f"HINWEIS: {len(stale)} Baseline-Eintrag/Eintraege inzwischen konform -> aus "
            f"{BASELINE_FILE} entfernen: {', '.join(stale)}"
        )


main()
