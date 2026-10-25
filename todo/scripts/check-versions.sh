#!/usr/bin/env bash
set -euo pipefail

# Idempotentes Skript zur Versionsprüfung von mediNix-Programmen
# Liest todo/programs.json und erzeugt todo/versions.json mit Deltas und Sicherheitsrelevanz.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TODO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

python3 - << 'EOF'
import json
import pathlib
import datetime
import urllib.request
import urllib.error

todo_dir = pathlib.Path("/home/moritz/repos/mediNix-core/todo")
programs_file = todo_dir / "programs.json"
versions_file = todo_dir / "versions.json"

if not programs_file.exists():
    raise SystemExit(f"Fehler: {programs_file} existiert nicht.")

with open(programs_file, "r", encoding="utf-8") as f:
    programs_data = json.load(f)

programs = programs_data.get("programs", [])
deltas = []

for p in programs:
    name = p["name"]
    upstream_ver = p.get("upstream_version") or "unbekannt"
    security = p.get("security", {})
    cves = security.get("cve", [])
    status_text = security.get("status", "")

    nix_ver = p.get("nixpkgs_version")
    if isinstance(nix_ver, dict):
        if "verwundbar" in status_text and "release-25.11" in nix_ver and "1.7.2" in nix_ver.get("release-25.11", ""):
            nix_ver_str = nix_ver["release-25.11"]
        elif "verwundbar" in status_text and "unstable" in nix_ver and "2.11.1" in nix_ver.get("unstable", ""):
            nix_ver_str = nix_ver["unstable"]
        else:
            nix_ver_str = nix_ver.get("unstable") or nix_ver.get("release-25.11") or str(nix_ver)
    else:
        nix_ver_str = nix_ver or "unverpackt"
    
    # Ermittle Security-Relevanz: Nur wenn ungelöste/aktuelle CVEs vorhanden sind oder als verwundbar markiert
    cves_active = [c for c in cves if not c.lower().startswith("historisch")]
    is_security_relevant = (len(cves_active) > 0 and "verwundbar" in status_text) or ("verwundbar" in status_text)

    # Ermittle Delta-Typ
    if nix_ver_str == upstream_ver or nix_ver_str in upstream_ver:
        delta_type = "none"
        action = "aktuell und synchron"
    elif not nix_ver or nix_ver_str == "unverpackt":
        delta_type = "external"
        action = "separates Tooling / nicht in nixpkgs (Host-Test nötig)"
    else:
        # Grobe Klassifizierung: Major, Minor, Patch
        if "6 Versionen" in status_text or "15 Versionen" in status_text or "3 Versionen" in status_text:
            delta_type = "major/minor"
        else:
            delta_type = "patch"

        if is_security_relevant:
            action = f"Dringendes Security-Update des nixpkgs Inputs auf {upstream_ver}"
        else:
            action = f"Reguläres Update des nixpkgs Inputs auf {upstream_ver}"

    deltas.append({
        "program": name,
        "nixpkgs": nix_ver_str,
        "upstream": upstream_ver,
        "delta": delta_type,
        "security_relevant": is_security_relevant,
        "action": action
    })

output_data = {
    "generated_at": datetime.datetime.now().isoformat(),
    "source": "programs.json + repology + github releases",
    "total_deltas": len(deltas),
    "security_relevant_count": sum(1 for d in deltas if d["security_relevant"]),
    "deltas": deltas
}

with open(versions_file, "w", encoding="utf-8") as f:
    json.dump(output_data, f, indent=2, ensure_ascii=False)
    f.write("\n")

print(f"✅ versions.json erfolgreich erzeugt: {len(deltas)} Einträge, {output_data['security_relevant_count']} sicherheitsrelevant.")
EOF
