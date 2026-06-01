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

# Single-instance lock — concurrent sessions race on repo/branch selection.
LOCK="$PORTFOLIO_ROOT/.session.lock"
# A lock older than this is always treated as stale. Longer than the max
# (NIGHT) session cap of 360 min plus headroom, so it can never kill a real run.
LOCK_MAX_AGE_SEC=$((7 * 3600))

# A lock is only "live" if the PID is alive AND that PID is still running this
# driver. Plain `kill -0` is not enough: after a reboot the OS recycles PIDs,
# so an orphaned lock's PID can come back to life as some unrelated process
# (this is what wedged sessions 2026-05-28 onward — PID 35017 got reused and
# every run refused to start). Matching the command line closes that hole.
lock_is_live() {
  local pid="$1"
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  ps -p "$pid" -o command= 2>/dev/null | grep -q 'run-session\.sh'
}

if [ -f "$LOCK" ]; then
  OTHER_PID="$(cat "$LOCK" 2>/dev/null || true)"
  LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || echo 0) ))
  if lock_is_live "$OTHER_PID" && [ "$LOCK_AGE" -lt "$LOCK_MAX_AGE_SEC" ]; then
    echo "ERROR: a session is already running (PID $OTHER_PID, lock age ${LOCK_AGE}s). Refusing to start a second." | tee -a "$LOG_FILE"
    exit 1
  fi
  echo ">>> clearing stale lock (PID ${OTHER_PID:-none}, age ${LOCK_AGE}s) — not a live session" | tee -a "$LOG_FILE"
  rm -f "$LOCK"
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

echo ">>> portfolio-session driver" | tee -a "$LOG_FILE"
echo ">>> timestamp: $TIMESTAMP" | tee -a "$LOG_FILE"
echo ">>> portfolio root: $PORTFOLIO_ROOT" | tee -a "$LOG_FILE"

# 1. Refresh portfolio-ops
if [[ ! -d "$OPS_DIR" ]]; then
  echo ">>> cloning portfolio-ops to $OPS_DIR" | tee -a "$LOG_FILE"
  mkdir -p "$PORTFOLIO_ROOT"
  cd "$PORTFOLIO_ROOT"
  gh repo clone dj-techs/portfolio-ops 2>&1 | tee -a "$LOG_FILE"
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

# 4. Time-of-day session cap (D-008): day = 2x the 90-min base, night = 4x.
#    Day window 06:00-18:00 local -> 180 min. Night 18:00-06:00 -> 360 min.
HOUR="$(date +%H)"
# strip any leading zero so arithmetic comparison is base-10
HOUR=$((10#$HOUR))
if [ "$HOUR" -ge 6 ] && [ "$HOUR" -lt 18 ]; then
  SESSION_CAP_MIN=180
  SESSION_PHASE="DAY"
else
  SESSION_CAP_MIN=360
  SESSION_PHASE="NIGHT"
fi
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
