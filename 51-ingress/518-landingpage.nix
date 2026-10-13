# ---
# id: "518-landingpage"
# title: "Family icon page — HTML organ of 511"
# domain: 51
# folder: 51-ingress
# status: active
# complexity: 2
# last_reviewed: 2026-10-02
# provides: ["landing-html"]
# requires: ["511-caddy"]
# adr: ADR-518-landingpage-honeypot
# ---
# Renderer only. No program names. A vhost with accessGroup stream|public
# becomes a tile. landing=false opts out. Sprite file: 50-core/icons.svg
# served as /icons.svg. Fragment = service name.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix;
  wanGroups = [
    "stream"
    "public"
  ];

  wanTiles = lib.filterAttrs (
    _n: m: (m.ui.showOnLanding or true) && lib.elem (m.accessGroup or "none") wanGroups && m.enable
  ) (config.medinix.manifest or { });

  lanTiles = lib.filterAttrs (
    _n: m: (m.ui.showOnLanding or true) && (m.accessGroup or "none") != "none" && m.enable
  ) (config.medinix.manifest or { });

  wanNames = lib.sort builtins.lessThan (lib.attrNames wanTiles);
  lanNames = lib.sort builtins.lessThan (lib.attrNames lanTiles);

  publicHost = n: (cfg.dns.hostnames or { }).${n} or n;

  tlsEnabled =
    cfg.ingress.tls.acmeHost != null
    || cfg.ingress.tls.mode == "custom"
    || cfg.ingress.tls.mode == "internal";

  # H19: the link scheme follows the actual TLS state, not just `domain != null`.
  wanHrefFor =
    n:
    if cfg.domain != null && tlsEnabled then
      "https://${publicHost n}.${cfg.domain}"
    else if cfg.domain != null then
      "http://${publicHost n}.${cfg.domain}"
    else
      "http://${n}.lan";

  lanHrefFor = n: "http://${n}.lan";

  fragment =
    n: m:
    let
      raw = m.ui.icon or "";
    in
    if raw != "" then raw else n;

  mkTile =
    hrefFn: tilesAttr: n:
    let
      m = tilesAttr.${n};
      id = fragment n m;
      title = m.ui.title or n;
    in
    ''
      <a class="srv" href="${hrefFn n}" aria-label="${n}" title="${title}">
        <svg class="icon" width="120" height="120" aria-hidden="true">
          <use href="/icons.svg#${id}"></use>
        </svg>
      </a>
    '';

  wanTilesHtml = lib.concatMapStrings (mkTile wanHrefFor wanTiles) wanNames;
  lanTilesHtml = lib.concatMapStrings (mkTile lanHrefFor lanTiles) lanNames;

  mkIndexHtml = tilesHtml: ''
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

  wanIndexHtml = mkIndexHtml wanTilesHtml;
  lanIndexHtml = mkIndexHtml lanTilesHtml;

  # Repo copy lives at 50-core/icons.svg (logorepo dist/icons.svg).
  # Fetch pin until that file is in the tree; 518 still only copies it.
  iconsSvg =
    if builtins.pathExists ../50-core/icons.svg then
      ../50-core/icons.svg
    else
      pkgs.fetchurl {
        url = "https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@7172697e434ff45ba9d2b2374e32919486cb545e/dist/icons.svg";
        hash = "sha256-qisWUumOeQ6NM/+UeIx04sP+DB0EMgjq9BZRcvMAfyg=";
      };

  landingRoot = pkgs.runCommand "medinix-landing" { } ''
    mkdir -p $out
    cat > $out/index.html <<'HTML'
    ${wanIndexHtml}
    HTML
    cp ${iconsSvg} $out/icons.svg
  '';

  lanLandingRoot = pkgs.runCommand "medinix-lan-landing" { } ''
    mkdir -p $out
    cat > $out/index.html <<'HTML'
    ${lanIndexHtml}
    HTML
    cp ${iconsSvg} $out/icons.svg
  '';

in
{
  options.medinix.ingress.vhosts = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options.iconId = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Sprite id. Empty = service name.";
        };
      }
    );
  };

  config = lib.mkIf (cfg.enable && cfg.ingress.enable && cfg.ingress.landing.enable) {
    medinix.ingress.landing.root = landingRoot;
    medinix.ingress.landing.lanRoot = lanLandingRoot;
  };
}
