# ADMIN-HANDOFF — Host-Verantwortung (Single Source of Truth)

mediNIX-core ist ein **portables NixOS-Modul** (Flake). Es liefert nur portable Logik:
Optionen + Assertions + Defaults. Alles was der Host liefern oder entscheiden muss,
steht **ausschließlich hier**. Keine verstreuten Host-Hinweise in AGENTS.md, README,
Modul-Kommentaren oder zweiten "q958.md"-Dateien. Das Flake ist ohne jede Host-Annahme
nutzbar — wer es einbindet, weiß allein über diese Datei, was er noch setzen muss.

---

## 1. Binary-Cache / Substituters (KRITISCH — verhindert Kompilierung)
**Ziel: Auf dem Zielhost wird NICHTS kompiliert. Nur absoluter Notfall-Build.**

```nix
# Host-configuration.nix
nix.settings = {
  substituters = [
    "https://cache.nixos.org"
    # Optional: eigener Fallback-Cache falls vorhanden
  ];
  trusted-substituters = [ "https://cache.nixos.org" ];
  # max-jobs = 0 würde mediNIX-cli Package-Build blockieren → NICHT setzen.
  # Nur substituters priorisieren, Build nur im Notfall auf anderem Rechner + nix copy.
};
```
Falls ein Package nicht im Cache ist: `nix build` auf schnellem Rechner,
Ergebnis via `nix copy --to ssh://root@<host>`.

---

## 2. Impermanence / Persist-Pfade + Backup
mediNIX-core erzwingt KEINE Impermanence. Stateless-Root ist Host-Entscheidung.
Wenn gewünscht:
- `tmpfs` auf `/` (oder impermanence-Flake)
- `persist`-Modul für `/nix/persist`, `/var/lib/*`, Secrets
- **Diese StateDirs müssen persistiert werden** (sonst Daten weg nach Reboot):
  `/var/lib/*-5xxx` (alle Media-Services), `/var/lib/ mediNix-state`

**Geplant (Roadmap, nicht im Modul):** `INV-STORE-xx` Guardrail — Build bricht wenn ein
State-Pfad außerhalb der Tier-Whitelist auftaucht (Impermanence-Whitelist-Ansatz).

### 2a. Restic-Backup (opt-in: `maintenance.backup.enable`)
Modul: `576-backup.nix`. Sichert nur die Media-StateDirs (`/var/lib/<name>-<port>`)
+ `secretsDir` — **nicht** blind ganz `/var/lib` (Ballast). Vor dem Backup werden die
Dienste gestoppt (DB-Safety, Pre/Post via `systemctl stop/start <plain-unit>`).
Retention: 7 täglich / 4 wöchentlich / 6 monatlich (`pruneOpts`).
Transcodes/Caches/incomplete ausgeschlossen.

**Host liefert:** `maintenance.backup.repository` (z.B. `/mnt/backup/restic` oder SFTP)
+ `maintenance.backup.passwordFile` (Pfad zur restic-Key-Datei, TPM/Host-Secret).
Ohne beide → Assertion bricht Build.

**Restore (Beispiel):**
```
# Repository initialisieren (einmalig auf Host):
restic -r <repository> --password-file <pwfile> init
# Snapshots auflisten:
restic -r <repository> --password-file <pwfile> snapshots
# Einzelnes StateDir restoren (Dienst vorher stoppen!):
systemctl stop sonarr
restic -r <repository> --password-file <pwfile> restore latest \
  --target / --include /var/lib/sonarr-5320
systemctl start sonarr
```

---

## 3. Storage-Mounts (ABC-Tiering physisch)
mediNIX-core definiert nur **logische** Pfade (`lib/abc-tiering.nix`):
- Tier A (NVMe/SATA-SSD): `/var/lib` → schnelle Platte
- Tier B (SATA-SSD): `storage.mediaRoot/downloads` → aktive Downloads
- Tier C (HDD, Spindown): `storage.mediaRoot/library` → Archiv

**Physische Zuordnung ist Host-Sache** — Mountpoints in Host-`configuration.nix` setzen.
`storage.mediaRoot` / `storage.metadataDir` sind Optionen (Default `/data/media`, `/data/cache`).

### 3a. Mover (ondemand, kein Timer)
`mover.enable` + `mover.mode = "ondemand"` (Default). Kein Calendar-Timer — die HDD soll
schlafen. Der Mover ist ein `systemd`-oneshot (`mediNix-mover`), der **nur bei Bedarf** läuft:
- **Trigger:** `systemd.path` beobachtet `stagingDir` (PathChanged/DirectoryNotEmpty) = Klingel
  ohne Uhr — aktiv sobald `mover.enable = true`. `minFreeGb` im Script bleibt die Bremse
  (bei genug Platz: exit 0, HDD bleibt in Ruhe). Wer nur manuell will: Mover per
  `systemctl start mediNix-mover` starten (Path-Unit unabhängig abschalten falls gewünscht).
