---
name: nixos-decimal-audit
description: Audit mediNix-core decimal conflicts, ports, duplicates.
---

# nixos-decimal-audit

Wiederverwendbarer Audit für das mediNix-core Boilerplate (grapefruit89/mediNix-core).
Prüft die Dezimalrahmen-Invarianten (ADR-0000) auf Verletzungen.

## Wann laden
- Nach jeder Umbenennung/Verschiebung von `.nix`-Modulen
- Vor jedem Commit in mediNix-core
- Bei Verdacht auf Duplikate ("Caddy zweimal", "SABnzbd mehrfach")
- Bei Inkonsistenz-Scans (User: "scan nach Inkonsistenzen")

## Invarianten (ADR-0000)
- Port = Dienstnummer × 10, UID = Port, GID = 5000
- Flat: `XX-domain/NNN-service.nix` — keine verschachtelten Service-Ordner
- Eine Datei pro Dienst (kein Caddy in 2 Dateien gespalten)
- 3-stellige Dienstnummer leitet ab; 4-stellige Zahlen leiten NICHTS ab
- 511=Caddy, 512=Pocket ID, 541=SABnzbd, 543=Mover (NICHT 541=Mover)
- 559=playback-tuning (Cross-deps inline in Service-Modulen, keine 559-cross-service.nix)

## Tools (in references/)
- `scan_duplicates.py` — voller Duplikat-Check (Namens-, Inhalt-, Nummern-, ID-Kollisionen + Caddy/SABnzbd-Spezial-Checks)
- `scan_inconsistencies.py` — Dezimalrahmen-Inkonsistenz-Check (Dateiname vs Port vs Dienstnummer, 5x0-Regel)

## Verwendung
```bash
python3 ~/.hermes/skills/nixos-decimal-audit/references/scan_duplicates.py
python3 ~/.hermes/skills/nixos-decimal-audit/references/scan_inconsistencies.py
```

ROOT in beiden Skripten ist hart auf `/opt/data/50-mediNix` gesetzt — bei anderem Pfad anpassen.

## Interpretation
- "NO NUMBER in filename" = Modul ohne Dienstnummer (ok bei default.nix/lib/, fehlerhaft bei Service-Modulen)
- "PORT X != file num Y*10" = Header-Port falsch (Dateiname korrekt, Port im NIXMETA-Header muss fix)
- "SUSPICIOUS 5x0" = 5x0 mit x≠0 ist kein gültiger Dienst (nur 500/520/570 sind Basis-ADRs)
- Namens-Duplikate über verschiedene Pfade = echtes Problem (zwei Dateien gleichen Namens)
- Inhalt-identisch = kopierte Datei (löschen)

## Bekannte false positives (ignorieren)
- `default.nix` mehrfach (Domain-Loader, gewollt)
- Port 22/2222/443/80 in Headern (SSH/Firewall, keine Service-Ports)
- `57-maintenance/*.nix` ohne Nummer (Provisioning-Submodule, gewollt)
