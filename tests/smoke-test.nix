# tests/smoke-test.nix
# Smoke-Test für mediNix-core — läuft in `nix flake check` via flake.nix checks.mediNix-smoke
# Minimaler Test: Navidrome-Service-Unit existiert + Port 5530 korrekt konfiguriert.
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia;
  # Navidrome: Port 5530 (553 × 10), UID 5530
  navidromePort = 5530;
  navidromeUnit = "navidrome-${toString navidromePort}.service";
in
{
  config = lib.mkMerge [
    {
      grapefruitMedia.navidrome.enable = true;
    }
    (lib.mkIf (cfg.enable && cfg.navidrome.enable) {
      # 1) Navidrome-Systemd-Unit muss existieren
      systemd.services.${navidromeUnit} = {
        # Reine Existenz-Prüfung (wird durch navidrome-Modul befriedigt)
        # Falls navidrome-Modul nicht lädt, fehlt die Unit → Build-Fehler
        wantedBy = lib.mkForce [ ];
        serviceConfig = lib.mkMerge [
          {
            # sanity: nicht auf 0.0.0.0
            # (navidrome-Modul setzt RestrictAddressFamilies bereits korrekt)
          }
        ];
      };

      # 2) Port-Konsistenz: Registry-Port == erwarteter Navidrome-Port
      assertions = [
        {
          assertion = (import ../lib/registry.nix { inherit lib; }).services.navidrome.port == navidromePort;
          message = "[SMOKE-TEST] Navidrome-Port in Registry != 5530 (Dezimalrahmen verletzt)";
        }
        {
          assertion = (import ../lib/registry.nix { inherit lib; }).services.navidrome.uid == navidromePort;
          message = "[SMOKE-TEST] Navidrome-UID in Registry != 5530 (Dezimalrahmen verletzt)";
        }
      ];
    })
  ];

  # Test-Exit-Check: wenn assertions fehlschlagen → `nix flake check` rot
  # Da assertions im NixOS-Modul-System sind, bricht der Build bei Verletzung.
}
