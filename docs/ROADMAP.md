# mediNix-core — Architektur-Leitfaden & Zukunfts-Roadmap

> **Vision:** `mediNix-core` ist ein spezialisierter, systemd-nativer **Pure-Media-Flake**.  
> Er enthält **ausschließlich** Mediendienste (Ingress, Acquisition, Transfer, Playback, Storage-Tiering) inklusive eines maßgeschneiderten **Observability- & Logging-Stacks** und robuster **Ressourcen-/OOM-Absicherung**.  
> Allrounder-Ballast (Smart Home, Vaultwarden, Git, Paperless, Game Server) verbleibt auf dem Host und gehört bewusst **nicht** in diesen Flake.

Dieses Dokument dient als Leitfaden und Spezifikation für zukünftige Ausbaustufen, adaptiert aus bewährten Mustern der Host-Konfiguration [`NixmitGROK`](/home/moritz/repos/NixmitGROK/).

---

## 1. Spezifische Medien-Veredelungen (Quick Wins)

### A. Audiobookshelf: Intel QuickSync (VA-API Transcoding)
- **Quell-Datei:** [`NixmitGROK/modules/50-media/audiobookshelf.nix`](/home/moritz/repos/NixmitGROK/modules/50-media/audiobookshelf.nix)
- **Problem:** [`552-audiobookshelf.nix`](/home/moritz/repos/mediNix-core/55-playback/552-audiobookshelf.nix) läuft aktuell rein auf der CPU.
- **Leitfaden & Umsetzung:**
  - Option `medinix.audiobookshelf.enableQuickSync` (Default: `true` wenn `cfg.hardware.accel == "intel"`) ergänzen.
  - Grafik-Pakete bereitstellen: `pkgs.intel-media-driver`, `pkgs.intel-compute-runtime`.
  - Umgebung setzen: `LIBVA_DRIVER_NAME = "iHD"`, `LIBVA_DRIVERS_PATH = "${pkgs.intel-media-driver}/lib/dri"`.
  - Berechtigungen in systemd: `users.users.audiobookshelf.extraGroups = [ "video" "render" ]`, `DeviceAllow = [ "/dev/dri rw" "/dev/dri/renderD128 rw" ]`.
  - **Nutzen:** Schnelles, CPU-schonendes Transcoding großer Audioformate (FLAC, m4b, Opus) beim mobilen Streaming.

### B. Jellyfin XML Pre-Seeding vor Erststart
- **Quell-Datei:** [`NixmitGROK/modules/50-media/jellyfin.nix`](/home/moritz/repos/NixmitGROK/modules/50-media/jellyfin.nix)
- **Problem:** Bis das Python-Provisioning nach dem Boot greift, startet eine frische Jellyfin-Instanz im englischen Standard-Setup.
- **Leitfaden & Umsetzung:**
  - Ablegen von statischen XML-Vorlagen (`jellyfin-system.xml`, `jellyfin-network.xml`) via systemd `preStart` in `/var/lib/jellyfin/config/` (nur wenn die Dateien noch fehlen).
  - Platzhalter per `sed` zur Build-/Startzeit ersetzen (`PreferredMetadataLanguage = de`, `MetadataCountryCode = DE`, `UICulture = de-DE`, `PublishedServerUrl`).
  - **Nutzen:** Jellyfin begrüßt den Nutzer ab Sekunde 1 auf Deutsch mit fertiger Server-URL, noch bevor die API konfiguriert wird.

### C. MediaCover-Auslagerung auf Tier B (*arr-Dienste)
- **Quell-Datei:** [`NixmitGROK/modules/50-media/arr-helper.nix`](/home/moritz/repos/NixmitGROK/modules/50-media/arr-helper.nix)  
  *Referenz:* [`NixmitGROK/docs/guides/GUIDE-media-stack.md`](/home/moritz/repos/NixmitGROK/docs/guides/GUIDE-media-stack.md)
- **Problem:** Sonarr, Radarr, Readarr und Prowlarr speichern Millionen Miniatur-Coverbilder in `/var/lib/{arr}/MediaCover`. Das bläht Backups (z. B. Restic von `/var/lib`) auf und belastet die Tier-A-System-SSD.
- **Leitfaden & Umsetzung:**
  - Bind-Mounts der `MediaCover`-Pfade nach `${storage.metadataDir}/{arr}` (auf Tier-B-Fast-Pool/SSD).
  - In `lib/service-factory.nix` oder den Arrs:
    ```nix
    BindPaths = [ "${storage.metadataDir}/${name}:/var/lib/${name}/MediaCover" ];
    ```
  - **Nutzen:** Backups bleiben winzig (nur SQLite-Datenbanken und Configs). Cover-Bilder verbleiben auf dem Fast-Pool und können jederzeit neu gecacht werden.

