#!/usr/bin/env python3
"""
Reconciles todo/plan.json and todo/decisions.json with the current code state on main.
"""

from pathlib import Path
import json
from datetime import datetime, timezone

REPO_DIR = Path("/home/moritz/repos/mediNix-core")
PLAN_FILE = REPO_DIR / "todo/plan.json"
DECISIONS_FILE = REPO_DIR / "todo/decisions.json"

with open(PLAN_FILE, "r", encoding="utf-8") as f:
    plan = json.load(f)

with open(DECISIONS_FILE, "r", encoding="utf-8") as f:
    decisions = json.load(f)

# Definition der Status-Updates für Todos
TODO_UPDATES = {
    "N-01-01": {
        "status": "partially-done",
        "note": "NixOS als SSoT in README.md etabliert; FIDO2/Passkey-Eintrag in ROADMAP.md steht noch aus"
    },
    "N-02-01": {
        "status": "done",
        "commit": "ee73808",
        "note": "erledigt durch Chat-1-Quickwin ee73808"
    },
    "N-03-01": {
        "status": "done",
        "commit": "ee73808",
        "note": "erledigt durch Chat-1-Quickwin ee73808"
    },
    "N-03-02": {
        "status": "done",
        "commit": "79dac74",
        "note": "erledigt durch Chat-1-Quickwin 79dac74"
    },
    "N-04-01": {
        "status": "done",
        "commit": "41dd098",
        "note": "erledigt durch Chat-1-Quickwin 41dd098"
    },
    "N-04-02": {
        "status": "done",
        "commit": "89d5c00",
        "note": "erledigt durch Chat-1-Quickwin 89d5c00"
    },
    "N-04-03": {
        "status": "done",
        "commit": "400a4c0",
        "note": "erledigt durch Chat-1-Quickwin 400a4c0"
    },
    "N-05-01": {
        "status": "done",
        "commit": "d90ce5a",
        "note": "erledigt durch Chat-1-Quickwin d90ce5a"
    },
    "N-05-02": {
        "status": "done",
        "commit": "51a5a44",
        "note": "erledigt durch Chat-1-Quickwin 51a5a44"
    },
    "N-05-03": {
        "status": "partially-done",
        "note": "Blocky übernimmt bereits .lan-Split-DNS via 51a5a44; Speedport-spezifischer Upstream-Test vor Ort optional"
    },
    "N-05-04": {
        "status": "done",
        "commit": "d90ce5a",
        "note": "erledigt durch Chat-1-Quickwin d90ce5a"
    },
    "N-06-01": {
        "status": "done",
        "commit": "14e756e",
        "note": "erledigt durch Chat-1-Quickwin 14e756e"
    },
    "N-06-02": {
        "status": "done",
        "commit": "389552f",
        "note": "erledigt durch Chat-1-Quickwin 389552f"
    },
    "N-07-01": {
        "status": "partially-done",
        "note": "PQC SSH Schlüsselaustausch in ADR-52 dokumentiert via e5c49a4; HNDL-Abschnitt in ADR-521 steht noch aus"
    },
    "N-08-01": {
        "status": "done",
        "commit": "19d6113",
        "note": "erledigt durch Chat-1-Quickwin 19d6113"
    },
    "N-10-01": {
        "status": "partially-done",
        "note": "In mediNix-core in ADR-0003 und ADR-551 dokumentiert via e5c49a4; Einpflege in externes Host-Repo q958 noch offen"
    },
    "N-11-01": {
        "status": "done",
        "commit": "51a5a44",
        "note": "erledigt durch Chat-1-Quickwin 51a5a44 und d90ce5a"
    },
    "N-11-02": {
        "status": "done",
        "commit": "14e756e",
        "note": "erledigt durch Chat-1-Quickwin 14e756e"
    },
    "N-12-01": {
        "status": "done",
        "commit": "99877f0",
        "note": "erledigt durch Chat-1-Quickwin 99877f0"
    },
    "N-12-02": {
        "status": "done",
        "commit": "99877f0",
        "note": "erledigt durch Chat-1-Quickwin 99877f0"
    },
    "N-14-01": {
        "status": "partially-done",
        "note": "Catch-All 404 und UDS-Socket-Reihenfolge abgesichert via ee73808 / 8f16b1d; finale Prüfung von Wildcard-Subdomains offen"
    },
    "N-22-01": {
        "status": "done",
        "commit": "90553ad",
        "note": "erledigt durch Bugfix 90553ad"
    },
    "N-23-01": {
        "status": "done",
        "commit": "f3153df",
        "note": "erledigt durch Bugfix f3153df"
    },
    "N-23-02": {
        "status": "done",
        "commit": "f3153df",
        "note": "erledigt durch Bugfix f3153df"
    },
    "N-24-01": {
        "status": "done",
        "commit": "21ca67f",
        "note": "erledigt durch Bugfix 21ca67f"
    },
    "N-26-01": {
        "status": "done",
        "commit": "status-quo",
        "note": "Status Quo bestätigt: 591-cross-domain.nix ist SSoT, 509-guardrails.nix verworfen"
    }
}

