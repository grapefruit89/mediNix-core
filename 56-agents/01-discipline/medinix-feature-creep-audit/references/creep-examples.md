# Feature-Creep Audit — Concrete Examples (Welle 1, 2026-08-13)

From the Mover + VPN review in mediNIX-core. Each row: creep → action taken.

## Stricken options (Phase 13 commit 98071f8)

| Option | Why creep | Action |
|--------|-----------|--------|
| `mover.jellyfinRefreshAfterMove` (bool) | Script had `curl .../Library/Refresh` but no API key/URL was ever passed to the unit → dead code without creds | Deleted option + script block. Handoff says: refresh via *arr→Jellyfin Connect or Host-mergerfs (stable logical path) |
| `mover.action = "copy"` | Goal is "SSD becomes free"; copy doubles space, contradicts it | Enum reduced to `["move"]` only |
| `mover.trigger = "path" \| "manual"` | path is correct, manual = just don't use the path unit. Unnecessary enum | Deleted; `systemd.path` activates with `mover.enable = true`. Manual = `systemctl start` by hand |
| `vpn.dnsMode` (enum vpn-plain/encrypted-hint) | Changed no codepath — 525 built resolv.conf identically from `dnsServers` regardless | Deleted; explanation moved to ADMIN-HANDOFF §4a (encrypted DNS = Host supplies stub on 127.0.0.1 or VPN-provider DNS) |

## Net result
4 options removed, ~30 lines of code deleted. Surface area shrank.

## Adjacent fixes that are NOT creep (kept)
- `systemd.path` Klingel + `minFreeGb` brake (event-driven, HDD sleeps)
- `StartLimitBurst=3` / `StartLimitIntervalSec=60` on the mover service (real start cap, vs Journal RateLimit which only caps logs)
- `find ... -size +50M \( -name '*.mkv' -o -name '*.mp4' \)` — precedence fix (whitelist grouped under `\( \)`)

## User-owned skill note
`medinix-implement-discipline` is USER-OWNED (not curator-managed). This audit skill is the
REVIEW companion and is curator-managed. Recommend `hermes curator adopt medinix-implement-discipline`
so both can be patched in future; for now they live separately on purpose (build vs. review lens).
