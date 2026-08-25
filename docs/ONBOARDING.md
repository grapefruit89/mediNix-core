---
id: "ONBOARDING"
title: "ONBOARDING"
domain: 50
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - general
links:
  adr: ""
  repo-harvest: ""
---
# mediNix-core — q958 Onboarding Checklist

Vor dem ersten `nixos-rebuild switch` auf q958 (192.168.2.73) — strukturell
vorbereiten, sonst failen die Runtime-Asserts oder Dienste starten nicht.

## Vor dem ersten Build

- [ ] `security.acme` in der Host-Config konfiguriert (DNS-01, Cloudflare API-Token, Wildcard `*.m7c5.de`)
- [ ] `/var/lib/acme/m7c5.de/` existiert mit `cert.pem` + `key.pem` (von Lego erzeugt)
- [ ] Tier-B Pfad gemountet: `${cfg.storage.mediaRoot}/downloads/` auf SSD (für SABnzbd temp)
- [ ] Tier-C Pfad gemountet: `${cfg.storage.mediaRoot}/library/` auf HDD-Array (finale Mediathek)
- [ ] `${cfg.storage.metadataDir}` zeigt auf SSD (nicht HDD — Jellyfin/ABS Metadaten sind I/O-heavy)
- [ ] systemd-credentials für API-Keys vorbereitet: `systemd-creds encrypt apikey.txt apikey.cred`
- [ ] `cfg.vpn.interface` gesetzt wenn `usenet-confinement.enable` (WireGuard ns muss existieren)
- [ ] `cfg.secrets.*ApiKeyFile` Pfade zeigen auf die `.cred`-Dateien (LoadCredentialEncrypted)
- [ ] SSH-Keys für `media-admin` + `backup` User in `security.emergencyUser.sshKeys` / `security.backupSsh.sshKeys`

## Secrets einrichten (einmalig auf q958)

Alle Secrets werden mit **TPM2 verschlüsselt** und als `.cred`-Dateien gespeichert.
Die `.cred`-Dateien können ins Repo — sie sind ohne DIESES TPM wertlos.

### Workflow
```bash
# 1. Secret als Plaintext vorbereiten (nur kurz, dann löschen)
echo "mein-cloudflare-token" > /tmp/cf-token.txt

# 2. Mit TPM verschlüsseln
systemd-creds encrypt --with-key=tpm2+host \
  /tmp/cf-token.txt \
  /var/lib/systemd/credential.d/mediNix-cf-token.cred

# 3. Plaintext löschen
shred -u /tmp/cf-token.txt

# 4. In configuration.nix referenzieren (nie den Inhalt!)
medinix.dns.cloudflareTokenCredential =
  "/var/lib/systemd/credential.d/mediNix-cf-token.cred";
```

### Secrets-Liste (alle verschlüsseln)
| Datei | Inhalt |
|-------|--------|
| mediNix-cf-token.cred | Cloudflare API Token |
| mediNix-wg-privkey.cred | WireGuard Private Key |
| mediNix-sabnzbd-server.cred | Usenet-Provider Credentials |
| mediNix-jellyfin-admin.cred | Jellyfin Admin-Passwort |
| mediNix-sonarr-apikey.cred | Sonarr API Key |
| mediNix-radarr-apikey.cred | Radarr API Key |
| mediNix-prowlarr-apikey.cred | Prowlarr API Key |
| mediNix-pocketid-secret.cred | Pocket-ID OIDC Secret |
| mediNix-crowdsec-enroll.cred | CrowdSec Enrollment Key |

### INV-SECRET (Build-Zeit-Garantie)
Kein Secret-Pfad darf im Nix-Store liegen (`/nix/store/...`). `599-cross-domain.nix`
prüft das via `INV-SECRET` Invariante. Violation → Build-Abbruch.

## Nach dem ersten Build

