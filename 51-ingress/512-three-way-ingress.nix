# ---
# id: "512-three-way-ingress"
# title: "Automatic 3-way Ingress (.local / .m7c5 / .m7c5.de)"
# domain: 50
# folder: 51-ingress
# status: active
# complexity: 3
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-5043
# provides: []
# requires: ["511-caddy"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---
# 51-ingress/512-three-way-ingress.nix — Automatic 3-way access
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia;
  domainWan = "m7c5.de";
  domainLan = "m7c5";
in
{
  services.caddy.enable = true;
  services.caddy.virtualHosts = lib.mkMerge (
    lib.mapAttrsToList (name: svc:
      let
        allowWan = svc.wan or svc.stream or false;
        proxy = "reverse_proxy 127.0.0.1:${toString svc.port}";
      in
      {
        "${name}.local" = { extraConfig = proxy; };
        "${name}.${domainLan}" = { extraConfig = proxy; };
      } // (lib.optionalAttrs allowWan {
        "${name}.${domainWan}" = { extraConfig = proxy; };
      })
    ) (import ../lib/registry.nix { inherit lib; })
  );

  # mDNS for .local resolution
  services.avahi = {
    enable = true;
    publish = {
      enable = true;
      userServices = true;  # IMPORTANT: required for .local names!
      addresses = true;
    };
  };
}
