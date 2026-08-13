---
name: medinix-dezimalrahmen
description: Governs mediNix ADR-0000 number schema for modules and ADRs.
---

# mediNix Dezimalrahmen (ADR-0000 Verfassung)

The Dezimalrahmen is the constitution of the mediNix number schema. ADR-0000 is
the source of truth — never delete it, never override it from memory. This skill
exists because an agent repeatedly violated it and got hard-corrected. Internalize.

## Trigger
- Working in `/opt/data/50-mediNix` (or any mediNix-derived repo).
- Naming/renaming a `.nix` module or an `ADR-*.md`.
- Doing a directory reorg / flattening.
- Auditing for "Inkonsistenzen" / consistency.
- User says "dezimalrahmen", "port map", "ADR umbenennen", "flach machen".

## The derivation formula (the ONLY truth)
A **3-digit Dienstnummer** (mediNix: 500–599) derives everything:
- **Port = Nummer × 10**  (e.g. 552 → 5520)
- **UID  = Nummer × 10**  (identical to Port — isomorphism)
- **GID  = Projekt × 1000 = 5000** (shared across all mediNix services)
- **ADR prefix = Nummer × 10** (e.g. Audiobookshelf 552 → `ADR-5520`)

CRITICAL COROLLARIES (all violated at least once — do NOT repeat):
1. **4-digit numbers derive NOTHING.** `5055`, `5003`, `5004`, `5020` as "ports"
   are INVALID. A 4-digit number is never a port. If a chat says "Pocket ID port
   5055", that is an error — correct is `512 → 5120`.
2. **2-digit numbers derive NOTHING** (domain blocks: 50-core, 51-ingress…).
3. **NO running numbers in ADR prefixes.** `ADR-5001`, `ADR-5002`, `ADR-5003`,
   `ADR-5101` are WRONG. The prefix must be `Dienstnummer × 10`. Schicht-Basis
   uses `Ordner00` (`ADR-5000`, `ADR-5700`). A service ADR uses the service
   number (`ADR-5520`). Running numbers violate ADR-0000 §4.
4. **Leaf position:** only `N0` (block-id, never a service) and `N1`–`N9`
   (services). The last digit of a Dienstnummer is the service role — never a
   free `0` (except a domain base like 500/570).
5. **Anker (`_0`/`_1`/`_2`/`_9`) apply only on CONTAINER positions (folders),
   NOT on leaf/service files.**

## Correct mediNix service map (memorize — 511=Caddy!)
| Service        | Dienst | Port | UID  | GID  | ADR      |
|----------------|--------|------|------|------|----------|
| Caddy          | 511    | 5110 | 5110 | 5000 | ADR-5110 |
| Pocket ID      | 512    | 5120 | 5120 | 5000 | ADR-5120 |
| Cloudflare DNS | 513    | —    | —    | —    | ADR-5130 |
| OIDC SSO       | 514    | 5140 | 5140 | 5000 | ADR-5140 |
| SABnzbd        | 541    | 5410 | 5410 | 5000 | ADR-5410 |
| Sonarr         | 532    | 5320 | 5320 | 5000 | ADR-5320 |
| Jellyfin       | 551    | 5510 | 5510 | 5000 | ADR-5510 |
| Audiobookshelf | 552    | 5520 | 5520 | 5000 | ADR-5520 |
| Navidrome      | 553    | 5530 | 5530 | 5000 | ADR-5530 |
| Feishin        | 554    | 5540 | 5540 | 5000 | ADR-5540 |
| Jellyseerr     | 561    | 5610 | 5610 | 5000 | ADR-5610 |

**HARD:** `511` is Caddy (the `_1` Zugang reverse proxy). `512` is Pocket ID.
Never swap them. A file that configures `services.caddy` belongs to `511`, not
`512` — even if named `512-three-way-ingress.nix`. Merge Caddy logic into
`511-caddy.nix` and create a real `512-pocket-id.nix` for the OIDC provider.
**ONE FILE PER SERVICE** (User: "schön dendritisch"): Caddy must NOT be split
across two files — `511-caddy-reverse-proxy.nix` + `511-three-way-ingress.nix`
were merged into a single `511-caddy.nix`. Two files for one Dienstnummer is a
collision, not a split of concerns.

