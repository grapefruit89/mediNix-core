# RUNBOOK — mediNix-core (Betrieb & Triage)

> **Ein Runbook, viele Knöpfe.** Jedes Symptom ist ein *Playbook* mit
> maschinenlesbarem Kopf (`id`, `symptom`, `bereich`, `chain`, `paths`, `error_pattern`, `fix`).
> Eine KI liest **nur diese Datei** und kann jeden Fall in 1–2 Befehlen abarbeiten —
> ohne zu suchen, wer/was/wohin gehört.
>
> **Quelle der Wahrheit:** IDs/Ports/UIDs/stateDirs kommen aus `lib/registry.nix`;
> die Playbooks aus **`lib/runbook.json`** (das CLI liest dieselbe Datei).
> §5 wird daraus **generiert** (`scripts/gen_runbook.py`), nicht von Hand gepflegt.

## 0. Die Knöpfe (alles über `medinix`)

| Befehl | Zweck |
|---|---|
| `medinix ids <50..59>` | **DER eine Befehl**: Ist-IDs eines Bereichs (Unit · Port · UID:GID · stateDir · Rechte) |
| `medinix show <service>` | Ein Dienst, volle Fakten + letzte 30 Log-Zeilen |
| `medinix logs <service> [n]` | journale Abfrage (systemd-nativ) |
| `medinix triage <bereich\|service\|symptom>` | **Knopf**: arbeitet die Playbook-Kette ab |
| `medinix check` · `repair` · `status` | Sammel-Status / Restart / Tabelle |

Typischer Ablauf einer KI: `medinix triage jellyfin-no-cover` → fertig.

---

## 1. Deploy & First Boot

1. **Immer erst Dry-Run** (Assertions sind fail-closed → sofortiger Abbruch):
   `nixos-rebuild dry-run --flake .#check`
2. `nixos-rebuild switch --flake .#check`
3. Verify: SSH `:22` erreichbar, dann `medinix check`.

**First-Boot-Guard:** Jellyfin muss seine SQLite (`ActivityLog` …) **unseeded**
initialisieren. Ein vorab gesetztes `system.xml` löst eine Migration gegen eine
noch nicht existierende DB aus (Lehre **L7**) → siehe `55-playback/551-jellyfin.nix`.

---

## 2. Logs lesen (journald)

- **Alles** landet in journald: jede Unit (stdout/stderr), Kernel, syslog.
- Ein Dienst: `journalctl -u <unit>.service -n 100 --no-pager`
- Live: `journalctl -u <unit>.service -f`
- Zeitfenster: `journalctl --since "30 min ago" -u <unit>.service`
- Größe/Grenzen/Grenzfälle: **§7**.

---

## 3. Dienst startet nicht / Unit down

1. `medinix show <service>` → `ActiveState`, `SubState`, `MainPID`, `User`, `Group`.
2. `systemctl status <unit>.service --no-pager`
3. Bekannte Fallen (alle schon einmal teuer gelernt):
   - `IPAddressDeny = [ "any" ]` blockt **127.0.0.1** (Inter-Service). Nutze
     `RestrictNetworkInterfaces = [ "lo" ]`.
   - .NET/Node brauchen `MemoryDenyWriteExecute = false` (JIT).
   - Jellyfin-GPU braucht `PrivateDevices = false` (sonst ist `/dev/dri` unsichtbar).
   - `LoadCredentialEncrypted` + `ProtectSystem = strict` → Pfad-Freigaben prüfen.
   - Ein NixOS-Modul darf auf oberster Ebene nur `imports`/`options`/`config` haben.
4. Rechte/Pfade: **§4**.

---

## 4. Identität, UID/GID & Pfade

**Dezimalrahmen (ADR-0000):** `Port = UID = Primär-GID = Num × 10`.
- `media` (GID 5000) **nur** als `extraGroups` — **nie** Primärgruppe.
- `stateDir = /var/lib/<name>` **ohne** Port-Suffix (ADR-0000 §9).
- Geteilte Ablagen: `2775 root:media` (**SetGID**) → neue Dateien erben `media`.
- Ein Befehl für alles: `medinix ids <bereich>`.

### §4b — UID/GID-Migration auf ein BESTEHENDES System
`mutableUsers = true` → NixOS **nummeriert bestehende Benutzer nicht um**. Nach dem
Setzen fester UIDs meldet der Switch nur „*not applying UID change of user 'X'
(alt → neu)*"; die State-Dateien gehören dann noch der **alten** UID → beim Start
**`permission denied`**. → einmalig `scripts/migrate-uids.sh` (usermod/groupmod + chown).
Auf einer **frischen** Installation nicht nötig.

---

## 5. Symptom-Playbooks (maschinenlesbar)

<!-- RUNBOOK-PLAYBOOKS START -->
**Generiert** aus [`lib/runbook.json`](../lib/runbook.json) (SSoT) — nicht von Hand
pflegen. Das CLI liest dieselbe Datei; neu erzeugen: `python3 scripts/gen_runbook.py`,
pruefen: `--check` (laeuft in `order-lint`).

Aufruf je Knopf: `medinix triage <id>` (oder `medinix triage <bereich|service>`).

### `404-am-edge` — Domain erreichbar, aber 404/502 am Caddy

```json
{
  "404-am-edge": {
    "bereich": "51",
    "chain": [
      "caddy-media"
    ],
    "error_pattern": "404|502|dial tcp|connection refused",
    "fix": "medinix show <svc>: lauscht der Backend-Port auf 127.0.0.1:<port>? vhost/Manifest pruefen",
    "paths": [
      "/etc/caddy-media/Caddyfile"
    ],
    "symptom": "Domain erreichbar, aber 404/502 am Caddy"
  }
}
```

