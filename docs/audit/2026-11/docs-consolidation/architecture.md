# Architecture principles

Extracted from the former `docs/chat exports/KONSOLIDIERUNG.md`. That file is gone.

## Keep

- Caddy is TLS + reverse proxy. Auth is Pocket-ID. No Pangolin/Zoraxy/Authentik/caddy-security.
- Services bind loopback. Publish only through 511.
- No host LAN IPs in the flake. Trusted nets are RFC1918 + ULA + loopback. Not CGNAT `100.64.0.0/10`.
- `internal` stays off WAN. `stream` / `public` / `idp` are the WAN classes.
- Subdomain + `/`, not `handle_path`.
- One file, one service. Delete the nix file, the organ is gone.
- Hardware, disks, NICs live on the host flake.
- Secrets: `LoadCredentialEncrypted` only. Nothing under `mediaRoot`.
- Eval must work before any fail-closed story counts.
- Factory returns users + units; merge both.
- Killswitch UIDs need a profile that still reaches the mark (not `IPAddressDeny=any` before routing).
- Disk presence is `mountpoint -q`, not `mkdir -p`.

## Rejected

- CrowdSec / Caddy WAF plugins (removed).
- mTLS and Caddy geoblock.
- External flake inputs for apps.
- Post-start `curl` to mutate app state.
