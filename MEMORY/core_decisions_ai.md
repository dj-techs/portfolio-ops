# Core Decisions (AI-readable, YAML, append-only)
# Schema: see .skills/portfolio-memory/SKILL.md

- id: D-001
  date: 2026-05-10
  decision: scope_per_portfolio_handoff_section_2
  rationale: locked_scope_prevents_drift
  alternatives_rejected: []
  reversibility: expensive
  related_issues: []
  superseded_by: D-003

- id: D-002
  # superseded by D-003
  date: 2026-05-10
  decision: stub_trending_scripts_at_bootstrap_implement_in_session_one
  rationale: handoff_forbids_pretending_things_work_section_10_no_fabricated_benchmarks
  alternatives_rejected: [implement_full_scanner_during_bootstrap, omit_workflows_entirely]
  reversibility: cheap
  related_issues: []
  superseded_by: D-003

# D-002 superseded
- id: D-003
  date: 2026-05-11
  decision: real_trending_scripts_implemented_using_stdlib_only
  rationale: bootstrap_proceeds_to_functional_state_per_user_followup_request
  alternatives_rejected: [keep_stubs_and_defer, use_external_deps_anthropic_sdk_feedparser]
  reversibility: cheap
  related_issues: []
  superseded_by: null
