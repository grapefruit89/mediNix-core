#!/usr/bin/env python3
"""
Aggregiert plan.json, decisions.json, antipatterns.md und concerns.json
aus allen 29 Blöcken (Chat 1 Blöcke 01-14 + neue Blöcke 15-29).
"""

from pathlib import Path
import json
import re
from datetime import datetime, timezone

BASE_DIR = Path("/home/moritz/repos/mediNix-core/todo")
CHAT1_BLOCKS_DIR = BASE_DIR / "done/2026-10-25_1bad3cc7_arch-vs-nixos/blocks"
NEW_BLOCKS_DIR = BASE_DIR / "blocks"
CHAT1_DONE_DIR = BASE_DIR / "done/2026-10-25_1bad3cc7_arch-vs-nixos"

chat1_blocks = sorted(CHAT1_BLOCKS_DIR.glob("*.json"))
new_blocks = sorted(NEW_BLOCKS_DIR.glob("*.json"))
all_block_files = chat1_blocks + new_blocks

assert len(all_block_files) == 29, f"Expected 29 blocks, got {len(all_block_files)}"

loaded_blocks = []
for p in all_block_files:
    with open(p, "r", encoding="utf-8") as f:
        data = json.load(f)
        b_id = data.get("block_id", p.stem)
        loaded_blocks.append((b_id, data))

# ==============================================================================
# 1. plan.json
# ==============================================================================
DONE_COMMITS = {
    "N-29-01": "6d82119",
    "N-29-02": "6d82119",
    "N-22-01": "90553ad",
    "N-23-01": "f3153df",
    "N-23-02": "f3153df",
    "N-24-01": "21ca67f"
}

todos = []
prio_all = {"high": 0, "medium": 0, "low": 0}
prio_open = {"high": 0, "medium": 0, "low": 0}
prio_done = {"high": 0, "medium": 0, "low": 0}

for b_id, b_data in loaded_blocks:
    for ns in b_data.get("next_steps", []):
        nid = ns["id"]
        prio = ns.get("priority", "medium")
        prio_all[prio] = prio_all.get(prio, 0) + 1
        
        is_done = nid in DONE_COMMITS
        item = {
            "id": nid,
            "block_id": b_id,
            "action": ns["action"],
            "priority": prio,
            "depends_on": ns.get("depends_on", []),
            "status": "done" if is_done else "open"
        }
        if is_done:
            item["commit_hash"] = DONE_COMMITS[nid]
            prio_done[prio] = prio_done.get(prio, 0) + 1
        else:
            prio_open[prio] = prio_open.get(prio, 0) + 1
            
        todos.append(item)

plan_doc = {
    "meta": {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "total_blocks": len(loaded_blocks),
        "blocks_processed": [b[0] for b in loaded_blocks],
        "total_next_steps": len(todos),
        "open_count": sum(prio_open.values()),
        "done_count": sum(prio_done.values()),
        "priority_summary": {
            "open": prio_open,
            "done": prio_done,
            "total": prio_all
        }
    },
    "todos": todos
}

with open(BASE_DIR / "plan.json", "w", encoding="utf-8") as f:
    json.dump(plan_doc, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"✅ Generated {BASE_DIR / 'plan.json'} with {len(todos)} todos ({sum(prio_open.values())} open, {sum(prio_done.values())} done)")

# ==============================================================================
# 2. decisions.json
# ==============================================================================
BLOCK_TO_THEME = {
    "17-manifest-service-contract": "manifest",
    "18-flake-architecture-ci": "flake",
    "19-community-flakes-benchmark": "flake",
    "27-caddy-plugin-replacements": "caddy-plugins",
    "02-caddy-catch-all": "caddy-ingress",
    "14-config-review-51-ingress": "caddy-ingress",
    "04-credentials-systemd-creds": "secrets",
    "07-pqc-hndl": "secrets",
    "20-machine-readable-systemd-nixos": "systemd",
    "23-systemd-hardening-syntax-bugs": "systemd",
    "15-nixmap-ast-audit": "nixmap",
    "16-agent-error-taxonomy": "agent-errors",
    "21-observability-automation": "observability",
    "03-crowdsec-scan-ban": "security-firewall",
    "08-firewall-nftables": "security-firewall",
    "05-mdns-vs-blocky": "networking-dns",
    "06-dns-wan-ip-provider": "networking-dns",
    "22-cloudflare-dns-bash-bug": "networking-dns",
    "01-arch-vs-nixos": "architecture-framework",
    "11-51-tree-struktur": "architecture-framework",
    "12-adr-dezimalrahmen": "architecture-framework",
    "13-lib-vs-50-core": "architecture-framework",
    "24-mkforce-500-host-baseline": "architecture-framework",
    "25-docs-trias": "architecture-framework",
    "26-guardrail-591": "architecture-framework",
    "09-kernel-hardening": "hardware-kernel",
    "10-power-management": "hardware-kernel",
}

