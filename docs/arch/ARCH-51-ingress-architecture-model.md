---
id: "ARCH-51-ingress-architecture-model"
title: "ARCH 51 — Ingress Architecture Model"
domain: 51
status: active
complexity: 3
last_reviewed: 2026-09-24
tags:
  - ingress
  - architecture
  - caddy
  - dns
  - acme
  - oidc
links:
  adr: "ADR-511"
  registry: "ARCH-51-invariant-registry"
---

# ARCH 51 — Ingress Architecture Model

Baseline: `c604ec6` (see `ARCH-51-invariant-registry`).

`51-ingress` is **not** "Caddy configuration". It is the declarative
**access / edge layer** of mediNix-core.

## Layered model

```text
                    ┌──────────────────────────────┐
                    │        NixOS / flake         │
                    │  declarative whole config    │
                    └──────────────┬───────────────┘
                                   │
                    ┌──────────────▼───────────────┐
                    │      lib / central SSoT      │
                    │ registry / factory / creds   │
                    │ hardening profiles           │
                    └──────────────┬───────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
              ▼                    ▼                    ▼
       Service modules         51-ingress            52-security
       55x / registry           "the door"            "the house"
              │                    │                    │
              │                    ▼                    │
              │              Caddy / DNS                │
              │              ACME / mDNS                │
              │              Auth / Landing             │
              │                    │                    │
              └─────────────► service endpoint ◄───────┘
                                   │
                                   ▼
                              systemd services
```

## 1. Declarative intent model

A service does not say "start Caddy with 37 directives". It declares its edge
intent:

```text
I am service X
I listen on port P
I want to be reachable under this edge name
my exposure class is public/internal/stream/idp/none
```

This lands in `medinix.ingress.vhosts."<service>"` and is consumed by several
edge organs:

```text
service module ──intent──► ingress.vhosts
                              ├──► 511 Caddy
                              ├──► 513 Cloudflare DNS
                              ├──► 514 ACME
                              ├──► 515 mDNS
                              └──► 518 Landing page
```

A service registers **once**; multiple edge organs consume that one intent.

## 2. Registry is the identity SSoT

`lib/registry.nix` defines the technical identity (`port`, `uid`, `gid`) with the
deliberate contract:

```text
port = num × 10 | uid = port | gid = 5000
```

and the chain is actually enforced:

```text
registry.uid == instance.uid == users.<unit-user>.uid
```

→ One technical identity, verified through the layers (H09).

## 3. Service factory

The factory (`lib/service-factory.nix`) produces recurring systemd/NixOS
structures so hardening is applied centrally. Its arguments are an **API**: a
parameter can be API-relevant even when the body does not use it (the `deadnix`
incident → H17, see the change pipeline).

## 4. Ownership boundary: 51 = door, 52 = house

```text
INTERNET / LAN ──► 51-ingress ("who gets in?") ──► service backend ──► 52-security ("how does the house stay safe?")
```

`51-ingress`: Caddy, public/private vhosts, auth integration, DNS, ACME, mDNS,
landing page, edge guardrails.

`52-security`: firewall, VPN, credentials, host protection, emergency access,
killswitch.

This is an ownership boundary, not just file organisation.

## 5. Ingress flow

```text
service seerr ──► ingress.vhosts.seerr
                       ├──► 511        → seerr.<domain>
                       ├──► 513/514    → DNS records
                       └──► 515        → seerr.local
                       518 consumes the same intent for the landing page
```

There are **not** five separate service definitions.

## 6. Canonical address model — exactly two addresses

For every service `{service}`:

```text
{service}.local
{service}.{domain}
```

and nothing else. Example: `domain = home.example.com`, `zone = example.com`,
`service = seerr`:

```text
seerr.local
seerr.home.example.com     ← canonical
seerr.example.com          ← WRONG
```

```text
domain = logical public service namespace
zone   = Cloudflare DNS zone / technical API layer
```

`zone` must **never** define a service FQDN. (This was the real 513 bug; the
prune path was fixed in `c604ec6`; the anchor half is still open → H03/M16.)

## 7. DNS and ACME are separate models

