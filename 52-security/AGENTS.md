# LLM Wiki: `52-security`

> **Purpose:** Break-glass access, sealed systemd credentials, WireGuard, fail-closed VPN confinement.

## Module Map

| ID | Module | Status | Complexity | Responsibility |
| --- | --- | --- | ---: | --- |
| `520-core-security` | `520-core-security.nix` | active | 3/5 | media GID, media-admin, recommended.*, optional FDE |
| `521-creds` | `521-creds.nix` | active | 3/5 | sealed-only credential policy |
| `525-vpn-interface` | `525-vpn-interface.nix` | active | 4/5 | WireGuard + encrypted private key |
| `526-vpn-killswitch` | `526-vpn-killswitch.nix` | active | 5/5 | UID nftables + policy routing |

There is no `528-fde-tpm2.nix` and no `529-recommendations.nix`. Do not recreate them. FDE options live in 520.

## Dependencies

- `lib/creds.nix` — path contract for 521
- `lib/registry.nix` — sudo unit list for 520, UIDs for 526

```
lib/creds.nix → 521-creds.nix
525-vpn-interface → 526-vpn-killswitch
520-core-security → lib/registry.nix
```

## Invariants

- Plaintext secrets and `dns.ddns.tokenFile` are rejected.
- Secret paths must not live under `storage.mediaRoot`.
- Load secrets with `LoadCredentialEncrypted`.
- GID 5000 is a shared library write domain, not a secret domain.
- VPN confinement is opt-in by UID. Fail closed when the VPN route is gone.
- 526 may allow loopback + RFC1918/ULA. That is not WAN.
- 525 and 526 stay separate.
- Domain 52 does not force host firewall or sysctl.

## Agent rules

- Never add a plaintext secret fallback.
- Never put credentials under the media tree.
- Do not widen VPN allow-rules without an explicit decision.
- Do not merge 525 and 526.
- Do not reintroduce 528/529.
- Credential changes: edit both `521-creds.nix` and `lib/creds.nix`.
- Keep this file and README in sync with the files that actually exist.
