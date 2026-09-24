---
id: "ARCH-51-closure-matrix"
title: "ARCH 51 — Closure Matrix (OPEN + Edge Security)"
domain: 51
status: active
complexity: 3
last_reviewed: 2026-09-24
tags:
  - ingress
  - closure
  - security
  - audit
links:
  adr: ""
  registry: "ARCH-51-invariant-registry"
  model: "ARCH-51-ingress-architecture-model"
---

# ARCH 51 — Closure Matrix (OPEN + Edge Security)

Baseline: `main` @ `3c53507`; q958 pinned to `ebe0d28` (code) and **runtime-verified
for the Gate-4 base** (`caddy-media` serves `http://home.local` 200, CIDR-gated).

Rule for this document: **no bare `OPEN`.** Every item ends as one of:

```text
FIXED              implementation + assertion/test
VERIFIED           additionally proven on the runtime layer
ACCEPTED           deliberate, with the trade-off stated
DESIGN-DECIDED     a contract was chosen; implementation may follow
```

Evidence chain per item: `Source → Eval → Generated config → Runtime → E2E`.

## Phase C — Edge / Security feature audit (actual activation)

The question is not "is it in the Nix code?" but "did it reach the generated
config and does it act at runtime?"

| Feature | Source | Eval | Generated config | Runtime | E2E | Verdict |
| --- | --- | --- | --- | --- | --- | --- |
| trustedCidrs | ✓ `511` | ✓ assertion | ✓ `remote_ip` abort in Caddyfile | ✓ | ✓ untrusted src aborted | **VERIFIED** |
| mDNS (`{svc}.local`) | ✓ `515` | ✓ | ✓ `avahi-publish` | ✓ running | ✓ `home.local` resolves | **VERIFIED** |
| Landing page | ✓ `518` | ✓ | ✓ `root`/`file_server` | ✓ | ✓ HTTP 200 | **VERIFIED** |
| Header strip (`request_header`) | ✓ `511:87-95` | ✓ `mediNix-ingress-header-strip` | ✓ | ✗ (needs forward-auth vhost) | ✗ | **partial** (eval/build only) |
| TLS / ACME | ✓ `514` | ✓ `mediNix-acme-positive` | ✗ (no `acmeHost` on q958) | ✗ | ✗ | **not runtime-verified** |
| DNS / DDNS | ✓ `513` | ✓ `mediNix-ddns-prune-fqdn` | ✗ (no ddns on q958) | ✗ | ✗ | **not runtime-verified** |
| Firewall | host-owned (`external`) | — | — | ✗ disabled on q958 | — | **ACCEPTED** (host owns it) |
| **CrowdSec** | option only, **no module reads it** (`default.nix:824`) | ✗ | ✗ | ✗ | ✗ | **NOT IMPLEMENTED** |
| **Rate limiting** | ✗ | ✗ | ✗ | ✗ | ✗ | **NOT IMPLEMENTED** |
| **Geo blocking** | ✗ | ✗ | ✗ | ✗ | ✗ | **NOT IMPLEMENTED** |

Notes:

- **CrowdSec**: `medinix.security.crowdsec.{enable,enrollKeyFile}` is declared
  (`default.nix:824`) but **no module consumes it**; `519` only *references*
  "CrowdSec (516)" in comments/assertion text and there is **no `516` module**.
  Dead option → remove or implement.
- **Rate limit / Geo block**: no source, no generated directive, no runtime.
  Geo blocking has **no realistic runtime test path** on q958 (no external egress
  geography) → if ever implemented, that must be documented as a runtime gap, not
  claimed as working.
- Header strip is proven only at eval/build (generated `request_header` order);
  a real negative request test needs a forward-auth vhost at runtime.

## Phase A — known runtime / eval bugs

- **H27 — orphan-cleanup** `OPEN`
  - Frage: single option home, default, endpoint.
  - Dateien: `57-maintenance/578-orphan-cleanup.nix:94`, `default.nix:483`.
  - Evidence: `medinix.orphanCleanup.enable=true` (578, default) vs
    `medinix.maintenance.orphanCleanup.enable=false` (default.nix, dead);
    `medinix-orphan-cleanup.timer` active; script curls hardcoded
    `https://ntfy.sh/medinix-alerts-example`.
  - Gewünschte Semantik: one option under `maintenance.*`, default **off**, no
    hardcoded public endpoint.
  - Impl: partial · Test: none · Runtime test: yes (timer) · Endstatus target: `FIXED`.

- **H30 — StateDirectory conflict** `OPEN`
  - Frage: who owns `systemd.services.<svc>.serviceConfig.StateDirectory`?
  - Dateien: `54-transfer/541-sabnzbd.nix`, `55-playback/551..553` vs nixpkgs modules.
  - Evidence: `"sabnzbd"` (nixpkgs) vs `"sabnzbd-5410"` (mediNix) → eval error the
    moment the service is enabled (latent for Gate-4 base).
  - Gewünschte Semantik: explicit ownership (`mkForce` mediNix dir **or** adopt
    nixpkgs dir **or** reconfigure nixpkgs service).
  - Endstatus target: `DESIGN-DECIDED` + `FIXED`.

