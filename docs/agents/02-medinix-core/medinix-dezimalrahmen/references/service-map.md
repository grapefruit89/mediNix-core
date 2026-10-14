# mediNix Service Map & Derivation Recap (ADR-0000)

## Derivation (the only truth)
- Dienstnummer (3-digit, 500-599 for mediNix) →
  Port = Nummer × 10, UID = Nummer × 10, ADR prefix = Nummer × 10.
- GID = Projekt × 1000 = **5000** for ALL mediNix services (shared, for media lib access).
- 2-digit numbers (50-59) = domain blocks, derive nothing.
- 4-digit numbers derive NOTHING — never a port.
- Schicht-Basis ADR uses Ordner00 (ADR-5000, ADR-5700). Service ADR uses service num.

## Service Map (memorize: 511 = Caddy, 512 = Pocket ID)
| Service        | Dienst | Port | UID  | GID  | ADR      |
|----------------|--------|------|------|------|----------|
| Caddy          | 511    | 5110 | 5110 | 5000 | ADR-5110 |
| Pocket ID      | 512    | 5120 | 5120 | 5000 | ADR-5120 |
| Cloudflare DNS | 513    | —    | —    | —    | ADR-5130 |
| OIDC SSO       | 514    | 5140 | 5140 | 5000 | ADR-5140 |
| SABnzbd        | 541    | 5410 | 5410 | 5000 | ADR-5260 |
| Sonarr         | 532    | 5320 | 5320 | 5000 | ADR-5320 |
| Jellyfin       | 551    | 5510 | 5510 | 5000 | ADR-5510 |
| Audiobookshelf | 552    | 5520 | 5520 | 5000 | ADR-5520 |
| Navidrome      | 553    | 5530 | 5530 | 5000 | ADR-5530 |
| Seerr     | 561    | 5610 | 5610 | 5000 | ADR-5610 |

## Hard rules (violated and corrected this session)
- 4-digit "ports" (5055) → INVALID.
- Running-number ADR prefixes (5001/5002/5003/5101) → must be ×10 (5010/5020/5030/5120).
- 511 is Caddy (reverse proxy, _1 Zugang). 512 is Pocket ID. Never swap.
- A file configuring `services.caddy` belongs to 511, even if named 512-*.
- Flat structure only: `XX-domain/NNN-service.nix`, no nested service folders.
- Each service gets its own ADR with UID/GID/Port/ADR-prefix row.
- git init + commit before destructive reorg; verify file parity (CLAUDE.md/data/ too).

## Reorg history (51-ingress fix)
Before: 511-caddy-reverse-proxy, 512-three-way-ingress (set services.caddy!),
531-sabnzbd-isolation (set sabnzbd, but 531≠541).
After: 511-caddy-reverse-proxy, 511-three-way-ingress, 512-pocket-id (new),
513-cloudflare-dns (new), 541-sabnzbd-isolation. No double-Caddy, no misnumbered 512.