---

## 2. System-Ressourcen & Dynamische Memory-/OOM-Hierarchie

### A. Dynamische Cgroup-Limits & OOMScoreAdjust
- **Quell-Datei:** [`NixmitGROK/lib/memory-policy.nix`](/home/moritz/repos/NixmitGROK/lib/memory-policy.nix)  
  *Dokumentation:* [`NixmitGROK/docs/adr/003-oom-cgroup-isolation.md`](/home/moritz/repos/NixmitGROK/docs/adr/003-oom-cgroup-isolation.md)
- **Problem:** Wenn SABnzbd mit 100 Verbindungen entpackt oder Jellyfin 4K-Streams transkodiert, kann das System in Speichermangel geraten. Ohne gezielte Hierarchie tötet der Linux OOM-Killer unvorhersehbar wichtige Systemprozesse (SSH, Caddy, Pocket-ID).
- **Leitfaden & Schutz-Hierarchie:**
  - Berechnung von `MemoryMax`, `MemoryHigh` und `OOMScoreAdjust` parametrisiert über `config.medinix.hardware.ramGB`:
  
  | Priorität / Dienst | OOMScoreAdjust | Rolle / Verhalten bei RAM-Mangel |
  |---|---|---|
  | **Pocket-ID & Ingress (Caddy)** | `-900` | **Unantastbar.** Authentifizierung und Reverse Proxy dürfen nie sterben. |
  | **Observability (Loki/Vector)** | `+200` | Gering geschützt; Logging darf bei Notstand gedrosselt werden. |
  | ***arr (Sonarr, Radarr, etc.)** | `+200` | `MemoryMax = 512M`, `MemoryHigh = 384M`. .NET-Prozesse werden eingehegt. |
  | **Audiobookshelf** | `+150` | `MemoryMax = 1G`, `MemoryHigh = 768M`. |
  | **Jellyfin** | `+100` | `MemoryMax = 6G`, `MemoryHigh = 4G`. Darf Spitzen nutzen, wird bei OOM vor Caddy beendet. |
  | **SABnzbd (Entpacker)** | `+300` | **Opferlamm.** Bei akutem Speichermangel wird SABnzbd zuerst gekillt, bevor das System instabil wird. |

- **Integration:** Verankerung in `lib/hardening-profiles.nix` und `lib/service-factory.nix`.

---

## 3. Observability-Stack: Logging & Health-Monitoring für Medien

Ein vollwertiger Medien-Stack benötigt Transparenz über Streaming-Traffic, Fehler-Spitzen und Festplatten-Status, ohne auf Cloud-Dienste angewiesen zu sein.

### A. Gatus: Visuelles Health- & Status-Dashboard
- **Quell-Dateien:** [`NixmitGROK/modules/40-observability.nix`](/home/moritz/repos/NixmitGROK/modules/40-observability.nix) & [`NixmitGROK/lib/gatus-endpoints.nix`](/home/moritz/repos/NixmitGROK/lib/gatus-endpoints.nix)
- **Konzept:**
  - Extrem schlanker Go-basierter Status-Server mit sauberem Web-UI.
  - Automatische Generierung von Endpoints für alle aktiven mediNix-Dienste:
    - HTTP-Checks auf `127.0.0.1:${port}` (Caddy, Jellyfin, Sonarr, Radarr, SABnzbd, etc.).
    - Mountpoint-Checks für Tier B (Fast Pool) und Tier C (Media Pool).
    - Lokale Socket-Checks für Ingress & SQLite.
  - Caddy vHost: `status.${domain}` mit `accessGroup = "public"` oder `accessGroup = "internal"`.

### B. Vector + Loki + Grafana: Die Medien-Logging-Pipeline
- **Quell-Datei:** [`NixmitGROK/modules/40-observability.nix`](/home/moritz/repos/NixmitGROK/modules/40-observability.nix) (Abschnitt Observability)
- **Architektur:**
  ```text
  [ Caddy JSON-Logs ] ──┐
  [ systemd journal ] ──┴─► [ Vector ] (Remap / Parse) ──► [ Loki ] ──► [ Grafana UI ]
  ```