513 owns the Cloudflare DNS anchor (DDNS + technical zone records); 514 owns the
ACME certificate for `acmeHost` (`*.acmeHost`). Two invariants:

```text
ACME credential ≠ Cloudflare DDNS credential
domain must be covered by acmeHost
```

## 8. Auth is its own intent model

```text
Pocket-ID  ≠  forward-auth gateway
```

Pocket-ID is the OIDC Identity Provider. A vhost may explicitly say
`auth.mode = "forward-auth"` and then **must** provide an explicit
`forwardAuthUpstream`. There is no implicit "Pocket-ID is running, so
`/oauth2/auth` will work".

## 9. Access groups are exposure semantics

`stream`, `public`, `internal`, `idp`, `none` drive exposure and auth rules.
`idp` is a semantic class whose identity is not yet hard-bound to a specific
vhost → **H22 open**.

## 10. `.local` is discovery, not a security boundary

`{service}.local` is a local naming/discovery path. The security boundary comes
from `trustedCidrs`, `auth`, `localBypass`, `accessGroup`, firewall/VPN. `.local`
must never be the sole access control.

## 11. Consumer graph

```text
ingress.vhosts ──► Caddy ──► HTTP/S ──► Landing
                 ├──► DNS  ──► public DNS
                 └──► mDNS ──► *.local
```

All consumers should share **one** definition of "enabled vhost" /
"servable endpoint". Today 511/515/518 each carry their own predicate →
**H13/H14/H15 open (Phase B)**.

## 12. Chameleon Caddy ownership

```text
ingress.mode
 ├── auto       ├── services.caddy.enable=true  → global Caddy
 │              └── false                       → caddy-media
 ├── global     → global Caddy
 └── standalone → caddy-media
```

This is **not** a simple XOR. The precise invariant is:

```text
mode == "standalone" ⇒ ¬services.caddy.enable
```

→ **H12 open (Phase A)**. The rule is derived from ownership semantics, not from
option names.

## 13. Fail closed, as early as possible

Wrong configuration should stop the **build** (Nix assertion), not surface at
runtime:

```text
public without explicit opt-in        → assertion
forward-auth without upstream         → assertion
active vhosts without trustedCidrs    → assertion
ACME == DDNS credential               → assertion
IPv6 active without IPv6 killswitch   → assertion
UID chain inconsistent                → assertion
managed firewall but firewall inactive→ assertion
```

## 14. Not everything becomes an assertion — the evidence chain

```text
Nix can prove        → assertion / eval test
Build can prove      → build / regression test
Only runtime proves  → runtime test
Process problem      → agent / change pipeline
```

```text
Source → Eval → Build → CI → Runtime
```

Example H25 (`RestrictNetworkInterfaces = [ "lo" ]`): whether this breaks
required outbound functions cannot be proven by a Nix assertion → Runtime.

## 15. Historical failure analysis is itself an architecture model

The H01–H26 matrix answers: *which class of failure must never silently return?*

```text
historical failure → root cause → invariant
  ├── assertion
  ├── regression test
  ├── build check
  ├── runtime test
  └── process guardrail
```

This is **engineering integrity** security, distinct from firewall/auth. See
`ARCH-51-invariant-registry`.

## 16. The seven core models

1. **Declarative intent model** — services declare edge intent; 51-ingress consumes it.
2. **Single source of truth / identity** — registry defines identity; factory/units must adopt it.
3. **Ownership boundary** — 51-ingress = door, 52-security = house.
4. **Canonical address model** — exactly `{service}.local` + `{service}.{domain}`; `zone` is infrastructure, not a second namespace.
5. **Fail-closed invariant model** — contradictions are rejected at Nix evaluation.
6. **Consumer graph model** — Caddy/DNS/ACME/mDNS/Landing consume the same intent (H13/H14/H15 not yet centralised).
7. **Evidence & change-control model** — `Source → Eval → Build → CI → Runtime` plus the change pipeline against agent/rewrite regressions.

## Status

`c604ec6` is the architecture baseline. Open items are bounded invariants, not an
architecture rebuild — see `ARCH-51-invariant-registry` (phases A–E).
