# ---
# id: "511-caddy"
# title: "Caddy Chameleon Ingress — 4 caddyClass templates (stream/internal/public/none)"
# domain: 50
# folder: 51-ingress
# status: active
# complexity: 4
# last_reviewed: 2026-08-13
# links:
#   adr: ADR-5110
#   skill: nixos-context7-gate
# context7:
#   - query: "services.caddy virtualHosts extraConfig reverse_proxy configuration"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "virtualHosts.<host>.extraConfig + hostName for Caddyfile injection"
#   - note: "flush_interval + remote_ip are Caddyfile syntax (caddyserver.com), not NixOS options"
# ---
# 51-ingress/511-caddy.nix — Chameleon Caddy Ingress
# ADR-5110: exactly ONE Caddy instance (inject global | standalone caddy-media).
# caddyClass controls the template per service (stream/internal/public/none).
{ lib, pkgs, config, ... }:

let
  cfg       = config.medinix;
  ing       = cfg.ingress;
  useGlobal = config.services.caddy.enable;

  registry        = (import ../lib/registry.nix { inherit lib; }).services;
  enabledServices = lib.filterAttrs (n: vhost:
    let
      # Use camelCase fallback for things like pocketId
      enabled = cfg.${n}.enable or cfg.${lib.toCamelCase n}.enable or (n == "pocket-id" && ing.auth.mode == "forward-auth") or false;
    in enabled && (registry.${n}.port or null) != null
  ) cfg.ingress.vhosts;

  # Secure LAN CIDRs. If the user specifies nothing in the config, we use restrictive defaults.
  # Groq P1: Added 100.64.0.0/10 so Tailscale clients are not blocked by Caddy.
  trustedCidrs = ing.trustedCidrs or [ "10.0.0.0/8" "100.64.0.0/10" "172.16.0.0/12" "192.168.0.0/16" "fd00::/8" ];
  trustedCidrsStr = builtins.concatStringsSep " " trustedCidrs;
  
  # Cloudflare IPs (IPv4 & IPv6) for trusted_proxies
  cloudflareIps = [
    "173.245.48.0/20" "103.21.244.0/22" "103.22.200.0/22" "103.31.4.0/22" 
    "141.101.64.0/18" "108.162.192.0/18" "190.93.240.0/20" "188.114.96.0/20" 
    "197.234.240.0/22" "198.41.128.0/17" "162.158.0.0/15" "104.16.0.0/13" 
    "104.24.0.0/14" "172.64.0.0/13" "131.0.72.0/22"
    "2400:cb00::/32" "2606:4700::/32" "2803:f800::/32" "2405:b500::/32" 
    "2405:8100::/32" "2a06:98c0::/29" "2c0f:f248::/32"
  ];
  cloudflareIpsStr = builtins.concatStringsSep " " cloudflareIps;

  # Base generation for the respective service
  mkBaseConfig = n: vhost:
    let
      svc = registry.${n};
      port = toString svc.port;
      
      authBlock = if ing.auth.mode == "forward-auth" then ''
        forward_auth ${(if ing.auth.forwardAuthUpstream != "" then ing.auth.forwardAuthUpstream else "127.0.0.1:${toString registry."pocket-id".port}")} {
          uri ${ing.auth.forwardAuthUri}
          copy_headers Remote-User Remote-Email Remote-Groups \
                       X-Auth-Request-User X-Auth-Request-Email
        }
      '' else "";

    in {
        # Streaming: flush -1 (no buffering), 300s timeouts, no compression, no auth
        stream = ''
          encode off
          ${vhost.customConfig}
          reverse_proxy http://127.0.0.1:${port} {
            flush_interval -1
            transport http {
              read_timeout 300s
              write_timeout 300s
            }
          }
        '';
        # Internal: LAN only via explicit trustedCidrs (P1.4), no auth since LAN is the boundary
        internal = ''
          @blocked not remote_ip ${trustedCidrsStr}
          abort @blocked
          encode zstd gzip
          ${vhost.customConfig}
          reverse_proxy http://127.0.0.1:${port}
        '';
        # Public: LAN + WAN, compression, with authBlock (P0.1)
        public = ''
          encode zstd gzip
          ${authBlock}
          ${vhost.customConfig}
          reverse_proxy http://127.0.0.1:${port}
        '';
        # IdP: Public WAN access, NO authBlock (prevents auth deadlock)
        idp = ''
          encode zstd gzip
          ${vhost.customConfig}
          reverse_proxy http://127.0.0.1:${port}
        '';
      }.${vhost.accessGroup};

  # ── Central Template Engine (Red-Team Fixes applied) ─────────
  # This function builds the configuration identically for GLOBAL and STANDALONE.
  mkVHostConfig = n: vhost:
    let
      tlsDirective =
        if ing.tls.acmeHost != null then
          # Red-Team P1.8: Use fullchain.pem instead of cert.pem
          "tls /var/lib/acme/${ing.tls.acmeHost}/fullchain.pem /var/lib/acme/${ing.tls.acmeHost}/key.pem"
        else if ing.tls.mode == "custom" then
          "tls ${ing.tls.certFile} ${ing.tls.keyFile}"
        else if ing.tls.mode == "internal" then
          "tls internal"
        else "";
    in 
      "${tlsDirective}\n${mkBaseConfig n vhost}";

  # Special template for .local (without TLS, pure HTTP)
  mkVHostConfigLocal = n: vhost: mkBaseConfig n vhost;

  # Standalone Config String
  caddyConfigStr = ''
    {
      servers {
        trusted_proxies static ${cloudflareIpsStr}
      }
    }
  '' + lib.concatStringsSep "\n" (lib.mapAttrsToList (n: vhost:
    (lib.optionalString (cfg.domain != null) ''
    ${n}.${cfg.domain} {
      ${mkVHostConfig n vhost}
    }
    '') + ''
    http://${n}.local {
      ${mkVHostConfigLocal n vhost}
    }
  '') enabledServices);

  # Standalone: Start dedicated caddy-media service via Factory
  caddyStandalone = (import ../lib/service-factory.nix { inherit lib config pkgs; }) {
    name = "caddy-media";
    uid = registry.caddy.uid;
    execStart = "${pkgs.caddy}/bin/caddy run --config /etc/caddy-media/Caddyfile";
    stateDir = registry.caddy.stateDir;
    profile = "network";
    extraConfig = {
      Service = {
        CPUWeight = lib.mkDefault 400;
        IOWeight = lib.mkDefault 200;
        MemoryMin = lib.mkDefault "64M";
        MemoryLow = lib.mkDefault "128M";
        MemoryHigh = lib.mkDefault "512M";
        MemoryMax = lib.mkDefault "768M";
        OOMScoreAdjust = lib.mkDefault (-500);
        ManagedOOMPreference = lib.mkDefault "avoid";
      };
    };
  };

