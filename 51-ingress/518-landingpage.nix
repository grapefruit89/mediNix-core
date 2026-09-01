# ---
# id: "518-landingpage"
# title: "Family icon page — HTML organ of 511"
# domain: 51
# folder: 51-ingress
# status: active
# complexity: 2
# last_reviewed: 2026-09-01
# links:
#   adr: ADR-5180
# provides: ["landing-html"]
# requires: ["511-caddy"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# adr: ADR-5180
# ---
# 51-ingress/518-landingpage.nix — content for 511, not a second proxy.
# Tiles = vhosts with landing=true and a non-empty iconSvg.
# 518 does not know program names, does not own icons, does not configure Caddy.
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix;

  tiles = lib.filterAttrs (_n: vhost:
    (vhost.landing or false)
    && ((vhost.iconSvg or "") != "")
  ) (cfg.ingress.vhosts or {});

  # Deterministic, generic order. No preferred program list.
  names = lib.sort builtins.lessThan (lib.attrNames tiles);

  publicHost = n: (cfg.dns.hostnames or {}).${n} or n;

  hrefFor = n:
    if cfg.domain != null then "https://${publicHost n}.${cfg.domain}"
    else "http://${n}.local";

  # Gradient/clip ids must be unique when several SVGs share one HTML page.
  uniqSvg = n: svg:
    lib.replaceStrings
      [ "id=\"" "url(#" "href=\"#" "xlink:href=\"#" ]
      [ "id=\"${n}-" "url(#${n}-" "href=\"#${n}-" "xlink:href=\"#${n}-" ]
      svg;

  mkTile = n:
    let vhost = tiles.${n};
    in ''
      <a class="srv" href="${hrefFor n}" aria-label="${n}">
      <div class="icon">${uniqSvg n vhost.iconSvg}</div>
      </a>
    '';

  tilesHtml = lib.concatMapStrings mkTile names;

  landingHtml = pkgs.writeTextDir "index.html" ''
    <!DOCTYPE html>
    <html lang="de">
    <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title></title>
    <meta name="robots" content="noindex, nofollow, noarchive, nosnippet">
    <meta name="referrer" content="no-referrer">
    <style>
    body { margin: 0; padding: 0; background: #000; display: flex; align-items: center; justify-content: center; min-height: 100vh; }
    .grid { display: flex; gap: 2rem; flex-wrap: wrap; justify-content: center; padding: 2rem; }
    .srv { width: 120px; height: 120px; border-radius: 14px; display: block; text-decoration: none; transition: transform 0.2s; }
    .srv:hover { transform: scale(1.05); }
    .icon { width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; }
    .icon svg { width: 100%; height: 100%; }
    </style>
    </head>
    <body>
    <div class="grid">
    ${tilesHtml}
    </div>
    </body>
    </html>
  '';

in {
  config = lib.mkIf (cfg.enable && cfg.ingress.enable && cfg.ingress.landing.enable) {
    medinix.ingress.landing.root = landingHtml;
  };
}

# Gold-Standard (ADR-5180):
# - 518 renders vhosts.landing + iconSvg. No program names, no icon map.
# - 511 serves landing.root. 515 publishes home.local.
# - A new tile is a vhost registration on the service module, never a 518 edit.
