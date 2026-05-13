# session-runner setup (one-time, on your Mac)

The autonomous portfolio session runs in **Claude Code** on your Mac, driven by Cowork's scheduled task. This document is how to set it up the first time.

## Prerequisites

- macOS with Terminal.app or iTerm2
- `gh` CLI authenticated as `jt-mchorse` (`gh auth login` if not)
- Node.js 18+ (for Claude Code install)
- `git` configured globally as `jt-mchorse / jmchorse.tech@gmail.com`

## Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code
claude --version   # confirm install
claude login       # one-time browser flow
```

Verify with a no-op:
```bash
echo "ping" | claude --print
```

## Bootstrap the local workspace

```bash
mkdir -p ~/projects/portfolio
cd ~/projects/portfolio
gh repo clone jt-mchorse/portfolio-ops
chmod +x portfolio-ops/session-runner/run-session.sh
```

## Run one session manually to confirm everything works

```bash
~/projects/portfolio/portfolio-ops/session-runner/run-session.sh
```

This should:
1. Pull latest portfolio-ops.
2. Validate `gh` is logged in as `jt-mchorse`.
3. Invoke Claude Code with the session prompt.
4. Log the entire run to `~/projects/portfolio/logs/session-<ts>.log`.

## Cowork schedules it

The Cowork scheduled task `portfolio-daily-session` invokes this script every 4 hours (08:00, 12:00, 16:00, 20:00 local) via osascript driving Terminal.app. You don't need to touch the cron — that's set up in Cowork's Scheduled section.

## Iterating on the prompt

The session prompt lives in `portfolio-ops/session-runner/SESSION_PROMPT.md`. Edit it, commit, push. The next run picks up changes automatically (run-session.sh pulls portfolio-ops at the start of each run).
