# portfolio-ops
> Operations and memory for JT McHorse's AI/ML engineering portfolio.

This repo is the spine of a 12-repo portfolio system. It contains:

- **`COWORK_HANDOFF.md`** — the binding handoff document Cowork reads at every session start.
- **`skills/`** — three Cowork skills (`portfolio-memory`, `portfolio-session`, `portfolio-trending`) that enforce the protocol across all repos.
- **`workflows/`** — daily and weekly trending intake workflows (run from inside this repo) plus a CI template applied to every portfolio repo.
- **`templates/`** — `init-portfolio-repo.sh` for new repos, `pull_request_template.md`, etc.
- **`issue_templates/`** — feature, bug, trending, decision-revisit forms.
- **`MEMORY/`** — append-only history and core decisions for portfolio-ops itself.

## Portfolio repos

| # | Repo | Spine |
|---|------|-------|
| 1 | [llm-eval-harness](https://github.com/jt-mchorse/llm-eval-harness) | Evals |
| 2 | [llm-cost-optimizer](https://github.com/jt-mchorse/llm-cost-optimizer) | ML ops |
| 3 | [prompt-regression-suite](https://github.com/jt-mchorse/prompt-regression-suite) | Testing |
| 4 | [rag-production-kit](https://github.com/jt-mchorse/rag-production-kit) | RAG |
| 5 | [embedding-model-shootout](https://github.com/jt-mchorse/embedding-model-shootout) | Research |
| 6 | [chunking-strategies-lab](https://github.com/jt-mchorse/chunking-strategies-lab) | Research |
| 7 | [vector-search-at-scale](https://github.com/jt-mchorse/vector-search-at-scale) | Performance |
| 8 | [python-async-llm-pipelines](https://github.com/jt-mchorse/python-async-llm-pipelines) | Performance |
| 9 | [agent-orchestration-platform](https://github.com/jt-mchorse/agent-orchestration-platform) | Agents/MCP |
| 10 | [mcp-server-cookbook](https://github.com/jt-mchorse/mcp-server-cookbook) | MCP |
| 11 | [nextjs-streaming-ai-patterns](https://github.com/jt-mchorse/nextjs-streaming-ai-patterns) | Full-stack |
| 12 | [ai-app-integration-tests](https://github.com/jt-mchorse/ai-app-integration-tests) | Testing |

## Trending workflow status

The trending workflows in `workflows/` reference `scripts/trending_scan.py` and `scripts/prune_stale_trending.py`, which **are not yet implemented**. They are the subject of the first feature session in this repo. Until then the workflows will fail if dispatched. This is documented honestly per handoff §10 ("don't invent benchmark numbers"): the system is half-built, not pretending to be done.

Required secrets for the trending workflow (set in repo settings → secrets after `scripts/` lands):
- `ANTHROPIC_API_KEY`
- `PORTFOLIO_PAT` (fine-scoped PAT with `repo` and `issues:write` across the 12 repos)

## License
MIT
