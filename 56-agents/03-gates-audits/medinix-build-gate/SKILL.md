---
name: medinix-build-gate
category: devops
description: "MANDATORY pre-commit gate sequence for mediNix. Enforces Context7 doc-lookups for all NixOS options, runs Assertion-Scripts for portability, runs Decimal-Audits, and prepares the commit using a strict DSP (Declarative Self-Prompting) workflow."
---

# medinix-build-gate

Dies ist die verpflichtende Pre-Commit und Build-Sequenz für jede Datei, die du im mediNix-core schreibst. 
Du MUSST nach dem DSP-Schema (Declarative Self-Prompting) arbeiten.

## DSP Workflow (Strict Enforcement)

Wenn du diesen Skill aufrufst, MUSST du deine Antwort zwingend in folgende drei Blöcke strukturieren. Du darfst keinen Block überspringen.

### [PLAN]
Deklariere exakt, welche Dateien du gleich prüfen wirst und liste die 3 Subtasks auf, die du ausführen wirst:
1. Context7 API Gate (Verifikation der NixOS-Optionen)
2. Portability Assertion (Prüfung auf harte IPs)
3. Decimal Audit Gate (Ausführung der Audit-Skripte)

### [EXECUTE]
Führe die Subtasks nacheinander aus und nutze Tools, um Ergebnisse zu verifizieren. Protokolliere jedes Ergebnis mit `Subtask X result:`.

**Subtask 1: Context7 API Gate**
- **Regel:** Keine NixOS-Option darf "aus dem Gedächtnis" geschrieben werden. Du musst jede Option via Context7 (`mcp_context7_query_docs`) verifizieren.
- **Parameter-Syntax:** Nutze zwingend `libraryId="/websites/nixos_manual_nixos_unstable"`.
- Falls Context7 keine Doku findet, formuliere die Query kürzer oder nutze native Systemd-Services.

**Subtask 2: Portability Assertion (Hard Guardrail)**
- **Regel:** Harte IPs (wie `192.168.x.x`), Hostnamen oder LAN CIDRs sind streng verboten.
- Führe das Assertion-Skript aus: `bash 56-agents/shared/scripts/assert_no_ips.sh <deine_datei.nix>`
- Wenn das Skript fehlschlägt (Exit Code 1), MUSST du die Datei reparieren und den Subtask wiederholen, bevor du zu Subtask 3 gehst.

**Subtask 3: Decimal Audit Gate**
- Führe die `scan_duplicates.py` und `scan_inconsistencies.py` Skripte aus, falls vorhanden.
- Behebe reale Konflikte. Ignoriere bekannte False Positives.

### [COMPOSE]
- Fasse die Ergebnisse der Subtasks zusammen.
- Erstelle den Commit.
- Schreibe in die Commit-Message zwingend, dass die Optionen via Context7 validiert wurden und die Portability-Assertion bestanden wurde.