decisions_by_theme = {}
decisions_items = []
status_counts = {"decided": 0, "rejected": 0}

for b_id, b_data in loaded_blocks:
    th = BLOCK_TO_THEME.get(b_id, "other")
    if th not in decisions_by_theme:
        decisions_by_theme[th] = []
    
    for dec in b_data.get("decisions", []):
        st = dec.get("status")
        if st in ("decided", "rejected"):
            status_counts[st] += 1
            item = {
                "id": dec["id"],
                "block_id": b_id,
                "theme": th,
                "statement": dec["statement"],
                "status": st,
                "verdict": dec.get("verdict", "neutral"),
                "rationale": dec.get("rationale", "")
            }
            decisions_by_theme[th].append(item)
            decisions_items.append(item)

decisions_doc = {
    "meta": {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "total_blocks": len(loaded_blocks),
        "total_decisions": len(decisions_items),
        "status_counts": status_counts,
        "theme_counts": {th: len(items) for th, items in decisions_by_theme.items()}
    },
    "by_theme": decisions_by_theme,
    "items": decisions_items
}

with open(BASE_DIR / "decisions.json", "w", encoding="utf-8") as f:
    json.dump(decisions_doc, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"✅ Generated {BASE_DIR / 'decisions.json'} with {len(decisions_items)} decisions ({status_counts['decided']} decided, {status_counts['rejected']} rejected)")

# ==============================================================================
# 3. antipatterns.md
# ==============================================================================
# Load A-01 to A-30 from done/antipatterns.md
chat1_antipatterns_text = (CHAT1_DONE_DIR / "antipatterns.md").read_text(encoding="utf-8")

# Extract table lines
table_entries = []
# parse table: | `A-01` | Arch Linux als Basis ... | Warum ... | `01-arch-vs-nixos` |
for line in chat1_antipatterns_text.splitlines():
    m = re.match(r"\|\s*`(A-\d+)`\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*`?(.*?)`?\s*\|", line)
    if m:
        aid, title, reason, source = m.groups()
        source = source.replace("`", "")
        table_entries.append({
            "id": aid,
            "title": title,
            "reason": reason,
            "source": source
        })

# Collect new antipatterns from blocks 15-27
new_entries = [
    {
        "id": "A-32",
        "title": "Nixmap als vollständigen Ersatz für NixOS-Modulhandbuch und Flake-Dokumentation betrachten",
        "reason": "Nixmap deckt primär elementare Sprachregeln und AST-Muster ab; Modulspezifika wie mkOption-Typen, submodule-Merge und Flake-Outputs müssen separat geprüft werden.",
        "source": "15-nixmap-ast-audit"
    },
    {
        "id": "A-33",
        "title": "Schwere Nix-Builds und QEMU-VM-Tests interaktiv im Vordergrund mit hohem Timeout blockierend ausführen",
        "reason": "Blockiert Agenten-Sessions für 10–20 Minuten pro Lauf und führt zu Timeout-Abbrüchen; Hintergrund-Tasks oder no-build Checks sind vorzuziehen.",
        "source": "16-agent-error-taxonomy"
    },
    {
        "id": "A-34",
        "title": "Vollständigen QEMU-VM-Boot bei jedem interaktiven Edit-Schritt erzwingen",
        "reason": "Blockiert die Agenten-Ausführung für bis zu 20 Minuten und verbraucht massiv CPU/Token ohne Mehrwert bei reinen Doku- oder Optionsänderungen.",
        "source": "18-flake-architecture-ci"
    },
    {
        "id": "A-35",
        "title": "Nixarr-Muster mit sops-nix und Network Namespaces für mediNix übernehmen",
        "reason": "Verletzt die Kerninvariante Zero-Container und Banned Technologies (sops-nix verboten, Namespaces stören UDS).",
        "source": "19-community-flakes-benchmark"
    },
    {
        "id": "A-36",
        "title": "Agenten-Wissen rein aus dem Modellgedächtnis ohne statische Optionen-Validierung nutzen",
        "reason": "Führt bei sich schnell ändernden nixpkgs-Optionen zwangsläufig zu Halluzinationen und Fehlbuilds.",
        "source": "20-machine-readable-systemd-nixos"
    },
    {
        "id": "A-37",
        "title": "Gatus-Monitoring-Endpunkte manuell und hardcodiert in 582-gatus.nix pflegen",
        "reason": "Führt zu sofortiger Dokumentations- und Monitoring-Drift, wenn Dienste umbenannt oder deaktiviert werden.",
        "source": "21-observability-automation"
    },
    {
        "id": "A-38",
        "title": "509-guardrails.nix als zusätzliche Assertion-Datei anlegen",
        "reason": "Redundant zu 591-cross-domain.nix; fragmentiert die Guardrail-Logik.",
        "source": "26-guardrail-591"
    },
    {
        "id": "A-39",
        "title": "caddy-tarpit für Web-Scans einsetzen ('Wer scannt, fliegt raus')",
        "reason": "Tarpit bindet Kernel-Sockets und Webserver-Ressourcen für bösartige Scans; Angreifer werden stattdessen sofort via CrowdSec + nftables kernel-nah auf Blocklist gesetzt.",
        "source": "27-caddy-plugin-replacements"
    },
    {
        "id": "A-40",
        "title": "caddy-defender für verzögerte Bot-Responses nutzen",
        "reason": "Verzögerte Responses binden Ressourcen. Klare 404-Codes triggern CrowdSec schneller und deterministischer.",
        "source": "27-caddy-plugin-replacements"
    },
    {
        "id": "A-41",
        "title": "cerberus Caddy-Plugin zur Ratenbegrenzung kompilieren",
        "reason": "Caddy-Plugin cerberus ist veraltet/unmaintained; nftables und CrowdSec auf Kernel-Ebene bieten robusteren Schutz ohne Caddy-Custom-Build-Risiken.",
        "source": "27-caddy-plugin-replacements"
    }
]