- **Action:** nur `move` (SSD frei, HDD = kanonisch). Kein `copy` (doppelter Platz, widerspricht Ziel).
- **Optional Jellyfin-Refresh:** nicht im Modul. Bei move ohne Host-mergerfs "springen" physische
  Pfade — Jellyfin muss dann neu scannen (UI/_arr→Jellyfin Connect). Mit mergerfs (stabiler
  logischer Pfad) entfällt das. Modul bleibt quiet, kein API-Key-Gefrickel an der Unit.
- Service-Unit hat `StartLimitBurst=3`/`StartLimitIntervalSec=60` (begrenzt reale Starts, nicht nur
  Logs — Journal-RateLimit drosselt nur Log-IO).
- Im Script: `df`-Check auf `mover.stagingDir` — erst wenn freier Platz < `mover.minFreeGb`
  werden Dateien (Whitelist `mover.mediaExtensions`, >= 50MB) nach `mover.archiveDir`
  verschoben (`action = "move"`, SSD wird frei; Hardlink SSD↔HDD unmöglich — cross-device).
- **Library-Pfade:** Bei `action = "move"` ändert sich der physische Ort der Datei. **Ohne**
  Host-mergerfs (gleicher logischer Pfad) müssen Sonarr/Radarr/Jellyfin neu scannen, sonst
  zeigen Imports/Streams auf tote Pfade. Mit mergerfs (§3b) bleibt der logische Pfad stabil.
- Playback-Dienste (Jellyfin/Audiobookshelf/Navidrome/Feishin) dürfen Tier-C lesen (Streaming);
  *arr/Indexer/Download halten die HDD nicht wach.

### 3b. mergerfs (optional, Host-seitig — NICHT im Modul)
Empfohlen wenn Jellyfin **eine** Library-UI haben soll statt zwei Pfade:
```
# Host-configuration.nix (Beispiel, nicht vom Modul erzeugt):
services.mergerfs = {
  enable = true;
  mounts."/srv/media" = {
    fsname = "media";
    branches = [ "/mnt/ssd/library" "/mnt/hdd/library" ];  # SSD + HDD
    options = [ "defaults" "allow_other" "category.create=ff" "minfreespace=20G" ];
  };
};
```
- **Vorteile:** ein Library-Root (Jellyfin zeigt auf `/srv/media`), Creates landen auf SSD
  (`category.create=ff` → first-found/freespace), große Files auf HDD. Mover kann physisch
  verschieben ohne Pfadbruch in der UI (logischer Pfad bleibt stabil).
- **Fallstricke:** Scans können HDD wecken; FUSE-Overhead; Spin-down-Politik (hdparm) bleibt
  Host; Hardlinks über Branches verhalten sich nicht wie lokal.
- Mover: weiter Modul-oneshot bei wenig Freiplatz — unabhängig ob Union oder zwei Pfade.
- **Nicht** ins portable Flake ziehen: Mounts/Branches/minfreespace/Paket/Spin-down sind Host
  (jede Maschine anders, ohne FUSE kein Eval-Start → Portabilität bricht).

---

## 4. VPN-Interface + UID-Routing (Usenet-Sandbox)
**Policy-Routing wohnt im Modul** (`526-vpn-policy-routing.nix`): UID-basierte Routing-Tabellen
(= UID: 5410 SABnzbd, 5360 Prowlarr) + `routingPolicyRules` (uidrange → lookup Tabelle) +
Default-Route `dev ${vpn.interface}` + fail-closed `unreachable` in der Tabelle. Kein netns,
kein Host-ip-rule-Kochrezept. Modul erfindet KEIN `networking.interfaces`.

**Host liefert nur:**
- Das WireGuard-Interface (z.B. `wg0`) + VPN-Keys (Host-Secret-Store)
- `grapefruitMedia.vpn.interface = "wg0";` (Name des Interfaces)
- `grapefruitMedia.vpn.dnsServers = [ "10.8.0.1" ];` (oder `127.0.0.1` bei DoT-Stub)
- `grapefruitMedia.sabnzbd.enable = true;` + `grapefruitMedia.prowlarr.enable = true;`

**Test:** Interface down → als `sabnzbd`-User darf kein Byte raus (`curl` als sabnzbd-User schlägt fehl,
DNS darf nicht resolven). Fail-closed: confinement an ohne interface/dns → Build bricht.

### 4a. Encrypted DNS (DoT/DoH) — Host liefert, Modul implementiert NICHTS
mediNIX-core schreibt nur `resolv.conf` mit `vpn.dnsServers` in die Sandbox
(`RestrictNetworkInterfaces = [ "lo" vpnIf ]` + `BindReadOnlyPaths` auf eigene resolv.conf).
**Kein DoT/DoH-Daemon im Modul** (stubby/unbound/cloudflared bleiben Host-Territorium).