## Flat structure (ADR-0000 §9)
Every module is `XX-domain/NNN-service.nix`. **NO nested service folders**
(e.g. `55-playback/55-wiedergabe/551-jellyfin.nix` is forbidden — breaks flat
auto-import). Flatten: copy contents up, delete nested dir. Each service gets its
own ADR with the full UID/GID/Port/ADR-prefix row above.

## Consistency + duplicate scan (run before declaring done)
1. `../../shared/scripts/scan_inconsistencies.py` — walks the repo, checks every `NNN-*.nix`
   against its header `ports:` and flags 4-digit ports, ports ≠ file-num×10,
   out-of-range domain blocks. Only known false-positives (`default.nix`,
   `flake.nix`, `lib/*`, firewall ports 22/80/443/2222 which are not service
   ports) may remain.
2. `../../shared/scripts/scan_duplicates.py` — full duplicate probe: same filename in different
   paths, content-identical files (sha256), SAME Dienstnummer in multiple files,
   same NIXMETA `id`. Real collisions found this session: `541-mover.nix` (SABnzbd
   number, belongs in 54-transfer) → renamed `543-mover.nix`; and two Caddy files
   sharing number 511. A number appearing in two service files is a COLLISION,
   not two halves — merge them. `default.nix` appearing 3× (Master + 53-factory +
   57-provisioning) is LEGITIMATE (each is a logic container, not a service).

## Auto-import master (ADR-0000 §9, current state)
`default.nix` auto-imports every `XX-domain/NNN-*.nix` via `builtins.readDir`
+ regex `^[0-9]{2}-.*` (dirs) and `^[0-9]{3}-.*\.nix$` (files). NO hardcoded
import list — adding a module file is enough. Per-domain `default.nix` that only
re-auto-imports (e.g. `55-playback/default.nix`) is REDUNDANT and was removed;
only `53-acquisition/default.nix` (arr factory) and `57-maintenance/default.nix`
(provisioning) keep logic. Do NOT add a new `default.nix` that just globs.

## Reorg safety (learned the hard way)
- **git init + commit BEFORE any destructive reorg.** User explicitly asked for it.
  Local repo, `master`, no remote until the user creates the GitHub repo.
- **File-parity check:** after deleting/moving, count files before vs after.
  A flatten that only `cp`'d `*.nix` dropped `CLAUDE.md` + `data/*.xml` (gold
  docs + Jellyfin config seeds) — recovered from the original repo, near-data-loss.
  `cp -r` the whole tree, or diff file lists.
- `grapefruit89/mediNix` is the upstream homelab (German folder names
  `51-zugang`). Its `AGENTS.md` forbids branches — only `main`. For the English
  portable core use a SEPARATE repo (`mediNix-core`), not a branch.

## Pitfalls (every one a real mistake this session)
- 4-digit "ports" (5055) — INVALID, 4-digit derives nothing.
- Running-number ADR prefixes (5001/5002/5003/5101) — must be ×10.
- 511=Caddy vs 512=Pocket ID confusion.
- Renaming `513-caddy → 511-caddy` but leaving `512-three-way-ingress.nix` (sets
  `services.caddy.enable`) → apparent double-Caddy + misnumbered 512. Fix:
  three-way-ingress is Caddy logic → `511-three-way-ingress.nix`; add real
  `512-pocket-id.nix`.
- Flattening without copying `CLAUDE.md`/`data/` → near data loss.
- Not git-versioning before a destructive move.

## "Look in my other repos" — DO NOT rely on memory
When the user says "guck in meinen anderen Repos", enumerate live via the GitHub
MCP tool `mcp__github__search_repositories` with query `user:grapefruit89` (no
name filter) — the full account has 20 repos, not just the 8 locally cloned.
The canonical registry of all Nix-repos is `ADR-0001-source-repository-registry.md`
in mediNix-core/docs. Priority: `devNIX` (ADR-8000 = decimal-framework
constitution, wins over local assumptions), `mediNix` (gold configs +
CLAUDE.md gold-standards), `mynixos-v5` (advanced SSO/SSoT patterns).

## Support files
- `../../shared/scripts/scan_inconsistencies.py` — deterministic consistency probe (run it).
- `../../shared/scripts/scan_duplicates.py` — duplicate/collision probe (run it too).
- `references/service-map.md` — full service map + derivation recap.
