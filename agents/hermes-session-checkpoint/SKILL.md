---
name: hermes-session-checkpoint
description: "Before /reset or deploy: snapshot repo and Memory safe."
---

# hermes-session-checkpoint

## Trigger
- Before any `/reset` command
- After a `nix flake check` or deploy
- At the end of any session longer than ~10 messages with real work done
- When the user says "checkpoint", "reset sicher", "vor dem reset"

## Steps (run in order)

1. **Repo state check**
   ```bash
   cd /opt/data/50-mediNix  # or relevant working dir
   git status --short
   git log --oneline -5
   ```
   - If uncommitted changes: COMMIT + PUSH them first (or warn explicitly).
   - If local != remote: PUSH.
   - Record the latest commit hash (short form).

2. **Memory freshness check**
   - Read `/opt/data/.hermes/memories/MEMORY.md`.
   - If it does not contain the current commit hash OR lacks the latest decided conflicts → it is stale.

3. **Rewrite Memory** with:
   - Current commit hash (latest push)
   - Full file index state (especially 59-guardrails numbering after any refactor)
   - Decided conflicts (e.g. usenet-confinement = UID-routing NOT netns)
   - Open points (what must be done after reset)
   - INV-SECRET status (expanded to all paths: yes/no)
   - Hard user corrections (never repeat)

4. **AGENTS.md repo check**
   - If `/opt/data/50-mediNix/AGENTS.md` exists: verify it matches current state.
   - If missing OR stale: write/update it (it survives any reset because it lives in the repo).
   - Commit + push AGENTS.md if changed.

5. **Output confirmation**
   - `✅ Checkpoint gesetzt — Reset ist sicher` (with hash + what was saved)
   - OR `❌ Problem: [what is blocking]` (uncommitted changes, missing AGENTS.md, etc.)

## Pitfalls
- Memory file lives at `/opt/data/.hermes/memories/MEMORY.md` — if it does NOT exist, CREATE it (it was missing once and caused near-loss).
- Never leave uncommitted work before reporting "safe" — reset destroys the working tree.
- AGENTS.md is the ultimate reset-survival doc: it is in the repo, not in Memory.
- q958 (192.168.2.73) is OFF — do not deploy without explicit go-ahead.

## Verification
```bash
test -f /opt/data/.hermes/memories/MEMORY.md && echo "MEMORY OK"
test -f /opt/data/50-mediNix/AGENTS.md && echo "AGENTS OK"
git -C /opt/data/50-mediNix status --short | grep -q . && echo "UNCOMMITTED!" || echo "CLEAN"
```
