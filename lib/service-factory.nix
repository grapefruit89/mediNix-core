# ---
# id: "service-factory"
# title: "Systemd-native Service Factory (mkService, isolation=systemd-only)"
# domain: 50
# folder: 50-media
# status: active
# complexity: 4
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-0000
# provides: ["mkService", "containerIsolation"]
# requires: []
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# ---
# lib/service-factory.nix — Systemd-native Service Factory
{ lib, pkgs, config, ... }:

{
  # containerIsolation: Systemd-native, no netns.
  # IMPORTANT: Loopback-only restriction, NO IPAddressDeny rules!
  # Services MUST communicate via 127.0.0.1 (Sonarr -> Jellyfin, etc.)
  containerIsolation = {
    extraInterfaces ? [],
    vpnInterface ? null,
  }: {
    RestrictNetworkInterfaces = lib.mkDefault ([ "lo" ] ++ extraInterfaces ++ lib.optional (vpnInterface != null) vpnInterface);
  };

  # mkService: Creates systemd unit with isolation + hardening
  mkService = {
    name,
    port,
    hardeningProfile ? "full",
    persistDirs ? [],
    readWritePaths ? [],
    readOnlyPaths ? [],
    memoryPolicy ? null,
    extraSystemd ? {},
    extraInterfaces ? [],
    vpnInterface ? null,
  }: let
    isolation = containerIsolation { inherit extraInterfaces vpnInterface; };
  in {
    systemd.services.${name} = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = lib.mkMerge [
        {
          User = name;
          Group = "media";
          UMask = "0002";
        }
        isolation  # Isolation ALWAYS as list in mkMerge!
        extraSystemd
      ];
    };

    users.users.${name} = {
      group = "media";
      isSystemUser = true;
      home = "/var/lib/${name}";
    };

    users.groups.${name} = {};
  };
}
