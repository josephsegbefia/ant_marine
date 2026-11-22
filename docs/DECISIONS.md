# ANT Marine W.A. — Architecture Decision Register

| ID | Area | Decision | Status | Rationale / owner / date |
|---|---|---|---|---|
| ADR-001 | App shape | One Rails modular monolith; ERB/Hotwire/Stimulus | Proposed direction agreed in conversation | Less integration overhead; shared business models |
| ADR-002 | Database | PostgreSQL | Proposed direction agreed | Mature relational integrity; Rails integration |
| ADR-003 | Hosting | Hetzner + Coolify + Cloudflare | Proposed direction agreed | Deployment control; separation from other apps |
| ADR-004 | Storage | Private S3-compatible object storage, Hetzner first candidate | Proposed, pending security PoC | Requires verified encryption at rest and independent backup |
| ADR-005 | Client signup | Invite after qualified/confirmed service | OPEN | Ease of public inquiry versus tenant security |
| ADR-006 | Quote/booking approval | Client acceptance and staff confirmation guards | OPEN | Contractual and payment implications |
| ADR-007 | Report roles | Technical approval and explicit release are distinct | Proposed, confirm roles | Prevent accidental publication |
| ADR-008 | Payment | Billing records initially; live collection separately decided | OPEN | Commercial/provider obligations |
| ADR-009 | Email | Action Mailer plus an external delivery service | OPEN (provider) | Deliverability |
| ADR-010 | Storage protection | Encryption method, keys, location, retention, backups | OPEN / launch blocker | Confidential documents |
| ADR-011 | Authorization product | Configurable RBAC with staff/client domains, catalogue, overrides, Team & Permissions UI | **REQUIRED** (master spec §3.1) | Spec update 2026-11-22; see `docs/architecture/ROLE_PERMISSION_SPEC.md` |
| ADR-012 | Policy implementation | Pundit policy classes + seeded permission catalogue | PROPOSED (Phase 3) | Alternative: app-layer policy modules without gem |
| ADR-013 | Permission UI | Dedicated staff/client Team & Permissions screens | REQUIRED pending Phase 1 DCR approval | `docs/design/PHASE_1_DESIGN_CHANGE_REQUEST_TEAM_PERMISSIONS.md` |

Only mark a decision `APPROVED` when the user or authorized stakeholder clearly confirms it. Keep history when decisions change.

**Phase 2.1 domain review:** Proposed and open items are catalogued in [`docs/architecture/P2_1_OPEN_DECISIONS.md`](architecture/P2_1_OPEN_DECISIONS.md). Promote entries here after stakeholder approval.
