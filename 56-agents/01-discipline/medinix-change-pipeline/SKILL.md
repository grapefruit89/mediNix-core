---
name: medinix-change-pipeline
category: devops
description: "Canonical Change/Commit Pipeline for mediNix-core. Load BEFORE any commit — for code, lint, and doc changes alike. Enforces: baseline → change → eval/build → diff-review → commit #1 → automated cleanup (nixfmt/statix/deadnix) → diff-review AGAIN → checks → commit #2 → push/CI → runtime. Three hard rules: (1) every commit is a verified state, never a staging area for unverified tool output; (2) automated refactoring is a code change and gets the same review as handwritten code — deadnix must NEVER strip function-API parameters; (3) diff size is a gate, not cosmetics (unexpected files / big deletions / new files => STOP)."
---

# mediNix Change / Commit Pipeline

A repeatable agent workflow so that changes are made quickly but the *character* of
the repository never changes unnoticed. It exists because a repo-wide
`deadnix --edit` once silently removed a public function parameter
(`port ? null`, `lib`) and broke evaluation — see §"Deadnix rule".

## When to load
Any task that will produce a commit — module work, lint cleanup, docs. Load it together
with `medinix-pre-commit` (scanners) and `medinix-governance` (commit discipline).

## Prime directives (put these above tactics)
1. **Every commit is a verified state.** No commit is a staging area for unverified
   tool output.
2. **Automated refactoring is a code change.** No `fix`, `--edit`, `fmt` or automatic
   rewrite may enter a commit unreviewed.
3. **Diff size is a gate, not a beauty score.** Unexpectedly many files, large deletions
   or new files ⇒ STOP and root-cause.

## The pipeline

```
0 BASELINE → 1 CHANGE → 2 EVAL/BUILD → 3 DIFF-REVIEW → 4 COMMIT#1
→ 5 AUTOMATED CLEANUP → 6 DIFF-REVIEW AGAIN → 7 CHECKS → 8 COMMIT#2 → PUSH → CI → RUNTIME
```

### 0. Baseline (record before touching anything)
```bash
git status --short            # MUST be clean; if not, stop
git rev-parse --short HEAD    # BASELINE = X  (fallback: git reset --hard X)
nix flake check               # eval ratchet; on hosts without nix: run on q958
git diff --check
```
`git reset --hard X` is the defined way back.

### 1. Change
Only the agreed task (e.g. "F2: *arr External only for public vhosts"). Never bundle
`+F2 +nixfmt +deadnix +README +"improvements"`. Scope creep = stop and ask.

### 2. Technical check
```bash
git diff --check
nix flake check
# plus, if relevant: nix build ... ; project-specific tests
```
Question answered: *is the changed state technically valid at all?*

### 3. Diff review (the "gross diff check" — mandatory)
```bash
git diff --stat ; git diff --numstat ; git diff --summary ; git diff --check
git diff          # read it
```
Inspect **A–E**:
- **A — Size.** 8 files +31/−18 should not become 47 files +812/−1403. STOP.
- **B — Paths.** Only the expected files?
- **C — Deletions.** Watch `deleted:` and large `-` blocks.
- **D — New files.** Why does each one exist?
- **E — API / surfaces.** In Nix, `{ lib, pkgs, port ? null, ... }:` is **not** "unused
  code" — it can be an interface. This is exactly what deadnix got wrong.

### 4. Commit #1 — only when all gates pass
Scope PASS · Size PASS · Unexpected-files PASS · Deletions PASS · Eval PASS · Build PASS ·
Tests PASS · `diff --check` PASS.
```bash
git add <exact paths>          # no blind -A when in doubt
git diff --cached
git diff --cached --check
git commit -m "..."
```
This is the safe anchor.

### 5. Automated cleanup (only now)
`nixfmt` / `statix fix` / `deadnix --edit` are **mutation tools**. Their output is a
*new* change → it starts the cycle again from step 3. SSoT: `formatter = nixfmt-rfc-style`
and the pinned versions used by the flake checks — run the tools from the check
derivations so the result matches CI.

### 6. Diff review AGAIN
```bash
git diff --stat ; git diff --numstat ; git diff --check ; git diff
```
"29 files +89/−117" is **not** automatically good — ask *why 29 files*. This is the step
that would have flagged the deadnix API removal immediately.

### 7. Checks
`nix flake check` (all checks) + `git diff --check` + project checks. All green before
the lint commit.

### 8. Commit #2 (single style/lint commit) → push → CI → runtime
Prefer **two** commits, not four tool-commits:
`COMMIT 1 = functional/security`, `COMMIT 2 = style/lint (nixfmt+statix+deadnix together)`.
Push only on explicit user "push". GitHub CI re-verifies; q958 runtime is a separate,
final level.

## Deadnix rule (mandatory)
- MAY remove unused **let-bindings** and `_`-prefix unused **lambda args**.
- MUST NOT remove a **function argument** of a non-module function (no `...` in the
  pattern) — that can be public API. `lib/service-factory.nix` `port ? null` and
  `lib/cli.nix` `lib` were passed by callers; removing them ⇒
  `error: function called with unexpected argument 'lib'`.
- NixOS modules `{ config, lib, pkgs, ... }:` carry `...` → dropping an unused named arg
  is safe because the caller's arg is absorbed.
- Before any repo-wide `deadnix --edit`: either add `...` to non-module signatures or
  exclude those files, then re-run eval.

## Statix policy
`statix.toml` at repo root disables `repeated_keys` (W20). Dotted-prefix style
(`checks.*`, `medinix.*`, `networking.*`, `systemd.services.X.*`) is intentional;
W20 is a structuring opinion, not a defect. Do **not** restructure 17 sites to please a
linter — that is an architecture decision, recorded once in `statix.toml`.

## Level separation (no level substitutes the next)
```
Source correctness → Build correctness → CI correctness → Runtime correctness
```
A green `nix flake check` proves the tested property only — never "it runs".

## References
- `../03-gates-audits/medinix-pre-commit` — scanners + 7 Quality Gates (before "done").
- `medinix-governance` — SSoT, Review-First, commit discipline.
- `../03-gates-audits/medinix-build-gate` — Context7 option verification.