## Phase B — open invariants

- **H13 — one canonical vhost predicate** `OPEN`
  - Dateien: `511:35-43` (`enabled && accessGroup!="none" && (hasPort||hasStatic)`),
    `515:33-43` (`enabled && accessGroup!="none" && port!=null`),
    `518:30-32` (`landing && accessGroup∈{stream,public}`, **no `enabled`**).
  - Gewünschte Semantik: shared `enabledVhost` / `servable` / `publicFqdn`.
  - Endstatus target: `FIXED` (shared predicate).

- **H14 — landing tile ⇒ servable endpoint** `OPEN`
  - Dateien: `518:30-32`.
  - Evidence: `tiles` does **not** check `cfg.<svc>.enable` → a disabled service
    with `accessGroup∈{stream,public}` yields a tile pointing at an endpoint 511
    never renders.
  - Endstatus target: `FIXED` + regression test.

- **H15 — `.local` ⇔ existing endpoint** `OPEN`
  - Dateien: `515:40` (no `hasStatic`) vs `511:42` (`hasStatic`).
  - Evidence: a `customConfig`-only vhost is servable via 511 but gets no mDNS.
  - Endstatus target: `FIXED` or `DESIGN-DECIDED`.

- **H16 — complete identity-header trust boundary** `partial`
  - Dateien: `511:87-95`.
  - Evidence: order proven by `mediNix-ingress-header-strip`; completeness vs the
    chosen auth proxy (oauth2-proxy) not proven by a negative request test.
  - Endstatus target: `VERIFIED` (negative runtime test).

- **H18 — docs drift gate in CI** `OPEN`
  - Dateien: `.github/workflows/flake-check.yml` (runs only `nix flake check`).
  - Evidence: `medinix-meta.py check-docs` exists, exits non-zero on drift, but is
    not wired into CI.
  - Endstatus target: `FIXED`.

- **H19 — landing link scheme ⇔ TLS state** `OPEN`
  - Dateien: `518:39` (`https://…` whenever `domain != null`).
  - Evidence: ignores `tlsEnabled` (`511:62`) → with `domain` set but no TLS the
    tile links to `https://` while 511 serves `http://`.
  - Endstatus target: `FIXED`.

- **H20 — reserved DNS labels** `OPEN`
  - Dateien: `513:33-49`, `515:43`.
  - Scopes: DNS zone (`wan`,`lan`,`*`,`@`,`_acme-challenge*`, apex) and local/mDNS
    (`home`).
  - Endstatus target: `FIXED` (zone-scoped reservation assertion).

- **H21 — credential content format** `OPEN`
  - Dateien: `513:124-130`, `514:106-114`, `52-security/521-creds.nix`, `lib/creds.nix`.
  - Evidence: transport is pinned (`LoadCredentialEncrypted`); the **content**
    contract (token vs JSON vs key/value) producer↔consumer is not asserted.
  - Endstatus target: `DESIGN-DECIDED` + assertion/test.

- **H22 — `idp` identity** `OPEN`
  - Dateien: `511:191-196` (`idp` = WAN vhost **without** `authBlock`), `512`.
  - Evidence: not covered by the H06 `public`-only assertion.
  - Gewünschte Semantik: explicit `auth.provider`/identity, not name magic.
  - Endstatus target: `DESIGN-DECIDED` + `FIXED`.

- **H25 — Pocket-ID outbound networking** `OPEN`
  - Dateien: `512:131` (`RestrictNetworkInterfaces=["lo"]`).
  - Evidence: whether this is compatible with required OIDC behaviour is a
    **runtime** question, not an eval one.
  - Endstatus target: `VERIFIED` (runtime).

- **H03/M16 — DNS anchor semantics** `OPEN` (architecture)
  - Dateien: `513:249-252` (anchor `wan.$ZONE/lan.$ZONE/*.$ZONE/$ZONE`).
  - Frage: is `dns.ddns.zone` a technical zone anchor namespace, and how do
    `domain`/`acmeHost`/`wan`/`lan`/`*`/`@` map onto it when `domain` is a
    subdomain?
  - Endstatus target: `DESIGN-DECIDED` + assertion.

- **F7 — `customConfig`-only vhosts** `DESIGN (deliberate)`
  - Dateien: `511:42`, `518`.
  - Evidence: `enabled` requires `medinix.<name>.enable`; `hasStatic` is
    effectively unreachable for a vhost without an enabled service.
  - Endstatus target: `DESIGN-DECIDED` (state it, then align 518/H14/H15).

## Summary

- **Bugs (Phase A):** H27, H30.
- **Invariant gaps (Phase B):** H03/M16, H13, H14, H15, H16, H18, H19, H20, H21, H22, H25, F7.
- **Security features not actually implemented (Phase C):** CrowdSec, rate limiting, geo blocking.
- **Verified on runtime:** trustedCidrs, mDNS, landing.
- **Not yet runtime-verified:** TLS/ACME, DNS/DDNS, header trust.

No counts are claimed as "done"; each item above carries its own end status.