### `deploy-assert` — nixos-rebuild bricht mit Assertion ab

```json
{
  "deploy-assert": {
    "bereich": "00",
    "chain": [],
    "error_pattern": "assertion|error:",
    "fix": "Assertion-Meldung nennt Invariante + Fix; NICHT forcieren (docs/RUNBOOK.md 1)",
    "paths": [],
    "symptom": "nixos-rebuild bricht mit Assertion ab"
  }
}
```

### `jellyfin-no-cover` — Jellyfin zeigt keine Cover

```json
{
  "jellyfin-no-cover": {
    "bereich": "55",
    "chain": [
      "jellyfin",
      "caddy-media"
    ],
    "error_pattern": "ImageMagick|convert: not found|Permission denied|No such file",
    "fix": "imagemagick ins PATH; Rechte 2775 root:media; Jellyfin-Metadata-Cache leeren",
    "paths": [
      "/data/media",
      "/data/metadata",
      "/var/lib/jellyfin"
    ],
    "symptom": "Jellyfin zeigt keine Cover"
  }
}
```

### `jellyfin-slow` — Jellyfin ruckelt / laedt langsam

```json
{
  "jellyfin-slow": {
    "bereich": "55",
    "chain": [
      "jellyfin",
      "caddy-media",
      "medinix-mdns-aliases"
    ],
    "error_pattern": "transcode|VA-API|device|Timeout|SQLite|database is locked",
    "fix": "/dev/dri sichtbar (PrivateDevices=false)? DB-WAL (571) ok? Disk-IO (587)?",
    "paths": [
      "/data/media"
    ],
    "symptom": "Jellyfin ruckelt / laedt langsam"
  }
}
```

### `no-lan-name` — {dienst}.local nicht erreichbar

```json
{
  "no-lan-name": {
    "bereich": "51",
    "chain": [
      "caddy-media",
      "medinix-mdns-aliases"
    ],
    "error_pattern": "avahi|publish|userServices|5353",
    "fix": "services.avahi.publish.userServices = true; avahi-daemon aktiv; UDP 5353 offen",
    "paths": [],
    "symptom": "{dienst}.local nicht erreichbar"
  }
}
```

### `secret-missing` — Dienst startet nicht: Credential fehlt

```json
{
  "secret-missing": {
    "bereich": "52",
    "chain": [],
    "error_pattern": "LoadCredential|credential|No such file|CREDENTIALS_DIRECTORY",
    "fix": "Blob vorhanden? systemd-creds entsiegeln; scripts/medinix-seal-secret.sh",
    "paths": [
      "/run/credentials"
    ],
    "symptom": "Dienst startet nicht: Credential fehlt"
  }
}
```

### `service-down` — Unbekannt - welcher Dienst ist down?

```json
{
  "service-down": {
    "bereich": "00",
    "chain": [],
    "error_pattern": "failed|ActiveState=inactive|start request repeated too quickly",
    "fix": "medinix ids <bereich> + medinix logs <unit> 100",
    "paths": [],
    "symptom": "Unbekannt - welcher Dienst ist down?"
  }
}
```

<!-- RUNBOOK-PLAYBOOKS END -->

---

## 6. Bereichs-Knöpfe

| Bereich | Inhalt | Knopf |
|---|---|---|
| 50-core | Baseline/Journald, Engine, Host-Integration | `medinix triage 50` |
| 51-ingress | Caddy · Pocket-ID · DDNS · ACME · mDNS · CrowdSec | `medinix triage 51` |
| 52-security | Core-Security · Creds · WireGuard · Killswitch | `medinix triage 52` |
| 53-acquisition | Sonarr · Radarr · Readarr · Lidarr · Prowlarr | `medinix triage 53` |
| 54-transfer | SABnzbd · Mover | `medinix triage 54` |
| 55-playback | Jellyfin · Audiobookshelf · Navidrome · Feishin | `medinix triage 55` |
| 56-exposition | Seerr | `medinix triage 56` |
| 57-maintenance | Storage · SQLite-WAL · Recyclarr · Backup · Drift | `medinix triage 57` |
| 58-observability | ntfy · Gatus · Runtime-Guard · Exporter · smartd | `medinix triage 58` |
| 59-guardrails | Cross-Domain-Assertions | `medinix triage 59` |

---

## 7. Log-Mengen & Grenzen (kein GB-Flood)

Quelle: `50-core/500-host-baseline.nix` → `systemd/journald.conf.d/10-mediNix.conf`:

```
[Journal]
Storage=persistent
SystemMaxUse=500M      # HARTE Kappe: Journal wird NIE größer
SystemMaxFileSize=50M
SystemKeepFree=2G      # hält zusätzlich 2 G Platte frei
MaxRetentionSec=2week
RateLimitIntervalSec=0 # kein Verwerfen von Zeilen
RateLimitBurst=0
```

- **Trade-off:** Rate-Limit aus + *arr auf `debug` = mehr Zeilen/Zeit → die 500 M
  füllen sich **schneller** → **kürzere Historie** (nicht mehr Platz).
- ***arr-Datei-Logs**: je ~1 MB × max. 51 Dateien ≈ **~50 MB pro App** (gedeckelt).
- **Erster Schritt auf der Maschine** (Ausgangscheck):
  ```bash
  journalctl --disk-usage
  journalctl -o json --since today --no-pager | jq -r '._SYSTEMD_UNIT' | sort | uniq -c | sort -rn | head
  du -sh /var/lib/*/logs 2>/dev/null | sort -h
  ```
- **Nachstellen:** zu schnell voll → `SystemMaxUse` auf z. B. `1G` **oder** *arr
  zurück auf `info`.

---

*Bei Unsicherheit gilt: messen → verstehen → Diff vorlegen → Go. Nicht raten.*
