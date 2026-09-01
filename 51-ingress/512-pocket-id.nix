{ lib, pkgs, config, ... }:

let
  cfg = config.medinix;
  ing = cfg.ingress;
  svc = (import ../lib/registry.nix { inherit lib; }).services."pocket-id";
  externalAuth =
    (ing.authProxyPresent or false)
    && ((ing.auth.forwardAuthUpstream or "") != "");
  active = cfg.pocketId.enable;
in {
  options.medinix.pocketId.exposure = lib.mkOption {
    type = lib.types.enum [ "idp" "internal" "none" ];
    default = "idp";
    description = "How 511 publishes pocket-id: idp | internal | none";
  };

  config = lib.mkIf (cfg.enable && active) {
    services.pocket-id = {
      enable = true;
      settings = { HOST = "127.0.0.1"; PORT = svc.port; };
      user = "pocket-id";
      group = "media";
    };
    systemd.services.pocket-id = (import ../lib/service-factory.nix { inherit lib config pkgs; }) {
      name = "pocket-id";
      stateDir = svc.stateDir;
      profile = "network";
      hardeningOnly = true;
      extraConfig = {
        RestrictNetworkInterfaces = [ "lo" ];
        ReadWritePaths = [ svc.stateDir ];
      };
    };
    users.users.pocket-id = {
      uid = svc.uid;
      group = "media";
      isSystemUser = true;
      home = svc.stateDir;
      createHome = true;
    };
    medinix.ingress.vhosts."pocket-id" = lib.mkIf (cfg.pocketId.exposure != "none") {
      accessGroup = lib.mkDefault cfg.pocketId.exposure;
    };
  };
}