# Update plan.json todos
counts = {"done": 0, "partially-done": 0, "still-open": 0}
prio_summary = {
    "done": {"high": 0, "medium": 0, "low": 0},
    "partially-done": {"high": 0, "medium": 0, "low": 0},
    "still-open": {"high": 0, "medium": 0, "low": 0},
    "total": {"high": 0, "medium": 0, "low": 0}
}

for t in plan["todos"]:
    tid = t["id"]
    prio = t.get("priority", "medium")
    prio_summary["total"][prio] += 1
    
    if tid in TODO_UPDATES:
        up = TODO_UPDATES[tid]
        t["status"] = up["status"]
        if "commit" in up:
            t["commit"] = up["commit"]
        if "note" in up:
            t["note"] = up["note"]
        counts[up["status"]] += 1
        prio_summary[up["status"]][prio] += 1
    else:
        t["status"] = "still-open"
        counts["still-open"] += 1
        prio_summary["still-open"][prio] += 1

plan["meta"]["reconciled_at"] = datetime.now(timezone.utc).isoformat()
plan["meta"]["status_counts"] = counts
plan["meta"]["priority_summary"] = prio_summary

with open(PLAN_FILE, "w", encoding="utf-8") as f:
    json.dump(plan, f, indent=2, ensure_ascii=False)
    f.write("\n")

print(f"Updated {PLAN_FILE}: {counts}")

# Update decisions.json
IMPLEMENTED_DECISIONS = {
    "D-01-01": "status-quo",
    "D-01-02": "status-quo",
    "D-02-01": "ee73808",
    "D-02-02": "ee73808",
    "D-03-01": "ee73808",
    "D-03-02": "79dac74",
    "D-04-01": "74a8a70",
    "D-04-02": "74a8a70",
    "D-04-03": "41dd098",
    "D-05-01": "d90ce5a",
    "D-05-02": "d90ce5a",
    "D-06-02": "94db365",
    "D-06-03": "14e756e",
    "D-07-01": "status-quo",
    "D-07-02": "status-quo",
    "D-08-01": "status-quo",
    "D-08-02": "status-quo",
    "D-09-01": "status-quo",
    "D-09-02": "status-quo",
    "D-10-03": "status-quo",
    "D-11-02": "d90ce5a",
    "D-12-01": "99877f0",
    "D-12-02": "99877f0",
    "D-13-01": "status-quo",
    "D-13-02": "status-quo",
    "D-13-03": "status-quo",
    "D-14-01": "ee73808",
    "D-14-04": "9867d92",
    "D-22-01": "90553ad",
    "D-23-01": "f3153df",
    "D-23-02": "f3153df",
    "D-24-01": "21ca67f",
    "D-26-01": "status-quo",
    "D-27-02": "status-quo",
    "D-27-04": "status-quo"
}

def update_decision_item(item):
    did = item["id"]
    if did in IMPLEMENTED_DECISIONS:
        item["implemented"] = True
        item["commit"] = IMPLEMENTED_DECISIONS[did]
    else:
        item["implemented"] = False

for item in decisions.get("items", []):
    update_decision_item(item)

for theme, items in decisions.get("by_theme", {}).items():
    for item in items:
        update_decision_item(item)

decisions["meta"]["reconciled_at"] = datetime.now(timezone.utc).isoformat()
decisions["meta"]["implemented_count"] = sum(1 for item in decisions.get("items", []) if item.get("implemented"))

with open(DECISIONS_FILE, "w", encoding="utf-8") as f:
    json.dump(decisions, f, indent=2, ensure_ascii=False)
    f.write("\n")

print(f"Updated {DECISIONS_FILE}: {decisions['meta']['implemented_count']} decisions marked as implemented")
