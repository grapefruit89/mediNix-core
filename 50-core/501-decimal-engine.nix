# ---
# id: "501-decimal-engine"
# title: "Decimal Framework Engine & Global Identity Injection (ADR-0000)"
# domain: 50
# folder: 50-core
# status: active
# complexity: 2
# last_reviewed: 2026-10-13
# adr: ADR-0000
# ---
{ config, lib, ... }:

let
  df = import ../lib/decimal-framework.nix { inherit lib; };
  manifests = config.medinix.manifest or { };
  activeServices = lib.filterAttrs (_name: meta: meta.enable) manifests;
  allActiveIds = lib.mapAttrsToList (_name: meta: meta.num) activeServices;
in
{
  assertions =
    lib.concatLists (lib.mapAttrsToList (name: meta: df.validate name meta.num) activeServices)
    ++ [
      {
        assertion = lib.length allActiveIds == lib.length (lib.unique allActiveIds);
        message = "[ADR-0000 Collision] Zwei aktive Dienste teilen sich dieselbe ID! IDs müssen strikt injektiv sein.";
      }
    ];

  users.groups.media = lib.mkDefault { gid = 5000; };

  users.users = lib.mapAttrs (name: meta:
    let
      spec = df.derive name meta.num;
    in
    {
      inherit (spec) uid;
      inherit (spec) group;
      home = spec.stateDir;
      isSystemUser = true;
    }
  ) (lib.filterAttrs (_: meta: meta.enable && (meta.hasDaemon or true)) manifests);

  systemd.services = lib.mapAttrs (name: meta:
    let
      spec = df.derive name meta.num;
    in
    {
      serviceConfig = {
        User = lib.mkOptionDefault name;
        Group = lib.mkOptionDefault spec.group;
        UMask = lib.mkOptionDefault "0002";
        StateDirectory = lib.mkOptionDefault "${name}-${toString spec.port}";
        WorkingDirectory = lib.mkOptionDefault spec.stateDir;
      };
    }
  ) (lib.filterAttrs (_: meta: meta.enable && (meta.hasDaemon or true)) manifests);

  environment.persistence = lib.mkIf (config.medinix.persist.enable or false) {
    "/persist".directories =
      lib.mapAttrsToList (name: meta:
        let
          spec = df.derive name meta.num;
        in
        {
          directory = spec.stateDir;
          user = name;
          inherit (spec) group;
          mode = "0750";
        }
      ) activeServices;
  };
}
