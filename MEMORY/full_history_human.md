# Session History (human-readable)

Chronological log of work sessions. Most recent first below the divider.

---

## 2026-05-10 — Bootstrap
**Duration:** bootstrap (exempt from 60-min cap per §9) · **Branch:** main (initial commits only)

- Created jt-mchorse/portfolio-ops with the handoff doc, three skills, two trending workflows, CI template, init script, issue templates, PR template, and stub scripts.
- Created the 12 portfolio repos with full scaffolding (18 files each: README, LICENSE, CONTRIBUTING, .gitignore, .github/{ISSUE_TEMPLATE, workflows/ci, pull_request_template}, .skills/{portfolio-memory, portfolio-session}, MEMORY/{four files with D-001}, docs/{architecture, benchmarks}).
- Applied the 16-label canonical set to each of the 13 repos.
- Filed 67 feature issues across the 12 demo repos, one per §2 core deliverable, with scope/acceptance/estimate per the feature.yml schema.

**Why this work, this session:** Bootstrap is the only session permitted to exceed 60 minutes per handoff §9. Single-shot setup beats incremental setup-then-work confusion.

**Open questions / blockers:**
- `scripts/trending_scan.py` and `scripts/prune_stale_trending.py` are stubs that exit 1. The workflows installed reference them but will fail until issue #1 / #2 land. This is documented honestly in the README rather than papered over with a fake green check.
- portfolio-ops needs `ANTHROPIC_API_KEY` and `PORTFOLIO_PAT` secrets configured (manual step by JT) before the workflows can pass.
- `chunking-strategies-lab` was filed with 4 initial issues, one short of the §12 "first 5" target — §2 only enumerates 4 deliverables; rather than fabricate, this is left for JT to fill.
- Branch protection on each repo is left to JT (requires GH Pro for free private repos; these are public, but the script's PR-required policy is a JT preference call).

**Next session:** Implement `scripts/trending_scan.py` per `skills/portfolio-trending/SKILL.md` as portfolio-ops issue #1. Estimated ~75 min.

## 2026-05-11 — Implement real trending scripts
**Duration:** ~45 min · **Branch:** main (direct commit to portfolio-ops, per protocol for memory + bootstrap follow-up)

- Wrote `scripts/trending_scan.py` implementing the SKILL spec: tiered daily/weekly source scan (Anthropic news + docs changelog, OpenAI blog, HF papers daily; Simon Willison, Eugene Yan, Lilian Weng, Latent Space, GitHub trending, HN for weekly), per-finding Claude eval with strict-JSON output and a system prompt that explicitly refuses to follow instructions in scraped content, 30-issue portfolio-wide cap, dedupe by title within target repo.
- Wrote `scripts/prune_stale_trending.py` to close `trending`-labeled issues with no engagement in 30 days.
- Both scripts use Python stdlib only (urllib for HTTP, re for naive XML/HTML parsing). Updated `requirements.txt` to reflect honestly that no pip deps are needed at this stage.

**Why this work, this session:** User explicitly asked to "complete the setup" after the bootstrap. Real scripts are now committed so the GitHub Actions cron actually has work to do when secrets are configured.

**Open questions / blockers:**
- `ANTHROPIC_API_KEY` and `PORTFOLIO_PAT` secrets are still pending JT's manual configuration in portfolio-ops settings. Without them, scheduled workflow runs will exit 1 cleanly with a clear error.
- Smoke test (handoff §9 step 10) is blocked on those secrets.
- Real parsing fidelity (HTML, RSS edge cases) is best-effort with regex. If signal quality suffers, a future session can introduce feedparser / beautifulsoup4. Documented honestly in requirements.txt.

**Next session:** After JT sets secrets, run the smoke test (dispatch trending-daily with --max-issues 1). Then start the first feature session on a portfolio repo per build sequence (llm-eval-harness issue #1).

## 2026-05-13 — Session-runner + cadence + PR auto-merge override
**Duration:** ~35 min · **Branch:** main (direct commit on follow-up to JT feedback)

- Added `session-runner/SESSION_PROMPT.md` — the canonical, version-controlled prompt every scheduled session uses. Edits propagate next run via run-session.sh's git pull.
- Added `session-runner/run-session.sh` — bash driver that validates env, refreshes portfolio-ops, and invokes `claude --print --dangerously-skip-permissions` with the prompt. Logs to `~/projects/portfolio/logs/`.
- Added `session-runner/SETUP.md` — one-time Mac install steps for Claude Code.
- Updated Cowork scheduled task `portfolio-daily-session`: cron changed from `30 8 * * 1-5` to `0 8,12,16,20 * * *` (every day, 4×/day). Prompt rewritten to drive osascript → Terminal.app → run-session.sh instead of running in the Cowork sandbox.
- The session prompt now enforces a strict Phase A (plan + PR review-and-merge) before Phase B (execute). D-004 overrides §10's no-auto-merge for non-draft PRs with green CI.

**Why this work, this session:** JT pushed back on three things: (1) cron too quiet, (2) sandboxed shell not using granted Mac permissions, (3) handoff §10's no-auto-merge bottlenecking velocity. All three are addressed.

**Open questions / blockers:**
- Claude Code must be installed on the Mac before the first scheduled run fires. JT should run the steps in SETUP.md.
- Manual smoke test recommended: `~/projects/portfolio/portfolio-ops/session-runner/run-session.sh` once before relying on the scheduler.
- ANTHROPIC_API_KEY and PORTFOLIO_PAT for the trending workflow are still pending JT action — unchanged.

**Next session:** First autonomous scheduled run (08:00 local tomorrow). Will pick `llm-eval-harness` issue #1 per Phase 1 selection rules.
