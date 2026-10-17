# ---
# id: "516-crowdsec"
# title: "CrowdSec — Edge-IPS (Engine + Firewall-Bouncer)"
# domain: 51
# folder: 51-ingress
# status: active
# complexity: 3
# last_reviewed: 2026-10-15
# links:
#   adr: ADR-516
# provides: ["crowdsec", "edge-bouncer"]
# requires: ["lib/ingress-access", "lib/service-factory", "lib/registry", "51-ingress/511-caddy"]
# ports: []
# upstream_docs: ["https://docs.crowdsec.net/docs/data_sources/intro"]
# forum_links: []
# upstream_github: "https://github.com/crowdsecurity/crowdsec"
# nixpkgs_attr: "services.crowdsec"
# state_dir: "/var/lib/crowdsec"
# uds_socket: false
# systemd_hardened: true
# links:
#   adr: ADR-516
# ---
# 51-ingress/516-crowdsec.nix — CrowdSec Edge-IPS
# ADR-516: genau EIN Edge-Bouncer (ADR-0000 §3, _1 = Access).
#
# Was hier passiert:
#   Engine  (nativ: services.crowdsec) liest die Caddy-Access-Logs aus dem
#           journald (511 loggt JSON nach stdout → journald, kein Datei-Umbau)
#           und erzeugt Entscheidungen (Ban).
#   Bouncer (services.crowdsec-firewall-bouncer) setzt die Entscheidungen in
#           nftables um — NUR wenn der Host die Firewall verwaltet
#           (hostIntegration.nftables == "managed", Publish-Don't-Apply).
#
# Nicht hier: TLS/ACME (514), Caddyfile (511). 516 kennt keinen Port und
# keinen Caddy-vHost (caddyClass = "none").
#
# Vorher war der Rand OHNE Bouncer: 519 (RT-3) liess fail2ban bewusst
# ungeschoren, weil 516 nicht existierte. Mit diesem Modul greift RT-3.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix;
  active = cfg.crowdsec.enable;
  managed = cfg.hostIntegration.nftables == "managed";
  ia = import ../lib/ingress-access.nix { inherit lib; };

  # Caddy schreibt den Access-Log (JSON, Header gestrippt) nach stdout →
  # journald. Die Acquisition liest genau diese Unit — kein zusaetzliches
  # Datei-Log, keine Rotation, keine zweite Quelle.
  # Die Unit haengt am Modus: global laeuft der Host-Caddy (`caddy.service`),
  # standalone die eigene `caddy-media.service`. Vorher stand hier hartkodiert
  # `caddy-media.service` — im Global-Modus las CrowdSec damit ins Leere, ohne
  # Assertion und ohne Warnung (stiller Blindflug, kein Ban mehr).
  # Ref: Review 2026-10-17, Finding 13.
  caddyUnit = ia.caddyUnitOf cfg.ingress.mode config.services.caddy.enable;