Drei Varianten für `vpn.dnsServers`:
- **Variante A (VPN-Provider-DNS):** `dnsServers = [ "10.8.0.1" ]` (VPN-interner Resolver, nur tunnel-intern)
- **Variante B (Host-DoT-Stub):** Host betreibt stubby/cloudflared/nextdns lokal auf 127.0.0.1
  → `dnsServers = [ "127.0.0.1" ]` + confinement
- **Variante C (networkd-DNS):** WireGuard-Interface bekommt DNS via systemd-networkd
  → Modul konsumiert nur die Adressen, Host setzt `vpn.dnsServers` entsprechend

Hinweis: Es gibt KEINE `dnsMode`-Option mehr. Das Modul baut resolv.conf immer gleich aus
`dnsServers` — encrypted DNS ist reine Host-Entscheidung (DoT-Stub auf 127.0.0.1 oder
VPN-Provider-DNS). Kein Codepfad hängt an einer Mode-Angabe.

### 4b. Runtime-Verify & ipify-Abhängigkeit (Ergänzung, kein Ersatz)
Der eigentliche Kill-Switch ist **systemd `RestrictNetworkInterfaces`** plus **Host-UID-Policy-Routing**.
Der Verify-Service (`usenet-vpn-verify.service` in 525) ist eine **ergänzende Laufzeit-Prüfung**
(gleicht Host-IP vs. VPN-IP via ipify ab und stoppt Usenet-Stack bei Leak-Gefahr).
Einschränkung: Verbraucht externe HTTPS-Anfrage (ipify) und braucht Netz. Daher:
- Der Kill-Switch funktioniert rein lokal ohne ipify (durch RestrictNetworkInterfaces).
- Verify ist nur eine defensive Zusatzschicht. Im reinen Offline-Betrieb ohne ipify-Zugang
  kann Verify fehlschlagen, auch wenn der Tunnel steht. (Kann bei Bedarf angepasst werden).

---

## 5. ACME / TLS-Zertifikate (flake-managed ab Phase 2)

`security.acme` wird **vom Modul** konfiguriert (`51-ingress/514-acme.nix`) sobald
`ingress.tls.acmeHost` gesetzt ist — kein manuelles `security.acme` im Host mehr nötig.

**Host liefert nur den Cloudflare-API-Token** (als TPM-gesiegeltes `.cred`-File):

```nix
grapefruitMedia = {
  ingress.tls.acmeHost      = "example.com";   # erzeugt *.example.com Wildcard
  ingress.tls.acmeCredential = "/var/lib/credstore.encrypted/cf-acme.cred";
  # Token-Format (vor Verschlüsselung): CF_DNS_API_TOKEN=<token>
};
```

Token-Priorität (erstes Non-null gewinnt):
1. `ingress.tls.acmeCredential` — dediziertes ACME-Cred (empfohlen)
2. `dns.ddns.cloudflareTokenCredential` — shared Cloudflare-Cred (DDNS-Reuse)
3. `dns.ddns.tokenCredential` — Legacy-Alias
4. `dns.ddns.tokenFile` — Plaintext-Fallback (nicht TPM-gesiegelt)

**Cred erzeugen:**
```bash
echo "CF_DNS_API_TOKEN=<token>" > /tmp/cf-token.env
systemd-creds encrypt --with-key=tpm2+host /tmp/cf-token.env \
  /var/lib/credstore.encrypted/cf-acme.cred
rm /tmp/cf-token.env
```

Caddy liest das Zertifikat automatisch aus `/var/lib/acme/<acmeHost>/fullchain.pem`.
DNS-01-Challenge — kein Port-80/443-WAN-Öffnen nötig.

---

## 6. Secrets-Erzeugung (systemd-credentials, TPM-Stufe vorbereitet)

mediNIX-core nutzt **natives systemd-credentials** — kein sops/agenix-Zwang im Modul.
(INV-SECRET prüft: keine `/nix/store/`-Pfade als Secret-Quelle.)

### Stufe 1 (jetzt, Standard)
Host legt Secret-Dateien unter `cfg.secrets.secretsDir` (eng: `chmod 600`, Owner `media`/root).
Unit referenziert via `LoadCredential = name:/pfad/zur/datei` und die App liest `%d/name`
(`/run/credentials/<unit>/name` — tmpfs, nicht im Nix-Store).
Beispiel: `LoadCredential = mediNix-sabnzbd-api:/var/lib/media-secrets/sabnzbd-api.key`