all_antipatterns = table_entries + new_entries

# Build markdown file
md_lines = [
    "# Anti-Pattern-Register (mediNix-core)",
    "",
    "> Aggregiert alle verworfenen Ideen und Anti-Patterns aus allen 27 Analyse-Blöcken.",
    "> Dient als verbindlicher Warnkatalog für Entwickler und Coding-Agenten, um bekannte Sackgassen zu vermeiden.",
    "",
    "| ID | Verworfenes Muster / Idee | Warum verworfen (Begründung) | Quelle (Block) |",
    "| :--- | :--- | :--- | :--- |"
]

for ap in all_antipatterns:
    md_lines.append(f"| `{ap['id']}` | {ap['title']} | {ap['reason']} | `{ap['source']}` |")

md_lines.append("")
md_lines.append("## Detaillierte Begründungen")
md_lines.append("")

for ap in all_antipatterns:
    md_lines.append(f"## {ap['id']}: {ap['title']}")
    md_lines.append(f"- **Warum verworfen:** {ap['reason']}")
    md_lines.append(f"- **Quelle:** `{ap['source']}`")
    md_lines.append("")

(BASE_DIR / "antipatterns.md").write_text("\n".join(md_lines) + "\n", encoding="utf-8")
print(f"✅ Generated {BASE_DIR / 'antipatterns.md'} with {len(all_antipatterns)} anti-patterns (31 Chat 1 + 10 neu)")

# ==============================================================================
# 4. concerns.json
# ==============================================================================
# Load existing concerns from done/concerns.json
with open(CHAT1_DONE_DIR / "concerns.json", "r", encoding="utf-8") as f:
    chat1_concerns_doc = json.load(f)

