# ---
# id: "511-caddy"
# title: "Caddy Chameleon Ingress (global inject | standalone caddy-media)"
# domain: 50
# folder: 51-ingress
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5110
# provides: ["ingress", "caddy"]
# requires: ["lib/registry", "options.grapefruitMedia"]
# ports: [5110]
# upstream_docs: ["https://caddyserver.com/docs/"]
# forum_links: []
# upstream_github: "https://github.com/caddyserver/caddy"
# nixpkgs_attr: "services.caddy"
# state_dir: "/var/lib/caddy-media"
# uds_socket: false
# systemd_hardened: true
# ---

# 51-ingress/511-caddy.nix — Chameleon Caddy Ingress
# ADR-5110: genau EINE Caddy-Instanz. Entweder in den globalen Host-Caddy
# injizieren (virtualHosts), oder eigenen caddy-media-Dienst starten.
# Niemals beide. Niemals Port 80/443 doppelt binden.
{ lib, pkgs, config, ... }:

let
  cfg       = config.grapefruitMedia;
  ing       = cfg.ingress;
  useGlobal = config.services.caddy.enable;

  # Alle aktivierten Dienste mit Port aus Registry
  registry        = (import ../lib/registry.nix { inherit lib; }).services;
  enabledServices = lib.filterAttrs (n: svc:
    cfg.${n}.enable or false && svc.port != null
  ) registry;

  # Caddy-Snippet für einen Dienst (reverse_proxy + optional forward_auth)
  mkVHost = name: svc:
    let
      authBlock = if ing.auth.mode == "forward-auth" then ''
        forward_auth ${ing.auth.forwardAuthUpstream} {
          uri ${ing.auth.forwardAuthUri}
          copy_headers Remote-User Remote-Email Remote-Groups \
                       X-Auth-Request-User X-Auth-Request-Email
        }
      '' else "";
      skipBlock = if ing.auth.skipPaths != [] then
        let paths = lib.concatStringsSep " " ing.auth.skipPaths;
        in ''
          @skip path ${paths}
          handle @skip { reverse_proxy http://127.0.0.1:${toString svc.port} }
          handle { ${authBlock} reverse_proxy http://127.0.0.1:${toString svc.port} }
        ''
      else ''
        ${authBlock}
        reverse_proxy http://127.0.0.1:${toString svc.port}
      '';
      tlsDirective = {
        "off"      = "";
        "internal" = "tls internal";
        "custom"   = "tls ${ing.tls.certFile} ${ing.tls.keyFile}";
      }.${ing.tls.mode};
    in ''
      ${name}.${cfg.domain} {
        ${tlsDirective}
        ${skipBlock}
      }
    '';

  caddyConfig = lib.concatStringsSep "\n"
    (lib.mapAttrsToList mkVHost enabledServices);

in lib.mkIf (cfg.enable && ing.enable) {

  # Chameleon: Global Caddy vorhanden → virtualHosts injizieren
  services.caddy.virtualHosts = lib.mkIf useGlobal
    (lib.mapAttrs (n: svc: {
      extraConfig = "reverse_proxy http://127.0.0.1:${toString svc.port}";
    }) enabledServices);

  # Standalone: Eigenen caddy-media Service starten
  systemd.services.caddy-media = lib.mkIf (!useGlobal) {
    description = "Caddy Media Ingress (mediNix-core standalone)";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.caddy}/bin/caddy run --config /run/caddy-media/Caddyfile";
      RuntimeDirectory = "caddy-media";
      StateDirectory   = "caddy-media";
      User  = "caddy-media";
      Group = "media";
      CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
      AmbientCapabilities   = "CAP_NET_BIND_SERVICE";
      NoNewPrivileges = true;
      ProtectSystem   = "strict";
      PrivateTmp      = true;
      RestrictNamespaces = true;
      LockPersonality = true;
    };
  };

  users.users.caddy-media = lib.mkIf (!useGlobal) {
    uid = 5110;
    group = "media";
    isSystemUser = true;
    home = "/var/lib/caddy-media";
    createHome = true;
  };

  environment.etc."caddy-media/Caddyfile" = lib.mkIf (!useGlobal) {
    text = caddyConfig;
  };

  # mDNS: Avahi-Einträge für .local wenn discovery.mdns.enable
  services.avahi = lib.mkIf cfg.discovery.mdns.enable {
    enable  = true;
    publish = { enable = true; userServices = true; addresses = true; };
  };

  # Firewall: nur Caddy-Ports öffnen (Dienste binden 127.0.0.1)
  networking.firewall.allowedTCPPorts = lib.mkIf (!useGlobal)
    (if ing.tls.mode == "off" then [ 80 ] else [ 80 443 ]);
}

# Gold-Standard (ADR-5110):
# - Chameleon: nie zwei Caddy-Instanzen, nie Port 80/443 doppelt
# - .local ist mDNS (Avahi userServices=true required)
# - forward_auth nur bei auth.mode=forward-auth + authProxyPresent
# - standalone nutzt UID 5110 (isomorph), GID 5000 (media)
