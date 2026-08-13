---
id: "ARCH-57-impermanence-storage"
title: "ARCH 5700 impermanence storage"
domain: 57
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - impermanence
  - storage
links:
  adr: ""
  repo-harvest: ""
---
# Strategy: Impermanence & Tiered Storage (NMS v4.2)

## 1. User Layer (KISS)
Dieses Dokument beschreibt, wie dein Server mit Daten umgeht. Wir nutzen ein "Stateless"-Prinzip: Das Betriebssystem wird bei jedem Neustart frisch aus dem Arbeitsspeicher (tmpfs) geladen. Nur deine wichtigen Daten (Fotos, Datenbanken, Einstellungen) werden dauerhaft auf den Festplatten gespeichert. Wir unterteilen diesen Speicher in drei Klassen (Tiers), um Geschwindigkeit und HDD-Ruhezustand (Spindown) optimal zu kombinieren.

## 2. Technical Layer (Aviation-Grade)

### Stateless Root & Persistenz
*   **Root (/) auf tmpfs:** Garantiert ein sauberes System nach jedem Reboot.
*   **Bind-Mounts:** Persistente Pfade werden via `persist` Modul nach `/nix/persist/` oder direkt auf die Tiers gemountet.

### Das 3-Tier Storage Modell
| Tier | Hardware | Fokus | Datentyp |
|---|---|---|---|
| **Tier A** | NVMe SSD | Speed & State | PostgreSQL, sops-secrets, App-Config |
| **Tier B** | SSD / Mirror | Active Media | Aktuelle Downloads, Cache |
| **Tier C** | HDDs (JBOD) | Mass Storage | Archiv-Filme, Backups (Spindown-Zone) |

### Implementierung: Storage-Management
Die Synchronisation zwischen Cloud und lokalem Speicher erfolgt ausschließlich auf **Tier A**.
*   **Restic-Target:** `/mnt/tier-a/state`.
*   **Atomic-Move Zone:** Downloads landen auf der NVMe und werden nach Abschluss per Hardlink in die `.staging` Ordner auf Tier C verschoben.

## 3. Reasoning Layer (History)

### [ADR-008] Impermanence vs. Traditionelle Installation
*   **Status:** Entschieden (März 2026).
*   **Kontext:** Traditionelle Linux-Installationen sammeln über die Zeit "Müll" (Logs, temporäre Dateien) an, was die Reproduzierbarkeit erschwert.
*   **Entscheidung:** Migration zu einem Stateless-Ansatz mit `tmpfs` auf `/`.
*   **Konsequenzen:** Jede Änderung am System *muss* deklarativ in den Nix-Files erfolgen, da sie sonst nach dem Neustart verloren geht. Dies erzwingt die Einhaltung der IaC-Prinzipien.

### [ADR-009] ABC-Tiering vs. MergerFS/RAID
*   **Status:** Entschieden (März 2026).
*   **Kontext:** MergerFS weckt alle HDDs gleichzeitig auf, was den Energieverbrauch erhöht und die Lebensdauer senkt.
*   **Entscheidung:** Explizite Mountpoints für HDDs und logische Trennung der Daten nach Zugriffshäufigkeit (Tiering).
*   **Vorteile:** Maximale Kontrolle über den Spindown einzelner Platten.

---
**Sources:**
*   `/home/Knowledge-Pipeline/raw/_duplikate/Claude-NMS v4.2 sovereign identity implementation strategy.md`
*   `/home/Knowledge-Pipeline/raw/_duplikate/Gemini-NixOS Homelab Architecture Review (1).md`
