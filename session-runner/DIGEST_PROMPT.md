# Portfolio Weekly Digest Prompt (canonical)

You are writing JT's Monday-morning portfolio digest. Goal: a scannable brief of the past 7 days across the 12 portfolio repos under `github.com/dj-techs`, plus `portfolio-ops`.

You run on JT's Mac via Claude Code with full shell access. `gh` is authenticated as `jt-mchorse`.

## Source data (all via gh CLI)

Repos in scope:
```
portfolio-ops rag-production-kit agent-orchestration-platform llm-eval-harness prompt-regression-suite ai-app-integration-tests nextjs-streaming-ai-patterns python-async-llm-pipelines embedding-model-shootout chunking-strategies-lab llm-cost-optimizer vector-search-at-scale mcp-server-cookbook
```

For each, gather (last 7 days):

```bash
SINCE=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d)

for r in <repos>; do
  echo "=== $r ==="
  # PRs
  gh pr list --repo jt-mchorse/$r --state all --json number,title,url,createdAt,mergedAt,isDraft --search "created:>=$SINCE"
  # Issues
  gh issue list --repo jt-mchorse/$r --state all --json number,title,url,createdAt,labels,closedAt --search "created:>=$SINCE"
  # Latest session entry from MEMORY (if cloned)
  if [[ -d ~/projects/portfolio/repos/$r ]]; then
    (cd ~/projects/portfolio/repos/$r && tail -30 MEMORY/full_history_ai.md)
  fi
done
```

## Output structure (≤600 words)

### Headlines (3–5 bullets)
The most important things that shipped or surfaced. One line each, repo-tagged.

### Shipped this week
Compact list grouped by repo. Only repos with activity. Each entry: `repo PR #N — title (merged|draft|open) → URL`. Skip repos with zero activity.

### Trending issues filed
Group by category label. For each: `repo#N — title`.

### Themes worth your attention
2–3 sentences. Cross-repo patterns. Recurring issue types. Decisions that need revisiting. If the week was thin, say "thin week, nothing to flag" — don't pad.

### Recommended focus for the upcoming week
One bullet per repo that needs attention. Format: `repo: <one specific issue or theme>`. Skip healthy repos.

## Delivery

1. Print the digest to stdout as the final part of your run.
2. Write it to `~/projects/portfolio/logs/digest-$(date -u +%Y-%m-%d).md`.
3. If `dj-techs/portfolio-ops` has Discussions enabled (check via `gh api /repos/dj-techs/portfolio-ops --jq .has_discussions`):
   - Get the categories: `gh api /repos/dj-techs/portfolio-ops/discussions/categories`
   - Post the digest: `gh api -X POST graphql -f query='mutation { createDiscussion(...) }'` — use the GraphQL `createDiscussion` mutation since REST doesn't support discussion creation. Title: `Weekly digest — week of $(date -u +%Y-%m-%d)`.
   - If discussions are off or posting fails, skip silently — the file on disk is the authoritative copy.

## Honesty rules

- If you can't fetch data for a repo, name the repo and the failure. Don't make up activity.
- If the past week had nothing shipped in a repo, say so plainly.
- Do not summarize commits as "made progress" without specifics. Concrete or skip.
- Time-cap the whole run at 30 minutes. If you're still gathering at 25 min, write whatever digest you have with what you've got.
