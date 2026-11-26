#!/usr/bin/env python3
"""Kette Registry -> Manifest -> Modul (read-only, CI-tauglich).

Regel: jeder Registry-Dienst MIT Port muss als `medinix.manifest.<name>` deklariert
sein (sonst existiert er fuer Engine/Ingress/Docs nicht). Umgekehrt darf kein
Manifest-Key auf einen Dienst zeigen, den die Registry nicht kennt.
Ausnahmen stehen mit Begruendung in scripts/manifest-edge-allowlist.txt.

Ohne nix-Abhaengigkeit: die Registry wird textuell gelesen (wie gen_service_map.py).
Exit 1 = Verstoss.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "50-core/registry.nix"
ALLOWLIST = ROOT / "scripts/manifest-edge-allowlist.txt"
ENTRY = re.compile(r"^\s{2,}([a-z][a-z0-9-]*)\s*=\s*mk([A-Za-z]+)\b", re.M)
MANIFEST = re.compile(r"medinix\.manifest\.([a-zA-Z0-9_-]+)\s*=")
COMMENT = re.compile(r"(?m)^\s*#.*$")
ARR_FACTORY = ROOT / "53-acquisition/arr-module.nix"
ARR_FACTORY_MANIFEST = re.compile(r'medinix\.manifest\.(?:\$\{name\}|"\$\{name\}")\s*=')
ARR_FACTORY_CALL = re.compile(r"\./arr-module\.nix\b")
ARR_NAME = re.compile(r'^\s*name\s*=\s*"([a-zA-Z0-9_-]+)"\s*;', re.M)


def allowlist() -> dict[str, str]:
    if not ALLOWLIST.is_file():
        return {}
    out = {}
    for line in ALLOWLIST.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            name, _, why = line.partition("|")
            out[name.strip()] = why.strip()
    return out


def registry_with_port() -> dict[str, bool]:
    """{dienst: hat_port} aus dem services-Block der Registry."""
    text = REGISTRY.read_text(encoding="utf-8")
    start = text.index("services = {")
    block = text[start:]
    out = {}
    for match in ENTRY.finditer(block):
        name, kind = match.group(1), match.group(2)
        # mkNoPort*/mkNoPortWithUnit = kein Listener -> die Manifest-Pflicht gilt nicht
        out[name] = not kind.startswith("NoPort")
    return out


def main() -> int:
    allowed = allowlist()
    registry = registry_with_port()
    # Nur MODULE zaehlen: Pruefkonfigurationen in flake.nix deklarieren bewusst
    # synthetische Dienste (medinix.manifest.probe) - die sind kein Registry-Dienst.
    declared = set()
    candidates = list(ROOT.glob("*/[0-9][0-9][0-9]-*.nix")) + list((ROOT / "lib").glob("**/*.nix"))
    arr_factory_declares = (
        ARR_FACTORY.is_file()
        and ARR_FACTORY_MANIFEST.search(COMMENT.sub("", ARR_FACTORY.read_text(encoding="utf-8"))) is not None
    )
    for nix in sorted(candidates):
        text = COMMENT.sub("", nix.read_text(encoding="utf-8"))
        declared |= set(MANIFEST.findall(text))
        if arr_factory_declares:
            call = ARR_FACTORY_CALL.search(text)
            if call:
                name_match = ARR_NAME.search(text, pos=call.end())
                if name_match:
                    declared.add(name_match.group(1))

    errors, hints, stale = [], [], []
    for name, has_port in sorted(registry.items()):
        if not has_port or name in declared:
            continue
        if name in allowed:
            hints.append(f"{name}: kein Manifest-Eintrag (Ausnahme) - {allowed[name]}")
        else:
            errors.append(f"Registry-Dienst '{name}' hat einen Port, aber keinen medinix.manifest.{name}-Eintrag")
    for name in sorted(declared - set(registry)):
        errors.append(f"medinix.manifest.{name} zeigt auf keinen Registry-Dienst")
    for name in sorted(set(allowed) - {n for n, p in registry.items() if p and n not in declared}):
        stale.append(name)

    for hint in hints:
        print(f"AUSNAHME: {hint}")
    for error in errors:
        print(f"FEHLER: {error}")
    if stale:
        print(f"HINWEIS: {len(stale)} Allowlist-Eintrag ohne Wirkung -> entfernen: {', '.join(stale)}")
    print(f"\nRegistry: {sum(1 for v in registry.values() if v)} Dienste mit Port, {len(declared)} Manifest-Keys, "
          f"{len(errors)} Fehler, {len(hints)} Ausnahmen.")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
