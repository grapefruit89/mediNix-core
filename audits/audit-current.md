# mediNix-core — current audit

Status: **not a production claim.** This is the living list.
Last updated: 2026-09-02

## Gates

| Gate | Status |
| --- | --- |
| nix parse / flake check on target host | not run here |
| eval assertions (521, 591, 511, 513, 514) | in code |
| deadnix / statix / nixosTest | not wired |
| documentation vs tree | 52/58/59 READMEs match modules |

## Closed in code (do not re-open from old audits)

- `.local` has CIDR abort; localBypass is auth-only
- Pocket-ID starts only when enabled; exposure is explicit
- ACME/DDNS: no `tokenFile`; sealed creds only
- CrowdSec gone
- RestrictAddressFamilies on hardening `base`
- 526 killswitch + unreachable default
- 521 sealed-path + no secrets under mediaRoot

## Still host-side

- Seal real `.encrypted` blobs on the machine
- `nix flake check` on the target
- 50-core/icons.svg vendor copy (518 fetches until then)

## Historical

- [audit-50-51-52.md](audit-50-51-52.md)
- [audit-53-54-55.md](audit-53-54-55.md)
