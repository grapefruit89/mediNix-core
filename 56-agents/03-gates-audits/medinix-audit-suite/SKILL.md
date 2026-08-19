---
name: medinix-audit-suite
category: devops
description: "Core verification skill for mediNix. Enforces decimal invariants, detects duplicates/collisions via shared scripts, enforces assertion quality, and extracts gold-standards from other repos."
---

# medinix-audit-suite

Dieses Skill vereint alle statischen Prüfungen, Scans und Quality-Gates, die das mediNix-core Boilerplate vor Struktur-Fehlern bewahren. Es wird verwendet, um Invarianten durchzusetzen und die Codebase auf Fehler zu prüfen.

## 1. Trigger & Fokus
- **Wann nutzen:** 
  - Nach jeder Umbenennung/Verschiebung von `.nix`-Modulen.
  - Bei Verdacht auf Duplikate ("Caddy zweimal vorhanden?").
  - Bei Inkonsistenz-Scans des Dezimalrahmens.
  - Beim Review von unklaren Assertion-/Fehlermeldungen.
  - Zur Extraktion von mediNix-relevanten Best-Practices ("Gold-Standards") aus Fremd-Repos.

## 2. Invarianten (ADR-0000)
- **Die goldene Regel:** Port = Dienstnummer × 10, UID = Port, GID = 5000.
- **Flat Structure:** `XX-domain/NNN-service.nix` — keine verschachtelten Service-Ordner.
- **Einzigartigkeit:** Eine Datei pro Dienst (z.B. Caddy darf nicht in 2 Dateien aufgespalten sein).
- Die 3-stellige Dienstnummer leitet alles ab. 4-stellige Zahlen im Dateinamen leiten NICHTS ab.

## 3. Die Audit-Werkzeuge (Shared Scripts)
Verwende diese Skripte für den Audit (Pfade beachten!):
```bash
python3 ../../shared/scripts/scan_duplicates.py
python3 ../../shared/scripts/scan_inconsistencies.py
```
*Tipp: Passe den `ROOT`-Pfad im Skript an dein aktuelles Arbeitsverzeichnis an, falls du nicht im Standardpfad bist.*

**Interpretation der Ergebnisse:**
- "PORT X != file num Y*10": Der Header-Port stimmt nicht mit dem Dateinamen überein (Kollision!).
- Namens-Duplikate über verschiedene Pfade: Echtes Problem, zwei Dateien heißen gleich.
- *False Positives:* `default.nix` (Domain-Loader) darf mehrfach vorkommen.

## 4. Assertion Quality (ADR-5043)
Jede `assertions = [` oder `warnings = [` Meldung MUSS folgendes Format haben:
1. **Tag Prefix:** `[<module-id>]` (z.B. `[595]`), um den Ursprung sofort zu finden.
2. **What:** Was ist kaputt (beobachteter Zustand)?
3. **Why:** Warum ist das ein Problem (Sicherheit, Lockout-Risiko)?
4. **Fix:** Welche Option muss geändert werden, um das Problem zu beheben?

*Beispiel:*
```nix
message = ''
  [595] SSH service is DISABLED.
  A mediNix host without SSH is unreachable after reboot.
  Fix: set grapefruitMedia.ssh.enable = true.
'';
```

## 5. Repo-Audit (Fremd-Code prüfen)
Wenn du ein fremdes NixOS-Repository analysierst, um Gold-Standards für mediNix zu finden:
1. **Ist es portabel?** Keine harten Host-IPs oder `my.*` Variablen.
2. **Ist es systemd-nativ?** Keine Docker-Container, kein `netns`. (Suche nach `RestrictNetworkInterfaces`).
3. Kopiere nur Konzepte, niemals rohen, unportablen Code in das 50-mediNix Boilerplate.
