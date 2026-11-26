---
id: "ADR-587"
title: "Disk-Health: SMART-Ueberwachung, Spindown-Timeout & Power-Event-Logging"
status: active
complexity: 2
last_reviewed: 2026-11-26
links:
  adr: ADR-0002 (systemd-first), ADR-570 (Storage-Tiering)
---

# ADR-587: Disk-Health - SMART mit Standby-Erhalt

## Kontext
Plattenausfaelle sollen frueh auffallen (reallocated/pending Sectors, Temperaturen). Die
Archiv-HDDs schlafen aber im Leerlauf - eine Ueberwachung, die sie staendig aufweckt, kostet Strom
und Lebenszeit. Zudem muss im Betrieb nachvollziehbar sein, wann und wie lange eine HDD tatsächlich
im Standby war oder durch einen Zugriff geweckt wurde.

## Entscheidung
- Ueberwachung mit **`smartd`** (systemd-first: Kernel-nahes Werkzeug aus nixpkgs, kein
  Daemon-Eigenbau, ADR-0002).
- **Standby-Erhalt** ueber `-n standby,q`: smartd fragt schlafende Platten **nicht** ab und
  protokolliert das nicht als Fehler - kein regelmaessiges Aufwecken.
- **Spindown-Timeout:** `medinix.diskHealth.spindownDelayMinutes` (Standard `120` Minuten ->
  `hdparm -S 244`) wird beim Systemstart über `medinix-disk-spindown.service` gesetzt.
- **Lautloses Power-Event-Logging:** Ein 60s-Timer (`medinix-disk-power`) fragt per `hdparm -C`
  ohne Spin-up den Power-State ab und protokolliert echte Zustandswechsel (`[SPIN-UP]`, `[SPINDOWN]`)
  in journald (`journalctl -t medinix-disk-power`).
- Alarme gehen **direkt an die interne Benachrichtigung** (Dienst 581, ntfy) via `-M exec <script>`,
  nicht per E-Mail.
- Geraete und Optionen kommen aus der Konfiguration (`device`, `options`), nicht hartkodiert.

## Begruendung
- Ohne `-n standby` wuerde jede Pruefung die Archiv-HDDs aufwecken (Spindown-Zeit, Verschleiss).
- ntfy statt Mail: der Stack hat bereits einen Push-Kanal (581); ein zweiter Kanal waere ein
  Zusatzprogramm ohne Mehrwert.

## Konsequenzen
- Fehler werden "beim naechsten Aufwachen" erkannt, nicht sofort - bewusster Tausch zugunsten der
  Spindown-Zeit.
- SMART-Werte landen im journald und (bei Fehlern) als Push. Es gibt kein eigenes Dashboard
  dafuer: Gatus (582) prueft Erreichbarkeit, nicht Sektorzustaende.
