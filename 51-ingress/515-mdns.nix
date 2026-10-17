# ---
# id: "515-mdns"
# title: "Avahi mDNS: {service}.local -> LAN-IP (Robust Alive-Check)"
# domain: 51
# folder: 51-ingress
# status: active
# complexity: 3
# last_reviewed: 2026-10-02
# links:
# provides: []
# requires: ["lib/ingress-access"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix;

  ia = import ../lib/ingress-access.nix { inherit lib; };
  manifest = config.medinix.manifest or { };
  # Nur Dienste, die wirklich aktiv sind. Quelle ist `manifest.enable` — dieselbe
  # Groesse wie in 511 (Rendering), 513 (DNS) und 518 (Tiles).
  #
  # Vorher stand hier eine eigene Aufloesung ueber Optionspfade
  # (cfg.<n>.enable / camelCase / observability.<n>) plus `registry.<n>.port`.
  # Das war ein dritter Interpretationsweg fuer dieselbe Frage und konnte still
  # divergieren: 511 rendert `{name}.lan` fuer JEDEN aktiven Manifest-Dienst,
  # 515 publizierte `{name}.local` aber nur fuer zusaetzlich deklarierte vHosts.
  # Der Kommentar verwies auf "511's enabledOf" — die Funktion existiert in 511
  # nicht (dort steht `lib.filterAttrs (n: m: m.enable && …)`).
  # Ref: Review 2026-10-17, Finding 18.
  enabledNames =
    (lib.attrNames (lib.filterAttrs (n: m: m.enable && ia.accessGroupOf cfg n m != "none") manifest))
    ++ lib.optional cfg.ingress.landing.enable "home";

  aliasScript = pkgs.writeShellScript "medinix-mdns-aliases" ''
    set -euo pipefail

    get_lan_ip() {
      ip=$(${pkgs.iproute2}/bin/ip -4 route get 1.1.1.1 2>/dev/null \
        | ${pkgs.gawk}/bin/awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }' \
        || true)
      if [ -z "''${ip:-}" ]; then
        ip=$(${pkgs.iproute2}/bin/ip -4 -o addr show scope global \
          | ${pkgs.gawk}/bin/awk '{ split($4, a, "/"); print a[1]; exit }' \
          || true)
      fi
      printf '%s' "''${ip:-}"
    }

    IP=""
    for _try in 1 2 3 4 5 6 7 8 9 10; do
      IP=$(get_lan_ip)
      if [ -n "$IP" ]; then
        break
      fi
      sleep 1
    done

    if [ -z "$IP" ]; then
      echo "medinix-mdns: no LAN IPv4 after retries -- skip publish" >&2
      exit 1
    fi

    echo "medinix-mdns: publishing aliases -> $IP"

    pids=""
    ${lib.concatMapStrings (name: ''
      ${pkgs.avahi}/bin/avahi-publish -a -R ${name}.local "$IP" &
      pids="$pids $!"
    '') enabledNames}

    cleanup() {
      for p in $pids; do
        kill "$p" 2>/dev/null || true
      done
    }
    trap cleanup EXIT INT TERM

    sleep 2
    alive=0
    for p in $pids; do
      if kill -0 "$p" 2>/dev/null; then
        alive=$((alive + 1))
      fi
    done

    if [ "$alive" -eq 0 ]; then
      echo "medinix-mdns: kein einziger Alias konnte publiziert werden." >&2
      echo "  Haeufigste Ursache: services.avahi.publish.userServices = false." >&2
      exit 1
    fi

    echo "medinix-mdns: $alive Alias(e) aktiv"
    wait
  '';
in
lib.mkIf (cfg.enable && cfg.ingress.enable && cfg.discovery.mdns.enable && enabledNames != [ ]) {
  services.avahi = {
    # mkDefault, damit der Host eingreifen kann (mkForce bzw. explizites false).
    enable = lib.mkDefault true;
    nssmdns4 = lib.mkDefault true;
    # Der Schalter lebt in `medinix.discovery.mdns.openFirewall` (Default:
    # nur bei managed Firewall) - hier nur lesen, nie hartkodieren.
    openFirewall = lib.mkDefault cfg.discovery.mdns.openFirewall;
    # nixpkgs-Default ist null = alle Interfaces ausser loopback/p2p. Der Host
    # kann hier explizit auf seine LAN-Interfaces einschraenken.
    allowInterfaces = cfg.discovery.mdns.allowInterfaces;
    publish = {
      enable = true;
      addresses = true;
      userServices = true;
    };
  };

  systemd.services.medinix-mdns-aliases = {
    description = "medinix mDNS aliases ({service}.local -> LAN-IP)";
    after = [
      "avahi-daemon.service"
      "network-online.target"
    ];
    wants = [
      "avahi-daemon.service"
      "network-online.target"
    ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      Type = "simple";
      ExecStart = "${aliasScript}";
      Restart = "on-failure";
      RestartSec = "5s";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
      ];
    };
  };

  systemd.services.medinix-mdns-aliases-restart = {
    description = "Restart media mDNS aliases after network change";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl restart medinix-mdns-aliases.service";
      # Baseline (ADR-5050): die Einheit ruft nur `systemctl` ueber den
      # systemd-Private-Socket auf. Deshalb CapabilityBoundingSet leer und nur
      # AF_UNIX - kein Netz, keine Schreibpfade. `RestrictNetworkInterfaces` aus
      # der ADR gilt hier bewusst NICHT: 515 publiziert auf dem LAN-Interface.
      # Ref: Review 2026-10-17, Finding 23.
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      CapabilityBoundingSet = [ "" ];
      RestrictAddressFamilies = [ "AF_UNIX" ];
    };
  };

  systemd.paths.medinix-mdns-aliases-refresh = {
    description = "Watch network leases for media mDNS re-publish";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = "/run/systemd/netif/leases";
      Unit = "medinix-mdns-aliases-restart.service";
      MakeDirectory = false;
    };
  };
}
