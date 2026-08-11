# ---
# id: "511-caddy"
# title: "Caddy Chameleon Ingress — 4 caddyClass templates (stream/internal/public/none)"
# domain: 50
# folder: 51-ingress
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5110
#   skill: nixos-context7-gate
# context7:
#   - query: "services.caddy virtualHosts extraConfig reverse_proxy configuration"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "virtualHosts.<host>.extraConfig + hostName for Caddyfile injection"
#   - note: "flush_interval + remote_ip private_ranges are Caddyfile syntax (caddyserver.com), not NixOS options"
# ---
# 51-ingress/511-caddy.nix — Chameleon Caddy Ingress
# ADR-5110: genau EINE Caddy-Instanz (inject global | standalone caddy-media).
# caddyClass steuert das Template pro Dienst (stream/internal/public/none).
{ lib, pkgs, config, ... }:

let
  cfg       = config.grapefruitMedia;
  ing       = cfg.ingress;
  useGlobal = config.services.caddy.enable;

  registry        = (import ../lib/registry.nix { inherit lib; }).services;
  enabledServices = lib.filterAttrs (n: svc:
    cfg.${n}.enable or false && svc.port != null && svc.caddyClass != "none"
  ) registry;

  # ── 4 Templates ───────────────────────────────────────────────
  # stream   → WAN, Cloudflare NOT proxied, flush_interval -1, no compression
  # internal → LAN only, external IPs blocked via remote_ip private_ranges
  # public   → LAN + WAN, compression, normal timeouts
  # none     → kein vHost (gefiltert oben)
  mkVHost = name: svc:
    let
      port = toString svc.port;
      authBlock = if ing.auth.mode == "forward-auth" then ''
        forward_auth ${ing.auth.forwardAuthUpstream} {
          uri ${ing.auth.forwardAuthUri}
          copy_headers Remote-User Remote-Email Remote-Groups \
                       X-Auth-Request-User X-Auth-Request-Email
        }
      '' else "";

      classBlock = {
        # Streaming: flush -1 (no buffering), 300s timeouts, no compression
        stream = ''
          encode off
          reverse_proxy http://127.0.0.1:${port} {
            flush_interval -1
            transport http {
              read_timeout 300s
              write_timeout 300s
            }
          }
        '';
        # Internal: block all non-private IPs (LAN only)
        internal = ''
          @blocked not remote_ip private_ranges
          abort @blocked
          encode zstd gzip
          ${authBlock}
          reverse_proxy http://127.0.0.1:${port}
        '';
        # Public: LAN + WAN, compression, normal timeouts
        public = ''
          encode zstd gzip
          ${authBlock}
          reverse_proxy http://127.0.0.1:${port}
        '';
      }.${svc.caddyClass};

      tlsDirective =
        if ing.tls.acmeHost != null then
          "tls /var/lib/acme/${ing.tls.acmeHost}/cert.pem /var/lib/acme/${ing.tls.acmeHost}/key.pem"
        else if ing.tls.mode == "custom" then
          "tls ${ing.tls.certFile} ${ing.tls.keyFile}"
        else if ing.tls.mode == "internal" then
          "tls internal"
        else "";
    in ''
      ${name}.${cfg.domain} {
        ${tlsDirective}
        ${classBlock}
      }
    '';

  caddyConfig = lib.concatStringsSep "\n" (lib.mapAttrsToList mkVHost enabledServices);

in lib.mkIf (cfg.enable && ing.enable) {

  # Chameleon: Global Caddy vorhanden → virtualHosts injizieren
  services.caddy.virtualHosts = lib.mkIf useGlobal
    (lib.mapAttrs (n: svc: {
      extraConfig = (lib.getAttr svc.caddyClass {
        stream   = "encode off\nreverse_proxy http://127.0.0.1:${toString svc.port} {\n  flush_interval -1\n  transport http {\n    read_timeout 300s\n    write_timeout 300s\n  }\n}";
        internal = "@blocked not remote_ip private_ranges\nabort @blocked\nencode zstd gzip\nreverse_proxy http://127.0.0.1:${toString svc.port}";
        public   = "encode zstd gzip\nreverse_proxy http://127.0.0.1:${toString svc.port}";
      });
    }) enabledServices);

  # Standalone: Eigenen caddy-media Service starten
  systemd.services.caddy-media = lib.mkIf (!useGlobal) {
    description = "Caddy Media Ingress (mediNix-core standalone)";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network.target" ];
    serviceConfig = lib.mkMerge [
      # network-Profil: CAP_NET_BIND_SERVICE, PrivateDevices=true
      (import ../lib/hardening-profiles.nix { inherit lib; }).network
      {
        ExecStart = "${pkgs.caddy}/bin/caddy run --config /run/caddy-media/Caddyfile";
        RuntimeDirectory = "caddy-media";
        StateDirectory   = "caddy-media";
        User  = "caddy-media";
        Group = "media";
      }
    ];
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
# - caddyClass steuert Template: stream/internal/public/none
# - .local ist mDNS (Avahi userServices=true required)
# - forward_auth nur bei auth.mode=forward-auth + authProxyPresent
# - standalone nutzt UID 5110 (isomorph), GID 5000 (media)
