# Session 2026-08-12 — New Patterns (appendix to SKILL.md)

## 1. Systemd Service-Overlay — INFINITE RECURSION Pitfall
When laying `sandboxAttrs` / extra `serviceConfig` onto an EXISTING systemd unit
(e.g. VPN confinement onto sabnzbd + prowlarr):
- WRONG (Infinite Recursion / Build-Error):
  `systemd.services.sabnzbd = lib.recursiveUpdate config.systemd.services.sabnzbd sandboxAttrs;`
  You cannot read `config.systemd.services.X` while defining `config` itself → cryptic
  NixOS recursion error.
- RIGHT: apply directly via `mkMerge`, WITHOUT reading `config`:
  ```nix
  systemd.services.sabnzbd = lib.mkIf config.services.sabnzbd.enable (lib.mkMerge [ sandboxAttrs ]);
  systemd.services.prowlarr = lib.mkIf config.services.prowlarr.enable (lib.mkMerge [ sandboxAttrs ]);
  ```
- `sandboxAttrs` = `{ serviceConfig = { RestrictNetworkInterfaces = [...]; ... }; }`. Merged
  via `mkMerge`, NOT recursiveUpdate-from-config.

## 2. VPN-Confinement — UID-Routing instead of netns
Usenet stack (SABnzbd 5410, Prowlarr 5360) is NOT put in a network namespace. Instead
UID-based routing: the host (systemd-networkd routeTables or wg-quick) routes those UIDs'
packets through the VPN table.
- Advantage vs netns: no port-mapping, no ns-overhead, loopback (127.0.0.1) between Arr
  stack stays reachable, no build-race at ns teardown.
- Module `52-security/525-usenet-confinement.nix`: `sandboxAttrs` (RestrictNetworkInterfaces
  = ["lo" vpnIf], BindReadOnlyPaths = own resolv.conf, PrivateIPC, InaccessiblePaths
  /sys/class/net) via mkMerge onto sabnzbd + prowlarr.
- Active leak-check: `systemd.paths` watchdog on `/sys/class/net/<if>/carrier` +
  `/operstate` → fires `usenet-vpn-verify.service`.
- **usenet-vpn-verify script (Fail-Closed):** real IP comparison, NOT just fwmark-rule check.
  `HOST_IP=$(curl --interface "" https://api.ipify.org)` vs
  `VPN_IP=$(curl --interface $IFACE https://api.ipify.org)`; on equal →
  `systemctl stop sabnzbd prowlarr` + exit 1. Add `flock` lock + 60s cache file against
  Thundering Herd. Add `pkgs.curl` to `path`!
- `vpn.interface` default = "" (host provides the interface; mediNix-core creates none).
  `vpn.dnsServers` (NOT `vpn.dns`) for the own resolv.conf.
- Reference: Nix-Grok `modules/10-network/1096-vpn.nix` (UID-routing + IP leak-check).

## 3. 59X-Assertions-Schema — Invariants + Errors
Old monolithic files (`591-assertions.nix`, `592-rollout.nix`, `596-security-assertions.nix`)
DELETED. Replaced by:
- `590-registry.nix` — DATA ONLY (no NixOS module): `invariants` (INV-01..07, system
  guarantees that always hold) + `errors` (VPN/TLS/AUTH/DNS/SEC/STORE, user errors) +
  helpers `mkInvariant`/`mkError`/`mkErrorDoc` (last appends ADR link).
  `INV-` = architecture violation (decimal framework etc.); `XXX-NNN` = config error.
- `591-ingress` (TLS/AUTH), `592-security` (SEC), `594-transfer` (VPN),
  `597-maintenance` (DNS), `599-cross-domain` (INV-01..07) — each imports `./590-registry.nix`
  and calls `reg.mkErrorDoc "CODE" CONDITION "ADR-NR"`.
- `ops/59A1-emergency-user.nix` + `ops/59A2-backup-ssh.nix` — outside the 59X schema
  (hex prefix `59A`; no clash with 591-599). Live under `cfg.security.emergencyUser.enable`
  / `cfg.security.backupSsh.enable` (NOT `cfg.emergencyUser`).
- Guardrails live under `cfg.security.enable` (NOT `cfg.enable`) — assertion files use
  `lib.mkIf cfg.security.enable { ... }`.
- **Invariants** are stronger than assertions: system guarantees (Port=Num×10, 127.0.0.1
  bindings, GID 5000, stream never without TLS, no secret in Nix-Store, no PrivateDevices
  when /dev/dri needed). Violation = architecture break.

## 4. patch-Tool Escape-Drift on .nix with Quotes
`patch` fails with "Escape-drift detected" when `old_string`/`new_string` contain `\"`
sequences (e.g. curl-JSON inside `script = ''...''` blocks). Workaround: rewrite the whole
file via `write_file` (write_file ignores the escape matcher). Always `read_file` the
current file first so the rewritten content stays consistent. Affects only the `patch`
matcher, not `write_file`.

## 5. Vektor-DB Gold → real bug found
The store's Caddy/CrowdSec findings corrected a WRONG plugin name in the module
(`crowdsecurity/caddy-cs-bouncer` → `hslatman/caddy-crowdsec-bouncer`). Context7 has no
Caddy-plugin catalog; verify plugin names against the actual upstream repo. This was the
only source that caught a real build-blocker.
