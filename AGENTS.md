# ANT Marine W.A. — Instructions for all AI coding agents

**Read first:** `docs/ANT_MARINE_MASTER_SPEC.md`, then `design/PHASE_1_DESIGN_HANDOFF.md` and relevant screens in `design/ANT_Marine_Design_Studio_Phase_1.html`.

## Core rules

- **Ruby on Rails only**: server-side Rails views + Hotwire (Turbo/Stimulus) + PostgreSQL + Tailwind. One modular Rails monolith; do not introduce React/Next, Express, Vue, GraphQL, Node-based frontend or microservices without approved architecture change.
- **UI is the contract**: follow the Phase 1 prototype for page coverage, page copy, spacing, states, routes and responsive behavior once reviewed/approved. The questionnaire controls factual product scope. Never publish fake project/client claims from sample designs.
- **No developer jargon in client or staff UI.** Use familiar everyday English; technical maritime service names are okay when accurately used.
- **Safety/security first**: authorize every request by organization/role/assignment, not only by navigation visibility. Protect every file request. Draft reports may not appear in the client portal until separately approved and explicitly released.
- All new business transitions must be tested for success, denied access, retry and invalid state. Add database constraints and audit events where needed.
- Keep commits/slices small and reviewable. Do not generate the entire application from one prompt. Prefer tests first for authorization and business transitions.
- Do not add dependencies until used. Justify any gem; use Rails standard components where practical. Don't create speculative infrastructure.
- Never read, echo or commit credentials. Never alter production/Cloudflare/Coolify/Hetzner or send real communications without explicit user authorization.
- Prefer Cursor's built-in Agent for coding; terminal is for setup, run and test. Never use Codex CLI.

## Required workflow

1. State current phase and slice; inspect source/spec, affected existing files, and screen IDs.
2. Present a concise file/migration/test plan before major edits.
3. Implement and test a complete but bounded vertical slice.
4. Run: relevant Rails tests, full test suite at checkpoint, `bin/rubocop`, `bin/brakeman`, migration check, diff check and targeted browser acceptance as applicable.
5. Report **actual** pass/fail statuses and outstanding risks; never claim tests ran if they did not.
6. Update `docs/DECISIONS.md`, any changed contract/requirements and phase progress only when the change is approved.

## Project precedence

Approved spec and decisions > original questionnaire for factual requirements > approved design review/prototype for UI > incidental AI suggestions. If sources conflict, explain and request a decision before irreversible changes.
