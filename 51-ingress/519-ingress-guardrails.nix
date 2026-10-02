# ---
# id: "519-ingress-guardrails"
# title: "Ingress guardrails — keep the edge on the mediNix path (advisory, with an escape hatch)"
# domain: 51
# folder: 51-ingress
# status: active
# complexity: 2
# provides: ["ingress-guardrails"]
# requires: ["511-caddy"]
# adr: ADR-0000
# ---
# Local invariants of the ingress domain — the `_9` anchor at domain level.
#
# Philosophy: the edge has ONE engine (Caddy), ONE edge-bouncer and ONE
# packet filter (nftables). Generic "standard" stacks (nginx, apache,
# iptables) are treated as legacy here.
#
# RT-3: fail2ban is NOT on the legacy list. CrowdSec (516) is planned but
# unimplemented — a guardrail that blocks fail2ban while pointing at a
# non-existent module leaves the edge with NO bouncer at all. Until 516
# exists, a fail2ban jail on the Caddy access logs (511, RT-3) is the
# sanctioned interim.
#
# These are build-time ASSERTIONS, not a bash gate. Each one carries its reason
# AND how to silence it — nobody should ever be stuck:
#   allow one name:   medinix.ingress.guardrails.allow = [ "nginx" ];
#   disable all:      medinix.ingress.guardrails.enable = false;
{ config, lib, ... }:

let
  cfg = config.medinix;
  g = cfg.ingress.guardrails;

  # Generic "standard" stacks we consider legacy on this edge.
  # name -> { enabled, why, instead }
  legacy = {
    nginx = {
      enabled = config.services.nginx.enable or false;
      why = "Caddy is the single ingress engine (ADR-511); a second proxy is redundant.";
      instead = "Caddy (511)";
    };
    httpd = {
      enabled = config.services.httpd.enable or false;
      why = "Caddy is the single ingress engine (ADR-511); Apache/httpd is redundant here.";
      instead = "Caddy (511)";
    };
    iptables = {
      enabled = config.networking.useIPTables or false;
      why = "The stack filters packets with nftables natively (ADR-52).";
      instead = "nftables";
    };
    # fail2ban deliberately NOT asserted (RT-3): CrowdSec (516) does not exist
    # yet — until then fail2ban on the Caddy access logs is the sanctioned
    # interim edge bouncer, not legacy.
  };
  legacyAssertions = lib.mapAttrsToList (n: v: {
    assertion = !(v.enabled && !(lib.elem n g.allow));
    message = ''
      [mediNix/519] "${n}" is enabled — we consider it LEGACY here and advise against it.
        Why:     ${v.why}
        Instead: ${v.instead}
        Really need it?   medinix.ingress.guardrails.allow = [ "${n}" ];
        Disable guardrails: medinix.ingress.guardrails.enable = false;
    '';
  }) legacy;

  # Things the ingress domain needs switched ON. Mode-aware: 511 can run the
  # global Caddy or its own standalone caddy-media unit (chameleon), and the
  # firewall may be managed here or by an external host firewall.
  keepOn = [
    {
      name = "caddy";
      on =
        (config.services.caddy.enable or false) || (builtins.hasAttr "caddy-media" config.systemd.services);
      hint = "the single ingress engine (global or standalone)";
    }
    {
      name = "firewall";
      on =
        (config.networking.firewall.enable or false)
        || (config.medinix.hostIntegration.firewall or "managed") == "external";
      hint = "the packet filter (managed or external)";
    }
  ];

  keepAssertions = lib.map (k: {
    # RT-8: selective escape hatch — a single `allow` entry silences exactly
    # one keepOn requirement; disabling ALL of 519 is no longer the only way.
    assertion = k.on || lib.elem k.name g.allow;
    message = ''
      [mediNix/519] ${k.name} is disabled — the ingress domain requires it (${k.hint}).
        Allow explicitly: medinix.ingress.guardrails.allow = [ "${k.name}" ];
        Disable guardrails: medinix.ingress.guardrails.enable = false;
    '';
  }) keepOn;
in
lib.mkIf (cfg.enable && cfg.ingress.enable && g.enable) {
  assertions = legacyAssertions ++ keepAssertions;
}
