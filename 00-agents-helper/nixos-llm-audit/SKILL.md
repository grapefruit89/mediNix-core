---
name: nixos-llm-audit
description: "Use when auditing NixOS modules with LLMs."
version: 1.0.0
author: Hermes
license: MIT
---

# NixOS LLM Cross-Validation Audit

## Trigger
Run when auditing / hardening a NixOS module or mediNIX-core repo, or when multiple AI
models produced audit findings needing triage before fix/commit.

## Core workflow
1. Collect findings from EVERY model. Each produces real AND phantom bugs — trust none alone.
2. VERIFY each finding against the actual source file (`default.nix`, `lib/registry.nix`,
   the module) — never the model's quoted line number. Confirm the option/attribute path
   exists and means what the model claims.
3. Classify REAL vs PHANTOM (model misread, e.g. `cfg.dns` vs `vpn.dns`).
4. Fix real bugs; skip phantoms but NOTE them.
5. Embed a shift-left guard (invariant or flake check) so the bug class can't recur.

## Why cross-validation pays off (real example)
In one mediNIX session, Grok + DeepSeek both reported phantom bugs (e.g. `vpn.dns`
vs `vpn.dnsServers`) AND missed two genuine P0 bugs that a THIRD model (Antigravity)
caught:
- `512-pocket-id.nix` used `registry.pocketId` — but the registry key is
  `services."pocket-id"` (with hyphen). → `attribute 'pocketId' missing` at
  `nix flake check`.
- `524-systemd-credentials.nix` read `cfg.services.<name>.apiKeyFile` — but the
  real options live at `cfg.secrets.<name>ApiKeyFile`. → every secret path was
  `null` → all services started WITHOUT credentials.

Lesson: a single model's audit is necessary but NOT sufficient. Run ≥2 models and
treat a finding NONE of them caught as the most dangerous class — it got past the
filters. The cross-model diff IS the value, not any single model's output.

## PITFALL — don't trust line numbers
DeepSeek claimed `vpn.dns` correct / `vpn.dnsServers` a drift bug; reverse was true
(`default.nix` Z494 defines `vpn.dnsServers`, no `vpn.dns`). Reopen the file always.

## PITFALL — portability context (K.O.)
mediNIX-core is portable: never hardcode IPs in modules. But distinguish run contexts:
- q958 (deploy host): ntfy local → `127.0.0.1:5810` is CORRECT in modules.
- Hermes container: `127.0.0.1:5810` unreachable → use `192.168.2.250:5810`.
Confusing them caused a real regression this session.

## PITFALL — show-before-commit
If user says "Zeig mir X vor dem Commit", display and WAIT. Committed-without-review
violates the workflow even if unpushed.

## P0/P1/P2 rubric (this project)
- P0 = `nix flake check` fails OR services start without credentials. Blocker.
- P1 = starts but function broken (SSO/Auth/Provisioning).
- P2 = runs but architecturally unclean. Can wait.

## Shift-left guards
Invariant in `59-guardrails/590-registry.nix` + matching `59X` file, or flake check.
Reference: references/shift-left-flake.md (devNIX ratsche + decimal-enforcer, adapted).
