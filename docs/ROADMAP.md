# mediNix-core — Architektur-Leitfaden & Zukunfts-Roadmap

> **Vision:** `mediNix-core` ist ein spezialisierter, systemd-nativer **Pure-Media-Flake**.  
> Er enthält **ausschließlich** Mediendienste (Ingress, Acquisition, Transfer, Playback, Storage-Tiering) inklusive eines maßgeschneiderten **Observability- & Logging-Stacks** und robuster **Ressourcen-/OOM-Absicherung**.  
> Allrounder-Ballast (Smart Home, Vaultwarden, Git, Paperless, Game Server) verbleibt auf dem Host und gehört bewusst **nicht** in diesen Flake.

> **Status Quo & Verifikation:**  
> Die Kernarchitektur (Storage-Tiering, gehärteter Mover, *arr MediaCover Bind-Mounts, Jellyfin XML-Pre-Seeding mit nativer `MetadataPath`-Auslagerung, SSoT Memory-/OOM-Policy, spindown-sicheres smartd-Monitoring) ist **vollständig implementiert** und unter [`docs/ACCEPTANCE-TESTS.md`](ACCEPTANCE-TESTS.md) eingefroren.

---

## 1. Observability-Stack: Status & Logging

Ein vollwertiger Medien-Stack benötigt Transparenz über Service-Health, Streaming-Traffic und Fehler-Spitzen, ohne auf Cloud-Dienste angewiesen zu sein.

### A. Gatus: Visuelles Health- & Status-Dashboard (Nächster Schritt)
- **Quell-Dateien:** [`NixmitGROK/modules/40-observability.nix`](/home/moritz/repos/NixmitGROK/modules/40-observability.nix) & [`NixmitGROK/lib/gatus-endpoints.nix`](/home/moritz/repos/NixmitGROK/lib/gatus-endpoints.nix)
- **Konzept:**
  - Extrem schlanker Go-basierter Status-Server mit sauberem Web-UI (`585-gatus.nix`).
  - Automatische Generierung von Endpoints für alle aktiven mediNix-Dienste:
    - HTTP-Checks auf `127.0.0.1:${port}` (Caddy, Jellyfin, Sonarr, Radarr, SABnzbd, etc.).
    - Mountpoint-Checks für Tier B (Fast Pool) und Tier C (Media Pool).
    - Lokale Socket-Checks für Ingress & SQLite.
  - Caddy vHost: `status.${domain}` mit `accessGroup = "internal"`.

### B. Vector + Loki + Grafana: Die Medien-Logging-Pipeline (Optional / Später)
- **Quell-Datei:** [`NixmitGROK/modules/40-observability.nix`](/home/moritz/repos/NixmitGROK/modules/40-observability.nix)
- **Architektur:**
  ```text
  [ Caddy JSON-Logs ] ──┐
  [ systemd journal ] ──┴─► [ Vector ] (Remap / Parse) ──► [ Loki ] ──► [ Grafana UI ]
  ```
- **Komponenten:**
  1. **Vector:** Liest direkt aus `journald`, parst Caddy-Access-Logs per VRL.
  2. **Loki:** TSDB-Schema v13 mit Filesystem-Storage auf Tier B (`/var/lib/loki`), 7 Tage Retention.
  3. **Grafana:** Hört lokal auf Unix-Socket (`/run/grafana/grafana.sock`) hinter Caddy mit vorkonfiguriertem Dashboard.

---

## 2. Storage-Erweiterungen (Optional / Später)

### A. HDD-freundliche Deferred Deletion Queue
- **Quell-Datei:** [`NixmitGROK/modules/05-deferred-ops.nix`](/home/moritz/repos/NixmitGROK/modules/05-deferred-ops.nix)  
  *Dokumentation:** [`NixmitGROK/docs/guides/GUIDE-storage-tiers.md`](/home/moritz/repos/NixmitGROK/docs/guides/GUIDE-storage-tiers.md)
- **Konzept:**
  - Löschanfragen für Tier C wandern in eine Queue auf Tier B (`${storage.mediaRoot}/delete_queue`).
  - Periodischer Timer prüft via `hdparm -C` den Status der Platten:
    ```bash
    if hdparm -C "$dev" 2>/dev/null | grep -q "active/idle"; then
      # HDDs laufen ohnehin -> jetzt sicher löschen
    fi
    ```
  - Befinden sich die HDDs im `standby`, bleibt die Datei in der Queue (kein unnötiger Spinup).
  - Spätestens nach `maxAgeDays = 7` wird das Löschen beim nächsten regulären Aufwachen forciert.

### B. Label-basiertes Automounting & MergerFS
- **Quell-Datei:** [`NixmitGROK/modules/35-automount.nix`](/home/moritz/repos/NixmitGROK/modules/35-automount.nix)
- **Konzept:**
  - Automatisches Einhängen anhand von Dateisystem-Labels (`NIXDATA`, `NIXMEDIA`, `NIXBACKUP`).
  - Dynamisches Hinzufügen von Zweigen zum MergerFS-Pool ohne manuelles Bearbeiten der Host-fstab.

---

## 3. Offene Implementierungs-Phasen

| Phase | Thema | Enthaltene Komponenten | Priorität |
|---|---|---|:---:|
| **Phase 18** | **Media Observability** | Gatus Health-Dashboard (`585-gatus.nix`) | **Mittel (Aktiv)** |
| **Phase 18b** | **Media Logging** | Vector + Loki + Grafana Pipeline (`586-logging.nix`) | Niedrig / Später |
| **Phase 19** | **Storage & Spindown** | Deferred Deletion Queue (`544-deferred-delete.nix`), Automounting | Niedrig / Später |

---

## 4. Bewusst abgelehnte Elemente (Out of Scope)

Die folgenden Elemente aus `NixmitGROK` bleiben dauerhaft **ausgeschlossen**:
- **Audiobookshelf QuickSync (VA-API):** Audiobookshelf ist ein reiner Audioserver; QuickSync/VA-API beschleunigt hardwareseitig ausschließlich Video-Codecs. Audio-Transcoding läuft immer auf der CPU. Eine Durchreichung von `/dev/dri` würde die systemd-Sandbox schwächen ohne jeden Nutzen.
- **Allround-Apps:** Vaultwarden, Homepage Dashboard, Paperless-ngx, n8n, Home Assistant, Zigbee2MQTT, Forgejo, Cockpit, AMP Game Server.
- **Host-Netzwerk:** Blocky DoT DNS Resolver, AdGuardHome (gehört auf den Router/Host).
- **Zentrale Shared-DBs:** PostgreSQL, Valkey (mediNix bleibt autonom mit isolierten SQLite-Datenbanken).
