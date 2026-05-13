#!/usr/bin/env bash
# Driver for the weekly portfolio digest.
#
# Same shape as run-session.sh but invokes Claude Code with DIGEST_PROMPT.md.
# Cron: Mondays 07:00 local via Cowork's portfolio-weekly-digest task.

set -euo pipefail

PORTFOLIO_ROOT="${PORTFOLIO_ROOT:-$HOME/projects/portfolio}"
OPS_DIR="$PORTFOLIO_ROOT/portfolio-ops"
LOG_DIR="$PORTFOLIO_ROOT/logs"
TIMESTAMP="$(date -u +%Y-%m-%dT%H%M%SZ)"
LOG_FILE="$LOG_DIR/digest-$TIMESTAMP.log"

mkdir -p "$LOG_DIR"

echo ">>> portfolio-digest driver" | tee -a "$LOG_FILE"
echo ">>> timestamp: $TIMESTAMP" | tee -a "$LOG_FILE"

if [[ ! -d "$OPS_DIR" ]]; then
  echo ">>> cloning portfolio-ops" | tee -a "$LOG_FILE"
  mkdir -p "$PORTFOLIO_ROOT"
  cd "$PORTFOLIO_ROOT"
  gh repo clone dj-techs/portfolio-ops 2>&1 | tee -a "$LOG_FILE"
else
  cd "$OPS_DIR"
  git pull --rebase 2>&1 | tee -a "$LOG_FILE"
fi

PROMPT_FILE="$OPS_DIR/session-runner/DIGEST_PROMPT.md"
if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "ERROR: $PROMPT_FILE not found" | tee -a "$LOG_FILE"
  exit 1
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: 'claude' CLI not found" | tee -a "$LOG_FILE"
  echo "See $OPS_DIR/session-runner/SETUP.md" | tee -a "$LOG_FILE"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh CLI not authenticated" | tee -a "$LOG_FILE"
  exit 1
fi

echo ">>> launching claude code digest" | tee -a "$LOG_FILE"
cd "$PORTFOLIO_ROOT"
claude --print --dangerously-skip-permissions "$(cat "$PROMPT_FILE")" 2>&1 | tee -a "$LOG_FILE"
echo ">>> log: $LOG_FILE"