### Stufe 2 (später, optional — TPM)
Gleiche Credential-Namen in der Unit, nur `LoadCredential` → `LoadCredentialEncrypted`:
```bash
systemd-creds encrypt --with-key=tpm2+host my-secret.env my-secret.env.encrypted
# Unit: LoadCredentialEncrypted = mediNix-sabnzbd-api:/var/lib/media-secrets/sabnzbd-api.key.encrypted
```
App merkt nichts (gleiche `%d/name`-Logik). Verschlüsselung ist Host-Job, kein Modul-Refactor.
**TPM ist Ausbaustufe, kein Blocker für Tag 1.**

### Vorbereitung (jetzt umsetzbar)
- Stabile Credential-Namen pro Zweck: `mediNix-sabnzbd-api`, `mediNix-restic-password`,
  `mediNix-jellyfin-admin`, `mediNix-cf-token`, …
- Units nutzen `%d/name`, keine hardcodierten Host-Pfade im App-Innern.
- Host-Pfad nur in `LoadCredential=name:/pfad` (oder `cfg.secrets.*`).

Betroffene Secrets: `sabnzbdApiKeyFile`, `prowlarrApiKeyFile`, `jellyfinAdminPasswordFile`,
`navidromeOidcFile`, `jellyseerrEnvFile`, Cloudflare-Token, SSH-Keys, Restic-Password.

### Nicht tun
- ❌ Secrets in `environment = { KEY = "klartext" }` (inline)
- ❌ sops-nix als Flake-Input erzwingen (nur Host-seitig optional)
- ❌ Vault / Docker-Secrets / eigene Krypto-Wrapper
- ❌ drei parallele Secret-Stacks

---

## 7. SSH / Notfall-Zugang (Empfehlung, kein Modul-Zwang)
mediNIX-core ändert SSH nicht. Empfehlung:
```nix
services.openssh = {
  enable = true;
  settings = {
    PasswordAuthentication = false;
    PermitRootLogin = "no";
  };
};
```

---

## 8. Firewall-Grundlage (Host-seitig)
mediNIX-core verzichtet auf eigene Firewall-Regeln (Additive Host Integration). Die **Basis**
(SSH-Zugriff, LAN-Regeln) ist Host-Config. mediNIX ergänzt nur mediNIX-spezifische Regeln.

---

## 9. Checkliste vor dem ersten `nixos-rebuild switch`
- [ ] Binary-Cache — wird vom Modul als Default gesetzt (§1), kein Host-Eintrag nötig
- [ ] Storage-Mounts vorhanden + gemountet (§3)
- [ ] `ingress.tls.acmeHost` + `acmeCredential` gesetzt, Cloudflare-Cred erzeugt (§5)
- [ ] TPM-Secrets verschlüsselt + Pfade in Modul-Optionen (§6)
- [ ] VPN-Interface + `cfg.vpn.dnsServers` + `cfg.vpn.interface` gesetzt (§4, nur bei Usenet)
- [ ] SSH-Hardening aktiv (§7)
- [ ] `nix flake check .#checks.x86_64-linux.nixos-check` läuft sauber
- [ ] CrowdSec-Hash ermittelt falls `observability.crowdsec.enable = true` (siehe docs/CROWDSEC-HASH.md)

---

## 10. Bekannte Fallstricke
- **Hairpin-NAT:** Wenn Dienste über Domain von LAN aus nicht erreichbar → Router-Hairpin fehlt.
- **mDNS vs. Domain:** `.local` (Avahi) nie in Cloudflare/ACME mischen.
- **UID-Routing:** Bei VPN-Isolation muss der Host das Interface UP haben (sonst blockiert mediNIX).
- **State-Pfade:** Bei Impermanence müssen alle `/var/lib/*-5xxx` persistiert werden (§2).

---

## mediNIX-core liefert (NICHT Host-Pflicht)
- ✅ Alle Media-Services (systemd-native, gehärtet, dezimal-gerahmt)
- ✅ Caddy-Ingress (Chameleon), Pocket-ID, Cloudflare-DDNS
- ✅ Guardrails (Invarianten/Errors, fail-closed)
- ✅ SQLite-WAL/optimize, Mover, Provisioning, Backup, Orphan-Cleanup (opt-in)
- ✅ RuntimeDirectory/tmpfs für SABnzbd/Jellyfin (transcode/incomplete)

## Host-Admin liefert (HIER, nicht im Modul)
- ✅ Binary-Cache-Config (Modul-Default, Override möglich)
- ❌ Impermanence + Persist-Pfade (§2)
- ❌ Tier-Hardware-Mounts (§3)
- ❌ VPN-Interface + WireGuard-Keys + Credential-Erzeugung (§4)
- ❌ Cloudflare-API-Token als `.cred`-File (§5)
- ❌ TPM-Secrets-Verschlüsselung für alle anderen Dienste (§6)
- ❌ SSH-Hardening, nftables-Basis (§7, §8)
