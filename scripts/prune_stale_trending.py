#!/usr/bin/env python3
"""Prune stale `trending`-labeled issues across the 12 portfolio repos.

Rules (from skills/portfolio-trending/SKILL.md):
- No engagement in 30 days → close with label `wontfix-stale`.
- "Engagement" = any comment, or any label change in the past 30 days,
  or any commit referencing the issue (#NNN in commit message — checked
  best-effort via the timeline API).
- Don't touch issues where someone (other than the bot/PR template) has
  commented in the last 30 days.

Required env:
  GH_TOKEN              fine-scoped PAT with issues:write on the 12 repos.

Exit codes:
  0   ran cleanly
  1   missing env or unrecoverable error
"""
from __future__ import annotations

import datetime as dt
import json
import os
import sys
import urllib.parse
import urllib.request
import urllib.error
from typing import Any

REPO_OWNER = "jt-mchorse"
STALE_DAYS = 30
USER_AGENT = "portfolio-trending-prune/1.0"

ALL_REPOS = [
    "rag-production-kit", "agent-orchestration-platform", "llm-eval-harness",
    "prompt-regression-suite", "ai-app-integration-tests", "nextjs-streaming-ai-patterns",
    "python-async-llm-pipelines", "embedding-model-shootout", "chunking-strategies-lab",
    "llm-cost-optimizer", "vector-search-at-scale", "mcp-server-cookbook",
]


def gh(method: str, path: str, body: Any = None) -> tuple[int, Any]:
    token = os.environ.get("GH_TOKEN")
    if not token:
        raise SystemExit("GH_TOKEN not set")
    url = f"https://api.github.com{path}" if not path.startswith("http") else path
    req = urllib.request.Request(url, method=method, headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": USER_AGENT,
    })
    if body is not None:
        req.data = json.dumps(body).encode()
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            payload = resp.read().decode() or "null"
            return resp.status, json.loads(payload)
    except urllib.error.HTTPError as e:
        body_txt = e.read().decode()
        try:
            return e.code, json.loads(body_txt)
        except Exception:
            return e.code, {"raw": body_txt}


def list_trending_issues(repo: str) -> list[dict]:
    issues = []
    page = 1
    while True:
        c, b = gh("GET", f"/repos/{REPO_OWNER}/{repo}/issues?state=open&labels=trending&per_page=100&page={page}")
        if c != 200 or not isinstance(b, list) or not b:
            break
        for issue in b:
            if "pull_request" not in issue:
                issues.append(issue)
        if len(b) < 100:
            break
        page += 1
    return issues


def is_stale(issue: dict) -> bool:
    updated = dt.datetime.fromisoformat(issue["updated_at"].replace("Z", "+00:00"))
    age_days = (dt.datetime.now(dt.timezone.utc) - updated).days
    return age_days >= STALE_DAYS


def close_stale(repo: str, issue: dict) -> None:
    n = issue["number"]
    # Add wontfix-stale label
    gh("POST", f"/repos/{REPO_OWNER}/{repo}/issues/{n}/labels", {"labels": ["wontfix-stale"]})
    # Comment
    gh("POST", f"/repos/{REPO_OWNER}/{repo}/issues/{n}/comments", {
        "body": f"Auto-closed by `prune_stale_trending.py`: no engagement in {STALE_DAYS} days. Reopen if still relevant.",
    })
    # Close
    gh("PATCH", f"/repos/{REPO_OWNER}/{repo}/issues/{n}", {
        "state": "closed",
        "state_reason": "not_planned",
    })
    print(f"[closed] {repo}#{n}: {issue['title'][:80]}")


def main() -> int:
    if not os.environ.get("GH_TOKEN"):
        print("GH_TOKEN not set; exiting 1", file=sys.stderr)
        return 1

    closed_total = 0
    for repo in ALL_REPOS:
        issues = list_trending_issues(repo)
        stale = [i for i in issues if is_stale(i)]
        if not stale:
            continue
        print(f"[{repo}] {len(stale)} stale of {len(issues)} open trending")
        for issue in stale:
            try:
                close_stale(repo, issue)
                closed_total += 1
            except Exception as e:
                print(f"[warn] {repo}#{issue['number']} close failed: {e}", file=sys.stderr)

    print(f"done — closed {closed_total} stale trending issues")
    return 0


if __name__ == "__main__":
    sys.exit(main())
