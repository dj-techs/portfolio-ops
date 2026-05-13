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

PORTFOLIO_ROOT="${PORTFOLIO_ROOT:-$HOME/projects/portfolio}"
OPS_DIR="$PORTFOLIO_ROOT/portfolio-ops"
LOG_DIR="$PORTFOLIO_ROOT/logs"
TIMESTAMP="$(date -u +%Y-%m-%dT%H%M%SZ)"
LOG_FILE="$LOG_DIR/session-$TIMESTAMP.log"

mkdir -p "$LOG_DIR"

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
  git pull --rebase 2>&1 | tee -a "$LOG_FILE"
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

# 4. Invoke Claude Code with the session prompt
echo ">>> launching claude code session" | tee -a "$LOG_FILE"
cd "$PORTFOLIO_ROOT"

# Claude Code with --print runs non-interactively and exits on completion.
# --dangerously-skip-permissions: scheduled task can't answer permission prompts;
# the session prompt itself enforces what's safe.
# Working dir: $PORTFOLIO_ROOT so cloned repos are accessible.
claude --print --dangerously-skip-permissions "$(cat "$PROMPT_FILE")" 2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}
echo ">>> claude exited with $EXIT_CODE" | tee -a "$LOG_FILE"
echo ">>> log: $LOG_FILE"
exit $EXIT_CODE
