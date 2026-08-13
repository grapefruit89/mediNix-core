---
title: Storage & Mover
type: Concept
---
# Storage & Mover

**SSoT (Single Source of Truth) für Storage-Architektur in mediNix-core**

- **Path**: Alle Storage-Mounts verwenden eindeutige Paths (z.B. `/opt/data/…`).
- **minFreeGb**: Muss für Cache-Drives streng konfiguriert werden, um Volllaufen zu verhindern.
- **mover**: Es gibt keinen klassischen Timer-Cronjob im Gast. Der Mover wird host-seitig ausgeführt oder durch Events getriggert.
- **mergerfs**: Läuft zwingend auf dem **Host** (devNIX), NICHT im Gast (mediNix-core). Das Gast-System bindet nur die final gemergten Pfade ein.
