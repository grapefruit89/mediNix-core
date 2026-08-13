---
name: medinix-assertion-quality
description: Enforces readable mediNix assertion messages what/why/fix.
---

# mediNix Assertion Quality (ADR-5043)

When you add, edit, or review any `assertions = [` or `warnings = [` block in
`/opt/data/50-mediNix/**/*.nix`, enforce this format. Reference impl:
`59-guardrails/595-ssh-assertions.nix`.

## Trigger
- Creating a new guardrail/assertion module in mediNix.
- Reviewing an existing assertion whose message is terse (e.g. `"ERROR: X aborted!"`).
- Any `nixos-rebuild` failure analysis where the message was unhelpful.

## Rule — every assertion message MUST contain
1. **Tag prefix** `[<module-id>]` so the message is traceable to a file (e.g. `[595]`, `[525]`).
2. **What** broke — the observed/blocked state.
3. **Why** — one sentence of rationale (security, lockout risk, contract).
4. **How** — the exact option or file to change to fix it.

Non-fatal reminders go in `warnings` (not `assertions`) — inform without blocking.

## Good vs Bad

Bad:
```
message = "ERROR: SSH disabled. Deployment aborted!";
```

Good:
```
message = ''
  [595] SSH service is DISABLED.
  A mediNix host without SSH is unreachable after reboot.
  Fix: set grapefruitMedia.ssh.enable = true.
'';
```

## Steps
1. Locate the `assertions`/`warnings` block.
2. For each entry, check the 4-part shape (tag, what, why, fix).
3. If missing, rewrite the message — keep the `assertion =` boolean unchanged.
4. Verify `warnings` are used for soft reminders, `assertions` for hard blockers.
5. Bracket-balance check: `for f in <file>; do o=$(grep -o "{" $f|wc -l); c=$(grep -o "}" $f|wc -l); echo "$f $o $c"; done` (must match).

## Pitfalls
- Do NOT put a live port number in a "deprecated" warning as if it were active — only as documentation text (grep must show no live assignment).
- Assertion booleans must stay correct; only the message string changes.
- `lib.singleton { assertion = ...; message = ...; }` is the idiomatic single-entry form.

## Verification
- `grep -rn "ERROR:" --include="*.nix" /opt/data/50-mediNix` should return nothing (all old terse messages migrated).
- Each message is self-explanatory without opening the source file.
