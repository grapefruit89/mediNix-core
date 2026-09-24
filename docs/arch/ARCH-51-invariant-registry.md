---
id: "ARCH-51-invariant-registry"
title: "ARCH 51 — Historical Failure → Contract Registry"
domain: 51
status: active
complexity: 3
last_reviewed: 2026-09-24
tags:
  - ingress
  - invariants
  - regression
  - audit
links:
  adr: ""
  model: "ARCH-51-ingress-architecture-model"
  matrix: "../ingress-security-matrix.md"
---

# ARCH 51 — Historical Failure → Contract Registry

Baseline: **`c604ec6`** (`main`, tree clean, `nix flake check` green, 51-ingress
frozen).

This registry answers, for each historical failure class:

> *Which class of failure must never silently return, and what enforces it?*

It is **not** a bug list. It converts past failures into durable contracts.

## Classification

```text
historical failure → root cause → invariant → enforcement layer
```

Enforcement layers:

- **A — hard Nix assertion** (deterministic at eval)
- **B — cross-module contract** (shared computed value / predicate)
- **C — regression test** (visible only in generated text/unit)
- **D — runtime gate** (Nix cannot know)
- **E — agent / change discipline** (protects development itself)

## Matrix

| ID | Invariant | Enforcement (concrete) | Protected? | Phase |
| --- | --- | --- | --- | --- |
| H01 | `*.{acmeHost} ⊇ {service}.{domain}` | Nix assertion (`514:74-83`) | yes | — |
| H02 | ACME credential ≠ DDNS credential | assertion (`514:59-65`) + negative test | yes | — |
| H04 | `External` only where forward_auth is really rendered | regression test `mediNix-arr-auth-method` | yes | — |
| H05 | forward-auth ⇒ explicit upstream | assertion (`511:323-325`) | yes | — |
| H06 | public-unauth only by explicit opt-in | assertion (`511:343,347`) | yes | — |
| H07 | active vhosts/landing ⇒ `trustedCidrs ≠ []` | assertion (`511:351`) | yes | — |
| H08 | emergency rights do not auto-grow with the registry | assertions (`520:133,141`) + negative tests | yes | — |
| H09 | `registry.uid = instance.uid = user.uid` | assertion (`526:102`) + negative test | yes | — |
| H10 | `ipv6 ∨ ¬enableIPv6` | assertion (`526:112`) + negative test | yes | — |
| H11 | one packet-filter owner; `managed` ⇒ firewall active | assertions (`520:61,72`) + check | yes | — |
| H23 | `request_header` < `forward_auth` | Caddy directive semantics + test | yes | — |
| H24 | repository evaluates | `nix flake check` (eval) | yes | — |
| H26 | non-root binds 80/443 | static profile (`hardening-profiles.nix:135`) | yes (static) | — |
| H03 | service FQDN only `${label}.${cfg.domain}` | prune: regression test ✅ / **anchor: open** | **partial** | B |
| H16 | all client identity headers stripped before trust-dependent backend | test covers ordering only, not completeness | **partial** | C |
| H17 | public Nix APIs never blindly reduced | **change pipeline (process)**, not mechanical | **partial** | E |
| H20 | `vhostName ∉ reservedLabels` | prune protection only, no assertion | **partial** | A |
| H12 | at most one Caddy owner (`standalone ⇒ ¬services.caddy.enable`) | — | **no** | A |
| H12b | standalone must not materialize `systemd.services.caddy` | regression test `mediNix-caddy-single-owner` | yes | — |
| H22 | `idp` only for the identity provider vhost | — | **no** | A |
| H13 | shared `enabledVhost` / `canonicalPublicFqdn` | — (three divergent predicates) | **no** | B |
| H14 | statically servable ⇒ discovery knows it | — | **no** | B |
| H15 | `.local` only for an existing edge endpoint | — | **no** | B |
| H18 | metadata headers ≡ generated docs | `check-docs` exists, **not wired into CI** | **no (CI-GAP)** | C |
| H19 | link scheme = actual TLS state | — | **no** | C |
| H21 | credential format uniform (513/514) | — (runtime) | **no** | C |
| H25 | Pocket-ID outbound | — | runtime | D |

**Qualitative summary:** several historical failure classes are already enforced
by assertions, regression tests, generated configuration or process guardrails;
others are open or require runtime evidence. A single count would be false
precision.

## Notes on selected items

- **H03 is one failure cluster with two technical halves:**
  ```text
  H03
   ├── service prune FQDN     ✅ fixed in c604ec6
   └── DNS anchor semantics   ⛔ data model still open (M16)
  ```
  Open question (must be decided, not derived from the service invariant):
  are `wan` / `lan` / wildcard / apex **technical zone anchors** (stay at
  `zone`) or should they also live under `domain`?

- **H18 = REAL / CI-GAP** (repo/agent infrastructure, not 51-ingress): the guard
  (`medinix-meta.py check-docs`, exits non-zero on drift/missing) exists but is
  **not** referenced in `.github/workflows/flake-check.yml`.

- **H12** is an **implication**, not `global XOR standalone`: `auto + caddy.enable`
  legitimately means global Caddy. `services.caddy.enable` may also arrive via
  `hostIntegration.reverseProxy = "managed"` (`500:31`).

- **H12b** (found on q958 at eval time, fixed in `6d47422`) is H12 at the
  systemd-unit level: `mkIf` on a **leaf**
  (`systemd.services.caddy.serviceConfig.OOMScoreAdjust = lib.mkIf useGlobal v`)
  still builds the option path → an empty phantom `caddy.service` appears in
  standalone mode. The fix guards the whole branch
  (`systemd.services.caddy = lib.mkIf useGlobal { … }`). Enforced by
  `checks.mediNix-caddy-single-owner` (standalone ⇒ `caddy-media` only; global ⇒
  `caddy` + `OOMScoreAdjust`).

- **H20** has **two scopes**: DNS zone (513/514: `wan`, `lan`, `*`, `@`,
  `_acme-challenge*`, apex) and local/mDNS (515: `home`). Not a single global list.

- **H22**: `idp` renders a WAN vhost **without** `authBlock` (`511:191-196`) and
  is **not** covered by the H06 public-unauth assertion (`511:45-47` filters
  `public` only). Semantics ("Pocket-ID only" vs general) and the identity
  mechanism are undecided.

## Phases

```text
Phase 0  Matrix reviewed & frozen                          (DONE)
Phase A  hard local guardrails        H12, H20, H22
Phase B  cross-module contracts       H03/M16, H13, H14, H15
Phase C  regression / CI              H16, H18, H19, H21
Phase D  runtime                      H25 + mDNS/ACME/Caddy-routes/header-trust/IPv6
Phase E  agent / change discipline    H17 (documented)
```

## Rule for Phase A onward

Do **not** start with "add the assertions". For each item first:

```text
failure → desired state → precise invariant
        → can Nix judge it safely?
        → correct enforcement layer
```

Otherwise an assertion that prevents one historical failure can forbid a
legitimate configuration.

Related: `ARCH-51-ingress-architecture-model`, `../ingress-security-matrix.md`
(R1–R20 / F1–F9), `56-agents/01-discipline/medinix-change-pipeline/SKILL.md`.