- [ ] `nix flake check .#checks.x86_64-linux.nixos-check` — darf nicht fehlschlagen
- [ ] `systemctl status jellyfin-5510 audiobookshelf-5520 navidrome-5530 feishin-5540`
- [ ] Caddy erreichbar: `curl -I https://jellyfin.m7c5.de`
- [ ] Sonarr: `curl -I http://127.0.0.1:5320` (LAN only — von außen blockiert durch Caddy `internal`-Template)
- [ ] ntfy (falls `observability.ntfy.enable`): `curl -I https://ntfy.m7c5.de`
- [ ] 574-provisioning abgewartet: `journalctl -u mediNix-provisioning` (registriert SABnzbd + Prowlarr in *arr)
- [ ] Arr-Apps: Settings → Connect → Ntfy manuell eintragen (Server `http://127.0.0.1:5810`, Topic aus `observability.ntfy.topic`)

## Bekannte Fallstricke

- **CrowdSec:** Caddy-Plugin-Hash (`caddy-cs-bouncer`) muss vor erstem Build via `nix build` ermittelt und in `511-caddy.nix` (`services.caddy.package` bei `observability.crowdsec.enable`) eingetragen werden. Aktuell `lib.fakeHash` als Platzhalter — Build-Fehler zeigt den korrekten Hash. Nur nötig wenn `observability.crowdsec.enable = true`.

  Hash ermitteln (einmalig auf q958):
  ```bash
  nix build --impure --expr \
    '(import <nixpkgs> {}).caddy.withPlugins {
      plugins = ["github.com/crowdsecurity/caddy-cs-bouncer@latest"];
      hash = "";
    }' 2>&1 | grep "got:"
  ```
  Den ausgegebenen Hash in `511-caddy.nix` (`hash = "..."`) eintragen.

- **Jellyfin:** Admin-Passwort aus `cfg.secrets.jellyfinAdminPasswordFile` — Datei muss vor Start existieren (LoadCredentialEncrypted). Ohne Datei: Jellyfin startet, aber Web-UI blockiert beim First-Run.
- **SABnzbd:** startet mit `-b 0` (kein daemon-fork) — `Type=simple` ist korrekt, nicht `forking`. `TimeoutStopSec=30` (Harvester #992: graceful-stop sonst kill-loop).
- **Audiobookshelf:** Port=5520 via Env-Var `PORT` gesetzt, NICHT in der App-Config. App bindet sonst 8000.
- **Navidrome:** `media`-group via `extraGroups = mkAfter [ "media" ]` — sonst leere Bibliothek OHNE Fehlermeldung (stiller Fail).
- **Feishin:** statische SPA, kein Prozess. Caddy `file_server` + `try_files {path} /index.html` Pflicht für Deep-Links. Braucht Backend (Navidrome/Jellyfin).
- **Hardening:** alle Dienste nutzen `lib/hardening-profiles.nix` (dotnet/python/nodejs/network/script). `PrivateDevices=false` NUR bei Jellyfin (VA-API /dev/dri). `MemoryDenyWriteExecute=false` bei .NET/Node (JIT). `PrivateNetwork=true` bei `script`-Profil — daher 574-provisioning nutzt `network` (braucht Loopback für API-Calls).
- **Split-DNS:** stream-Dienste (Jellyfin/ABS/Navidrome) brauchen lokalen DNS-Override auf Server-LAN-IP (Hairpin-NAT vermeiden). Host-side via Router (Speedport Custom-DNS) oder Blocky/AdGuard. mediNix-core macht das nicht (ADR-5115, note).

## Anti-Lockout (kritisch bei Remote-Deploy)

- `594-no-password-auth.nix`: `PasswordAuthentication=false`, SSH-Keys only (kein `jarvis ALL=(ALL) NOPASSWD:ALL` — das war ein Bug, entfernt).
- `595-backup-ssh.nix`: 2. SSH-Dienst Port 2222 (LAN reachable, keys only) für Notfälle.
- `521-nftables.nix`: Port 22 + 2222 in `allowedTCPPorts`. Nie `IPAddressDeny=[any]` (blockiert Loopback).
- Immer `nixos-rebuild boot` statt `switch` bei Unsicherheit — bei Boot-Fail rollt Grub zurück.
