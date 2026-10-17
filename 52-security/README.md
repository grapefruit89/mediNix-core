---
id: 52-security
title: Security Domain (Core, Credentials & VPN)
description: Foundational host security, sealed systemd credentials, break-glass access, WireGuard and fail-closed VPN confinement.
aliases: [Security, Hardening, Credentials, VPN]
tags: [architecture, medinix, security, systemd-creds, wireguard, nftables, policy-routing]
last_reviewed: 2026-10-17
---

# 52-security: Security & Hardening Domain

Additive host integration. Domain 52 does not force `networking.firewall.enable`, global default-drop, or `boot.kernel.sysctl`. Hosts opt in.

**Scope (KISS):** `_2` protects **the system itself** — secrets (521), VPN (525/526), **host** firewall, kernel hardening. The **edge defenses** (Geo-IP, CrowdSec, rate-limiting) belong to `51-ingress` (`_1`), because they govern *who gets in*. Mnemonic: *`_1` = the door + who gets through · `_2` = protect the house.*

Four modules. 528 and 529 were stubs; their leftovers live in 520. Do not recreate them.

## 1. Module map

| ID | Module | Responsibility |
| --- | --- | --- |
| **520** | [`520-core-security.nix`](520-core-security.nix) | GID 5000, optional `media-admin`, `medinix.recommended.*`, optional LUKS+TPM2 |
| **521** | [`521-creds.nix`](521-creds.nix) | Sealed-only `systemd-creds` policy at eval time |
| **525** | [`525-vpn-interface.nix`](525-vpn-interface.nix) | WireGuard interface + encrypted private key |
| **526** | [`526-vpn-killswitch.nix`](526-vpn-killswitch.nix) | UID mark + policy routing + unreachable fallback |

## 2. Credentials

```
encrypted blob on disk
        ↓
LoadCredentialEncrypted
        ↓
/run/credentials/<unit>/
        ↓
service reads at runtime
```

`lib/creds.nix` validates the path. `521` enforces it. Service modules declare their own `LoadCredentialEncrypted`.

Accepted names: `*.encrypted`, `*.cred`, `/etc/credstore.encrypted/…`.
Rejected: `dns.ddns.tokenFile`, `passwordFile`, anything under `storage.mediaRoot`, `secrets.autoGenerate`.
Store: `/var/lib/medinix/secrets/`.

## 3. VPN

```
525 interface
        ↓
526 killswitch
        ├─ nftables mark by UID
        ├─ policy table
        └─ unreachable default if the VPN route is gone
```

526 is **not** "absolute isolation". Confined UIDs may still reach loopback, RFC1918/ULA, and the VPN iface. Everything else is drop. WAN without the tunnel is the thing that fails closed.

## 4. Break-glass

`media-admin` is SSH-key only. sudo is `systemctl restart <registry unit>` and `systemctl status * --no-pager`. No shell, no `nixos-rebuild`.

## 5. Declarative vs. imperative

**Declarative** (Nix values, reproducible):

- `users.groups.media.gid`, `users.users.media`
- `users.users.root.openssh.authorizedKeys.keys` (additive)
- `users.users.media-admin`, `security.sudo.extraConfig`
- `boot.initrd.systemd.enable`, `boot.initrd.luks.devices."root"`
- `networking.wireguard.interfaces.<if>` (525)
- `networking.nftables.tables.medinix_vpn_{mark,filter}` (526 — written only
  while `networking.nftables.enable`)
- `systemd.services.medinix-vpn-route` (526)
- `environment.etc."medinix-killswitch-resolv.conf"` (526)
- `medinix.recommended.*` (suggestion only — see the host interface)

**Imperative, deliberately** — the `ExecStart` of `medinix-vpn-route` (526):

```
ip rule add fwmark <mark> table <table> priority 1000
ip route replace unreachable default table <table> metric 100
ip route replace default dev <vpnIf> table <table> metric 10
```

That is **not** a setup script: it is `Type=oneshot` with `RemainAfterExit=true`,
so the state is re-established on every boot, and `ExecStart` verifies
fail-closed (`ip rule show | grep`). `networking.iproute2` is **not** an option
for this on unstable (only `rttablesExtraConfig` exists); a `systemd-networkd`
rewrite (`[RoutingPolicyRule]`/`[Route]`) is open.

Two deliberate couplings:

- `networking.firewall.checkReversePath = lib.mkDefault "loose"` (526) —
  WireGuard routing is asymmetric and breaks with `strict`. Overridable; a
  `mkForce "strict"` breaks the killswitch.
- `networking.nftables.tables.*` (526) — own namespace (`medinix_vpn_*`), written
  **only** while `networking.nftables.enable`, and asserted (see the matrix).

