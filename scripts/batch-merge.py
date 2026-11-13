#!/usr/bin/env python3
"""batch-merge.py — merged alle Symlinks eines Batches in EINE Datei.

Struktur (eine Batch = ein Ordner):

    Batches/B01 - Thema/
        prompt.md            der Prompt (regulaere Datei, wird NICHT gemerged)
        merged.md            Build-Output (wird NICHT gemerged, ist ignoriert)
        registry.nix ->      Symlink auf die Quelle im Repo
        ...

Aufruf:
    python3 scripts/batch-merge.py "Batches/B01 - Thema"

Verhalten:
  - liest ALLE Symlinks im Ordner, loest sie auf und prueft, dass das Ziel
    innerhalb dieses Repos liegt (kein Zugriff auf $HOME, /etc, ...)
  - sortiert nach Zielpfad (deterministisch, damit zwei Laeufe gleich aussehen)
  - schreibt merged.md: Kopf (Batch, Repo, HEAD, Arbeitsbaum, Datum, Anzahl),
    je Datei Pfad + SHA256 + Zeilen + Inhalt, am Ende die SHA256-Tabelle
  - bricht mit Exit 2 ab bei: kein Symlink, kaputtem Symlink, Ziel ausserhalb
    des Repos, Binaerdatei, fehlender Datei
  - warnt (Exit 0) bei mehr als 6 Dateien — dann ist der Schnitt vermutlich zu grob

Die SHA256-Tabelle ist verbindlich: der Anhang ist ein Schnappschuss des
Arbeitsbaums, nicht des Commits.
"""
from __future__ import annotations

import hashlib
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
WARN_FILES = 6
SKIP_NAMES = {"prompt.md", "merged.md", "README.md"}

LANG = {
    ".nix": "nix",
    ".md": "markdown",
    ".py": "python",
    ".sh": "bash",
    ".json": "json",
    ".yml": "yaml",
    ".yaml": "yaml",
    ".ps1": "powershell",
    ".toml": "toml",
}


def sh(*cmd: str) -> str:
    try:
        return subprocess.check_output(cmd, cwd=REPO, text=True, timeout=20).strip()
    except Exception:
        return ""


def fail(msg: str) -> int:
    print(f"batch-merge: {msg}", file=sys.stderr)
    return 2


def main() -> int:
    if len(sys.argv) != 2:
        return fail('usage: batch-merge.py "Batches/B01 - Thema"')

    batch = Path(sys.argv[1])
    if not batch.is_absolute():
        batch = (Path.cwd() / batch).resolve()
    if not batch.is_dir():
        return fail(f"kein Ordner: {batch}")

    links = sorted(p for p in batch.iterdir() if p.is_symlink())
    if not links:
        return fail(f"keine Symlinks in {batch} — erst verlinken, dann mergen")

    entries = []
    for link in links:
        if link.name in SKIP_NAMES:
            continue
        target = link.resolve()
        if not target.is_file():
            return fail(f"kaputter Symlink: {link.name} -> {os.readlink(link)}")
        if REPO not in target.parents:
            return fail(f"Ziel ausserhalb des Repos: {link.name} -> {target}")
        data = target.read_bytes()
        if b"\0" in data[:4096]:
            return fail(f"keine Textdatei: {link.name} -> {target}")
        entries.append((link.name, target, data))

    entries.sort(key=lambda e: str(e[1].relative_to(REPO)))

    head = sh("git", "rev-parse", "--short", "HEAD") or "(kein git)"
    dirty = sh("git", "status", "--porcelain")
    dirty_n = len(dirty.splitlines()) if dirty else 0

    out = [
        f"# Batch: {batch.name}",
        "",
        f"- Repo: `{REPO}`",
        f"- Basis: `HEAD {head}`",
        f"- Arbeitsbaum: {'**dirty** (' + str(dirty_n) + ' Pfade)' if dirty else 'clean'}",
        f"- Gebaut: {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        f"- Dateien: {len(entries)}",
        "",
        "> Schnappschuss des Arbeitsbaums, nicht des Commits. Verbindlich ist die",
        "> SHA256-Tabelle am Ende.",
        "",
    ]

    table = ["| Datei | SHA256 | Zeilen | Bytes |", "|---|---|---|---:|"]
    for name, target, data in entries:
        rel = target.relative_to(REPO)
        text = data.decode("utf-8", errors="replace")
        lines = text.count("\n") + (0 if text.endswith("\n") or not text else 1)
        digest = hashlib.sha256(data).hexdigest()
        lang = LANG.get(target.suffix, "")
        out += [
            f"## `{rel}`",
            "",
            f"Symlink `{name}` · SHA256 `{digest}` · {lines} Zeilen · {len(data)} Bytes",
            "",
            f"```{lang}",
            text.rstrip("\n"),
            "```",
            "",
        ]
        table.append(f"| `{rel}` | `{digest}` | {lines} | {len(data)} |")

    out += ["## SHA256-Tabelle (verbindlich)", ""] + table + [""]

    merged = batch / "merged.md"
    merged.write_text("\n".join(out), encoding="utf-8")
    print(f"batch-merge: {merged} ({len(entries)} Dateien, {merged.stat().st_size} Bytes)")

    if len(entries) > WARN_FILES:
        print(
            f"batch-merge: WARNUNG — {len(entries)} Dateien. Der Schnitt ist damit "
            "vermutlich zu grob; passt die Frage noch in einen Satz?",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
