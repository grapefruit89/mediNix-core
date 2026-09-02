---
id: 510-logos
title: logorepo sprite ↔ modules
---

Do not open the GitHub blob page as an image. That is HTML.

Wrong:
- https://github.com/grapefruit89/logorepo/blob/main/dist/icons.svg
- https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/ID.svg   (literal `ID`)

Right:
- Sprite file: https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/dist/icons.svg
- One logo:    https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/jellyfin.svg
- In the landing page Caddy serves `/icons.svg` same-origin. Tiles use `<use href="/icons.svg#jellyfin">`.

18 ids: acme audiobookshelf bitwarden caddy cloudflare feishin jellyfin lidarr navidrome nixos ntfy pocket-id prowlarr radarr recyclarr seerr sonarr unraid.
No metube.svg, no readarr.svg.

## Family page (your index.html) = the WAN list

| tile | accessGroup | why |
| --- | --- | --- |
| jellyfin | stream | big media, CF ToS risk |
| audiobookshelf | stream | same |
| navidrome | stream | same |
| seerr | public | WAN UI, no media pipe |
| feishin | public | WAN SPA, bytes come from navidrome |
| metube | public | WAN UI — **no module in this flake yet** |

`stream` = WAN + long-lived media. Caddy does not orange-cloud that traffic; grey DNS + Caddy.
`public` = WAN + small HTML/API. Seerr still has forward_auth.
`internal` = not on that HTML. Arr/SAB stay off the family page.
