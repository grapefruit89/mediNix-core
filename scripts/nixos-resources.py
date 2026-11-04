#!/usr/bin/env python3
"""Rendert docs/NIXOS-RESOURCES.md aus docs/NIXOS-RESOURCES.json.

Die JSON ist die Quelle; die Markdown-Datei ist eine generierte Ansicht fuer
Menschen. Beide koennen nicht auseinanderdriften, weil die MD nur aus der JSON
entsteht.

Aufruf:
    python3 scripts/nixos-resources.py --write   # MD neu schreiben
    python3 scripts/nixos-resources.py --check   # Exit 1, wenn MD != JSON-Render

Exit-Codes: 0 = ok, 1 = Drift oder Fehler, 2 = Aufruffehler.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JSON_PATH = ROOT / "docs" / "NIXOS-RESOURCES.json"
MD_PATH = ROOT / "docs" / "NIXOS-RESOURCES.md"

# Reihenfolge und Ueberschriften der Kategorien (bewusst hier, nicht in der JSON:
# die JSON haelt Daten, keine Darstellungsreihenfolge).
CATEGORY_ORDER = [
    ("standard-docs", "Standard-Dokumentation"),
    ("patterns", "Patterns & Flake-Referenzen"),
    ("server-ops", "Server & Betrieb"),
    ("security", "Sicherheit"),
    ("tools", "Werkzeuge"),
    ("community", "Community"),
    ("banned-reference", "Bewusst nicht verwendet (BANNED)"),
    ("nixos-org-infra", "NixOS-Org-Infrastruktur (nicht projektrelevant)"),
]

RELEVANCE_MARK = {"high": "hoch", "medium": "mittel", "low": "niedrig"}


def render(data: dict) -> str:
    entries = data["entries"]
    cats = data["categories"]
    out: list[str] = []

    out.append("# NixOS-Ressourcen (kuratiert, maschinenlesbar)")
    out.append("")
    out.append("> **Generiert.** Diese Datei wird aus `docs/NIXOS-RESOURCES.json` erzeugt —")
    out.append("> **nicht per Hand editieren**. Änderungen gehören in die JSON.")
    out.append(">")
    out.append("> ```")
    out.append("> python3 scripts/nixos-resources.py --write   # neu schreiben")
    out.append("> python3 scripts/nixos-resources.py --check   # Drift prüfen (CI)")
    out.append("> ```")
    out.append("")
    out.append(
        f"Stand: {data['updated']} · **{len(entries)} Einträge** in "
        f"**{len(cats)} Kategorien** · Schema-Version {data['version']}"
    )
    out.append("")
    out.append(data["purpose"])
    out.append("")
    if data.get("provenance"):
        out.append(data["provenance"])
        out.append("")
    out.append("---")
    out.append("")

    # --- Lokale Abfrage: bewusst VOR der Liste, weil sie der schnellere Weg ist.
    out.append("## Lokale Abfrage (bevorzugt)")
    out.append("")
    out.append("Die externen Quellen sind der **Fallback**. Zuerst lokal messen:")
    out.append("")
    out.append("```bash")
    out.append("# Repo-Root: Optionen der Prüfkonfiguration")
    out.append("nix eval --json .#nixosConfigurations.check.options.medinix.<pfad>")
    out.append("")
    out.append("# Host: einzelne Option")
    out.append("nixos-option medinix.<pfad>")
    out.append("")
    out.append("# Paket suchen")
    out.append("nix search nixpkgs <term> --json")
    out.append("```")
    out.append("")
    out.append(
        "Die `search.nixos.org`-API ist **instabil** (Elasticsearch-Backend, kein "
        "öffentliches API-Versprechen). Nur nutzen, wenn lokal nichts geht."
    )
    out.append("")
    out.append("## jq-Beispiele")
    out.append("")
    out.append("```bash")
    out.append("# nur die wirklich wichtigen Quellen")
    out.append("jq '.entries[] | select(.relevance==\"high\")' docs/NIXOS-RESOURCES.json")
    out.append("")
    out.append("# was der Agent direkt parsen kann")
    out.append("jq '.entries[] | select(.machine_readable==true)' docs/NIXOS-RESOURCES.json")
    out.append("")
    out.append("# was mediNix bewusst nicht nutzt — mit Begründung")
    out.append("jq '.entries[] | select(.banned_in_medinix==true)' docs/NIXOS-RESOURCES.json")
    out.append("```")
    out.append("")
    out.append("---")
    out.append("")

    # --- Kategorien
    for key, title in CATEGORY_ORDER:
        items = [e for e in entries if e["category"] == key]
        if not items:
            continue
        out.append(f"## {title}")
        out.append("")
        if key in cats:
            out.append(f"*{cats[key]}*")
            out.append("")
        for e in items:
            marks = [RELEVANCE_MARK.get(e["relevance"], e["relevance"])]
            if e.get("machine_readable"):
                marks.append("maschinenlesbar")
            if e.get("banned_in_medinix"):
                marks.append("**BANNED**")
            out.append(f"- **[{e['title']}]({e['url']})** — {' · '.join(marks)} · {e['license']}")
            out.append(f"  {e['why']}")
            if e.get("banned_reason"):
                out.append(f"  ⛔ {e['banned_reason']}")
            if e.get("api_url"):
                out.append(f"  API: `{e.get('api_method', 'GET')} {e['api_url']}`")
            if e.get("api_caveat"):
                out.append(f"  ⚠️ {e['api_caveat']}")
            if e.get("api_notes"):
                out.append(f"  ℹ️ {e['api_notes']}")
            if e.get("repo_url"):
                out.append(f"  Repo: {e['repo_url']}")
            if e.get("use_cases"):
                out.append(f"  Use-Cases: {', '.join(f'`{u}`' for u in e['use_cases'])}")
        out.append("")

    out.append("---")
    out.append("")
    out.append("## Nicht in dieser Liste")
    out.append("")
    out.append(
        "Projekt-spezifische Upstream-Quellen (die tatsächlich importierten Flake-Inputs "
        "und die Herkunft einzelner Entscheidungen) stehen in "
        "[`UPSTREAM-SOURCES.md`](UPSTREAM-SOURCES.md)."
    )
    out.append("")
    return "\n".join(out)


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[1] not in ("--write", "--check"):
        print("Aufruf: python3 scripts/nixos-resources.py --write|--check", file=sys.stderr)
        return 2

    try:
        data = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"FEHLER: {JSON_PATH} nicht lesbar/valide: {exc}", file=sys.stderr)
        return 1

    # Schema-Minimum pruefen, damit ein Tippfehler nicht still durchgeht.
    missing = [k for k in ("version", "updated", "purpose", "categories", "entries") if k not in data]
    if missing:
        print(f"FEHLER: Pflichtfelder fehlen in der JSON: {missing}", file=sys.stderr)
        return 1
    ids = [e.get("id") for e in data["entries"]]
    if len(ids) != len(set(ids)):
        dupes = sorted({i for i in ids if ids.count(i) > 1})
        print(f"FEHLER: doppelte ids in der JSON: {dupes}", file=sys.stderr)
        return 1
    unknown = sorted({e["category"] for e in data["entries"]} - set(data["categories"]))
    if unknown:
        print(f"FEHLER: Kategorien benutzt, aber nicht deklariert: {unknown}", file=sys.stderr)
        return 1

    rendered = render(data)

    if argv[1] == "--write":
        MD_PATH.write_text(rendered, encoding="utf-8")
        print(f"geschrieben: {MD_PATH.relative_to(ROOT)} ({len(rendered.splitlines())} Zeilen)")
        return 0

    # --check
    try:
        current = MD_PATH.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"FEHLER: {MD_PATH} nicht lesbar: {exc}", file=sys.stderr)
        return 1
    if current != rendered:
        print(
            "FEHLER: docs/NIXOS-RESOURCES.md ist nicht synchron mit der JSON.\n"
            "Beheben mit:  python3 scripts/nixos-resources.py --write",
            file=sys.stderr,
        )
        return 1
    print(
        f"OK: docs/NIXOS-RESOURCES.md ist synchron "
        f"({len(data['entries'])} Einträge, {len(data['categories'])} Kategorien)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
