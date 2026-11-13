#!/usr/bin/env python3
"""review-slice.py — baut den Anhang fuer EINE Review-Scheibe.

Warum: ein Fat Review ueber das ganze Repo liefert Zahlen, die beim Schreiben
schon veralten. Eine Scheibe ist eine Frage, 2-4 Dateien, ein Messblock.

Aufruf:
    python3 scripts/review-slice.py reviews/2026-11-13-thema

Erwartet in <verzeichnis>:
    files.txt   eine Pfadzeile je Quelle (relativ zum Repo oder absolut,
                '# Kommentar' erlaubt, Leerzeilen ignoriert)

Schreibt:
    merge.txt   Kopf (Repo, HEAD, Arbeitsbaum-Status, Datum) + je Datei
                Pfad/SHA256/Zeilen + Inhalt + abschliessende SHA256-Tabelle

Abbruch (Exit 2) wenn: files.txt fehlt/leer, ein Pfad ausserhalb des Repos
liegt, eine Datei fehlt oder nicht Text ist. Warnung (Exit 0) wenn > 4 Dateien.

Angehaengt wird NUR merge.txt plus prompt.md als Text. merge.txt ist
Build-Output und steht in .gitignore.
"""
from __future__ import annotations

import hashlib
import subprocess
import sys
from datetime import datetime
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MAX_FILES = 4

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
    print(f"review-slice: {msg}", file=sys.stderr)
    return 2


def main() -> int:
    if len(sys.argv) != 2:
        return fail("usage: review-slice.py <slice-dir>")

    slice_dir = Path(sys.argv[1])
    if not slice_dir.is_absolute():
        slice_dir = (Path.cwd() / slice_dir).resolve()
    files_txt = slice_dir / "files.txt"
    if not files_txt.is_file():
        return fail(f"{files_txt} fehlt")

    entries = []
    for raw in files_txt.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        p = Path(line)
        p = p if p.is_absolute() else (REPO / p)
        p = p.resolve()
        if REPO not in p.parents and p != REPO:
            return fail(f"ausserhalb des Repos: {line}")
        if not p.is_file():
            return fail(f"fehlt: {line}")
        data = p.read_bytes()
        if b"\0" in data[:4096]:
            return fail(f"keine Textdatei: {line}")
        entries.append((p, data))

    if not entries:
        return fail("files.txt enthaelt keinen Pfad")

    head = sh("git", "rev-parse", "--short", "HEAD") or "(kein git)"
    dirty = sh("git", "status", "--porcelain")
    dirty_n = len(dirty.splitlines()) if dirty else 0

    out = [
        "# Review-Scheibe",
        "",
        f"- Repo: `{REPO}`",
        f"- Basis: `HEAD {head}`",
        f"- Arbeitsbaum: {'**dirty** (' + str(dirty_n) + ' Pfade)' if dirty else 'clean'}",
        f"- Gebaut: {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        f"- Dateien: {len(entries)}",
        "",
        "> Der Anhang ist ein Schnappschuss des Arbeitsbaums, nicht des Commits.",
        "> Verbindlich ist die SHA256-Tabelle am Ende.",
        "",
    ]

    table = ["| Datei | SHA256 | Zeilen | Bytes |", "|---|---|---|---:|"]
    for path, data in entries:
        rel = path.relative_to(REPO)
        text = data.decode("utf-8", errors="replace")
        lines = text.count("\n") + (0 if text.endswith("\n") or not text else 1)
        digest = hashlib.sha256(data).hexdigest()
        lang = LANG.get(path.suffix, "")
        out += [
            f"## `{rel}`",
            "",
            f"SHA256 `{digest}` · {lines} Zeilen · {len(data)} Bytes",
            "",
            f"```{lang}",
            text.rstrip("\n"),
            "```",
            "",
        ]
        table.append(f"| `{rel}` | `{digest}` | {lines} | {len(data)} |")

    out += ["## SHA256-Tabelle (verbindlich)", ""] + table + [""]

    merge = slice_dir / "merge.txt"
    merge.write_text("\n".join(out), encoding="utf-8")

    print(f"review-slice: {merge} ({len(entries)} Dateien, {merge.stat().st_size} Bytes)")
    if len(entries) > MAX_FILES:
        print(
            f"review-slice: WARNUNG — {len(entries)} Dateien, die Methode sagt 2-4. "
            "Passt die Frage noch in einen Satz?",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
