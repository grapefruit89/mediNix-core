# mediNix-core — Akzeptanz- & Freeze-Testmatrix

> **Sicherheits- & Architekturphilosophie:**
> **Defense in Depth mit begrenzter Komplexität (~90 % Schutz)**
>
> Wir schützen pragmatisch die wahrscheinlichsten und teuersten Fehlerklassen:
> - VPN-Leakage (Download-Traffic ins WAN)
> - Falsche oder versehentliche Netzwerkfreigaben
> - Unberechtigter Lese-/Schreibzugriff auf fremde Service-State-Verzeichnisse
> - Versehentliches Überschreiben oder Zerstören von Mediendateien
> - Parallele Mover-Läufe und Lock-Konflikte
> - Volllaufen der SSD oder HDDs
> - OOM-Eskalation / Systeminstabilität bei RAM-Spitzen
> - Unnötiges Aufwecken schlafender HDDs (Spindown-Schonung)
> - Aufblähen von Backups durch leicht regenerierbare Cache- und Bilddaten
>
> Extrem unwahrscheinliche Sonderfälle (Kernel-Race-Conditions, hyper-komplexe Namespace-Exploits) werden bewusst **nicht** durch zusätzliche komplexe Abstraktionen (eBPF, eigene Network Namespaces) abgefangen.

---

## 14-Punkte Freeze-Matrix (Stop-Kriterium)

Sobald diese 14 Tests auf der Zielhardware / im Testdeployment erfolgreich validiert sind, wird die Storage-, Mover- und Sandboxing-Architektur **eingefroren**. Keine weiteren Schutzebenen oder Abstraktionen mehr.

| # | Testfall | Erwartetes Verhalten | Verifikationsmethode |
|---|---|---|---|
| **1** | **SABnzbd WAN-Egress** | SABnzbd kann ausschließlich über das WireGuard-/VPN-Interface Daten laden. | Test-Download; Gegenprüfung mit `curl -4 ifconfig.me` aus dem Kontext. |
| **2** | **VPN-Killswitch** | Fällt das VPN-Interface aus oder wird gestoppt, bricht SABnzbd sofort ab (kein WAN-Leak). | `ip link set down dev <vpn>` -> Download stoppt, keine Pakete über Default-Route. |
| **3** | **Prowlarr Autonomie** | Prowlarr funktioniert uneingeschränkt direkt über WAN ohne VPN-Zwang. | Indexer-Testlauf in Prowlarr-UI. |
| **4** | **Arrs Datenpfade** | Sonarr/Radarr können ihre eigenen Konfigurationen und `/data`-Verzeichnisse lesen/schreiben. | Serien-/Film-Import und SQLite-Schreibtest. |
| **5** | **MediaCover BindPaths** | Sonarr speichert Covers im ausgelagerten SSD-Cache (`${metadataDir}/sonarr-MediaCover`). | Cover laden; `ls /mnt/ssd/cache/sonarr-MediaCover` prüfen. |
| **6** | **Peer-Isolation** | Sonarr/Radarr haben keinerlei Zugriff auf fremde State-Verzeichnisse (`/var/lib/<peer>`). | Testlesezugriff auf fremde State-Dirs schlägt mit `Permission denied` fehl. |
| **7** | **Mover Schwellwert** | Überschreitet die SSD den Schwellwert (z.B. 80%), verschiebt der Mover alte Medien auf Tier C. | Trigger mit Testdatei via `systemctl start medinix-mover`. |
| **8** | **Mover Abbruchsicherheit** | Ein Abbruch (SIGINT/SIGTERM) hinterlässt keine korrupten Zieldateien. | `kill -15` während Transfer; Temp-Datei `.staging_mover/tmp_*` wird isoliert bereinigt. |
| **9** | **Kein blindes Überschreiben** | Existiert die Zieldatei bereits identisch auf HDD, wird die Quelle ohne erneuten Transfer dedupliziert/bereinigt. | Testtransfer mit bestehender Zieldatei gleicher Größe/Hash. |
| **10** | **Mover Mutex / Concurrency** | Zwei parallele Mover-Starts blockieren sich gegenseitig (nur eine Instanz aktiv). | Zweiter Start via `flock` beendet sich sofort ohne Fehler. |
| **11** | **HDD-Kapazitätsschutz** | Hat die HDD nicht genügend freien Speicherplatz, bricht der Mover ab; Quelldatei auf SSD bleibt unberührt. | Test mit simulierter voller HDD; Quelldatei bleibt 100% erhalten. |
| **12** | **Keine doppelten Libraries** | Jellyfin greift ausschließlich auf den logischen Pfad `/data` (MergerFS) zu; Verschieben von SSD auf HDD erzeugt keine Duplikate. | Medien scannen vor und nach Mover-Lauf in Jellyfin. |
| **13** | **Spindown-Schonung** | Befinden sich HDDs im Standby, weckt die periodische SMART-Prüfung (`smartd -n standby,q`) sie nicht auf. | `hdparm -y /dev/sdX` -> Warten auf smartd-Intervall -> `hdparm -C` prüfen. |
| **14** | **OOM-Schutzhierarchie** | Bei künstlicher RAM-Verknappung opfert der Kernel SABnzbd (`+300`) vor Jellyfin (`+100`) und schützt Caddy (`-900`). | Stress-Test mit `stress-ng --vm`; Caddy und Pocket-ID bleiben unterbrechungsfrei erreichbar. |
