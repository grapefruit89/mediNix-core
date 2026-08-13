# Robust background-wrapper for long CPU jobs on the Tower (via SSH)

Use this when launching a multi-hour embedding/index build (e.g. `grok_index_v2.py`,
~3.76h) over SSH so it neither dies with the session nor gets killed by a mistaken
`pkill -f`.

## Why this shape
- `nohup python3 x.py &` inside an SSH call dies when the SSH session ends → use
  `setsid bash -c "..."` to fully detach into a new session.
- `pkill -f x.py` also matches the SSH command string that CONTAINS `x.py`, killing
  the session itself → use a PID-file and `kill -0 <pid>` instead of pattern kill.
- A build that writes nothing until the end is unrecoverable on crash → the index
  script itself must `np.save`/`json.dump` incrementally (see CRITICAL SAVE RULE in
  the umbrella SKILL.md).

## Working wrapper (run on Tower)

```bash
#!/usr/bin/env bash
# run_grok_v2.sh — robust detached launcher for the Grok v2 FAISS build.
set -u
SCRIPT_DIR="/mnt/user/data/hermes_knowledge/nixos_vectors"
SCRIPT="$SCRIPT_DIR/grok_index_v2.py"
PIDFILE="/run/grok_v2.pid"
LOGFILE="$SCRIPT_DIR/grok_index_v2.log"
VENV="$SCRIPT_DIR/venv/bin/activate"
MAX_RETRIES=3

log() { echo "[$(date +%FT%T)] $*" | tee -a "$LOGFILE"; }

# 1) Script must exist
if [ ! -f "$SCRIPT" ]; then log "ERROR: $SCRIPT missing — aborting."; exit 1; fi

# 2) Already running? (PID-file guard, no pkill -f self-match)
if [ -f "$PIDFILE" ]; then
    OLD=$(cat "$PIDFILE" 2>/dev/null || echo "")
    if [ -n "$OLD" ] && kill -0 "$OLD" 2>/dev/null; then
        log "Already running as $OLD — skipping."; exit 0
    else
        log "Stale PID file — removing."; rm -f "$PIDFILE"
    fi
fi

# 3) Run with retry; setsid fully detaches from the SSH session
attempt=0
while [ $attempt -lt $MAX_RETRIES ]; do
    attempt=$((attempt+1))
    log "=== Attempt $attempt/$MAX_RETRIES ==="
    setsid bash -c "echo \$\$ > '$PIDFILE'; source '$VENV'; exec python3 '$SCRIPT'" >> "$LOGFILE" 2>&1 &
    wait $!
    RC=$?
    if [ $RC -eq 0 ]; then log "OK (RC=0)."; rm -f "$PIDFILE"; exit 0; fi
    log "Crash RC=$RC. Retry in 10s..."; sleep 10
done
log "FAILED after $MAX_RETRIES attempts."; rm -f "$PIDFILE"; exit 1
```

## Test before trusting
Validate the wrapper with a short fake script (not the 3.76h real one):
1. fake_ok.sh (sleep 2; exit 0) → wrapper exits 0, PID-file removed.
2. fake_crash.sh (exit 1) → 3 retries, then "FAILED".
3. Start fake_ok in background, then run wrapper again → "Already running" guard fires.

All three passed this session. The real build was then scheduled via cron
(`0 4 * * *`) calling this wrapper — the cron only starts it; the wrapper self-guards.
