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
  adr: ADR-0000 (fail-closed principle), ADR-0003 (no central assertion registries), ADR-5050 (systemd-hardening-baseline)
---

# ADR-5043: Assertion Quality Standard

## Status
Accepted (2026-08-12). Mandatory for all `assertions` / `invariants` in mediNix-core.

## Context
Assertions are the only line of defense against erroneous consumer configurations (fail-closed: build breaks, never just a warning - ADR-0000). Previously, assertions were scattered across modules with inconsistent message quality. This ADR standardizes the format and semantics so that every build error is self-explanatory.

## Decision

### 1. Two Categories (never mix)
- **Invariants** (`INV-*` as prose labels): Architectural guarantees of the system,
  independent of user config. Examples: Port = Num*10, GID=5000, 127.0.0.1-Binding,
  no containers. They live **where they are checked** - cross-domain ones in
  `59-guardrails/591-cross-domain.nix`.
- **Errors**: user config errors (VPN/TLS/AUTH/DNS/SEC/STORE topics). Same rule: the
  assertion sits in the module whose option it validates.
- `INV-*` / `XXX-NNN` are descriptive labels in prose, **not** a code registry: no
  `[CODE]` prefix is required, and there is no table to look up. ADR-0003 §3:
  "No central assertion registries ... Errors must be human- and AI-readable at the source".

### 2. Message Format (MANDATORY)
Every assertion message MUST contain:
- **What** is wrong (specific, no vagueness)
- **Why** it is wrong (architectural reasoning)
- **How** to fix it (specific instruction)

Schema:
```
[mediNix/<module>] SHORT_DESCRIPTION.
  Was: <wrong state>
  Warum: <architectural reasoning>
  Wie: <specific instruction, e.g. "set medinix.X.enable = true">
  Ref: ADR-XXXX   (welcome, not required)
```
The `[mediNix/…]` prefix names the module that owns the assertion - it is a locator,
not a category code.

### 3. Fail-closed (NO Exceptions)
- Assertions break the `nix flake check` with a **non-zero exit**.
- Never use `warn` or `lib.warn` - it gets overlooked in deployment.
- Conditional: only wrap with `lib.mkIf cfg.enable`, do not weaken the assertion itself.

### 4. Messages at the source
Every message is written where it is checked. Static text is fine; dynamic values are
interpolated right there (`"${toString port}"`). A separate file holding message
templates would be a second truth that drifts - forbidden by ADR-0003 §3.

### 5. Every Bug = a permanent check
If a bug is found (Audit, Deploy, Runtime), it MUST leave behind a check that catches the
same mistake in the next build: the assertion next to the option it protects, plus a
regression check in `flake.nix` (`checks.mediNix-negative-*` via `expectAssertion`) where
the reason matters. An ad-hoc fix without such a check is forbidden - otherwise the same
bug returns.

## Consequences
- Every build error is readable and actionable: Was/Warum/Wie at the source.
- No lookup table and no `[CODE]`: nobody has to resolve an indirection to understand a
  build failure.
- Cross-domain guarantees are the only ones with a dedicated home
  (`59-guardrails/591-cross-domain.nix`); everything else is inline.

## Anti-Patterns (FORBIDDEN)
- `assertions = [ { assertion = ...; message = "something is wrong"; } ];` (missing Was/Warum/Wie)
- `lib.warn "..."` instead of an assertion (not fail-closed)
- A central assertion registry or message table, and `[CODE]` prefixes that force a
  lookup (ADR-0003 §3)
- **Enum Drift:** Assertions MUST test against the actual current Enum values (e.g. `"none"` instead of `"off"`). Assertions that test outdated Enum values provide a false sense of security and always pass.

## Änderung 2026-10-17 (Review 51-ingress, Finding 25)
Die Abschnitte 1, 2, 4, 5 und die Anti-Patterns beschrieben ein **zentrales Register**
(`59-guardrails/590-registry.nix` mit `invariants`/`errors`, `mkInvariant`/`mkError`) und
verlangten `[CODE]`-Präfixe. Dieses Schema wurde mit `533126e` ("Comprehensive architecture
and audit fixes") **wieder verworfen**: `590-registry.nix`, `591-assertions.nix`,
`592-rollout.nix` und `596-security-assertions.nix` sind gelöscht, an ihre Stelle trat
`591-cross-domain.nix` mit **inline**-Assertions; `mkInvariant` kommt im Repo nicht mehr
vor. Diese ADR beschreibt jetzt die geltende Praxis (ADR-0003 §3). Die historische Notiz
`docs/agents/02-medinix-core/nixos-medinix-authoring/references/session-2026-08-12-patterns.md`
bleibt als Zeitdokument stehen und traegt einen Status-Hinweis.
