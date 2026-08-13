---
name: medinix-pre-commit
description: "Use before git commit / 'fertig' on 50-mediNix."
version: 1.0.0
author: Hermes
license: MIT
---

# mediNix Pre-Commit Gate

## Trigger
Run this gate BEFORE claiming "done" / before any `git commit` on
`/opt/data/50-mediNix/`. For creating a module use `medinix-module-author`; for
build failures use `medinix-debug-nix`.

## 1. Decimal inconsistency scan (after renames/structure changes)
```bash
python3 ../../shared/scripts/scan_inconsistencies.py
```
Flags: wrong Dienstnummer in filename (e.g. 513-Caddy vs 511), wrong `ports:`
in header (must = filename×10), non-zero-ending 4-digit ports, folder/file
numbers outside 500–599. Legitimate false-positives: `default.nix`,
`flake.nix`, `lib/*.nix`, provisioning modules in 57-maintenance (no own
port), SSH/firewall ports (22/443/2222).

## 2. Duplicate / collision scan
```bash
python3 ../../shared/scripts/scan_duplicates.py
```
Checks: same filename in different paths, sha256-identical files, SAME
Dienstnummer in multiple files, same NIXMETA `id`.

**KRITICAL — Section 3 (Num-dupes) is ALWAYS real.**
If it reports "GLEICHE DIENSTNUMMER IN MEHREREN DATEIEN", that is NOT a false
positive. It means two files share a 3-digit prefix in different folders
(e.g. `593-no-password-auth.nix` AND `593-emergency-user.nix`). Decimal
framework requires each number exactly once. NEVER dismiss the count as
"known false positives" and commit anyway. Read the list; rename one
(`git mv`, then fix its `# id:`/header/`requires:`). `default.nix` (loader,
multiple per domain) is the only legit duplicate.

## 3. Structural legacy-duplicate check (scanner does NOT catch this)
```bash
for d in [0-9][0-9]-*/; do echo "$d:"; find "$d" -name "[0-9][0-9][0-9]-*.nix"|sort; done
```
Two files in the SAME folder with the same function (same number, or
`X-Y-z.nix` + `X-Y-z-other.nix`) → delete the older. Known legacy dupes from
task 12c: `52-security/` had 522/523/524/525/526 (replaced by 521–524, not
deleted); `59-guardrails/` had 592-emergency-user (dup of 593), 595-ssh-assertions
(legacy); `53-acquisition/` had 536-sqlite-wal (belongs 542), 541-sabnzbd-isolation
(belongs 541). The scanner will NOT warn — check manually every task.

## 4. Portability / artifact verification
```bash
grep -rn "192\.168\." . --include="*.nix" && echo FAIL || echo OK   # no hardcoded IPs
grep -rn "q958\|jarvis\|moritz" . --include="*.nix" && echo FAIL || echo OK  # no machine-names
for d in [0-9][0-9]-*/; do c=$(find "$d" -name "[0-9][0-9][0-9]-*.nix"|wc -l); echo "$d: $c"; done
ls CLAUDE.md compat-my.nix handoff-*.md 2>/dev/null && echo FAIL || echo OK  # no dev-artefacts
```

## 5. Context7 gate
Every NixOS option added since last commit MUST be Context7-verified
(`medinix-build-gate`). No unverified options in the diff.

## 6. Language rule
All `.nix` files, inline comments, and ADRs are ENGLISH. Chat is German.

## 6b. Seven Quality Gates (Aviation-Grade Purity Protocol)
Every module/PR must pass these gates before "done". Derived from
GUIDE-58-seven-quality-gates (mynixos-knowledge-base), adopted 2026-08-12.
1. **Community-Goldstandard** — Abgleich mit nixpkgs/modules. Nutzen wir beste bekannte Patterns?
2. **API-Accuracy** — Jede neue NixOS-Option via Context7 verifiziert (medinix-build-gate).
   Keine Deprecations, keine halluzinierten Optionen.
3. **SSoT-Compliance** — Strikte Bindung an lib/registry.nix (Port/UID/GID) + default.nix (Optionen).
   Keine Hardcoded-Werte (Portabilitäts-K.O.-Kriterium).
4. **SRE-Hardening** — systemd-unit maximal isoliert (lib/hardening-profiles.nix).
   systemd-analyze security < 4.0 Ziel (soweit pragmatisch).
5. **Dendritic Integrity** — "One Service, One File". Keine Zirkelbezüge, keine verschachtelten Ordner.
6. **Hygiene & Purity** — Kein toter Code, keine Meta-Options, keine ungenutzten Imports.
7. **Traceability** — Jedes Modul referenziert Quellen im YAML-Header (links.adr / links.repo-harvest).

## 7. Git safety net
- Boilerplate is locally versioned (no remote, NO push without explicit OK).
- `git add -A && git commit -m "..."` — git shows renames as `R` (verify with
  `git status --short`).
- Branch `main`. NEVER branch into original `grapefruit89/mediNix` (its
  AGENTS.md forbids branches — only `main`).
- To switch GitHub default `master`→`main`: Web-UI Settings→Branches FIRST,
  THEN `git push --delete origin master`. CLI/API cannot change default branch
  without a PAT (deploy-key is SSH-only).
- Push with deploy-key: `.ssh/config` is write-protected → use
  `GIT_SSH_COMMAND="ssh -i /opt/data/.ssh/<key> -o IdentitiesOnly=yes -o StrictHostKeyChecking=no" git push ...`.

## References
- `../../shared/scripts/scan_inconsistencies.py`
- `../../shared/scripts/scan_duplicates.py`
- `../nixos-medinix-authoring/references/dezimalrahmen-naming.md`
