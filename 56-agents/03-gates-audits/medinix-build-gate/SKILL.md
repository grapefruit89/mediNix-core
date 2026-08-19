---
name: medinix-build-gate
category: devops
description: "MANDATORY pre-commit gate sequence for mediNix. Enforces Context7 doc-lookups for all NixOS options, checks for hardcoded IP portability K.O., runs Decimal-Audits, and prepares the commit."
---

# medinix-build-gate

Dies ist die verpflichtende Pre-Commit und Build-Sequenz für jede Datei, die du im mediNix-core schreibst. Arbeite die Sequenz strikt von oben nach unten ab, bevor du committest.

## 1. Context7 API Gate (Verifikation aller Optionen)
- **Regel:** Keine NixOS-Option darf "aus dem Gedächtnis" geschrieben werden. Du musst jede Option via Context7 (`mcp_context7_query_docs`) verifizieren.
- **Parameter-Syntax:** Nutze zwingend `libraryId="/websites/nixos_manual_nixos_unstable"` (NICHT `libraryName`!).
- **Library Routing:**
  - `/websites/nixos_manual_nixos_unstable` → für Core-Optionen (`networking.nftables`, `systemd.services.<name>.serviceConfig.*`, `security.acme`).
  - `/nixos/nixpkgs` → für Community-Module (`services.sonarr`, `services.jellyfin`). *Wichtig: Diese sind NICHT im Core-Manual!*
- Falls Context7 keine Doku findet ("No documentation matched"), formuliere die Query kürzer oder nutze `systemd.services` nativ.

## 2. Portability K.O. Check (Hard Check)
- **Niemals:** Harte IPs (wie `192.168.x.x`), hartkodierte Hostnamen (`q958`, `jarvis`), oder LAN CIDRs (`/24`) in portablen Modulen!
- Wenn du eine LAN-Spezifik brauchst, muss sie über eine `nullOr str` Option in der `default.nix` konfigurierbar gemacht werden. Ist sie null, greift das Fallback (z.B. ein leeres `mkIf`).
- Wer harte IPs im Modul committet, zwingt diese Netzkonfiguration allen Konsumenten des Repositories auf.

## 3. Decimal Audit Gate
- Führe vor dem Commit immer die `medinix-audit-suite` aus (konkret: die Skripte `scan_duplicates.py` und `scan_inconsistencies.py`).
- Behebe reale Konflikte. Ignoriere bekannte False Positives (z.B. `default.nix`).

## 4. Commit & Push
- Erstelle den Commit.
- Schreibe in die Commit-Message eine kurze Notiz, dass die Optionen via Context7 validiert wurden und der Portability Check grün ist.
