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

- id: D-004
  date: 2026-05-13
  decision: scheduled_sessions_review_and_merge_ready_prs
  rationale: jt_explicitly_overrode_section_10_for_velocity_drafts_still_protected
  alternatives_rejected: [keep_full_human_in_loop, auto_merge_all_prs_ignoring_draft_status]
  reversibility: cheap
  related_issues: []
  superseded_by: null

- id: D-005
  date: 2026-05-13
  decision: execution_via_claude_code_on_local_mac_not_cowork_sandbox
  rationale: cowork_bash_is_sandboxed_no_gh_auth_propagation_jt_requested_full_use_of_granted_permissions
  alternatives_rejected: [stay_in_cowork_sandbox_with_baked_in_pat, switch_entire_workflow_to_claude_code_only]
  reversibility: cheap
  related_issues: []
  superseded_by: null
