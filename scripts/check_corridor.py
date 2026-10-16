#!/usr/bin/env python3
"""Korridor-Muster als Check (Kette Korridor -> Checks, Auswahl 2026-10-16).

Geprueft wird nur, was mechanisch eindeutig ist; jede bewusste Ausnahme steht mit
Begruendung in scripts/corridor-allowlist.txt. Kommentare werden ausgeblendet,
damit Fehlermeldungen/Zitate nicht als Verstoss zaehlen.

Muster:
  - dynamicuser           : DynamicUser = true (AB-007 / locked_invariants)
  - media-primaergruppe   : Group = "media" in serviceConfig (AB-025 / ADR-0000 §5)
  - statedir-port-suffix  : stateDir mit Nummernsuffix (/var/lib/<name>-<nummer>)
  - uid-hartkodiert       : uid = <3-4 stellige Zahl> in einem Modul (Engine besitzt die Konten)

Exit 1 = Verstoss.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ALLOWLIST = ROOT / "scripts/corridor-allowlist.txt"
PATTERNS = {
    "dynamicuser": re.compile(r"DynamicUser\s*=\s*true"),
    "media-primaergruppe": re.compile(r"\bGroup\s*=\s*\"media\""),
    "statedir-port-suffix": re.compile(r"/var/lib/[a-zA-Z0-9_-]+-[0-9]{3,4}\b"),
    "uid-hartkodiert": re.compile(r"^\s*uid\s*=\s*[0-9]{3,4}\s*;", re.M),
}
# Nur Zeilen-Kommentare ausblenden. Bewusst NICHT String-Bloecke entfernen:
# die enthalten echten Code (Shell-Skripte in '' '') - und ein zu grober Filter
# hat zuvor genau die Treffer verschluckt (Ausnahmen wirkten "tot").
COMMENT = re.compile(r"(?m)^\s*#.*$")


def allowlist() -> set[tuple[str, str]]:
    if not ALLOWLIST.is_file():
        return set()
    out = set()
    for line in ALLOWLIST.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        parts = [p.strip() for p in line.split("|")]
        if len(parts) >= 2:
            out.add((parts[0], parts[1]))
    return out


def main() -> int:
    allowed = allowlist()
    errors, hints, used = [], [], set()
    for nix in sorted(ROOT.glob("**/*.nix")):
        if ".git" in nix.parts:
            continue
        rel = str(nix.relative_to(ROOT))
        code = COMMENT.sub("", nix.read_text(encoding="utf-8"))
        for name, pattern in PATTERNS.items():
            for match in pattern.finditer(code):
                line = code[: match.start()].count("\n") + 1
                if (name, rel) in allowed:
                    used.add((name, rel))
                    hints.append(f"{rel}:{line}: {name} (Ausnahme)")
                else:
                    errors.append(f"{rel}:{line}: {name} -> '{match.group(0).strip()}'")

    stale = allowed - used
    for hint in hints:
        print(f"AUSNAHME: {hint}")
    for error in errors:
        print(f"FEHLER: {error}")
    if stale:
        print(f"HINWEIS: {len(stale)} Allowlist-Eintrag ohne Treffer -> entfernen: "
              + ", ".join(f"{n}@{p}" for n, p in sorted(stale)))
    print(f"\n{len(errors)} Verstoss/Verstoesse, {len(hints)} Ausnahmen, {len(stale)} tote Eintraege.")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
