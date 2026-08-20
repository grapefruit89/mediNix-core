# ---
# id: "582-crowdsec"
# title: "CrowdSec — native WAF/IPS agent (58-observability, Service 582)"
# domain: 58
# folder: 58-observability
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5820
#   skill: nixos-context7-gate
#   note: "CrowdSec runs as native systemd agent (NO Docker). Caddy talks to the
#          local agent via crowdsec-appsec plugin at http://127.0.0.1:8081.
#          Caddy Plugin (caddy-cs-bouncer) is compiled in 511-caddy.nix via
#          pkgs.caddy.withPlugins — replace hash=lib.fakeHash before first
#          build via nix build. Replaces Unraid Docker-CrowdSec."
# context7:
#   - query: "services.crowdsec enable configuration settings example"
#     library: /nixos/nixpkgs
#     snippet: "services.crowdsec.enable + settings (freeform submodule pattern)"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.observability.crowdsec;
in lib.mkIf cfg.enable {
  # Native CrowdSec agent (no Docker — runs as systemd.service)
  
  # P1.4 Fix: Enable nftables bouncer to actually block attackers
  services.crowdsec-firewall-bouncer = {
    enable = true;
    settings = {
      mode = "nftables";
      nftables = {
        ipv4 = {
          enabled = true;
          set-only = true;
          table = "medinix_security";
        };
        ipv6 = {
          enabled = true;
          set-only = true;
          table = "medinix_security";
        };
      };
    };
  };

  services.crowdsec = {
    enable = true;
    settings = {
      # Agent listens on localhost for Caddy AppSec plugin
      api = {
        server = {
          listen_uri = "127.0.0.1:8081";
        };
      };
      # Collections: sensitives, caddy, etc. (via cscli)
      # Bouncer for nftables is handled by Caddy plugin (AppSec)
    };
  };

  # Enrollment (if enrollKeyFile set — otherwise local standalone mode)
  # cscli enroll --token $(cat enrollKeyFile)
  systemd.services.crowdsec-enroll = lib.mkIf (cfg.enrollKeyFile != null) {
    description = "CrowdSec enrollment";
    wantedBy = [ "multi-user.target" ];
    after    = [ "crowdsec.service" ];
    serviceConfig = {
      Type            = "oneshot";
      User            = "crowdsec";
      Group           = "crowdsec";
      LoadCredentialEncrypted = [ "crowdsec-enroll:${cfg.enrollKeyFile}" ];
    };
    script = ''
      if [ ! -f /var/lib/crowdsec/enrolled ]; then
        if ! ${pkgs.crowdsec}/bin/cscli enroll --token "$(cat /run/credentials/crowdsec-enroll/crowdsec-enroll)"; then
          echo "CrowdSec enrollment failed!" >&2
          exit 1
        fi
        touch /var/lib/crowdsec/enrolled
      fi
    '';
  };

  # Caddy must use AppSec plugin → injected via extraConfig in 511-caddy.nix
  # if cfg.observability.crowdsec.enable. Placeholder for Phase 2 integration.
  #
  # CRITICAL (Vector DB Sweep): CrowdSec Bouncer needs parsable Caddy logs.
  # Caddy JSON logs are NOT natively readable by CrowdSec without log encoder.
  # In 511-caddy.nix (if crowdsec.enable), the Caddy log format must be set to
  # Apache Common Log Format (CLF):
  #   logging → ... → encoder = "common_log" (or transform-encoder for IP-Masking)
  # Otherwise the bouncer cannot extract attacks from the access logs.
}
