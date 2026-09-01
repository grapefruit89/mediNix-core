# ---
# id: "55x-example"
# title: "Example service — copy this file, never edit 511/518 for a new app"
# domain: 55
# folder: 55-playback
# status: template
# ---
# How a program joins Caddy, Pocket ID and the landing page.
#
# 1. Copy this file next to the real service modules. Rename id / option path.
# 2. Add the service to lib/registry.nix (name, port, uid, caddyClass).
# 3. Enable it on the host: medinix.<name>.enable = true;
# 4. Do not touch 511-caddy.nix, 513, 515 or 518.
#
# accessGroup / registry caddyClass:
#   stream    media (Jellyfin, Navidrome) — no compress, long timeouts, no auth
#   internal  LAN only — abort outside trustedCidrs, no forward_auth
#   public    WAN+LAN — compress; forward_auth if ingress.auth.mode = "forward-auth"
#   idp       only Pocket ID itself (no forward_auth, deadlock shield)
#   none      no vhost
#
# Landing page:
#   landing = true  +  non-empty iconSvg  → tile
#   landing = false or no SVG             → no tile
#
# Pocket ID / forward-auth (host-wide, not per service):
#   medinix.pocketId.enable = true;
#   medinix.ingress.auth.mode = "forward-auth";
#   # empty forwardAuthUpstream → 127.0.0.1:<pocket-id-port>
#   # public services get the auth wall; internal / stream / .local do not
#
# Addresses after enable (domain set, TLS via 514):
#   https://{name}.{domain}     policy from accessGroup
#   http://{name}.local         HTTP, no TLS, no auth, no abort
{ config, lib, pkgs, ... }:

let
  name = "example";                          # registry key + vhost name
  cfg  = config.medinix.${name};
  reg  = (import ../lib/registry.nix { inherit lib; }).services.${name};
in
lib.mkIf cfg.enable {

  # --- process (minimal). Replace with the real unit. ---
  systemd.services.${name} = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = lib.getExe pkgs.hello;     # ← real package
      User = name;
      Group = "media";
    };
    environment = {
      HOST = "127.0.0.1";
      PORT = toString reg.port;
    };
  };

  users.users.${name} = {
    uid = reg.uid;
    group = "media";
    isSystemUser = true;
    home = reg.stateDir;
    createHome = true;
  };

  # --- ingress contract. This is the only thing 51-ingress reads. ---
  medinix.ingress.vhosts.${name} = {
    accessGroup = reg.caddyClass;            # or "public" / "internal" / "stream"
    landing     = true;                      # false = no family-page tile
    iconSvg     = ''
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96">
        <rect width="96" height="96" rx="16" fill="#1f2937"/>
        <circle cx="48" cy="48" r="20" fill="#9ca3af"/>
      </svg>
    '';
    # skipPaths = [ "/healthz" "/api/health" ];  # only if accessGroup=public + forward-auth
    # customConfig = "";                         # extra Caddyfile lines; still reverse_proxied
  };

  # Optional public alias (default is the registry key):
  # medinix.dns.hostnames.${name} = "example";
}

# Host snippet (not part of this module):
#
#   medinix.example.enable = true;
#
#   # once per host, if any public service needs OIDC:
#   medinix.pocketId.enable = true;
#   medinix.pocketId.exposure = "idp";       # login UI on pocket-id.{domain}
#   medinix.ingress.auth.mode = "forward-auth";
#
#   medinix.ingress.landing.enable = true;   # default already true
