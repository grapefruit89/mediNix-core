# ---
# id: "518-landingpage"
# title: "Family icon page — HTML organ of 511"
# domain: 51
# folder: 51-ingress
# status: active
# last_reviewed: 2026-09-02
# provides: ["landing-html"]
# requires: ["511-caddy"]
# adr: ADR-5180
# ---
# Tiles = landing=true + accessGroup in stream|public|idp.
# Icon: <use href="/icons.svg#id">. id = vhost.iconId or the vhost name.
# Sprite pinned from grapefruit89/logorepo.
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix;
  wanGroups = [ "stream" "public" "idp" ];

  tiles = lib.filterAttrs (_n: vhost:
    (vhost.landing or false)
    && lib.elem (vhost.accessGroup or "none") wanGroups
  ) (cfg.ingress.vhosts or {});

  names = lib.sort builtins.lessThan (lib.attrNames tiles);

  publicHost = n: (cfg.dns.hostnames or {}).${n} or n;

  hrefFor = n:
    if cfg.domain != null then "https://${publicHost n}.${cfg.domain}"
    else "http://${n}.local";

  iconIdOf = n: vhost:
    let raw = vhost.iconId or "";
    in if raw != "" then raw else n;

  mkTile = n:
    let id = iconIdOf n tiles.${n};
    in ''
      <a class="srv" href="${hrefFor n}" aria-label="${n}">
        <svg class="icon" width="120" height="120" aria-hidden="true">
          <use href="/icons.svg#${id}"></use>
        </svg>
      </a>
    '';

  tilesHtml = lib.concatMapStrings mkTile names;

  indexHtml = ''
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
    .icon { width: 120px; height: 120px; display: block; }
    </style>
    </head>
    <body>
    <div class="grid">
    ${tilesHtml}
    </div>
    </body>
    </html>
  '';

  iconsSvg = pkgs.fetchurl {
    url = "https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@7172697e434ff45ba9d2b2374e32919486cb545e/dist/icons.svg";
    hash = "sha256-qisWUumOeQ6NM/+UeIx04sP+DB0EMgjq9BZRcvMAfyg=";
  };

  landingRoot = pkgs.runCommand "medinix-landing" { } ''
    mkdir -p $out
    cat > $out/index.html <<'HTML'
    ${indexHtml}
    HTML
    cp ${iconsSvg} $out/icons.svg
  '';

in {
  options.medinix.ingress.vhosts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.iconId = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          logorepo symbol id (logos/<id>.svg). Empty = the vhost attribute name.
          Source: github.com/grapefruit89/logorepo.
        '';
      };
    });
  };

  config = lib.mkIf (cfg.enable && cfg.ingress.enable && cfg.ingress.landing.enable) {
    medinix.ingress.landing.root = landingRoot;
  };
}
