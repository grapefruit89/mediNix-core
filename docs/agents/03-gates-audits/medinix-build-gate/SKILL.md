---
name: medinix-build-gate
mcp: [nixos, context7]
category: devops
description: "MANDATORY pre-commit gate sequence for mediNix. Verifies every NixOS option against the LIVE source (nixpkgs module code in the store, nix eval, search.nixos.org, nix-MCP) - never from memory; Context7 is only a quick index. Runs Assertion-Scripts for portability, Decimal-Audits, and prepares the commit with a strict DSP workflow."
---

# medinix-build-gate

Dies ist die verpflichtende Pre-Commit und Build-Sequenz für jede Datei, die du im mediNix-core schreibst. 
Du MUSST nach dem DSP-Schema (Declarative Self-Prompting) arbeiten.

## DSP Workflow (Strict Enforcement)

Wenn du diesen Skill aufrufst, MUSST du deine Antwort zwingend in folgende drei Blöcke strukturieren. Du darfst keinen Block überspringen.

### [PLAN]
Deklariere exakt, welche Dateien du gleich prüfen wirst und liste die 3 Subtasks auf, die du ausführen wirst:
1. Optionen-Gate (Verifikation gegen die LIVE-Quelle)
2. Portability Assertion (Prüfung auf harte IPs)
3. Decimal Audit Gate (Ausführung der Audit-Skripte)

### [EXECUTE]
Führe die Subtasks nacheinander aus und nutze Tools, um Ergebnisse zu verifizieren. Protokolliere jedes Ergebnis mit `Subtask X result:`.

**Subtask 1: Optionen-Gate (LIVE-Quelle zuerst)**
- **Regel:** Keine NixOS-Option darf "aus dem Gedächtnis" geschrieben werden. Verifiziere jede Option gegen die **Live-Quelle**: nixpkgs-Modul-Code im Store (`nix eval`, `grep -r options.<pfad>`), `search.nixos.org` oder das nix-MCP (`tools.nixos.nix`).
- **Rangfolge (verbindlich, siehe AGENTS.md):** Live-Quelle (Modul-Code/Paket) > NixOS-Wiki > Upstream-Doku > Context7. Context7 ist ein Sparformat-Index, kann veraltet sein - bei Widerspruch gewinnt die Live-Quelle.
- Kennt die Quelle die Option nicht: Option streichen oder einen nativen Service nutzen - nicht raten.

**Subtask 2: Portability Assertion (Hard Guardrail)**
- **Regel:** Harte IPs (wie `192.168.x.x`), Hostnamen oder LAN CIDRs sind streng verboten.
- Führe das Assertion-Skript aus: `bash docs/agents/shared/scripts/assert_no_ips.sh <deine_datei.nix>`
- Wenn das Skript fehlschlägt (Exit Code 1), MUSST du die Datei reparieren und den Subtask wiederholen, bevor du zu Subtask 3 gehst.

**Subtask 3: Decimal Audit Gate**
- Führe die `scan_duplicates.py` und `scan_inconsistencies.py` Skripte aus, falls vorhanden.
- Behebe reale Konflikte. Ignoriere bekannte False Positives.

### [COMPOSE]
- Fasse die Ergebnisse der Subtasks zusammen.
- Erstelle den Commit.
- Schreibe in die Commit-Message, dass die Optionen gegen die LIVE-Quelle geprueft wurden und die Portability-Assertion bestanden wurde.
