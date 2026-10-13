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
  config.assertions =
    lib.concatLists (lib.mapAttrsToList (name: meta: df.validate name meta.num) activeServices)
    ++ [
      {
        assertion = lib.length allActiveIds == lib.length (lib.unique allActiveIds);
        message = "[ADR-0000 Collision] Zwei aktive Dienste teilen sich dieselbe ID! IDs müssen strikt injektiv sein.";
      }
    ];

  options.environment.persistence = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.directories = lib.mkOption {
        type = lib.types.listOf lib.types.anything;
        default = [ ];
      };
    });
    default = { };
    description = "Fallback stub for impermanence if not defined by host.";
  };

  config = lib.mkMerge [
    { users.groups.media = lib.mkDefault { gid = 5000; }; }
    (lib.mkMerge (lib.mapAttrsToList (name: meta:
      let
        spec = df.derive name meta.num;
        hasDaemon = meta.hasDaemon or true;
      in
      lib.mkIf hasDaemon {
        users.users.${name} = {
          inherit (spec) uid;
          group = spec.group;
          home = spec.stateDir;
          isSystemUser = true;
        };
        systemd.services.${name}.serviceConfig = {
          User = lib.mkDefault name;
          Group = lib.mkDefault spec.group;
          UMask = lib.mkDefault "0002";
          StateDirectory = lib.mkDefault "${name}-${toString spec.port}";
          WorkingDirectory = lib.mkDefault spec.stateDir;
        };
      }
    ) activeServices))
    (lib.mkIf ((config.medinix.persist.enable or false) || (config.environment.persistence ? "/persist")) {
      environment.persistence."/persist".directories =
        lib.mapAttrsToList (name: meta:
          let
            spec = df.derive name meta.num;
          in
          {
            directory = spec.stateDir;
            user = name;
            group = spec.group;
            mode = "0750";
          }
        ) activeServices;
    })
  ];
}
