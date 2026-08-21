---
id: "ADR-5043"
title: "Assertion Quality Standard (fail-closed, readable what/why/fix)"
domain: 50
status: active
complexity: 2
last_reviewed: 2026-08-20
tags:
  - core
  - governance
links:
  adr: ADR-0000 (fail-closed principle), ADR-5050 (systemd-hardening-baseline)
  skill: medinix-assertion-quality
---

# ADR-5043: Assertion Quality Standard

## Status
Accepted (2026-08-12). Mandatory for all `assertions` / `invariants` in mediNix-core.

## Context
Assertions are the only line of defense against erroneous consumer configurations (fail-closed: build breaks, never just a warning - ADR-0000). Previously, assertions were scattered across modules with inconsistent message quality. This ADR standardizes the format and semantics so that every build error is self-explanatory.

## Decision

### 1. Two Categories (never mix)
- **Invariants** (`INV-*`): Architectural guarantees of the system. Independent of user config.
  Examples: Port = Num*10, GID=5000, 127.0.0.1-Binding, no containers.
  Central SSoT: `59-guardrails/590-registry.nix` (`invariants` attrset).
- **Errors** (`VPN-*` / `TLS-*` / `AUTH-*` / `DNS-*` / `SEC-*` / `STORE-*`):
  User config errors. Central SSoT: `590-registry.nix` (`errors` attrset).

### 2. Message Format (MANDATORY)
Every assertion message MUST contain:
- **What** is wrong (specific, no vagueness)
- **Why** it is wrong (architectural reasoning)
- **How** to fix it (specific instruction)

Schema:
```
[INVARIANT|CODE] SHORT_DESCRIPTION.
  Expected: <correct state>
  Found: <actual state>
  Fix: <specific instruction, e.g., "set grapefruitMedia.X.enable = true">
  Ref: ADR-XXXX
```

### 3. Fail-closed (NO Exceptions)
- Assertions break the `nix flake check` with a **non-zero exit**.
- Never use `warn` or `lib.warn` - it gets overlooked in deployment.
- Conditional: only wrap with `lib.mkIf cfg.enable`, do not weaken the assertion itself.

### 4. No dynamic strings in Registry
`590-registry.nix` contains static message templates (String, no `toString` at runtime). Dynamic values (e.g., actual port) are injected in the calling module via `lib.mkIf` - the registry remains the SSoT for the text.

### 5. Every Bug = Invariant
If a bug is found (Audit, Deploy, Runtime), it MUST be immortalized as an Invariant/Error in `590-registry.nix`, which will catch the same error during the next build. Ad-hoc fixes without a registry entry are forbidden (otherwise docs drift away).

## Consequences
- `medinix-assertion-quality` skill is the implementation reference (grep-checks for format).
- `medinix-pre-commit` gate checks: no assertion without `[CODE]` prefix, no empty messages.
- Consumers importing mediNix-core get readable, actionable build errors.

## Anti-Patterns (FORBIDDEN)
- `assertions = [ { assertion = ...; message = "something is wrong"; } ];` (missing What/Why/Fix)
- `lib.warn "..."` instead of `mkInvariant` (not fail-closed)
- Inline text in modules instead of a central registry (docs drift)
- Using `INV-*` for config errors (these are `errors`, not invariants)
- **Enum Drift:** Assertions MUST test against the actual current Enum values (e.g. `"none"` instead of `"off"`). Assertions that test outdated Enum values provide a false sense of security and always pass.
