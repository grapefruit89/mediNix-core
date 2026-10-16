---
id: "ADR-543"
title: "Cold-Archive-Tiering: On-Demand-Mover statt Cron"
status: active
complexity: 3
last_reviewed: 2026-10-16
links:
  adr: ADR-5000 (native services), ADR-570 (Storage-Tiering)
---

# ADR-543: Cold-Archive-Tiering - On-Demand-Mover statt Cron

## Kontext
Medien liegen in Tier B (SSD, schnell) und Tier C (HDD, kalt). Laeuft die SSD voll, muss
rechtzeitig verschoben werden - ohne dauerhaften Daemon und ohne `cron` (ADR-5000: native Dienste).

## Entscheidung
- Ein **On-Demand-Mover** als Unit `mediNix-mover`, ausgeloest von einem **systemd-Timer**
  (Safety-Netz, `mediNix-mover-safety`) und optional per Path-Trigger - **kein** `cron`.
- Der Mover arbeitet bedarfsgesteuert: Ziel ist "genug freier Platz auf der SSD", dann stoppt er
  (Fill-Level-Check auf Tier B).
- Es wandern nur **whitelisted Endungen**, Dateien **>= 50 MB**, die seit **mindestens 5 Minuten**
  unveraendert sind (`-mmin +5`); aktiv geoeffnete Dateien werden uebersprungen (Lock-Check).

## Datenintegritaet (die eigentlichen Regeln)
- **Atomares Veroeffentlichen:** erst in eine kollisionsfreie Temp-Datei im Ziel kopieren, dann
  umbenennen - nie direkt in den Zielpfad schreiben.
- **Vorflug-Check:** die Ziel-HDD braucht Platz fuer die Datei **plus 1 GB** Reserve.
- **Ziel existiert bereits:** gleiche Groesse -> Staging-Datei entfernen (voriger Lauf war
  unterbrochen); andere Groesse -> warnen und **nicht** ueberschreiben.
- **Nebenlaeufigkeit:** ein Lock verhindert ueberlappende Laeufe (manuell, Timer, Pfad-Trigger).
- **Abbruch:** Signal-Trap entfernt sofort eine in Arbeit befindliche Temp-Datei.
- **Aufraeumen:** Staging-Reste aus abgebrochenen Laeufen (> 24 h) werden entfernt.
- **Fehl-Mount-Schutz:** niemals auf die Root-SSD schreiben, wenn der Ziel-Mount fehlt.

## Konsequenzen
- Kein "Cron feuert zur falschen Zeit"-Risiko; die Safety-Timer-Frequenz muss zur Erwartung passen.
- Der Lauf ist idempotent und jederzeit erneut ausfuehrbar; jeder Abbruch hinterlaesst hoechstens
  eine Temp-Datei, die beim naechsten Lauf aufgeraeumt wird.
