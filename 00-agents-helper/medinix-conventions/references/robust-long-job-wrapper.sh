# Robust long-running job wrapper (e.g. FAISS index rebuild ~3.76h on CPU)
# Lessons from grok_index_v2.py zombie failure on Unraid Tower.
#
# ANTI-PATTERNS that caused the zombie (DO NOT):
#   - nohup python3 script.py & inside SSH -> dies with the session
#   - pkill -f script.py -> matches the SSH command itself (kills own session)
#   - no PID file -> cannot kill precisely, cannot detect "already running"
#   - deleting the script while the process runs -> orphan with no source
#
# PATTERN (use this):

#!/usr/bin/env bash
set -u
SCRIPT_DIR="/mnt/user/data/hermes_knowledge/nixos_vectors"
SCRIPT="$SCRIPT_DIR/grok_index_v2.py"
PIDFILE="/run/grok_v2.pid"
LOGFILE="/mnt/user/data/hermes_knowledge/nixos_vectors/grok_index_v2.log"
mkdir -p "$(dirname "$PIDFILE")"

# 1) Already-running guard (precise, no pkill -f self-match)
if [ -f "$PIDFILE" ]; then
  OLD=$(cat "$PIDFILE")
  if kill -0 "$OLD" 2>/dev/null; then
    echo "Already running as $OLD — skipping."; exit 0
  fi
  rm -f "$PIDFILE"
fi

# 2) Existence check before start (don't launch a missing file)
[ -f "$SCRIPT" ] || { echo "MISSING: $SCRIPT"; exit 1; }

# 3) setsid -> fully decoupled from SSH session (no zombie on disconnect)
#    3x retry on crash, then clean give-up
for i in 1 2 3; do
  setsid bash -c "echo \$\$ > '$PIDFILE'; exec python3 '$SCRIPT'" >>"$LOGFILE" 2>&1 &
  wait $!
  RC=$?
  [ $RC -eq 0 ] && { rm -f "$PIDFILE"; echo "DONE"; exit 0; }
  echo "Attempt $i failed (rc=$RC), retry in 10s" >>"$LOGFILE"
  sleep 10
done
echo "FAILED after 3 attempts" >>"$LOGFILE"; exit 1

# Invoke from cron as: bash /path/run_grok_v2.sh
# Kill precisely later with: kill -9 $(cat /run/grok_v2.pid)  (never pkill -f)
