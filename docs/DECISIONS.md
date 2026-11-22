# ANT Marine W.A. — Architecture Decision Register

| ID | Area | Decision | Status | Rationale / owner / date |
|---|---|---|---|---|
| ADR-001 | App shape | One Rails modular monolith; ERB/Hotwire/Stimulus | Proposed direction agreed in conversation | Less integration overhead; shared business models |
| ADR-002 | Database | PostgreSQL | Proposed direction agreed | Mature relational integrity; Rails integration |
| ADR-003 | Hosting | Hetzner + Coolify + Cloudflare | Proposed direction agreed | Deployment control; separation from other apps |
| ADR-004 | Storage | Private S3-compatible object storage, Hetzner first candidate | Proposed, pending security PoC | Requires verified encryption at rest and independent backup |
| ADR-005 | Client signup | Invitation-based client portal onboarding after qualified engagement | PROPOSED default (pending stakeholder approval) | Public inquiry without account remains separate; see ADR-014 |
| ADR-006 | Quote/booking approval | Quote acceptance by Organisation Owner or member with explicit `quotes.accept` grant; staff confirmation guards on booking/project | PROPOSED default (pending stakeholder approval) | Default roles: owner + manager; members via override only |
| ADR-007 | Report roles | Technical approval and explicit release are distinct | Proposed, confirm roles | Prevent accidental publication |
| ADR-008 | Payment | Billing records initially; live collection separately decided | OPEN | Commercial/provider obligations |
| ADR-009 | Email | Action Mailer plus an external delivery service | OPEN (provider) | Deliverability |
| ADR-010 | Storage protection | Encryption method, keys, location, retention, backups | OPEN / launch blocker | Confidential documents |
| ADR-011 | Authorization product | Configurable RBAC with staff/client domains, catalogue, overrides, Team & Permissions UI | **REQUIRED** (master spec §3.1) | Spec update 2026-11-22; see `docs/architecture/ROLE_PERMISSION_SPEC.md` |
| ADR-012 | Policy implementation | Pundit policy classes + central `Authorization::EffectivePermissions` resolver (ROLE_PERMISSION_SPEC §4–5) | PROPOSED default (pending stakeholder approval) | Alternative: app-layer policy modules without gem |
| ADR-013 | Permission UI | Dedicated staff/client Team & Permissions screens | REQUIRED product intent; **implementation blocked** until DCR approved | `docs/design/PHASE_1_DESIGN_CHANGE_REQUEST_TEAM_PERMISSIONS.md` — **awaiting stakeholder approval** |
| ADR-014 | Public commercial intake | Anonymous quotation and inquiry requests without portal account | PROPOSED default (pending stakeholder approval) | Aligns with master spec §2.1–2.2 |
| ADR-015 | Ownership privileges | Protected role keys, `team.transfer_ownership`, last active Owner / Super Admin safeguards | PROPOSED default (pending stakeholder approval) | ROLE_PERMISSION_SPEC §6 |
| ADR-016 | Custom roles | Defer user-defined custom roles beyond initial release — fixed catalogue roles + per-user overrides only | PROPOSED default (pending stakeholder approval) | P2-OD-032 |
| ADR-017 | Authentication stack | Rails 8 `authentication` generator + app-owned invitation/session extensions | PROPOSED default (pending stakeholder approval) | See `docs/architecture/P2_2_AUTHENTICATION_ARCHITECTURE.md`; Devise fallback documented |

Only mark a decision `APPROVED` when the user or authorized stakeholder clearly confirms it. Keep history when decisions change.

**Phase 2 architecture:** Review package [`P2_5_STAKEHOLDER_APPROVAL_PACK.md`](architecture/P2_5_STAKEHOLDER_APPROVAL_PACK.md) and [`P2_5_FINAL_ARCHITECTURE_REVIEW.md`](architecture/P2_5_FINAL_ARCHITECTURE_REVIEW.md). P2-OD-043 (quote→project 1:1) remains **PROPOSED** until confirmed. Promote ADR entries to APPROVED only after explicit stakeholder sign-off.
