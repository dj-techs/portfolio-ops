#!/usr/bin/env bash
# Driver for an autonomous portfolio session.
#
# Runs on JT's Mac as jt-mchorse. Invoked either by the Cowork scheduled task
# (via osascript opening Terminal.app) or manually.
#
# Flow:
#   1. Update portfolio-ops to get the latest SESSION_PROMPT.md.
#   2. Invoke Claude Code with the prompt.
#   3. Log output to logs/session-<timestamp>.log.

set -euo pipefail

# When invoked via launchd / nohup / cron, PATH is minimal. Add common
# install locations so gh, claude, node etc. are reachable. ~/.local/bin
# is where Claude Code's installer puts the binary on macOS.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

PORTFOLIO_ROOT="${PORTFOLIO_ROOT:-$HOME/projects/portfolio}"
OPS_DIR="$PORTFOLIO_ROOT/portfolio-ops"
LOG_DIR="$PORTFOLIO_ROOT/logs"
TIMESTAMP="$(date -u +%Y-%m-%dT%H%M%SZ)"
LOG_FILE="$LOG_DIR/session-$TIMESTAMP.log"

mkdir -p "$LOG_DIR"

# --- Session time cap (computed early so the lock can record it) -------------
# Day window 06:00-18:00 local -> 180 min; night 18:00-06:00 -> 360 min.
HOUR=$((10#$(date +%H)))
if [ "$HOUR" -ge 6 ] && [ "$HOUR" -lt 18 ]; then
  SESSION_CAP_MIN=180; SESSION_PHASE="DAY"
else
  SESSION_CAP_MIN=360; SESSION_PHASE="NIGHT"
fi

# --- Single-instance lock with a watchdog ------------------------------------
# Only one session may run (concurrent runs race on repo/branch selection), but
# a crashed, slept, reused-PID, or *frozen* prior run must never wedge the
# schedule. The lock records "PID START_EPOCH CAP_MIN LOGFILE" so a later run can
# tell a healthy live session from a corpse — and, if the holder is alive but
# stuck, kill its whole process tree and take over.
LOCK="$PORTFOLIO_ROOT/.session.lock"
LOCK_HARD_MAX_SEC=$((7 * 3600))               # absolute ceiling; older is always stale
FREEZE_GRACE_MIN="${FREEZE_GRACE_MIN:-20}"    # allowed overrun past a session's own cap
# Opt-in heartbeat: if >0, a session whose log has been silent this many minutes
# is treated as frozen. Off by default because `claude --print` may buffer output;
# enable once you've confirmed your sessions write to the log steadily.
FREEZE_IDLE_MIN="${FREEZE_IDLE_MIN:-0}"

# Alive AND still running this driver — guards against PID reuse after a reboot
# (PID 35017 got recycled and wedged every run 2026-05-28 onward).
pid_is_our_driver() {
  local pid="$1"
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  ps -p "$pid" -o command= 2>/dev/null | grep -q 'run-session\.sh'
}

# Kill a stuck session's entire process group (driver + claude + descendants).
kill_session() {
  local pid="$1" pgid
  [ -n "$pid" ] && [ "$pid" != "$$" ] || return 0
  pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')"
  echo ">>> killing stuck session PID $pid (pgid ${pgid:-n/a})" | tee -a "$LOG_FILE"
  if [ -n "$pgid" ]; then
    kill -TERM "-$pgid" 2>/dev/null || true; sleep 5; kill -KILL "-$pgid" 2>/dev/null || true
  else
    kill -TERM "$pid" 2>/dev/null || true; sleep 5; kill -KILL "$pid" 2>/dev/null || true
  fi
}

if [ -f "$LOCK" ]; then
  # Parse the rich lock format; tolerate the legacy PID-only format.
  read -r OTHER_PID OTHER_START OTHER_CAP OTHER_LOG < "$LOCK" 2>/dev/null || true
  LOCK_MTIME="$(stat -f %m "$LOCK" 2>/dev/null || echo 0)"
  : "${OTHER_START:=$LOCK_MTIME}"   # legacy lock: use file mtime as start proxy
  : "${OTHER_CAP:=360}"             # legacy lock: assume the max (NIGHT) cap
  { [ -n "$OTHER_LOG" ] && [ -f "$OTHER_LOG" ]; } || OTHER_LOG="$LOCK"
  NOW="$(date +%s)"
  AGE=$(( NOW - OTHER_START ))
  IDLE=$(( NOW - $(stat -f %m "$OTHER_LOG" 2>/dev/null || echo "$OTHER_START") ))
  OVERRUN_SEC=$(( OTHER_CAP * 60 + FREEZE_GRACE_MIN * 60 ))

  REASON=""
  if ! pid_is_our_driver "$OTHER_PID"; then
    REASON="PID ${OTHER_PID:-none} is gone or has been reused — not a live session"
  elif [ "$AGE" -ge "$LOCK_HARD_MAX_SEC" ]; then
    REASON="age ${AGE}s exceeds the 7h hard ceiling"
  elif [ "$AGE" -ge "$OVERRUN_SEC" ]; then
    REASON="overran its ${OTHER_CAP}m cap (age ${AGE}s, +${FREEZE_GRACE_MIN}m grace) — frozen/stuck"
  elif [ "$FREEZE_IDLE_MIN" -gt 0 ] && [ "$IDLE" -ge $(( FREEZE_IDLE_MIN * 60 )) ]; then
    REASON="no log output for ${IDLE}s (>= ${FREEZE_IDLE_MIN}m) — frozen"
  fi

  if [ -z "$REASON" ]; then
    echo "ERROR: a healthy session is already running (PID $OTHER_PID, age ${AGE}s, idle ${IDLE}s). Refusing to start a second." | tee -a "$LOG_FILE"
    exit 1
  fi

  echo ">>> prior lock is stale: $REASON" | tee -a "$LOG_FILE"
  pid_is_our_driver "$OTHER_PID" && kill_session "$OTHER_PID"   # alive but stuck -> kill it
  rm -f "$LOCK"
fi

# Acquire: record PID, start time, cap, and log path for the next run's watchdog.
echo "$$ $(date +%s) $SESSION_CAP_MIN $LOG_FILE" > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

echo ">>> portfolio-session driver" | tee -a "$LOG_FILE"
echo ">>> timestamp: $TIMESTAMP" | tee -a "$LOG_FILE"
echo ">>> portfolio root: $PORTFOLIO_ROOT" | tee -a "$LOG_FILE"

# 1. Refresh portfolio-ops
if [[ ! -d "$OPS_DIR" ]]; then
  echo ">>> cloning portfolio-ops to $OPS_DIR" | tee -a "$LOG_FILE"
  mkdir -p "$PORTFOLIO_ROOT"
  cd "$PORTFOLIO_ROOT"
  gh repo clone jt-mchorse/portfolio-ops 2>&1 | tee -a "$LOG_FILE"
else
  echo ">>> pulling portfolio-ops" | tee -a "$LOG_FILE"
  cd "$OPS_DIR"
  git fetch origin 2>&1 | tee -a "$LOG_FILE"
  git checkout main 2>&1 | tee -a "$LOG_FILE"
  git reset --hard origin/main 2>&1 | tee -a "$LOG_FILE"
fi

PROMPT_FILE="$OPS_DIR/session-runner/SESSION_PROMPT.md"
if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "ERROR: $PROMPT_FILE not found" | tee -a "$LOG_FILE"
  exit 1
fi

# 2. Verify Claude Code is available
if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: 'claude' CLI not found in PATH" | tee -a "$LOG_FILE"
  echo "Install with: npm install -g @anthropic-ai/claude-code" | tee -a "$LOG_FILE"
  echo "Or follow: https://docs.claude.com/en/docs/agents-and-tools/claude-code" | tee -a "$LOG_FILE"
  exit 1
fi

# 3. Verify gh is authenticated
if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh CLI not authenticated. Run: gh auth login" | tee -a "$LOG_FILE"
  exit 1
fi

WHO="$(gh api /user --jq .login 2>/dev/null || echo unknown)"
if [[ "$WHO" != "jt-mchorse" ]]; then
  echo "ERROR: gh authenticated as '$WHO', expected 'jt-mchorse'" | tee -a "$LOG_FILE"
  exit 1
fi
echo ">>> gh auth ok as $WHO" | tee -a "$LOG_FILE"

# 4. Session window/cap were computed up front (see the lock section above).
echo ">>> session window: $SESSION_PHASE — cap ${SESSION_CAP_MIN} min" | tee -a "$LOG_FILE"

# 5. Invoke Claude Code with the session prompt, prefixed by a runtime override
#    header so the static prompt's 90-min cap is superseded for this run.
echo ">>> launching claude code session" | tee -a "$LOG_FILE"
cd "$PORTFOLIO_ROOT"

RUNTIME_HEADER="## RUNTIME OVERRIDE (read first)

This is a ${SESSION_PHASE} session. **Hard time cap for THIS run: ${SESSION_CAP_MIN} minutes.** This supersedes the 90-minute cap written in the prompt below.

This is a **multi-issue, multi-repo run**. Do not stop after one issue. The loop is:
1. Run Phase A once at the start (read context + PR review/merge pass).
2. Pick a repo + issue, do Phase B, do Phase C (push, PR, MEMORY).
3. Then LOOP: go back to Phase A step 4 (repo selection), pick the next repo/issue, and repeat Phase B+C.
4. Keep looping until you are within 15 minutes of the ${SESSION_CAP_MIN}-minute cap, then stop cleanly.

Aim to fully close 2-4 issues in a DAY session and 5-9 in a NIGHT session. Each issue still gets its own branch, PR, and MEMORY commit. Quality bar is unchanged — no fabricated benchmarks, tests with code, MEMORY separate from code commits.

---

"

# Claude Code with --print runs non-interactively and exits on completion.
# --dangerously-skip-permissions: scheduled task can't answer permission prompts;
# the session prompt itself enforces what's safe.
claude --print --dangerously-skip-permissions "${RUNTIME_HEADER}$(cat "$PROMPT_FILE")" 2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}
echo ">>> claude exited with $EXIT_CODE" | tee -a "$LOG_FILE"
echo ">>> log: $LOG_FILE"
exit $EXIT_CODE
