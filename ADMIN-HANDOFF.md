# mediNix — Administrator Handoff & Host Integration

Das mediNix-Flake-Modul verwendet das "Publish-Don't-Apply"-Prinzip. Es diktiert keine globalen Systemeinstellungen wie Sysctls oder Firewalls ungefragt, sondern stellt sie als hochgradig optimierte Empfehlungen bereit, die du in deiner Host-Konfiguration bewusst importierst.

Für Kern-Komponenten (Reverse-Proxy, Firewall/nftables, Storage) bietet mediNix einen Tri-State-Schalter:
- `managed`: mediNix baut und konfiguriert die Komponente für dich.
- `external`: Der Host ist verantwortlich, mediNix hängt sich additiv an.
- `off`: Die Komponente ist vollständig deaktiviert.

## 1. Minimal-Integration (Kopieren in deine `configuration.nix`)

Füge diesen Block zu deiner Host-Konfiguration hinzu, um mediNix perfekt mit dem Host zu verheiraten:

```nix
{ config, lib, pkgs, ... }:
{
  # 1. mediNix aktivieren und Tri-States festlegen
  medinix.enable = true;
  medinix.hostIntegration = {
    reverseProxy = "managed";  # mediNix installiert und betreibt Caddy
    nftables     = "managed";  # mediNix aktiviert nftables und den Kill-Switch
    storage      = "external"; # Host regelt die mergerfs/ZFS Mounts
    vpn          = "managed";  # mediNix erstellt das wg0-Interface
  };

  # 2. Kernel & Härtungs-Empfehlungen übernehmen (KISS!)
  # Der Host wendet die von mediNix sorgfältig kalkulierten Sicherheits-Empfehlungen an:
  boot.kernel.sysctl = config.medinix.recommended.sysctl;
  
  # 3. Mount-Härtung (noexec/nosuid/nodev auf Download-Ordnern)
  # Wende die Empfehlungen auf deine manuell definierten fileSystems an:
  # fileSystems."/srv/media/staging".options = config.medinix.recommended.mountOptions.staging;

  # 4. Host liefert Fakten (Credentials & Co)
  # Der TPM-gesiegelte Cloudflare-Token (NICHT im Flake gespeichert!)
  # medinix.host.credentials.acme-dns-token = "/var/lib/credstore.encrypted/cf-acme.cred";
}
```

## 2. Herausgelöste Einstellungen (ausmedinix-core_rausgeflogen)

Folgende globale Einstellungen wurden aus dem Kern-Flake entfernt und müssen nun vom Host gehandhabt oder explizit importiert werden:

1. **`networking.nftables.enable`**: Wurde aus dem Killswitch (`526-vpn-killswitch.nix`) entfernt. Wird jetzt über `hostIntegration.nftables = "managed"` automatisch gesetzt, andernfalls muss es in der `configuration.nix` des Hosts stehen.
2. **`services.caddy.enable`**: Wird jetzt über `hostIntegration.reverseProxy = "managed"` gesteuert.
3. **MergerFS Pools**: Wurden aus `570-storage.nix` hinter den `hostIntegration.storage = "managed"`-Schalter gelegt.
4. Alle Module greifen ab sofort auf den Namespace `medinix.*` statt `grapefruitMedia.*` zu.
