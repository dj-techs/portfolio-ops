# Core Decisions

Strategic decisions for this repo, with reasoning. Append-only — superseded decisions are marked, not removed.

## D-001 — Scope locked to portfolio handoff §2 (2026-05-10)
**Decision:** Scope of this repo is fixed by the portfolio handoff document, section 2.

**Why:** The handoff spec was deliberated; ad-hoc scope expansion within a session is the failure mode this prevents.

**Alternatives considered:** None — this is a baseline.

**Reversibility:** Expensive. Scope changes require a deliberate revisit and a new decision entry.

**Related issues:** —

## D-002 — Trending scripts stubbed at bootstrap [SUPERSEDED BY D-003], implemented in session one (2026-05-10)
**Decision:** `scripts/trending_scan.py` and `scripts/prune_stale_trending.py` are committed as stubs that exit 1; the real implementation is filed as portfolio-ops issue #1 and #2.

**Why:** Handoff §10 is explicit — "do not invent benchmark numbers" and the same principle applies to plumbing. A workflow that silently no-ops would imply the trending system works when it doesn't. A stub that exits 1 + a README note is honest. Bootstrap exists to make the system reviewable, not pretend it's done.

**Alternatives considered:**
- Implement the full scanner during bootstrap — rejected because it's real engineering work that violates the bootstrap-vs-session boundary; would also lock in design choices without thinking.
- Omit the workflows entirely — rejected because the workflow YAML is part of the spec the system was reviewed on; presence + honest stub is better than silent absence.

**Reversibility:** Cheap. The first two issues replace the stubs.

**Related issues:** —

## D-003 — Real trending scripts using stdlib only (2026-05-11)
**Decision:** `scripts/trending_scan.py` and `scripts/prune_stale_trending.py` are committed with real implementations using only the Python standard library. Supersedes D-002 (which left them as stubs).

**Why:** Following bootstrap, JT explicitly asked to complete the setup. The choice between adding external deps (anthropic SDK, feedparser, beautifulsoup4) and using stdlib came down to dependency hygiene — for a script that runs in GitHub Actions on a schedule, fewer moving parts means fewer failure modes from upstream package changes. The Anthropic Messages API is a simple HTTPS endpoint; urllib calls it directly with the same response shape.

**Alternatives considered:**
- Keep the D-002 stubs — rejected because the user request was to complete, not defer further.
- Use the official Anthropic Python SDK + feedparser + bs4 — rejected because we don't need them for this fidelity. A future session can swap in if regex parsing proves brittle.

**Reversibility:** Cheap. Either component can be swapped to SDKs in a follow-up session without API surface changes for callers.

**Related issues:** —

*D-002 is marked superseded by D-003 in `core_decisions_ai.md`.*
