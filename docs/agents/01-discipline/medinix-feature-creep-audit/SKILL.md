---
name: medinix-feature-creep-audit
category: devops
description: "Audit mediNIX for feature creep. Net-Optionen rule."
---

# mediNIX Feature-Creep Audit

Review lens for mediNIX-core modules. Complements `medinix-implement-discipline` (build discipline,
Phase A–E). Use it when: reviewing settled code for ballast, or before adding a new `mkOption`.

## When to run this audit
- After a large build/refactor (settled code, before calling it "done").
- When the user says "feature creep", "zu viel", "überflüssig", "das brauchen wir nicht".
- Before adding any new `mkOption` — ask: "welche Option strike ich dafür?" (Net-Optionen-Regel).

## Creep categories (strike / simplify / host-only / default-out)
1. **Dead option** — defined but no (or unclear) wiring to make it work.
   Example: `jellyfinRefreshAfterMove` (API call in script, but no API key/URL passed to the unit → dead).
   → Strike until credentials are actually wired, or move to Host/UI (e.g. *arr→Jellyfin Connect).
2. **Doc-as-code** — option that changes no codepath, only documents semantics.
   Example: `vpn.dnsMode` (enum vpn-plain/encrypted-hint; 525 built resolv.conf identically regardless).
   → Delete the option; put the explanation as a paragraph in ADMIN-HANDOFF.
3. **Goal-contradiction** — option that defeats the stated objective.
   Example: `mover.action = "copy"` while the goal is "SSD becomes free" (move frees, copy doubles).
   → Keep only the goal-aligned value (`move`); strike `copy`.
4. **Premature complexity** — built but enable=false + placeholder (fakeHash), no real use yet.
   Example: CrowdSec in Caddy path with `lib.fakeHash`, default enable=false.
   → Leave enable=false; don't expand until actually used.
5. **Unnecessary enum** — enum where one value is the obvious default and the other is "turn it off".
   Example: `mover.trigger = path | manual` — path is correct, manual = just don't use path.
   → Drop the enum; path-unit activates with `enable=true`. Manual = start by hand.
6. **Duplicate** — two things doing the same job, or two INV IDs for one invariant.
   → Merge; one SSoT, one message.

## The Net-Optionen rule
For every NEW option added: strike or simplify ONE existing option. Surface area must shrink or stay
flat, not grow. "Jede neue Option = eine gestrichene" — if you can't strike one, the new one is creep.

## What is NOT creep (keep)
- VPN confinement + Policy-Routing + DNS-Asserts
- Ondemand-Mover with systemd.path + minFreeGb + Whitelist + move
- Restic with narrow paths (plain Units)
- Registry / Factory / plain Units
- ADMIN-HANDOFF as Host-list
- Assertions with usable Messages

## Event-driven > Calendar (mediNIX timing)
- `OnCalendar = "*:0/15"` is systemd-timer syntax, NOT cron. But still a fixed-interval wake.
- For "HDD should sleep" goals: prefer `systemd.path` (PathChanged/DirectoryNotEmpty) as a Klingel
  (event trigger, no clock) + a brake in the script (e.g. `df`-check vs `minFreeGb` → exit 0 if free).
- Path = Klingel (something changed), brake = minFreeGb (only act on real pressure). No 15-min HDD wake.
- NEVER use cron/crontab/iptables as mediNIX paths (INV-TECH-03 bans services.cron; nftables only).

## Pitfall: find precedence
`find DIR -type f -size +50M -o -name '*.mkv'` WITHOUT grouping matches ALL *.mkv regardless of size
(find operator precedence: -o separates filters, not ANDs them). Correct:
`find DIR -type f -size +50M \( -name '*.mkv' -o -name '*.mp4' \)`
Always group whitelist extensions under `\( \)` when combined with another predicate.

## Pitfall: systemd StartLimit vs Journal RateLimit
- `RateLimitBurst`/`RateLimitIntervalSec` (serviceConfig) throttle LOG output, NOT service starts.
- To cap how often a unit STARTS (e.g. path-unit hammering on a chatty dir): use
  `StartLimitBurst` + `StartLimitIntervalSec` on the service unit.
- Both coexist: StartLimit = real starts, RateLimit = log IO. Don't confuse them.

## References
- `references/creep-examples.md` — concrete before/after from the mediNIX Mover + VPN audit (Welle 1).
