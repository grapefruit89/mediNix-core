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

RATSCHE 2 (2026-10-16, ADR-00-nixmeta-v3 + Baustelle 7): fuer Dienst-Module
(`NNN-*.nix`) sind ZUSAETZLICH Pflicht: `folder` (== Ordnername), `status`,
`complexity`, `links.adr`.
  Upstream-Angaben (`upstream_github` | `upstream_docs` | `nixpkgs_attr`) sind laut
  ADR-00 **Extended Fields** ("For complex modules") und daher NICHT Pflicht - der
  Check meldet sie nur als Hinweis-Zeile.

RATSCHE 3 (2026-11-04, ADR-0000 §14 "Datei-Klassifikation"): jede Datei wird per
`classify()` genau einer Kategorie zugeordnet (Modul, Library, Engine, Package, Test,
Root-Config, Tooling-Einstieg) oder einer Zone (`docs/examples/**`, `docs/**/templates/**`).
`kind:` ist Pflicht ausser bei Modul (NNN-Praefix) und in Zonen (dort verboten), und muss
dem Ergebnis von `classify()` entsprechen. `folder:` muss bei JEDER Datei dem Verzeichnis
relativ zur Wurzel entsprechen.

stehen in `scripts/nixmeta-baseline.txt` — die Liste darf nur schrumpfen: ist ein
Eintrag konform geworden, meldet der Check das als Hinweis. Neu erzeugen mit
`python3 scripts/nixmeta_check.py --write-baseline`.
"""
import os
import re
import sys

import yaml

CORE = ("id", "title", "domain", "last_reviewed")
BASELINE_FILE = "scripts/nixmeta-baseline.txt"
UPSTREAM_KEYS = ("upstream_github", "upstream_docs", "nixpkgs_attr")
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
STATUS = {"active", "deprecated", "draft", "example", "template"}
FENCE = "# ---"

# --- ADR-0000 §14 Datei-Klassifikation (Ratsche 3) ---------------------------
# Reihenfolge ist bindend: explizite Listen VOR den Mustern, weil
# `50-core/501-decimal-engine.nix` Engine- UND Modulform erfuellt und
# `50-core/repl.nix` Tooling- UND Libraryform (ADR-0000 §14.4.1).
ROOT_FILES = {"flake.nix", "default.nix"}
ENGINE_FILES = {"50-core/501-decimal-engine.nix", "50-core/service-contract.nix"}
TOOLING_FILES = {"50-core/repl.nix"}
MODULE_RE = re.compile(r"^[0-9]{2}-[^/]+/[0-9]{3}-.*\.nix$")
LIBRARY_RE = re.compile(r"^[0-9]{2}-[^/]+/[^/]+\.nix$")
PACKAGE_RE = re.compile(r"^packages/[^/]+/[^/]+\.nix$")
# Tests liegen neben dem Vertrag, den sie pruefen (50-core/registry.nix).
# Sie passen auf LIBRARY_RE, deshalb explizit VOR den Mustern - wie
# ENGINE_FILES/TOOLING_FILES oben.
TEST_FILES = {
    "50-core/smoke-test.nix",
    "50-core/vm-smoke-test.nix",
}

# Kategorie -> erwarteter `kind:`-Wert. Kategorien, die hier NICHT stehen, tragen
# kein `kind:`: `module` (der NNN-Praefix ist die Aussage) und die beiden Zonen.
KIND_OF = {
    "library": "library",
    "engine": "engine",
    "package": "package",
    "test": "test",
    "root-config": "root-config",
    "tooling": "tooling",
}


def classify(path):
    """Liefert die §14-Kategorie: eine von sieben, `zone:<status>` oder `unklassifiziert`."""
    p = path.replace("\\", "/")
    if p in ROOT_FILES:
        return "root-config"
    if p in ENGINE_FILES:
        return "engine"
    if p in TOOLING_FILES:
        return "tooling"
    if p in TEST_FILES:
        return "test"
    if MODULE_RE.match(p):
        return "module"
    if LIBRARY_RE.match(p):
        return "library"
    if PACKAGE_RE.match(p):
        return "package"
    if p.startswith("docs/examples/"):
        return "zone:example"
    if p.startswith("docs/") and "/templates/" in p:
        return "zone:template"
    return "unklassifiziert"


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


def baseline():
    """Zeilen aus scripts/nixmeta-baseline.txt (ohne Kommentare)."""
    path = os.path.join(os.getcwd(), BASELINE_FILE)
    if not os.path.exists(path):
        return set()
    with open(path, encoding="utf-8") as fh:
        return {line.split("#")[0].strip() for line in fh if line.split("#")[0].strip()}


def as_int(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def check(path):
    """Liefert (harte Verstoesse, Ratsche-Luecken) fuer diese Datei."""
    bad = []
    missing = []
    optional = []
    block, err = header_of(path)
    if err:
        return [err], [], []
    try:
        data = yaml.safe_load("\n".join(block))
    except yaml.YAMLError as exc:
        first = str(exc).splitlines()[0]
        return [f"Header ist kein gueltiges YAML: {first}"], [], []
    if not isinstance(data, dict):
        return ["Header ist kein YAML-Mapping (Schluessel: Wert)"], [], []

    for key in CORE:
        if data.get(key) in (None, ""):
            bad.append(f"Pflichtfeld `{key}:` fehlt")

    # ADR-0000 §14: Datei-Klassifikation (Ratsche 3)
    category = classify(path)
    kind = data.get("kind")
    kind_str = str(kind).strip() if kind not in (None, "") else None
    if category == "unklassifiziert":
        bad.append("§14: Datei passt in keine Kategorie (ADR-0000 §14.1)")

    stem = os.path.basename(path)[:-4]
    # Regel: bei `NNN-service.nix` MUSS die id dem Dateinamen entsprechen (der
    # Dezimalrahmen macht sie eindeutig). Bei anderen Dateien (default.nix,
    # flake.nix, Beispiele) gibt es keinen eindeutigen Dateinamen - dort ist die
    # id ein sprechender Bezeichner (z. B. "arr-provision" fuer
    # packages/arr-provision/default.nix), nur nicht leer.
    if re.match(r"^\d{3}-", stem):
        if data.get("id") not in (None, "") and str(data["id"]) != stem:
            bad.append(f"`id: {data['id']}` != Dateiname `{stem}`")

    reviewed = str(data.get("last_reviewed", ""))
    if reviewed and not DATE.match(reviewed):
        bad.append(f"`last_reviewed: {reviewed}` ist kein YYYY-MM-DD")

    status = data.get("status")
    if status is not None and str(status) not in STATUS:
        bad.append(f"`status: {status}` nicht in {sorted(STATUS)}")

    norm_path = path.replace("\\", "/")
    if norm_path.startswith("docs/examples/"):
        if status != "example":
            bad.append(f"`status: {status}` != `example` (Zonenregel docs/examples/**)")
        if kind_str is not None:
            bad.append(
                f"§14.2: `kind: {kind_str}` ist in der Zone docs/examples/** verboten "
                "(die Zone ist die Aussage)"
            )
    elif norm_path.startswith("docs/") and "/templates/" in norm_path:
        if status != "template":
            bad.append(f"`status: {status}` != `template` (Zonenregel docs/**/templates/**)")
        if kind_str is not None:
            bad.append(
                f"§14.2: `kind: {kind_str}` ist in der Zone docs/**/templates/** verboten "
                "(die Zone ist die Aussage)"
            )
    elif kind_str is not None and category == "module":
        bad.append(
            f"§14.3: `kind: {kind_str}` ist bei Modul verboten "
            "(der NNN-Praefix traegt die Aussage)"
        )

    # ADR-0000 §14.3: `kind:` ist Pflicht ausser bei Modul und in Zonen.
    if category in KIND_OF:
        expected = KIND_OF[category]
        if kind_str is None:
            bad.append(f"§14.3: Pflichtfeld `kind:` fehlt (Kategorie {category} -> `{expected}`)")
        elif kind_str != expected:
            bad.append(f"§14.3: `kind: {kind_str}` != `{expected}` (Kategorie {category})")

    if data.get("complexity") is not None:
        complexity = as_int(data["complexity"])
        if complexity is None or not 1 <= complexity <= 5:
            bad.append(f"`complexity: {data['complexity']}` nicht im Bereich 1..5")

    if re.match(r"^\d{3}-", stem):
        folder = data.get("folder")
        dirname = os.path.basename(os.path.dirname(path))
        if folder in (None, ""):
            missing.append("Pflichtfeld `folder:` fehlt")
        elif str(folder) != dirname:
            missing.append(f"`folder: {folder}` != Ordnername `{dirname}`")
        if data.get("status") in (None, ""):
            missing.append("Pflichtfeld `status:` fehlt")
        if data.get("complexity") in (None, ""):
            missing.append("Pflichtfeld `complexity:` fehlt")
        links = data.get("links")
        if not isinstance(links, dict) or not str(links.get("adr", "")).strip():
            missing.append("Pflichtfeld `links.adr:` fehlt")
        # ADR-00: upstream_* sind Extended Fields ("For complex modules"), nicht
        # Pflicht. Sie werden als Hinweis gemeldet, nicht als Verstoss.
        if not any(data.get(k) for k in UPSTREAM_KEYS):
            optional.append("ohne Upstream-Spur (optional laut ADR-00)")

    # ADR-0000 §14.4.4: `folder:` == Verzeichnis relativ zur Wurzel — fuer ALLE
    # Dateien. NNN-Module sind oben schon geprueft (dort genuegt der Ordnername,
    # weil sie immer auf Ebene 1 liegen); hier die uebrigen.
    if not re.match(r"^\d{3}-", stem):
        folder = data.get("folder")
        rel_dir = os.path.dirname(path) or "."
        if folder in (None, ""):
            bad.append("§14.4: Pflichtfeld `folder:` fehlt")
        elif str(folder).strip() != rel_dir:
            bad.append(f"§14.4: `folder: {folder}` != Verzeichnis `{rel_dir}`")

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
    return bad, missing, optional


def backlog_of(files):
    out = []
    for path in files:
        bad, missing, _ = check(path)
        if not bad and missing:
            out.append((path, missing))
    return out


def main():
    if "--write-baseline" in sys.argv:
        base = baseline()
        open(BASELINE_FILE, "w", encoding="utf-8").write(
            "# nixmeta-Ratsche (Baustelle 7): Dienst-Module mit noch fehlenden Pflichtfeldern.\n"
            "# Liste darf nur schrumpfen - konform gewordene Eintraege entfernen.\n"
            + "".join(f"{p}\n" for p, _ in backlog_of(nix_files()))
        )
        print(f"{BASELINE_FILE} geschrieben ({len(base)} alte -> {len(backlog_of(nix_files()))} aktuelle Eintraege)")
        return

    files = nix_files()
    base = baseline()
    violations, backlog, stale = [], [], []
    ohne_upstream = []
    for path in files:
        bad, missing, opt = check(path)
        if opt:
            ohne_upstream.append(path)
        if bad:
            violations.append((path, bad))
        elif missing and path in base:
            backlog.append((path, missing))
        elif missing:
            violations.append((path, missing))
        elif path in base:
            stale.append(path)
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
    if ohne_upstream:
        print(
            f"Hinweis: {len(ohne_upstream)} Dienst-Modul(e) ohne Upstream-Spur - "
            f"optional laut ADR-00 ('Extended Fields'), kein Verstoss."
        )
    if backlog:
        print(f"Ratsche-Backlog ({len(backlog)} Datei(en), Liste {BASELINE_FILE}):")
        for path, msgs in backlog:
            print(f"  {path}: {'; '.join(msgs)}")
    if stale:
        print(
            f"HINWEIS: {len(stale)} Baseline-Eintrag/Eintraege inzwischen konform -> aus "
            f"{BASELINE_FILE} entfernen: {', '.join(stale)}"
        )


main()