## 6. Host interface

| Field | Values | Producer | Consumer | 52 behaviour |
| --- | --- | --- | --- | --- |
| `hostIntegration.firewall` | `managed`/`external`/`off` | 500 | 520 (assertion) | `managed` ⟹ `networking.firewall.enable` or `networking.nftables.enable` |
| `hostIntegration.nftables` | `managed`/`external`/`off` | 500 | 520 (XOR assertion), 526 | `managed` ⟹ 503 sets `networking.nftables.enable`; 526 asserts `enable` — **not** `managed`, so an external host with its own nftables activation passes |
| `medinix.recommended.*` | free | 520 | 503 (`recommended.nftables`), host | 52 never writes `boot.kernel.sysctl`; the rest is an exported suggestion list |

**Forbidden in 52:** writing `boot.kernel.sysctl`, setting
`networking.firewall.enable` itself, touching Caddy/vhosts/ACME/DDNS/mDNS.

## 7. Fail-closed: assertion matrix

Every assertion is a **build break**, not a warning.

| Module | Assertion | Protects against |
| --- | --- | --- |
| 520 | `firewall = managed` ⟹ `firewall.enable \|\| nftables.enable` | managed claim without an active packet filter |
| 520 | `firewall = managed` **XOR** `nftables = managed` | two competing packet-filter owners |
| 520 | `em.enable` ⟹ `em.allowedServices != []` | break-glass user that may restart nothing |
| 520 | every `em.allowedServices` ∈ `registry.services` | typo in the break-glass list |
| 520 | `fde.enable` ⟹ `fde.rootUuid != null` | LUKS device without UUID = boot hang |
| 521 | generated `secretChecks`: `secrets.*File` sealed and not under `storage.mediaRoot` | plaintext secret in the store; API key inside the player write domain |
| 521 | `!secrets.autoGenerate` | plaintext key generation |
| 521 | `dns.ddns.tokenFile == null` | Cloudflare token in cleartext |
| 521 | backup/offsite: `passwordFile` empty and credential sealed | backup password in cleartext |
| 525 | `privateKeyCredentialPath != null` | WireGuard without a key (cryptic systemd failure) |
| 525 | `vpn.dns != []` | DNS leak via a cleartext resolv.conf |
| 525 | `vpn.peer.publicKey != ""` | peerless interface = up, but carries no traffic |
| 526 | `dnsServers != []`, `vpnInterface != ""` | killswitch without DNS / interface |
| 526 | every instance name ∈ `config.systemd.services` | killswitch for a non-existent unit |
| 526 | **R15:** `registry.uid == instance.uid == users.<unit-user>.uid` | killswitch targeting the wrong UID |
| 526 | **R16:** `ipv6 ∨ !networking.enableIPv6` | IPv6 escape from a confined UID |
| 526 | `checkReversePath != true` | asymmetric routing drops WireGuard packets |
| 526 | `networking.nftables.enable` | killswitch tables declared but never loaded |

## 8. Known findings

- **`unitUserOf` fallback (526):** without `serviceConfig.User` the helper falls
  back to the service name; for `DynamicUser = true` that user usually does not
  exist → R15 fires. Fail-closed, but the message does not name the cause.
- **`networking.iproute2`:** no option for `ip rule` / `ip route` with fwmark and
  `unreachable default` on unstable. The `Type=oneshot` service is the
  replacement; a `systemd-networkd` rewrite is open.
- **`medinix.recommended.sysctl`, `.mountOptions.staging`,
  `.firewall.checkReversePath`** are set by 520 but read by nobody in-tree — they
  are an exported host suggestion list (503 applies only `recommended.nftables`,
  never sysctl).

## 9. Threat model: GID 5000

`Group=media` plus `UMask=0002` is the library write domain. Compromised Sonarr can rewrite an mkv. It must not rewrite an API key. Secrets stay off `mediaRoot`. Players bind the library read-only; SAB writes only `mediaRoot/downloads`.

## 10. Host firewall

`hostIntegration.firewall = managed` lists 80/443. It does not enable the firewall. 520 asserts `networking.firewall.enable` or `networking.nftables.enable` when `managed` is set.

`medinix.recommended.sysctl` is a suggestion list. 520 does not write `boot.kernel.sysctl`.

## Agent rule

1. No plaintext secret path.
2. Validate with `lib/creds.nix`.
3. Use `LoadCredentialEncrypted`.
4. Do not silently widen 526 allow-rules into WAN.
5. Keep 525 and 526 separate.
6. Do not bring back 528/529.
7. When the module tree changes, update this file and `AGENTS.md`.
