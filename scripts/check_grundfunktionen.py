#!/usr/bin/env python3
"""Durchsetzung der NixOS-Grundfunktionen (bindend, ADR-0002).

Geprueft wird nur, was mechanisch eindeutig entscheidbar ist:
  1. keine aktivierte Container-Engine (ADR-5000): virtualisation.docker/podman.enable = true,
     virtualisation.oci-containers.*/virtualisation.containers.*
  2. keine unreinen Eval-Quellen: builtins.currentSystem, builtins.getEnv, <nixpkgs>
Alles Weitere (Deklarativitaet, Determinismus, fail-closed, systemd-native) ist im ADR
beschrieben und wird von der Pruef-Leiter getragen, nicht von Textmustern.

String-Literale werden vor der Pruefung entfernt: eine verbietende Assertion DARF das
verbotene Muster zitieren ("virtualisation.docker.enable = true ist verboten") - das ist
die Durchsetzung dieser Regel und kein Verstoss.

Exit 1 = Verstoss.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

RULES = [
    (
        "Container-Engine aktiviert (ADR-0002/ADR-5000: systemd-native, keine Container)",
        re.compile(
            r"virtualisation\.(?:docker|podman)\.enable\s*=\s*(?:lib\.mkForce\s+)?true"
            r"|virtualisation\.(?:oci-containers|containers)\s*="
        ),
    ),
    (
        "unreine Eval-Quelle (ADR-0002: deterministisch)",
        re.compile(r"builtins\.currentSystem|builtins\.getEnv\b|=\s*<nixpkgs>"),
    ),
]

STRING_BLOCK = re.compile(r"''.*?''", re.S)
STRING_QUOTED = re.compile(r'"(?:[^"\\]|\\.)*"')


def code_only(text: str) -> str:
    """String-Literale (auch mehrzeilige) entfernen, Zeilenzahl erhalten."""
    text = STRING_BLOCK.sub(lambda m: "\n" * m.group(0).count("\n"), text)
    return STRING_QUOTED.sub('""', text)


def main() -> int:
    hits: list[str] = []
    for nix in sorted(ROOT.glob("**/*.nix")):
        if ".git" in nix.parts:
            continue
        code = code_only(nix.read_text(encoding="utf-8"))
        for reason, pattern in RULES:
            for match in pattern.finditer(code):
                line = code[: match.start()].count("\n") + 1
                hits.append(f"{nix.relative_to(ROOT)}:{line}: {reason} -> '{match.group(0).strip()}'")

    for hit in hits:
        print(f"FEHLER: {hit}")
    if hits:
        print(f"\n{len(hits)} Verstoss/Verstoesse gegen ADR-0002.")
        return 1
    print("OK: keine aktivierte Container-Engine, keine unreinen Eval-Quellen in *.nix (ADR-0002).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
