---
id: 510-logos
title: logorepo sprite ↔ landing tiles
---

Pattern (same origin):

```html
<svg class="icon" width="120" height="120" aria-hidden="true">
  <use href="/assets/img/icons.svg#{service}"></use>
</svg>
```

`{service}` is the vhost key: `jellyfin`, `seerr`, `audiobookshelf`, …
518 writes that in. Do not hardcode one app in the template.

`iconId` only if the sprite id differs from the service name.
