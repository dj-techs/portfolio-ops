# Core Decisions

Strategic decisions for this repo, with reasoning. Append-only — superseded decisions are marked, not removed.

## D-001 — Scope locked to portfolio handoff §2 (2026-05-10)
**Decision:** Scope of this repo is fixed by the portfolio handoff document, section 2.

**Why:** The handoff spec was deliberated; ad-hoc scope expansion within a session is the failure mode this prevents.

**Alternatives considered:** None — this is a baseline.

**Reversibility:** Expensive. Scope changes require a deliberate revisit and a new decision entry.

**Related issues:** —

## D-002 — Trending scripts stubbed at bootstrap, implemented in session one (2026-05-10)
**Decision:** `scripts/trending_scan.py` and `scripts/prune_stale_trending.py` are committed as stubs that exit 1; the real implementation is filed as portfolio-ops issue #1 and #2.

**Why:** Handoff §10 is explicit — "do not invent benchmark numbers" and the same principle applies to plumbing. A workflow that silently no-ops would imply the trending system works when it doesn't. A stub that exits 1 + a README note is honest. Bootstrap exists to make the system reviewable, not pretend it's done.

**Alternatives considered:**
- Implement the full scanner during bootstrap — rejected because it's real engineering work that violates the bootstrap-vs-session boundary; would also lock in design choices without thinking.
- Omit the workflows entirely — rejected because the workflow YAML is part of the spec the system was reviewed on; presence + honest stub is better than silent absence.

**Reversibility:** Cheap. The first two issues replace the stubs.

**Related issues:** —