new_concerns_map = {
    "manifest": {
        "description": "SSoT Service Contract Schema (50-core/manifest.nix)",
        "source": "17-manifest-service-contract",
        "fields": [
            "id",
            "decimal",
            "access_group",
            "health_path",
            "backup_paths",
            "vpn_routed",
            "sqlite_tuning",
            "hardening_profile"
        ],
        "status": "proposed",
        "goal": "Single Source of Truth für Modul-Metadaten; deklarative Generierung von Gatus-, Restic- und Homepage-Konfigurationen"
    },
    "flake-ci": {
        "description": "Flake-Architektur & 3-Stufen-CI (Fast-Eval PR-Gate, Unit-Tests, Full-Check)",
        "source": "18-flake-architecture-ci",
        "components": [
            "fast-eval gate (<3s)",
            "nix-unit fuer 50-core/",
            "flake check --no-build",
            "periodischer vollständiger VM/QEMU-Testlauf"
        ],
        "status": "decided"
    },
    "community-benchmark": {
        "description": "Best-Practices-Benchmark gegen Community-Flakes (nixarr, Misterio77, nix-darwin)",
        "source": "19-community-flakes-benchmark",
        "patterns": [
            "follows-Minimierung",
            "Pinning von System-Inputs",
            "Keine Container/Namespaces für UDS",
            "Minimaler Overlay-Scope"
        ],
        "status": "decided"
    },
    "machine-readable": {
        "description": "Maschinenlesbare Systemd- und NixOS-Optionen-Extraktion für Agenten",
        "source": "20-machine-readable-systemd-nixos",
        "tools": [
            "nixos-option --json",
            "systemd-analyze security --json",
            "sys-triage"
        ],
        "status": "decided"
    },
    "observability": {
        "description": "Deklarative Observability & Monitoring-Automatisierung",
        "source": "21-observability-automation",
        "components": [
            "Gatus Auto-Konfiguration aus Manifest",
            "VictoriaLogs sys-log CLI",
            "Ntfy Push-Alarmierung"
        ],
        "status": "decided"
    },
    "caddy-plugins": {
        "description": "Kernel-nahe und native Alternativen zu Custom-Caddy-Plugins",
        "source": "27-caddy-plugin-replacements",
        "replacements": {
            "caddy-security-headers": "Standard Caddyfile header Direktive",
            "caddy-ratelimit": "Caddy native rate_limit oder nftables / CrowdSec",
            "caddy-tarpit": "Sofortiger Drop via nftables / CrowdSec",
            "caddy-defender": "CrowdSec Ban-Kette",
            "caddy-cerberus": "Kernel-nah via nftables"
        },
        "status": "decided"
    },
    "nixmap": {
        "description": "44-Regeln Nix-AST Lint Matrix & statische Analyse",
        "source": "15-nixmap-ast-audit",
        "enforced_rules": [
            "Kein // Operator (recursiveUpdate statt //)",
            "Keine assert/throw im Modulbaum",
            "Kein with (explizite Bindings)",
            "Keine rec-Selbstreferenz",
            "Option-Default-Prüfung"
        ],
        "status": "decided"
    },
    "agent-errors": {
        "description": "Taxonomie von Agenten-Fehlerklassen & automatisierte Guardrails",
        "source": "16-agent-error-taxonomy",
        "error_classes": [
            "Tool-Aufruf-Fehler (Quotes, Escapes)",
            "Trailing Commas in JSON/Nix",
            "Maskierte Exit-Codes in Pipes",
            "Ghost-Configs",
            "Lange synchrone Blockaden"
        ],
        "mitigations": [
            "Statische Validierung vor Commit",
            "sys-triage vor Änderungen",
            "Zero-Remote Invariante"
        ],
        "status": "decided"
    },
    "docs-trias": {
        "description": "Architektur-Dokumentations-Trias (ADR, NIXMETA, programs.json)",
        "source": "25-docs-trias",
        "roles": {
            "ADR": "Warum (Architekturentscheidungen, Trade-offs, Begründung)",
            "NIXMETA": "Was (Modulinvarianten, Ports, Pfade im Code-Header)",
            "programs.json": "Wie (Maschinenlesbare Konfiguration, Datenverzeichnisse, Tuning)"
        },
        "status": "decided"
    },
    "guardrails": {
        "description": "Cross-Domain Guardrails & Invarianten-Prüfung (591-cross-domain.nix)",
        "source": "26-guardrail-591",
        "invariants": [
            "Port=UID=Numx10",
            "Keine Daemonen auf 0 und 9",
            "UDS-Konsistenz",
            "Keine Banned Technologies"
        ],
        "status": "decided"
    }
}

concerns_merged = dict(chat1_concerns_doc.get("concerns", {}))
concerns_merged.update(new_concerns_map)

concerns_doc = {
    "meta": {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "total_concerns": len(concerns_merged),
        "chat1_concerns_count": len(chat1_concerns_doc.get("concerns", {})),
        "new_concerns_count": len(new_concerns_map),
        "note": "Aggregierte Concern-Matrix aus Chat 1 und den Blöcken 15-27."
    },
    "distributions": chat1_concerns_doc.get("distributions", {}),
    "concerns": concerns_merged
}

with open(BASE_DIR / "concerns.json", "w", encoding="utf-8") as f:
    json.dump(concerns_doc, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"✅ Generated {BASE_DIR / 'concerns.json'} with {len(concerns_merged)} concerns (8 Chat 1 + 10 neu)")
