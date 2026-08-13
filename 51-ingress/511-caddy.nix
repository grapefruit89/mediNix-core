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

  # Sichere LAN-CIDRs. Wenn der User in der Config nichts angibt, nutzen wir restriktive Defaults.
  trustedCidrs = ing.trustedCidrs or [ "192.168.178.0/24" "10.0.0.0/8" "fd00::/8" ];
  trustedCidrsStr = builtins.concatStringsSep " " trustedCidrs;

  # ── Zentrale Template Engine (Red-Team Fixes angewandt) ─────────
  # Diese Funktion baut die Konfiguration für GOBAL und STANDALONE identisch zusammen.
  mkVHostConfig = n: svc:
    let
      port = toString svc.port;
      
      authBlock = if ing.auth.mode == "forward-auth" then ''
        forward_auth ${ing.auth.forwardAuthUpstream} {
          uri ${ing.auth.forwardAuthUri}
          copy_headers Remote-User Remote-Email Remote-Groups \
                       X-Auth-Request-User X-Auth-Request-Email
        }
      '' else "";

      tlsDirective =
        if ing.tls.acmeHost != null then
          # Red-Team P1.8: Nutze fullchain.pem statt cert.pem
          "tls /var/lib/acme/${ing.tls.acmeHost}/fullchain.pem /var/lib/acme/${ing.tls.acmeHost}/key.pem"
        else if ing.tls.mode == "custom" then
          "tls ${ing.tls.certFile} ${ing.tls.keyFile}"
        else if ing.tls.mode == "internal" then
          "tls internal"
        else "";

      classBlock = {
        # Streaming: flush -1 (no buffering), 300s timeouts, no compression, no auth
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
        # Internal: LAN only via explizite trustedCidrs (P1.4), mit authBlock (P0.1)
        internal = ''
          @blocked not remote_ip ${trustedCidrsStr}
          abort @blocked
          encode zstd gzip
          ${authBlock}
          reverse_proxy http://127.0.0.1:${port}
        '';
        # Public: LAN + WAN, compression, mit authBlock (P0.1)
        public = ''
          encode zstd gzip
          ${authBlock}
          reverse_proxy http://127.0.0.1:${port}
        '';
      }.${svc.caddyClass};
    in 
      "${tlsDirective}\n${classBlock}";

  # Standalone Config String
  caddyConfigStr = lib.concatStringsSep "\n" (lib.mapAttrsToList (n: svc: ''
    ${n}.${cfg.domain} {
      ${mkVHostConfig n svc}
    }
  '') enabledServices);

in lib.mkIf (cfg.enable && ing.enable) {

  # Chameleon: Global Caddy vorhanden → virtualHosts injizieren
  # CrowdSec Plugin via caddy.withPlugins
  services.caddy.package = lib.mkIf (cfg.observability.crowdsec.enable) (pkgs.caddy.withPlugins {
    plugins = [ "github.com/hslatman/caddy-crowdsec-bouncer@latest" ];
    hash = lib.fakeHash; 
  });

  services.caddy.virtualHosts = lib.mkIf useGlobal
    (lib.mapAttrs' (n: svc: lib.nameValuePair "${n}.${cfg.domain}" {
      extraConfig = mkVHostConfig n svc;
    }) enabledServices);

  # Standalone: Eigenen caddy-media Service starten
  systemd.services.caddy-media = lib.mkIf (!useGlobal) {
    description = "Caddy Media Ingress (mediNix-core standalone)";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network.target" ];
    serviceConfig = lib.mkMerge [
      (import ../lib/hardening-profiles.nix { inherit lib; }).network
      {
        ExecStart = "${pkgs.caddy}/bin/caddy run --config /run/caddy-media/Caddyfile";
        RuntimeDirectory = "caddy-media";
        StateDirectory   = "caddy-media";
        User  = "caddy-media";
        Group = "caddy-media";
      }
    ];
  };

  users.users.caddy-media = lib.mkIf (!useGlobal) {
    uid = 5110;
    group = "caddy-media";
    isSystemUser = true;
    home = "/var/lib/caddy-media";
    createHome = true;
  };
  
  users.groups.caddy-media = lib.mkIf (!useGlobal) {
    gid = 5110;
  };

  environment.etc."caddy-media/Caddyfile" = lib.mkIf (!useGlobal) {
    text = caddyConfigStr;
  };

  # mDNS: Avahi-Einträge für .local
  services.avahi = lib.mkIf cfg.discovery.mdns.enable {
    enable  = true;
    publish = { enable = true; userServices = true; addresses = true; };
  };

  # Firewall: nur Caddy-Ports öffnen
  networking.firewall.allowedTCPPorts = lib.mkIf (!useGlobal)
    (if ing.tls.mode == "off" then [ 80 ] else [ 80 443 ]);
}

# Gold-Standard (ADR-5110, Red-Team Assessed):
# - Chameleon: nie zwei Caddy-Instanzen, Security-Policies für Global und Standalone sind 100% identisch
# - remote_ip nutzt explizite trustedCidrs (nicht einfach pauschal private_ranges)
# - Hostnamen werden streng aus dem Registry-Key `n` abgeleitet, nicht aus name
# - fullchain.pem wird bevorzugt, um Chain-Probleme zu verhindern
