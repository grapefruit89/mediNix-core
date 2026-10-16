#!/usr/bin/env python3
"""Repo-seitige Pruefung der Agenten-Skills (CI-tauglich, fail-closed).

Regeln (siehe AGENTS.md + docs/CONVENTIONS.md):
  - Ablage: docs/agents/<kategorie>/<skill>/SKILL.md mit YAML-Front-Matter.
  - Pflichtfelder: `name` (== Ordnername, eindeutig) und `description`
    (Trigger-Beschreibung; kurze Beschreibungen werden als Hinweis gelistet).
  - Kante Skills -> MCP: wer einen MCP-Server aufruft (`tools["<server>"]`,
    `tools.<server>.`, `mcp__<server>` - auch in references/), MUSS ihn im
    Front-Matter deklarieren: `mcp: [server, ...]`. Deklarierte Server muessen in
    scripts/mcp-servers.txt stehen (versionierte SSoT; die Live-Konfiguration
    ~/.config/opencode/opencode.jsonc ist maschinenlokal und fuer die CI
    unsichtbar -> lokal wird Drift als Hinweis gemeldet).

Kein PyYAML: das Front-Matter wird mit Regex gelesen (order-lint installiert keine
Abhaengigkeiten). Exit 1 = Regelverstoss.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SERVER_FILE = ROOT / "scripts/mcp-servers.txt"
LIVE_CONFIG = Path.home() / ".config/opencode/opencode.jsonc"

FRONT_MATTER = re.compile(r"^---\n(.*?)\n---\n", re.S)
NAME = re.compile(r'^name:\s*"?(.+?)"?\s*$', re.M)
DESC = re.compile(r"^description:\s*(.+?)(?=\n[a-z_]+:|\Z)", re.S | re.M)
MCP_INLINE = re.compile(r"^mcp:\s*\[(.*?)\]\s*$", re.M)
MCP_BLOCK = re.compile(r"^mcp:\s*$\n((?:[ \t]+-[ \t]*\S+[ \t]*\n?)+)", re.M)
MCP_ITEM = re.compile(r"^[ \t]+-[ \t]*(\S+)[ \t]*$", re.M)
SHORT_DESC = 80


def servers() -> dict[str, str]:
    """{server: Zweck} aus scripts/mcp-servers.txt (SSoT fuer die CI)."""
    if not SERVER_FILE.is_file():
        return {}
    out = {}
    for line in SERVER_FILE.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            name, _, why = line.partition("|")
            out[name.strip()] = why.strip()
    return out


def live_servers() -> set[str]:
    """Server-Namen aus der maschinenlokalen opencode.jsonc (nur lokal verfuegbar).

    Gezaehlt wird nur die ERSTE Ebene des `mcp`-Blocks: ein Schluessel, dessen Wert
    ein Objekt ist. Verschachtelte Schluessel (z. B. environment/headers in einem
    Server-Eintrag) sind keine Server.
    """
    if not LIVE_CONFIG.is_file():
        return set()
    text = re.sub(r"^\s*//.*$", "", LIVE_CONFIG.read_text(encoding="utf-8"), flags=re.M)
    position = text.find('"mcp"')
    if position < 0:
        return set()
    depth = 0
    found: set[str] = set()
    index = text.find("{", position)
    while index < len(text):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                break
        elif depth == 1 and char == '"':
            closing = text.find('"', index + 1)
            key = text[index + 1 : closing]
            if re.match(r"\s*:\s*\{", text[closing + 1 :]):
                found.add(key)
        index += 1
    return found


def mcp_declared(front_matter: str) -> list[str]:
    inline = MCP_INLINE.search(front_matter)
    if inline:
        return [x.strip() for x in inline.group(1).split(",") if x.strip()]
    block = MCP_BLOCK.search(front_matter)
    return [x.strip() for x in MCP_ITEM.findall(block.group(1))] if block else []


def mcp_used(body: str, known: dict[str, str]) -> list[str]:
    used = []
    for server in known:
        pattern = (
            rf'tools\["{re.escape(server)}"\]'
            rf"|tools\.{re.escape(server)}\b"
            rf"|mcp__{re.escape(server)}"
        )
        if re.search(pattern, body):
            used.append(server)
    return used


def main() -> int:
    errors: list[str] = []
    hints: list[str] = []
    names: list[str] = []
    known = servers()
    if not known:
        print(f"FEHLER: {SERVER_FILE.relative_to(ROOT)} fehlt oder ist leer")
        return 1
    live = live_servers()

    for skill_file in sorted((ROOT / "docs/agents").glob("*/*/SKILL.md")):
        rel = skill_file.relative_to(ROOT)
        expected = skill_file.parent.name
        text = skill_file.read_text(encoding="utf-8")
        match = FRONT_MATTER.match(text)
        if not match:
            errors.append(f"{rel}: YAML-Front-Matter (--- ... ---) fehlt")
            continue
        front_matter = match.group(1)

        found_name = NAME.search(front_matter)
        if not found_name:
            errors.append(f"{rel}: 'name' fehlt im Front-Matter")
            continue
        name = found_name.group(1).strip()
        names.append(name)
        if name != expected:
            errors.append(f"{rel}: name '{name}' != Ordnername '{expected}'")

        found_desc = DESC.search(front_matter)
        if not found_desc or not found_desc.group(1).strip():
            errors.append(f"{rel}: 'description' fehlt (Trigger-Beschreibung ist Pflicht)")
        else:
            desc = " ".join(found_desc.group(1).split())
            if len(desc) < SHORT_DESC:
                hints.append(f"{rel}: description nur {len(desc)} Zeichen -> {desc}")

        # Kante Skills -> MCP
        declared = mcp_declared(front_matter)
        body = text + "".join(
            ref.read_text(encoding="utf-8") for ref in sorted((skill_file.parent / "references").glob("*.md"))
        )
        used = mcp_used(body, known)
        for server in declared:
            if server not in known:
                errors.append(f"{rel}: mcp-Server '{server}' steht nicht in scripts/mcp-servers.txt")
            elif live and server not in live:
                hints.append(f"{rel}: '{server}' ist lokal nicht in opencode.jsonc konfiguriert")
        for server in used:
            if server not in declared:
                errors.append(
                    f"{rel}: ruft den MCP-Server '{server}' auf, deklariert ihn aber nicht"
                    f" -> Front-Matter `mcp: [{server}]`"
                )
        if declared and not used:
            hints.append(f"{rel}: deklariert {declared}, ruft aber keinen Server direkt auf (bewusst?)")

    duplicates = sorted({n for n in names if names.count(n) > 1})
    for dup in duplicates:
        errors.append(f"doppelter Skill-name: '{dup}' (Namen muessen eindeutig sein)")

    for extra in sorted(live - set(known)):
        hints.append(f"live konfigurierter Server '{extra}' fehlt in scripts/mcp-servers.txt")
    if hints:
        print("Hinweise (kein Fehler):")
        for hint in hints:
            print(f"  - {hint}")
    for error in errors:
        print(f"FEHLER: {error}")
    if errors:
        print(f"\n{len(errors)} Regelverstoss/Verstoesse, {len(names)} Skills geprueft.")
        return 1
    print(f"OK: {len(names)} Projekt-Skills formal in Ordnung ({len(hints)} Hinweise).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
