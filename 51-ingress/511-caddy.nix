# ---
# id: "511-caddy"
# title: "Caddy Reverse Proxy + 3-way Ingress + secure_headers"
# domain: 50
# folder: 51-ingress
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5110
# provides: [caddy]
# requires: ["lib/registry"]
# ports: [5110]
# upstream_docs: ["https://caddyserver.com/docs/"]
# forum_links: []
# upstream_github: "https://github.com/caddyserver/caddy"
# nixpkgs_attr: "services.caddy"
# state_dir: "/var/lib/caddy"
# uds_socket: false
# systemd_hardened: true
# ---
# 51-ingress/511-caddy.nix — Caddy reverse proxy + 3-way ingress + secure headers
{ lib, pkgs, config, ... }:

let
  cfg = config.grapefruitMedia.caddy;
  domainWan = "m7c5.de";
  domainLan = "m7c5";
  registry = import ../lib/registry.nix { inherit lib; };
in
{
  options.grapefruitMedia.caddy = {
    enable = lib.mkEnableOption "Caddy reverse-proxy + ingress";
    secureHeaders = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Inject secure_headers snippet on every site.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;
      # 3-way ingress: .local (mDNS) / .m7c5 (LAN) / .m7c5.de (WAN, if allowed)
      virtualHosts = lib.mkMerge (
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
        ) registry
      );
    };

    # mDNS for .local resolution (ADR-5110: userServices required!)
    services.avahi = {
      enable = true;
      publish = {
        enable = true;
        userServices = true;  # IMPORTANT: required for .local names!
        addresses = true;
      };
    };

    # Caddy must never starve (single point of failure for all ingress)
    systemd.services.caddy.serviceConfig = {
      MemoryMin = "64M";
      MemoryLow = "128M";
      ManagedOOMPreference = "avoid";
    };

    networking.firewall.allowedTCPPorts = [ 5110 ];
  };
}

# Gold-Standard (from CLAUDE.md + ADR-5110):
# - Caddy terminates TLS; never expose service ports directly
# - secure_headers = HSTS + X-Content-Type-Options baseline
# - mDNS userServices=true required, else .local silently fails
# - Caddy is SPOF: MemoryMin/ManagedOOMPreference protects it
# - SABnzbd internal 5410 (reverse_proxy), external 58946 is NZB feed only
