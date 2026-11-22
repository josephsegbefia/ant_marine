# ANT Marine W.A. — Architecture Decision Register

| ID | Area | Decision | Status | Rationale / owner / date |
|---|---|---|---|---|
| ADR-001 | App shape | One Rails modular monolith; ERB/Hotwire/Stimulus | Proposed direction agreed in conversation | Less integration overhead; shared business models |
| ADR-002 | Database | PostgreSQL | Proposed direction agreed | Mature relational integrity; Rails integration |
| ADR-003 | Hosting | Hetzner + Coolify + Cloudflare | Proposed direction agreed | Deployment control; separation from other apps |
| ADR-004 | Storage | Private S3-compatible object storage, Hetzner first candidate | Proposed, pending security PoC | Requires verified encryption at rest and independent backup |
| ADR-005 | Client signup | Invitation-based client portal onboarding after qualified engagement | **APPROVED** 2026-11-22 | Product owner P2.5A; public intake separate — ADR-014 |
| ADR-006 | Quote/booking approval | Quote acceptance by Organisation Owner or member with explicit `quotes.accept` grant; staff confirmation guards on booking/project | **APPROVED** 2026-11-22 | Product owner P2.5A; default roles: owner + manager; members via override |
| ADR-007 | Report roles | Technical approval and explicit release are distinct | Proposed, confirm roles | Prevent accidental publication |
| ADR-008 | Payment | MVP manual payment records only; live online payment processing deferred | **APPROVED** 2026-11-22 | Product owner P2.5A; no card processing in MVP |
| ADR-009 | Email | Action Mailer plus an external delivery service | OPEN (provider) | Deliverability |
| ADR-010 | Storage protection | Block confidential production files until proven; execute bounded P3-STORAGE-01 PoC; encryption method/keys/retention | **APPROVED (objective + PoC plan)** 2026-11-22; **implementation OPEN** | Product owner P2.5A; not verified production-ready |
| ADR-011 | Authorization product | Configurable RBAC with staff/client domains, catalogue, overrides, Team & Permissions UI | **REQUIRED** (master spec §3.1) | Spec update 2026-11-22; see `docs/architecture/ROLE_PERMISSION_SPEC.md` |
| ADR-012 | Policy implementation | Pundit policy classes + central `Authorization::EffectivePermissions` resolver (ROLE_PERMISSION_SPEC §4–5) | **APPROVED** 2026-11-22 | Product owner P2.5A |
| ADR-013 | Permission UI | Dedicated staff/client Team & Permissions screens; DCR approved to add M07a–j / C15a–j to HTML studio (final designs not yet approved) | **APPROVED** 2026-11-22 | Product owner P2.5A; HTML update pending separate task |
| ADR-014 | Public commercial intake | Anonymous quotation and inquiry requests without portal account | **APPROVED** 2026-11-22 | Product owner P2.5A |
| ADR-015 | Ownership privileges | Protected role keys, `team.transfer_ownership`, last active Owner / Super Admin safeguards and recovery | **APPROVED** 2026-11-22 | Product owner P2.5A; ROLE_PERMISSION_SPEC §6 |
| ADR-016 | Custom roles | Defer user-defined custom roles beyond initial release — fixed catalogue roles + per-user overrides only | **APPROVED** 2026-11-22 | Product owner P2.5A |
| ADR-017 | Authentication stack | Rails 8 `authentication` generator + app-owned invitation/session extensions | **APPROVED** 2026-11-22 | See `docs/architecture/P2_2_AUTHENTICATION_ARCHITECTURE.md` |

Only mark a decision `APPROVED` when the user or authorized stakeholder clearly confirms it. Keep history when decisions change.

**P2.5A reconciliation (2026-11-22):** Enumerated ADRs and P2-OD-004/043 approved in commit `08a5423` — see [`P2_5A_STAKEHOLDER_DECISION_RECORD.md`](architecture/P2_5A_STAKEHOLDER_DECISION_RECORD.md).

**P2.5B exit prep (2026-11-22):** P2-OD-040–042 recommendations in [`P2_5B_PHASE_2_EXIT_DECISIONS.md`](architecture/P2_5B_PHASE_2_EXIT_DECISIONS.md) remain **PROPOSED** until product owner approves. Phase 2 full exit pending; Phase 3 Wave A **GO** per that document.
