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
# adr: ADR-518
# links:
#   adr: ADR-518
# ---
# Renderer only. No program names. A vhost with accessGroup stream|public
# becomes a tile (resolved via lib/ingress-access.nix, same as 511/513).
# Per-vhost overrides it declares and reads: landing (hide), iconId, iconSvg.
# Sprite file: 50-core/icons.svg served as /icons.svg.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix;
  # WAN-Tiles nur fuer stream|public — `idp` ist WAN-Login und bekommt bewusst
  # KEIN Family-Tile (anders als 511/513, die idp mitrendern/-publizieren).
  wanGroups = [
    "stream"
    "public"
  ];

  ia = import ../lib/ingress-access.nix { inherit lib; };
  manifest = config.medinix.manifest or { };

  # Gleiche Aufloesung wie 511 (Rendering) und 513 (DNS): der Vhost-Override
  # gewinnt. Vorher las 518 das Manifest direkt — ein public-Override rendert in
  # 511 einen WAN-vHost, lieferte hier aber kein Tile.
  # Vhost-Override (landing) gewinnt, sonst das Manifest (ui.showOnLanding).
  # Vorher war `landing` deklariert, aber unbenutzt (Dead-Config).
  showOnLanding =
    n: m:
    let
      override = cfg.ingress.vhosts.${n}.landing or null;
    in
    if override != null then override else (m.ui.showOnLanding or true);
  groupOf = n: m: ia.accessGroupOf cfg n m;

  wanTiles = lib.filterAttrs (
    n: m: showOnLanding n m && lib.elem (groupOf n m) wanGroups && m.enable
  ) manifest;

  lanTiles = lib.filterAttrs (n: m: showOnLanding n m && groupOf n m != "none" && m.enable) manifest;

  wanNames = lib.sort builtins.lessThan (lib.attrNames wanTiles);
  lanNames = lib.sort builtins.lessThan (lib.attrNames lanTiles);

  publicHost = n: (cfg.dns.hostnames or { }).${n} or n;

  # Definition in lib/ingress-access.nix (Duplikat mit 511 aufgeloest).
  tlsEnabled = ia.tlsEnabledOf cfg.ingress;

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

  # Sprite-Id: Vhost-Override (iconId) > Manifest (ui.icon) > Service-Name.
  fragment =
    n: m:
    let
      vhostIcon = cfg.ingress.vhosts.${n}.iconId or "";
      manifestIcon = m.ui.icon or "";
    in
    if vhostIcon != "" then
      vhostIcon
    else if manifestIcon != "" then
      manifestIcon
    else
      n;

  # Attribut-Kontext: `n`, `title` und `id` kommen aus Manifest/Config und werden
  # HTML-escaped. `iconSvg` bleibt bewusst roh - Betreiber-SVG, gleiche
  # Vertrauensstufe wie die Datei selbst.
  # Ref: Review 2026-10-17, Finding 26.
  mkTile =
    hrefFn: tilesAttr: n:
    let
      m = tilesAttr.${n};
      id = fragment n m;
      title = m.ui.title or n;
      inlineSvg = cfg.ingress.vhosts.${n}.iconSvg or "";
      icon = if inlineSvg != "" then inlineSvg else ''<use href="/icons.svg#${lib.escapeXML id}"></use>'';
    in
    ''
      <a class="srv" href="${hrefFn n}" aria-label="${lib.escapeXML n}" title="${lib.escapeXML title}">
        <svg class="icon" width="120" height="120" aria-hidden="true">
          ${icon}
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
  config = lib.mkIf (cfg.enable && cfg.ingress.enable && cfg.ingress.landing.enable) {
    medinix.ingress.landing.root = landingRoot;
    medinix.ingress.landing.lanRoot = lanLandingRoot;
  };
}