in
{
  options.medinix.crowdsec = {
    enable = lib.mkEnableOption "CrowdSec Edge-IPS (Engine + optionaler Firewall-Bouncer)";

    bouncer = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Firewall-Bouncer aktivieren (setzt Entscheidungen in nftables um).
        Verlangt `medinix.hostIntegration.nftables = "managed"` — sonst bricht
        die Assertion ab (fail-closed), statt still nichts zu tun.
      '';
    };
  };

  config = lib.mkMerge [
    {
      # Dienst-Steckbrief: die Engine besitzt den Account (UID = GID = 5160,
      # UPG nach ADR-0000 §4). extraGroups systemd-journal: die Engine muss die
      # Journal-Eintraege von caddy-media lesen duerfen.
      medinix.manifest.crowdsec = {
        enable = active;
        num = 516;
        accessGroup = "none";
        hasDaemon = true;
        extraGroups = [ "systemd-journal" ];
        ui = {
          title = "CrowdSec";
          description = "Edge-IPS (Caddy-Access-Logs)";
          icon = "crowdsec";
          group = "Security";
          showOnLanding = false;
        };
        monitoring = {
          enable = false; # keine HTTP-Schnittstelle nach aussen
        };
        ops = {
          priority = "high";
          ramBudget = "256M";
          notes = "Liest caddy-media aus dem Journal; Ban-Entscheidungen gehen an den Firewall-Bouncer.";
        };
        sources = {
          upstream = "https://docs.crowdsec.net/docs/data_sources/intro";
          repo = "https://github.com/crowdsecurity/crowdsec";
          nixos = "https://search.nixos.org/options?query=services.crowdsec";
        };
      };
    }

    (lib.mkIf active {
      assertions = [
        {
          # Ohne ingress.enable existiert keine Caddy-Unit — die Engine liefe
          # ohne Datenquelle und bannte nichts (fail-open durch Stille).
          # Ref: Review 2026-10-17, Finding 13.
          assertion = cfg.ingress.enable;
          message = ''
            [mediNix/516] CrowdSec ist aktiv, aber medinix.ingress ist aus.
            Die Engine liest ihre Daten ausschliesslich aus den Caddy-Access-Logs
            (Unit ${caddyUnit}) — ohne Ingress gibt es keine Quelle und keine Bans.
            Entweder medinix.ingress.enable = true setzen oder
            medinix.crowdsec.enable = false.
          '';
        }
        {
          assertion = !(cfg.crowdsec.bouncer && !managed);
          message = ''
            [mediNix/516] CrowdSec Firewall-Bouncer ist aktiv (medinix.crowdsec.bouncer = true),
            aber der Host verwaltet die Firewall nicht (medinix.hostIntegration.nftables =
            "${cfg.hostIntegration.nftables}", erwartet "managed").

            Der Bouncer schreibt in nftables - das ist Host-Hoheit (Publish-Don't-Apply,
            ADR-0000). Zwei Wege:
              a) Host uebernimmt die Firewall:  medinix.hostIntegration.nftables = "managed";
              b) nur die Engine betreiben:       medinix.crowdsec.bouncer = false;
                 (die Host-Pflicht steht dann in docs/ADMIN-HANDOFF.md)
          '';
        }
      ];

      # ── Engine (nativ) ────────────────────────────────────────────────
      services.crowdsec = {
        enable = true;
        # Collection = Caddy-Parser + base-http-scenarios (Hub: crowdsecurity/caddy).
        hub.collections = [ "crowdsecurity/caddy" ];
        localConfig = {
          acquisitions = [
            {
              source = "journalctl";
              journalctl_filter = [ "_SYSTEMD_UNIT=${caddyUnit}" ];
              labels.type = "caddy";
            }
          ];
          # Ohne Profil reagiert CrowdSec auf KEINE Entscheidung (Modulwarnung).
          profiles = [
            {
              name = "default.yaml";
              filters = [ "Alert.Remediation == true && Alert.GetScope() == \"Ip\"" ];
              decisions = [
                {
                  type = "ban";
                  duration = "4h";
                }
              ];
              on_success = "break";
            }
          ];
        };
      };

      # Hardening-Injektion (kein Account: den besitzt die Engine, s. Manifest).
      # Kein RestrictNetworkInterfaces: die Engine laedt Hub-Szenarien und
      # Konsens-Daten aus dem Internet.
      systemd.services.crowdsec = (import ../lib/service-factory.nix { inherit lib config pkgs; }) {
        name = "crowdsec";
        profile = "network";
        ownsAccount = false;
        hardeningOnly = true;
        extraConfig = {
          ReadWritePaths = [ "/var/lib/crowdsec" ];
        };
      };

      # ── Firewall-Bouncer (nur mit Host-Verwaltung) ────────────────────
      services.crowdsec-firewall-bouncer = lib.mkIf (cfg.crowdsec.bouncer && managed) {
        enable = true;
        # Der Bouncer baut seine nftables-Kette selbst; 503/520 bleiben die
        # Quelle der BASIS-Regeln, Bans kommen ausschliesslich von hier.
        createRulesets = true;
        settings.mode = "nftables";
        registerBouncer.bouncerName = "mediNix-firewall-bouncer";
      };
    })
  ];
}

# Gold-Standard (ADR-516):
# - Genau EIN Edge-Bouncer; fail2ban ist damit Legacy (519 RT-3 greift)
# - Engine liest journald (511 loggt JSON nach stdout) — keine zweite Logquelle
# - Profile sind Pflicht: ohne sie reagiert CrowdSec nicht
# - Der Bouncer schreibt nur bei hostIntegration.nftables == "managed" in
#   nftables; sonst ist die Host-Pflicht in ADMIN-HANDOFF.md dokumentiert
# - UPG: Primaergruppe = crowdsec (UID/GID 5160); systemd-journal nur als
#   supplementary group im Manifest (extraGroups)
