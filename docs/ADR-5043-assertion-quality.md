---
id: "ADR-5043-assertion-quality"
title: "Build assertions must be human- and LLM-readable"
domain: 50
status: active
last_reviewed: 2026-08-11
links:
  adr: [ADR-5043]
  modules:
    - path: 59-guardrails/595-ssh-assertions.nix
    - path: 52-security/525-ssh-antilockout.nix
---

# ADR-5043: Assertion Quality Standard

## Status
Active.

## Context
Early mediNix assertions used terse messages like `"ERROR: SSH disabled."` which
force the operator (or an LLM agent) to reverse-engineer *what* broke, *why*, and
*how to fix it*. That wastes time during a failed `nixos-rebuild` — exactly when
you are most likely to be locked out or rushed.

## Decision
Every `assertions` entry in mediNix MUST follow this shape:
1. A stable tag prefix (`[<file-id>]`) so the message is traceable to a module.
2. **What** broke (the observed state).
3. **Why** it is dangerous / rejected (one sentence of rationale).
4. **How** to fix it (the exact option or file to change).

Example (good):
```
[595] nftables is active but port 22 (canonical SSH) is NOT in
allowedTCPPorts. The build would lock you out of the host.
Fix: add 22 to networking.firewall.allowedTCPPorts in
523-nftables-hardening.nix (keep it consistent with 525-ssh-antilockout).
```

Example (bad):
```
ERROR: nftables active but port 22 not allowed. Deployment aborted!
```

Non-fatal reminders use `warnings` (not `assertions`) so they inform without
blocking the build.

## Consequences
- A failed build is self-explanatory; no context-switching to read the module.
- LLM agents can parse and act on the Fix line directly.
- Reviewers check assertion messages alongside the boolean condition.

## Verification
- `595-ssh-assertions.nix` and `525-ssh-antilockout.nix` are the reference
  implementations. New guardrail modules copy this format.
