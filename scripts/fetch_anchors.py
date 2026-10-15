#!/usr/bin/env python3
"""Lagert die ENGLISCHEN Semantic-Anchor-Definitionen ein, die docs/TERMINOLOGY.md referenziert.

Quelle: https://llm-coding.github.io/Semantic-Anchors/anchors/<id>.txt
Lizenz: Apache-2.0 (LLM-Coding). Der Originaltext bleibt UNVERAENDERT; jeder Datei
wird nur ein Kopf (Quelle/Datum/Lizenz) vorangestellt -> als Aenderung gekennzeichnet
(Apache-2.0 §4b). Attribution bleibt im Text enthalten.

IDs kommen aus den /anchor/<id>-Links in docs/TERMINOLOGY.md.

Aufruf:
  python3 scripts/fetch_anchors.py            # holt/aktualisiert (braucht Netz)
  python3 scripts/fetch_anchors.py --check    # offline: jede ID muss lokal liegen
"""

from __future__ import annotations

import datetime as dt
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOC = ROOT / "docs" / "TERMINOLOGY.md"
OUT = ROOT / "docs" / "anchors"
UP = "https://llm-coding.github.io/Semantic-Anchors"
LICENSE_URL = "https://raw.githubusercontent.com/LLM-Coding/Semantic-Anchors/main/LICENSE"
DATE = dt.date.today().isoformat()


def ids() -> list[str]:
    text = DOC.read_text(encoding="utf-8")
    # relative Links (anchors/<id>.md) UND Upstream-Links (/anchor/<id>) akzeptieren
    found = set(re.findall(r"anchors/([a-z0-9-]+)\.md", text))
    found |= set(re.findall(r"/anchor/([a-z0-9-]+)", text))
    return sorted(found)


def fetch(url: str) -> str:
    with urllib.request.urlopen(url, timeout=30) as r:
        return r.read().decode("utf-8")


def header(aid: str) -> str:
    return (
        f"<!-- Vendored from {UP}/anchor/{aid} (English original, anchors/{aid}.txt)\n"
        f"     Fetched: {DATE} . License: Apache-2.0 (see LICENSE-APACHE-2.0.txt) . (c) LLM-Coding\n"
        f"     Modification: none to the text below; only this wrapper header was added. -->\n\n"
    )


def readme(ids_: list[str]) -> str:
    lines = [
        "# Semantic Anchors (eingelagert)",
        "",
        "Englische **Original-Definitionen** der Anker, die `docs/TERMINOLOGY.md` benutzt.",
        f"- Quelle: <{UP}/> (Index: <{UP}/llms-index.txt)",
        f"- Abruf: **{DATE}** . Lizenz: **Apache-2.0** (siehe `LICENSE-APACHE-2.0.txt`), (c) LLM-Coding",
        "- Texte **unverändert**; je Datei nur ein Kopf (Quelle/Datum/Lizenz).",
        "- Erneuern: `python3 scripts/fetch_anchors.py` (braucht Netz). Prüfen: `--check`.",
        "",
        f"## Eingelagert ({len(ids_)})",
        "",
    ]
    lines += [f"- `{a}` — <{UP}/anchor/{a}>" for a in ids_]
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    want = ids()
    if not want:
        raise SystemExit("keine Anker in docs/TERMINOLOGY.md gefunden")
    if "--check" in sys.argv:
        missing = [a for a in want if not (OUT / f"{a}.md").is_file()]
        if missing:
            print("fehlende Anker-Snapshots:", ", ".join(missing))
            return 1
        print(f"{len(want)} Anker-Snapshots vorhanden.")
        return 0
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "LICENSE-APACHE-2.0.txt").write_text(fetch(LICENSE_URL), encoding="utf-8")
    for a in want:
        try:
            body = fetch(f"{UP}/anchors/{a}.txt")
        except Exception as exc:  # noqa: BLE001
            raise SystemExit(f"Fetch fehlgeschlagen für {a}: {exc}") from exc
        (OUT / f"{a}.md").write_text(header(a) + body, encoding="utf-8")
        print("  ok", a)
    (OUT / "README.md").write_text(readme(want), encoding="utf-8")
    print(f"{len(want)} Anker eingelagert -> docs/anchors/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
