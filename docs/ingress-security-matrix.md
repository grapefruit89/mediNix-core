# Ingress Security Matrix (Red-Team R1–R20)

Scope: the red-team audit of `51-ingress` / `52-security`. This file records the
**verified verdict** per finding and **which assertion or test enforces it**.

Rule for this document: it claims nothing that is not backed by an executed
check. Verify with:

```bash
nix flake check            # evaluates all checks
nix build .#checks.x86_64-linux.<name>   # runs the named negative/positive test
```

Design principle: **security by explicit intent** — unsafe choices stay
possible, but they must be *declared*, never inherited from a default.

## Findings

| ID  | Verdict | Enforced by |
| --- | --- | --- |
| R1  | DESIGN  | `stream` accessGroup template has no `forward_auth` (511); app auth is authoritative. WAN exposure is an explicit choice. |
| R2  | REAL → fixed | public vhost without auth → build error unless `auth.mode = "forward-auth"` or `allowUnauthenticated = true` (511 assertion). |
| R3  | REAL → fixed | `ingress.auth.localBypass` default `false`; per-vhost `localBypass` explicit (511 `applyAuth`). |
| R4  | REAL → fixed | `trustedCidrs` default `[]`; any enabled vhost with empty list → build error (511). |
| R5  | ACCEPTED | `customConfig` is the documented owner escape hatch; the security policy owner stays 511. |
| R6  | REAL → fixed | `skipPaths` renamed to `unauthenticatedPaths`; public vhost with bypass paths → build error (511). |
| R7  | REAL → fixed (2nd pass) | 1st fix used response-only `header`; corrected to `request_header` (F1). `checks.mediNix-ingress-header-strip` now requires `request_header` + order before `forward_auth`. |
| R8  | DESIGN  | DDNS prune needs `Zone:DNS:Edit`; that is exactly the documented token scope (default.nix, 513). |
| R9  | PHANTOM | 513 reads its credential consistently (`$CREDENTIALS_DIRECTORY/cf-ddns-token`, 513:110). |
| R10 | PHANTOM | 513 uses `profile = "network"`, not `script`. |
| R11 | REAL → fixed | ACME/DDNS use separate tokens; equal paths → build error (514). `checks.mediNix-negative-token-shared` now uses `expectAssertion` (fires for the **right reason** — v1 was green because an unrelated option was broken, F3). |
| R12 | REAL → fixed | `firewall = "managed"` → 500 enables `networking.firewall.enable`; C1 guardrail + single-owner assertion (520) + `checks.mediNix-firewall-managed`. |
| R13 | ACCEPTED | `rp_filter = 2` is a **recommendation** (520 `recommended.sysctl`), loose mode is correct for WireGuard/policy-routing. |
| R14 | REAL → fixed | emergency user restarts **only** `security.emergencyUser.allowedServices`; empty/unknown → build error (520) + `checks.mediNix-negative-emergency-*`. |
| R15 | REAL → fixed | 526 asserts `registry.uid == instance.uid == users.<unit-user>.uid` + `checks.mediNix-negative-uid-chain`. |
| R16 | REAL → fixed | 526 asserts `ipv6 \|\| !networking.enableIPv6` (fail-closed) + `checks.mediNix-negative-vpn-ipv6`. |
| R17 | DESIGN  | 526 permits loopback + explicit LAN CIDRs — it is *egress confinement*, not "all traffic must use VPN". |
| R18 | DESIGN  | 52 protects processes; 51 owns the ingress policy. Kept separate by design. |
| R19 | DESIGN  | forward_auth header trust = strip client headers, then copy trusted ones (R7 test closes the regression gap). |
| R20 | ADDRESSED | Batch B0 + this matrix: fail-closed defaults, explicit intent, executed checks. |

## Findings from the independent cold-start audit (2nd pass)

These are additional findings from a fresh, independent review that did **not**
read this file. They are kept separate from R1–R20.

| ID  | Verdict | Evidence |
| --- | --- | --- |
| F1  | REAL → fixed | `stripAuthHeaders` used response-only `header`; now `request_header` (511:73). Covered by `checks.mediNix-ingress-header-strip`. |
| F2  | REAL → fixed | `AUTH__METHOD = External` iff `auth.mode=forward-auth`, but the 511 `internal` template (`511:169`) has **no `authBlock`** → rendered `sonarr.example.com` = CIDR-abort + `reverse_proxy` only (`forward_auth` count 0), while `public` (seerr) gets `request_header`+`forward_auth` ⇒ LAN client reaches *arr which trusts a non-existent proxy → admin without login. Fix (532/533/536): `External` only when the **resolved** vhost exposure is `public`, else `Forms` (534/535 already `Forms`). Test `checks.mediNix-arr-auth-method`. |
| F3  | REAL → fixed | 514 used `security.acme.certs.<n>.environment`, which does not exist in nixpkgs → `tls.acmeHost` broke evaluation. Now `dnsResolver`; `checks.mediNix-acme-positive`. |
| F4  | REAL → fixed | Rendered with `landing.enable`, no vHosts, `trustedCidrs=[]`: `http://home.local { root * …; file_server }` with **no abort** → reachable via WAN `Host: home.local`. Fix: assertion now `(enabledServices == {} && !landingOn) \|\| trustedCidrs != []`. Test `mediNix-negative-landing-cidrs`. |
| F5  | REAL → fixed | Pocket-ID docs: *"exclusively an OIDC provider … no built-in proxy provider"*; `/oauth2/auth` is oauth2-proxy's endpoint. Fix: removed the Pocket-ID fallback; assertion requires `authProxyPresent` + non-empty `forwardAuthUpstream`. Test `mediNix-negative-forward-auth-upstream`. |
| F6  | fixed | Assertion (514): `domain == null \|\| domain == acmeHost \|\| hasSuffix ".${acmeHost}" domain`. Test `mediNix-negative-acme-domain`. |
| F7  | DESIGN (open) | `customConfig`-only vHosts never render (`enabled` requires `medinix.<name>.enable`); `hasStatic` effectively unreachable. **Deliberately not touched** — architecture decision. |
| F8  | fixed | `515-mdns` filter now also requires `accessGroup != "none"`. |
| F9  | fixed | `unauthenticatedPaths` typed `strMatching "^/[^ \t\"{}]*$"` (global + per-vhost) → whitespace/quotes/braces rejected, no silent bypass widening. |

## Runtime access matrix

| Source        | Host                | accessGroup | Expectation                    |
| ------------- | ------------------- | ----------- | ------------------------------ |
| WAN           | `svc.{domain}`      | `internal`  | abort (not in trustedCidrs)     |
| LAN           | `svc.{domain}`      | `internal`  | reachable (CIDR-gated)          |
| WAN/LAN       | `svc.{domain}`      | `public`    | forward_auth required           |
| WAN           | `svc.{domain}`      | `stream`    | app auth (explicit exception)   |
| WAN           | `svc.{domain}`      | `idp`       | login reachable, no forward_auth|
| WAN           | `svc.local`         | (any)       | abort (CIDR-gated)              |
| WAN           | unknown host        | catch-all   | abort                           |
| client sends  | `Remote-User` hdr   | `public`    | ignored; auth response wins     |
| VPN down      | confined uid (IPv4) | —           | DROP                            |
| VPN down      | confined uid (IPv6) | —           | DROP (ipv6 asserted on)         |
