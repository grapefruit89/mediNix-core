# tests/smoke-test.nix
# Smoke-Test für mediNix-core — läuft in `nix flake check` via flake.nix checks.mediNix-smoke
# Minimaler Test: Navidrome-Port/-UID in der Registry == Dezimalrahmen (5530).
{
  config,
  lib,
  ...
}:

let
  cfg = config.medinix;
  # Navidrome: Port 5530 (553 × 10), UID 5530
  navidromePort = 5530;
in
{
  config = lib.mkMerge [
    {
      medinix.navidrome.enable = true;
      # trustedCidrs has no broad default anymore (fail-closed) — set one.
      medinix.ingress.trustedCidrs = [
        "10.0.0.0/8"
        "192.168.0.0/16"
      ];
    }
    (lib.mkIf (cfg.enable && cfg.navidrome.enable) {
      # Port-Konsistenz: Registry-Port == erwarteter Navidrome-Port
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
