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

## 2026-05-16 — Multi-issue DAY session: six PRs across five repos
**Duration:** ~65 min real time (DAY cap = 180 min) · **Branches:** six `session/2026-05-16-*` branches

Six PRs opened in one DAY session (target was 2–4; over-delivered because the Protocol+dep-free-default+lazy-Anthropic-extra pattern is now load-bearing in seven modules across four repos, so each new "feature behind a seam" reuses the same shape):

1. **rag-production-kit PR #14** — `Rewriter` Protocol with `TemplateRewriter` (dep-free, rule-based decomposition for compare/then/multi-question-and patterns) + `AnthropicRewriter` (lazy-imported via existing `[rag-anthropic]` extra). Wired into `Retriever.search(rewriter=...)`. D-014. Real bench: recall@3 on synthetic 18-chunk multi-hop fixture rises 0.625 → 0.812.
2. **mcp-server-cookbook PR #9** — third cookbook server `github-gists` (API wrapper + token auth pattern). D-007 records the redaction posture: bearer token never appears in tool results, error messages, or logs; request body dropped from error context. CI job added. 28 hermetic tests using injected fetch.
3. **rag-production-kit PR #15** — `CostRecord` + `PriceTable` (operator-supplied, no defaults, D-015) + `TelemetryStore` (stdlib `sqlite3`) + `aggregate` (p50/p95/p99) + a stdlib HTTP dashboard with inline-SVG charts. Branched off main so it's independent of PR #14; the two only collide on `__init__.py` exports.
4. **llm-eval-harness PR #14** — `eval_harness/drift.py` three-axis drift detection (length / embedding-cluster / judge). Each axis scored by Jensen-Shannon divergence (D-014, bounded `[0, 1]`, generalizes to categorical clusters where KS doesn't). Inline-SVG HTML report. `eval-harness drift` CLI subcommand. Smoke fixtures + tests assert default-threshold posture.
5. **llm-cost-optimizer PR #10** — `cost_optimizer/batch.py`: `BatchBackend` Protocol, `InMemoryBatchBackend` for hermetic CI, `AnthropicBatchBackend` duck-typed per D-002. Idempotency = caller key + content hash, conflict raises (D-010). `compare_realtime_vs_batch` with `BATCH_DISCOUNT_FACTOR = 0.5`. 28 hermetic tests.
6. **prompt-regression-suite PR #9** — `prompt-snap` console script (`run`/`update`/`diff` subcommands). Pure glue, no new decisions. `update --force` defends against accidental re-baselining. 25 hermetic tests.

Five of six PRs record a new core decision; the sixth (the CLI) is intentionally just glue.

**Why this work, this session:** Filling out the v0.1 surface of multiple repos simultaneously while the cross-repo pattern (`Protocol` + dep-free default + lazy production binding) is fresh. Five repos move toward v0.1: rag-production-kit's `Retriever.search` now exposes both pre-retrieval rewriting and per-request cost telemetry; the cookbook adds its API-with-auth entry; the eval harness's drift detection axis lands; the cost optimizer adds the batch axis; prompt-regression-suite gets its CLI.

**Open questions / blockers:**
- The two rag-production-kit PRs (#14 rewriter, #15 telemetry) collide only on `rag_kit/__init__.py` exports — whichever lands second needs a one-line rebase merging the new export lists.
- One follow-up issue filed: `mcp-server-cookbook#10` (filesystem-sandbox CI job missing). Priority:low so it doesn't crowd the queue.
- No PR-review pass at session start (zero open non-draft PRs across the portfolio), so the review-and-merge step (D-004) was a no-op.

**Next session:** Sweep the six PRs for CI signal and merge per D-004. The next code-writing target depends on what merges first — the safe choices are `embedding-model-shootout`, `chunking-strategies-lab`, or `vector-search-at-scale` (all untouched this run, all still have open priority:med work).