in lib.mkMerge [
  (lib.mkIf (cfg.enable && ing.enable) {
    # Chameleon: Global Caddy present → inject virtualHosts
    # CrowdSec Plugin via caddy.withPlugins
    services.caddy.package = lib.mkIf (cfg.observability.crowdsec.enable) (pkgs.caddy.withPlugins {
      plugins = [ "github.com/hslatman/caddy-crowdsec-bouncer@latest" ];
      hash = lib.fakeSha256; 
    });

    assertions = [
      {
        assertion = !(cfg.ingress.tls.acmeHost != null && cfg.ingress.tls.certFile != null);
        message = ''
          [mediNix] You cannot specify both acmeHost and certFile for TLS.
          
          [AI/Admin Context]
          Reason: A virtual host must either be automatically provisioned via ACME (acmeHost) OR manually provisioned via a static certificate file. Specifying both causes a Caddy syntax conflict.
          Ref: ADR-5043 (Ingress Configuration)
        '';
      }
      {
        assertion = cfg.ingress.tls.mode != "custom" || (cfg.ingress.tls.certFile != null && cfg.ingress.tls.keyFile != null);
        message = ''
          [mediNix] Custom TLS mode requires both certFile and keyFile.
          
          [AI/Admin Context]
          Reason: If you bypass ACME to provide your own certificates, Caddy needs both the public cert and the private key.
          Ref: ADR-5043 (Ingress Configuration)
        '';
      }
      {
        assertion = cfg.ingress.auth.mode != "forward-auth" || cfg.pocketId.enable || cfg.ingress.authProxyPresent;
        message = ''
          [mediNix] forward-auth requires pocket-id to be enabled or an external auth proxy present.
          
          [AI/Admin Context]
          Reason: If ingress auth is set to forward-auth, Caddy will forward all unauthenticated requests to an identity provider. If none is configured, all protected routes will return 502 Bad Gateway.
          Ref: ADR-5120 (Identity Provider & Forward Auth)
        '';
      }
    ];

    services.caddy.globalConfig = lib.mkIf useGlobal ''
      servers {
        trusted_proxies static ${cloudflareIpsStr}
      }
    '';

    services.caddy.virtualHosts = lib.mkIf useGlobal
      (lib.mkMerge [
        (lib.mkIf (cfg.domain != null) (lib.mapAttrs' (n: vhost: lib.nameValuePair "${n}.${cfg.domain}" {
          extraConfig = mkVHostConfig n vhost;
        }) enabledServices))
        (lib.mapAttrs' (n: vhost: lib.nameValuePair "http://${n}.local" {
          extraConfig = mkVHostConfigLocal n vhost;
        }) enabledServices)
      ]);

    environment.etc."caddy-media/Caddyfile" = lib.mkIf (!useGlobal) {
      text = caddyConfigStr;
    };

    # mDNS: Avahi entries for .local
    services.avahi = lib.mkIf cfg.discovery.mdns.enable {
      enable  = true;
      publish = { enable = true; userServices = true; addresses = true; };
    };

    # Firewall: only open Caddy ports
    networking.firewall.allowedTCPPorts = lib.mkIf (!useGlobal)
      (if ing.tls.mode == "off" then [ 80 ] else [ 80 443 ]);
  })
  
  (lib.mkIf (cfg.enable && ing.enable && !useGlobal) caddyStandalone)
]

# Gold-Standard (ADR-5110, Red-Team Assessed):
# - Chameleon: never two Caddy instances, security policies for Global and Standalone are 100% identical
# - remote_ip uses explicit trustedCidrs (not just blanket private_ranges)
# - Hostnames are strictly derived from the registry key `n`, not from name
# - fullchain.pem is preferred to prevent chain issues
