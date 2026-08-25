# ---
# id: "518-landingpage"
# title: "Minimal Static Landingpage for Apex Domain"
# domain: 51
# folder: 51-ingress
# status: active
# complexity: 2
# last_reviewed: 2026-08-25
# links: 
# provides: []
# requires: []
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix;
  
  landingHtml = pkgs.writeTextDir "index.html" ''
    <!DOCTYPE html>
    <html lang="de">
    <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Dashboard</title>
    <meta name="robots" content="noindex, nofollow, noarchive, nosnippet">
    <meta name="referrer" content="no-referrer">
    <style>
    body { margin: 0; padding: 0; background-color: #000; display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 100vh; overflow: hidden; }
    .x-hp { display: none; }
    .grid { display: flex; gap: 2rem; flex-wrap: wrap; justify-content: center; padding: 2rem; }
    .srv { width: 120px; height: 120px; cursor: pointer; transition: transform 0.2s; position: relative; border-radius: 14px; }
    .srv:hover { transform: scale(1.05); }
    .icon { width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; }
    </style>
    <link rel="icon" href='data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><text y=".9em" font-size="90">🗺️</text></svg>'>
    </head>
    <body data-domain="${cfg.domain}">
    <!-- Bot Honeypot (CrowdSec triggers on these 404s) -->
    <div class="x-hp" aria-hidden="true">
    <div class="hp-link" data-url="/wp-admin"></div>
    <div class="hp-link" data-url="/.env"></div>
    </div>
    <div class="grid" id="gx">

    <!-- /go/1 -> jellyfin -->
    <div class="srv" data-go="/go/1">
    <div class="icon"><svg xmlns="http://www.w3.org/2000/svg" xml:space="preserve" viewBox="0 0 512 512" pointer-events="none">
    <defs>
    <linearGradient id="jf-a" x1="97.5" x2="522" y1="483.9" y2="729" gradientTransform="translate(0 -278)" gradientUnits="userSpaceOnUse">
    <stop offset="0" stop-color="#aa5cc3"/><stop offset="1" stop-color="#00a4dc"/>
    </linearGradient>
    <linearGradient id="jf-b" x1="94.2" x2="518.7" y1="489.6" y2="734.7" gradientTransform="translate(0 -278)" gradientUnits="userSpaceOnUse">
    <stop offset="0" stop-color="#aa5cc3"/><stop offset="1" stop-color="#00a4dc"/>
    </linearGradient>
    </defs>
    <path fill="url(#jf-a)" d="M256 196c-22 0-95 132-84 154s157 22 168 0-61-154-84-154"/>
    <path fill="url(#jf-b)" d="M256 0C188 0-30 395 3 462s473 66 506 0S324 0 256 0m166 404c-22 44-310 44-331 0s121-303 165-303 187 260 166 303"/>
    </svg></div>
    </div>

    <!-- /go/2 -> seerr -->
    <div class="srv" data-go="/go/2">
    <div class="icon"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><path fill="#fff" d="M256 0C114.6 0 0 114.6 0 256s114.6 256 256 256 256-114.6 256-256S397.4 0 256 0zm0 464c-114.7 0-208-93.3-208-208S141.3 48 256 48s208 93.3 208 208-93.3 208-208 208zm0-336c-70.6 0-128 57.4-128 128s57.4 128 128 128 128-57.4 128-128-57.4-128-128-128zm0 208c-44.1 0-80-35.9-80-80s35.9-80 80-80 80 35.9 80 80-35.9 80-80 80z"/></svg></div>
    </div>

    <!-- /go/3 -> audiobookshelf -->
    <div class="srv" data-go="/go/3">
    <div class="icon"><svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 512 512" pointer-events="none">
    <defs>
    <linearGradient id="abs-a" x2="0" y2="1"><stop offset=".3" stop-color="#cd9d49"/><stop offset="1" stop-color="#875d27"/></linearGradient>
    </defs>
    <circle cx="255.5" cy="256" r="247.4" fill="url(#abs-a)" stroke="#f0f0f8" stroke-width="16" paint-order="stroke"/>
    <path fill="#f0f0f8" d="M245.2 46.9a151.3 151.3 0 0 0-141 150.9v32.8l-9.4 7a8 8 0 0 0-2.7 5.8v39.3q0 3.4 2.7 5.8c4.7 3.9 15.4 12 32.1 20.4v3.8c0 10.3 6.6 18.6 14.8 18.6s14.8-8.4 14.8-18.6v-94.2c0-10.3-6.6-18.6-14.8-18.6-7.9 0-14.3 7.7-14.8 17.3v-19.4a128.6 128.6 0 0 1 257.2 0v19.4c-.5-9.7-7-17.3-14.8-17.3-8.2 0-14.8 8.4-14.8 18.6v94.2c0 10.3 6.6 18.6 14.8 18.6s14.8-8.4 14.8-18.6v-3.8a172 172 0 0 0 32.1-20.4 8 8 0 0 0 2.7-5.8v-39.3q-.2-3.6-2.7-5.8-3-2.6-9.4-7v-32.8c0-87.6-74.2-156.9-161.6-150.9"/>
    <path id="abs-b" fill="#f0f0f8" d="M246.2 164.9c-9.9 0-17.9 8-17.9 17.9v200.6c0 9.9 8 17.9 17.9 17.9h18.5c9.9 0 17.9-8 17.9-17.9V182.8c0-9.9-8-17.9-17.9-17.9zM235.1 213h40.8v4.3h-40.8z"/>
    <use xlink:href="#abs-b" transform="translate(62)"/><use xlink:href="#abs-b" transform="translate(-62)"/>
    <path fill="none" stroke="#f0f0f8" stroke-linecap="round" stroke-width="27" d="M135.4 421h252.8" paint-order="fill markers stroke"/>
    </svg></div>
    </div>

    </div>
    <script>
    // Routing without visible hrefs
    document.querySelectorAll('[data-go]').forEach(el => {
      el.addEventListener('click', e => {
        if (e.isTrusted) location.href = el.dataset.go;
      });
    });
    </script>
    </body>
    </html>
  '';

  # Configure the Apex domain if a domain is set and ingress is active
  apexHost = lib.mkIf (cfg.enable && cfg.domain != null) {
    extraConfig = ''
      # Serve static HTML
      root * ${landingHtml}
      file_server
      
      # Routing for guests (via 302 to prevent WebSocket issues with handle_path)
      redir /go/1 https://jellyfin.${cfg.domain} 302
      redir /go/2 https://jellyseerr.${cfg.domain} 302
      redir /go/3 https://audiobookshelf.${cfg.domain} 302
      
      # The 404s (e.g. /wp-admin, /.env) naturally fall through to a 404 since file_server is active.
    '';
  };

in
{
  # If global caddy is used, inject into its config
  config = lib.mkIf (config.services.caddy.enable && cfg.enable) {
    services.caddy.virtualHosts."${cfg.domain}" = apexHost;
  };
}
