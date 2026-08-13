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

## 2. Impermanence / Persist-Pfade
mediNIX-core erzwingt KEINE Impermanence. Stateless-Root ist Host-Entscheidung.
Wenn gewünscht:
- `tmpfs` auf `/` (oder impermanence-Flake)
- `persist`-Modul für `/nix/persist`, `/var/lib/*`, Secrets
- **Diese StateDirs müssen persistiert werden** (sonst Daten weg nach Reboot):
  `/var/lib/*-5xxx` (alle Media-Services), `/var/lib/ mediNix-state`

**Geplant (Roadmap, nicht im Modul):** `INV-STORE-xx` Guardrail — Build bricht wenn ein
State-Pfad außerhalb der Tier-Whitelist auftaucht (Impermanence-Whitelist-Ansatz).

---

## 3. Storage-Mounts (ABC-Tiering physisch)
mediNIX-core definiert nur **logische** Pfade (`lib/abc-tiering.nix`):
- Tier A (NVMe/SATA-SSD): `/var/lib` → schnelle Platte
- Tier B (SATA-SSD): `storage.mediaRoot/downloads` → aktive Downloads
- Tier C (HDD, Spindown): `storage.mediaRoot/library` → Archiv

**Physische Zuordnung ist Host-Sache** — Mountpoints in Host-`configuration.nix` setzen.
`storage.mediaRoot` / `storage.metadataDir` sind Optionen (Default `/data/media`, `/data/cache`).

---

## 4. VPN-Interface + UID-Routing (Usenet-Sandbox)
Bei `usenet-confinement.enable` baut mediNIX-core die systemd-Unit-Isolation
(UID-Routing via `NetworkNamespacePath`). Der Host muss liefern:
- Das WireGuard-Interface (z.B. `wg0`) + VPN-Keys
- `cfg.vpn.dnsServers` (explizit, keine stillen Defaults — Assertion erzwingt das)
- `cfg.vpn.interface` (Name des VPN-Interfaces)

Keine festen Interface-Namen als Modul-Default — der Host setzt sie.

---

## 5. ACME / TLS-Zertifikatspfade
`ingress.tls.acmeHost` leitet `/var/lib/acme/{acmeHost}/cert.pem` + `key.pem` ab.
**`security.acme` (Lego, DNS-01 via Cloudflare) wird vom Host konfiguriert**, nicht vom Modul.
Caddy liest nur das fertige Zertifikat. Host-Job:
```nix
security.acme = {
  acceptTerms = true;
  certs."m7c5.de" = {
    domain = "m7c5.de";
    dnsProvider = "cloudflare";  # API-Token via TPM-cred
  };
};
```

---

## 6. Secrets-Erzeugung (systemd-creds, TPM)
mediNIX-core bindet Secrets via `LoadCredentialEncrypted` / `EnvironmentFile` ein
(INV-SECRET prüft: keine `/nix/store/`-Pfade). Die **Verschlüsselung** ist Host-Job:
```bash
systemd-creds encrypt --with-key=tpm2+host my-secret.env my-secret.env.encrypted
```
Pfade zu den `.encrypted`-Files kommen in `cfg.secrets.*` (Host-Config).
Betroffene Secrets: `sabnzbdApiKeyFile`, `prowlarrApiKeyFile`, `jellyfinAdminPasswordFile`,
`navidromeOidcFile`, `jellyseerrEnvFile`, Cloudflare-Token, SSH-Keys.

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
mediNIX-core liefert `521-nftables.nix` (Ingress-Firewall). Die **Basis**
(SSH-Zugriff, LAN-Regeln) ist Host-Config. mediNIX ergänzt nur mediNIX-spezifische Regeln.

---

## 9. Checkliste vor dem ersten `nixos-rebuild switch`
- [ ] Binary-Cache in Host-`configuration.nix` gesetzt (§1)
- [ ] Storage-Mounts vorhanden + gemountet (§3)
- [ ] `security.acme` konfiguriert, Zertifikat erzeugt (§5)
- [ ] TPM-Secrets verschlüsselt + Pfade in `cfg.secrets.*` (§6)
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
- ❌ Binary-Cache-Config (§1)
- ❌ Impermanence + Persist-Pfade (§2)
- ❌ Tier-Hardware-Mounts (§3)
- ❌ VPN-Interface + Keys (§4)
- ❌ ACME/TLS-Zertifikatserzeugung (§5)
- ❌ TPM-Secrets-Verschlüsselung (§6)
- ❌ SSH-Hardening, nftables-Basis (§7, §8)
