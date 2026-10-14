# Portability Scan — K.O.-Kriterium Enforcement

mediNIX-core must stay a portable Flake: no hardcoded Host IPs, machine names, or house-VPN
names in `.nix` code or `mkOption default =`.

## Scan command (run from repo root)
```bash
# Strict: private/host-specific names that must NEVER be in .nix as default or code heuristic
grep -rn "mediahost\|example\.de\|192\.168\.\|wg0\|10\.8\.0\.\|Troi[sß]dorf\|grapefruit89@" \
  --include="*.nix" . || echo "SAUBER"

# Loose: what IS allowed as generic example = only
grep -rn 'example = "wg0"\|example = \[ "10.0.0.1" \]\|example.com' --include="*.nix" .
```

Allowed in `.nix`: `example = "wg0"`, `example = "example.com"`, `example = [ "10.0.0.1" ]`,
`acmeHost example = "example.com"`. These are documentation, not defaults.

## Mandatory exemptions (do NOT "fix" these)
- `docs/ADR-*.md` — historical ADRs that genuinely document the example.com / mediahost decision. Leave.
- `docs/ONBOARDING.md` — deliberate mediahost-specific deploy handoff. Leave (it is Host-doc, not module).
- `CHANGELOG.md` — may note "mediahost AUS" as project status. Leave.
- `AGENTS.md` — mediahost may appear as "physischer Deploy-Host" but must say "portabel bleibt".

## What to strip (violations)
- `default.nix` `example = "wg0"` → `"wg0"`; `example = "example.com"` → `"example.com"`.
- Any CLI grep heuristic matching `wg0` (e.g. `mediNix-cli` VPN probe) → drop `wg0`,
  keep `wg|vpn`.
- `README.md` quickstart `domain = "example.com"` → `"example.com"`.

## Net result after Phase 7/8 (this session)
- `526-vpn-policy-routing.nix` moved UID policy routing INTO the module (tables 5410/5360 +
  routingPolicyRules + fail-closed `unreachable`). Host no longer writes ip-rule recipes.
- `ADMIN-HANDOFF.md` §4 reduced to ≤5-line checklist + test. Host delivers only: WG interface +
  Keys (secret store), `vpn.interface`, `vpn.dnsServers`, `sabnzbd.enable`, `prowlarr.enable`.
- `*.nix` scan clean: no wg0/mediahost/example/192.168. Only generic examples remain.
