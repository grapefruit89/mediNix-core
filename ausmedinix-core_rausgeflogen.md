# Herausgelöste Einstellungen (ausmedinix-core_rausgeflogen)

Dieses Dokument protokolliert alle globalen Host-Konfigurationen, die aus dem Kern-Flake entfernt wurden, um das Publish-Don't-Apply-Prinzip durchzusetzen.

1. **`networking.nftables.enable = true`**: 
   Wurde aus dem Killswitch (`526-vpn-killswitch.nix`) komplett entfernt. Wird jetzt über `hostIntegration.nftables = "managed"` automatisch gesetzt, andernfalls muss es in der `configuration.nix` des Hosts stehen.
   *Grund:* Der Core darf die Host-Firewall-Engine nicht ungefragt aktivieren.

2. **`services.caddy.enable = true`**: 
   Wird jetzt über `hostIntegration.reverseProxy = "managed"` gesteuert. Stand früher teils hartcodiert im Code, wenn `useGlobal` nicht genutzt wurde.
   *Grund:* Vermeidung von Kollisionen mit existierenden Caddy-Setups auf dem Host.

3. **MergerFS Pools (`fileSystems` & `environment.systemPackages = [ pkgs.mergerfs ]`)**: 
   Wurden aus `570-storage.nix` hinter den `hostIntegration.storage = "managed"`-Schalter gelegt. Vorher hat der Flake einfach physische Mountpoints ungefragt zusammengelegt.
   *Grund:* Storage-Mounts (wie ZFS-Datasets oder LVM-Volumes) sind ureigenstes Host-Gebiet.

4. **`boot.kernel.sysctl`**: 
   Die Härtungsmaßnahmen wurden in `medinix.recommended.sysctl` verschoben. 
   *Grund:* Verhindert Konflikte, wenn der Host-Admin eigene Kernel-Parameter setzt.

5. **`networking.firewall.checkReversePath`**: 
   Verschoben nach `medinix.recommended.firewall.checkReversePath`. 
   *Grund:* Das ist ein kritischer Eingriff in die globale Routing-Policy, der vom Host explizit gebilligt werden muss.

6. **`UMask = lib.mkForce "0002"`**:
   Das `mkForce` wurde aus allen Media-Diensten (Jellyfin, etc.) entfernt und durch normale Priorität ersetzt.
   *Grund:* Der Host-Admin kann nun bei Bedarf das UMask überschreiben, ohne selbst mit `mkForce` oder `mkOverride` kämpfen zu müssen.

7. **`EnvironmentFile = lib.mkForce [ credRuntime ]`**:
   Das `mkForce` wurde aus dem ACME-Modul (`514-acme.nix`) entfernt.
   *Grund:* Siehe oben (Merge-Disziplin).

8. **`vpn.interfaceName` Default**:
   Geändert von `wg0` auf `wg-medinix`.
   *Grund:* `wg0` ist auf Hosts mit bestehendem VPN fast immer schon belegt. Der neue Name verhindert Kollisionen.
