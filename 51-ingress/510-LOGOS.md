---
id: 510-logos
title: logorepo sprite ↔ landing tiles
---

`logos/sonarr.svg` is the source file. No `<symbol id>`.
`dist/icons.svg#sonarr` is the sprite.

Wrong in HTML:
```html
<img src="https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/sonarr.svg">
<use href="https://cdn.jsdelivr.net/…/dist/icons.svg#sonarr">  <!-- CORS -->
```

Right (same origin, like `/assets/img/ico_e8911.svg#comment`):
```html
<svg class="icon" width="120" height="120" aria-hidden="true">
  <use href="/assets/img/icons.svg#sonarr"></use>
</svg>
```

518 copies `dist/icons.svg` to the landing root as `/assets/img/icons.svg`.
`iconId` on the vhost is the fragment (`jellyfin`, `seerr`, …).

Header `# logo:` lines in modules point at `logos/<id>.svg` only as the source file for humans. Tiles never load that URL.
