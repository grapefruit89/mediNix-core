# ADMIN-HANDOFF — Was der Host-Admin selbst konfigurieren muss

mediNIX-core ist ein **portables NixOS-Modul** (Flake). Es importiert sauber, setzt ein paar
Optionen, fertig. Aber es ist **kein Komplett-System** — bestimmte Dinge sind bewusst
**Host-Verantwortung** und gehören NICHT ins Modul (Portabilitäts-K.O.-Kriterium: keine
hardcoded IPs/Maschinen/Pfade).

Dieses Dokument ist die Checkliste für den Admin auf q958 (192.168.2.73) nach dem Flake-Import.

---

## 1. Binary-Cache (KRITISCH — verhindert Kompilierung)
**Ziel: Auf q958 wird NICHTS kompiliert. Nur absoluter Notfall-Build.**

In der Host-`configuration.nix`:
```nix
nix.settings = {
  substituters = [
    "https://cache.nixos.org"
    # Optional: eigener Cache falls vorhanden (z.B. cache.m7c5.de)
  ];
  trusted-substituters = [ "https://cache.nixos.org" ];
  # Maximum sparsam bauen — aber mediNIX-cli Package braucht evtl. Build:
  # max-jobs = 0 würde das blockieren → nicht setzen, nur substituters priorisieren.
};
```
Falls ein Package nicht im Cache ist: `nix build` läuft auf einem schnellen Rechner,
Ergebnis via `nix copy` auf q958 (`--to ssh://root@192.168.2.73`).

---

## 2. Impermanence (optional, Host-Entscheidung)
mediNIX-core erzwingt KEINE Impermanence. Wenn du Stateless-Root willst:
- `tmpfs` auf `/` via `fileSystems."/".fsType = "tmpfs"` (oder impermanence-Flake)
- `persist`-Modul für `/nix/persist`, `/var/lib/*`, Secrets
- mediNIX-stateDirs (`/var/lib/*-5xxx`) müssen persistiert werden (sonst Daten weg nach Reboot)

**Geplant (Roadmap):** `INV-STORE-xx` Guardrail — Build bricht wenn ein State-Pfad außerhalb
der Tier-Whitelist auftaucht (Impermanence-Whitelist-Ansatz, Build-Time-Cheap).

---

## 3. ABC-Tiering Hardware-Zuordnung
mediNIX-core definiert nur logische Pfade (`tierA=/var/lib/$svc`, `tierB=mediaRoot/downloads`,
`tierC=mediaRoot/library` via `lib/abc-tiering.nix`). Die **physische Zuordnung** ist Host-Sache:
- Tier A (NVMe/SATA-SSD): `/var/lib` → schnelle Platte
- Tier B (SATA-SSD): `mediaRoot/downloads` → aktive Downloads
- Tier C (HDD, Spindown): `mediaRoot/library` → Archiv

Mountpoints in Host-`configuration.nix` setzen, nicht im Modul.

---

## 4. SSH-Hardening (Host-seitig)
mediNIX-core ändert SSH nicht. Empfehlung:
```nix
services.openssh = {
  enable = true;
  settings = {
    PasswordAuthentication = false;
    PermitRootLogin = "no";
    # Port 22 belassen oder auf non-standard (ADR-0021 diskutiert 53844 vs 22)
  };
};
# Optional: TPM-gebundene SSH-Keys (siehe ONBOARDING.md "TPM-SSH-Keys")
```

---

## 5. TPM-Secrets (Host-seitig)
Secrets werden in mediNIX-core via `LoadCredentialEncrypted` / `EnvironmentFile` eingebunden
(INV-SECRET prüft: keine `/nix/store/`-Pfade). Die **Verschlüsselung** ist Host-Job:
```bash
systemd-creds encrypt --with-key=tpm2+host my-secret.env my-secret.env.encrypted
```
Pfade zu den `.encrypted`-Files kommen in `cfg.secrets.*` (Host-Config).

---

## 6. nftables-Baseline (Host-seitig)
mediNIX-core liefert `521-nftables.nix` (Ingress-Firewall). Die **Basis** (SSH-Zugriff,
LAN-Regeln) ist Host-Config. mediNIX ergänzt nur die mediNIX-spezifischen Regeln.

---

## Zusammenfassung: mediNIX-core liefert
- ✅ Alle Media-Services (systemd-native, gehärtet, dezimal-gerahmt)
- ✅ Caddy-Ingress (Chameleon), Pocket-ID, Cloudflare-DDNS
- ✅ Guardrails (Invarianten/Errors, fail-closed)
- ✅ SQLite-WAL, Mover, Provisioning, Backup-Modul (opt-in)

## Zusammenfassung: Host-Admin liefert
- ❌ Binary-Cache-Config (damit nichts kompiliert wird)
- ❌ Impermanence (optional)
- ❌ Tier-Hardware-Mounts
- ❌ SSH-Hardening, TPM-Secrets, nftables-Basis
