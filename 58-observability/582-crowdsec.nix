# ---
# id: "582-crowdsec"
# title: "CrowdSec — native WAF/IPS agent (58-observability, Dienst 582)"
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
#          Caddy-Plugin (caddy-cs-bouncer) wird in 511-caddy.nix via
#          pkgs.caddy.withPlugins eincompiliert — hash=lib.fakeHash, vor erstem
#          Build via nix build ersetzen. Replaces Unraid Docker-CrowdSec."
# context7:
#   - query: "services.crowdsec enable configuration settings example"
#     library: /nixos/nixpkgs
#     snippet: "services.crowdsec.enable + settings (freeform submodule pattern)"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.observability.crowdsec;
in lib.mkIf cfg.enable {
  # Native CrowdSec agent (kein Docker — läuft als systemd.service)
  services.crowdsec = {
    enable = true;
    settings = {
      # Agent lauscht auf localhost für Caddy AppSec-Plugin
      api = {
        server = {
          listen_uri = "127.0.0.1:8081";
        };
      };
      # Collections: sensitives, caddy, etc. (via cscli)
      # Bouncer für nftables wird von Caddy-Plugin übernommen (AppSec)
    };
  };

  # Enrollment (falls enrollKeyFile gesetzt — sonst lokaler Standalone-Modus)
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
        ${pkgs.crowdsec}/bin/cscli enroll --token "$(cat /run/credentials/crowdsec-enroll/crowdsec-enroll)" || true
        touch /var/lib/crowdsec/enrolled
      fi
    '';
  };

  # Caddy muss AppSec-Plugin nutzen → in 511-caddy.nix via extraConfig injiziert
  # wenn cfg.observability.crowdsec.enable. Platzhalter für Phase 2 Integration.
}