- **Komponenten:**
  1. **Vector:**
     - Liest direkt aus `journald` (keine Datei-Puffer nötig).
     - Parst Caddy-Access-Logs per VRL (`parse_json(.message)`): HTTP-Status, Client-IP, Pfade, Upstream-Latenz.
     - Weist automatische Log-Levels zu (`>= 500 -> error`, `>= 400 -> warn`, sonst `info`).
  2. **Loki:**
     - TSDB-Schema v13 mit Filesystem-Storage auf Tier B (`/var/lib/loki`).
     - Strikte Retention von 7 Tagen (`retention_period = 168h`), automatische Compactor-Bereinigung.
     - Geringer RAM-Footprint (`MemoryMax = 1G`).
  3. **Grafana:**
     - Hört lokal auf Unix-Socket (`/run/grafana/grafana.sock`) hinter Caddy.
     - Automatisches Provisioning der Loki-Datenquelle (`datasources.settings.datasources = [ { name = "Loki"; type = "loki"; url = "..."; } ]`).
     - Vordefiniertes Dashboard für:
       - Streaming-Bandbreite & aktive Jellyfin-Streams.
       - Caddy-Fehlerraten (4xx/5xx).
       - *arr-Sync- und Importfehler.
       - SABnzbd-Download-Geschwindigkeit und Festplatten-Schreibdurchsatz.

---

## 4. Fortgeschrittenes Storage- & Spindown-Management

### A. HDD-freundliche Deferred Deletion Queue
- **Quell-Datei:** [`NixmitGROK/modules/05-deferred-ops.nix`](/home/moritz/repos/NixmitGROK/modules/05-deferred-ops.nix)  
  *Dokumentation:** [`NixmitGROK/docs/guides/GUIDE-storage-tiers.md`](/home/moritz/repos/NixmitGROK/docs/guides/GUIDE-storage-tiers.md)
- **Konzept:**
  - Löschanfragen für Tier C wandern in eine Queue auf Tier B (`${storage.mediaRoot}/delete_queue`).
  - Periodischer Timer prüft via `hdparm -C` den Status der Platten (`/dev/disk/by-label/NIXMEDIA*`):
    ```bash
    if hdparm -C "$dev" 2>/dev/null | grep -q "active/idle"; then
      # HDDs laufen ohnehin -> jetzt sicher löschen
    fi
    ```
  - Befinden sich die HDDs im `standby`, bleibt die Datei in der Queue (kein unnötiger Spinup).
  - Spätestens nach `maxAgeDays = 7` wird das Löschen beim nächsten regulären Aufwachen forciert.

### B. SMART-Monitoring & Scrutiny Web-UI
- **Quell-Datei:** [`NixmitGROK/modules/36-disk-health.nix`](/home/moritz/repos/NixmitGROK/modules/36-disk-health.nix)  
  *Dokumentation:** [`NixmitGROK/docs/guides/GUIDE-disk-health.md`](/home/moritz/repos/NixmitGROK/docs/guides/GUIDE-disk-health.md)
- **Konzept:**
  - `smartd`-Integration mit Spindown-Schonung (`-n standby`).
  - Scrutiny-Dashboard zur Visualisierung von Festplattentemperaturen, Betriebsstunden, Reallocated Sectors und Spindown-Verhalten.

### C. Label-basiertes Automounting & MergerFS
- **Quell-Datei:** [`NixmitGROK/modules/35-automount.nix`](/home/moritz/repos/NixmitGROK/modules/35-automount.nix)
- **Konzept:**
  - Automatisches Einhängen anhand von Dateisystem-Labels (`NIXDATA`, `NIXMEDIA`, `NIXBACKUP`).
  - Dynamisches Hinzufügen von Zweigen zum MergerFS-Pool ohne manuelles Bearbeiten der Host-fstab.

---

## 5. Implementierungs-Phasen für mediNix-core

| Phase | Thema | Enthaltene Komponenten | Aufwand |
|---|---|---|---|
| **Phase 16** | **Media Quick-Wins** | Audiobookshelf VA-API/QuickSync, *arr MediaCover Bind-Mounts, Jellyfin XML-Seeds | Klein |
| **Phase 17** | **Memory & OOM-Policy** | `lib/memory-policy.nix`, dynamische Cgroup-Limits via `hardware.ramGB` | Mittel |
| **Phase 18** | **Media Observability** | Gatus Health-Dashboard (`585-gatus.nix`), Vector + Loki + Grafana Pipeline (`586-logging.nix`) | Mittel |
| **Phase 19** | **Storage & Spindown** | Deferred Deletion Queue (`544-deferred-delete.nix`), Scrutiny / smartd (`578-disk-health.nix`) | Mittel |

---

## 6. Bewusst abgelehnte Elemente (Out of Scope)

Die folgenden Elemente aus `NixmitGROK` bleiben dauerhaft **ausgeschlossen**:
- **Allround-Apps:** Vaultwarden, Homepage Dashboard, Paperless-ngx, n8n, Home Assistant, Zigbee2MQTT, Forgejo, Cockpit, AMP Game Server.
- **Host-Netzwerk:** Blocky DoT DNS Resolver, AdGuardHome (gehört auf den Router/Host).
- **Zentrale Shared-DBs:** PostgreSQL, Valkey (mediNix bleibt autonom mit isolierten SQLite-Datenbanken).
