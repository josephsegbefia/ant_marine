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
| P2-OD-040 | Session storage | Database-backed revocable `sessions` + `users.security_version` invalidation | **APPROVED** 2026-11-22 | Product owner; implemented P3-A1 |
| P2-OD-041 | Audit events | `event_type` + JSONB `metadata`; no Rails STI on audit | **APPROVED** 2026-11-22 | Product owner; table deferred past P3-A1 |
| P2-OD-042 | Assignment access | Explicit `access_scope` on assignments + policy enforcement | **APPROVED** 2026-11-22 | Product owner; assignments deferred past P3-A1 |

Only mark a decision `APPROVED` when the user or authorized stakeholder clearly confirms it. Keep history when decisions change.

**P2.5A reconciliation (2026-11-22):** Enumerated ADRs and P2-OD-004/043 approved in commit `08a5423` — see [`P2_5A_STAKEHOLDER_DECISION_RECORD.md`](architecture/P2_5A_STAKEHOLDER_DECISION_RECORD.md).

**P2.5B exit prep (2026-11-22):** P2-OD-040–042 **APPROVED** by product owner for Phase 3 foundation; see [`P2_5B_PHASE_2_EXIT_DECISIONS.md`](architecture/P2_5B_PHASE_2_EXIT_DECISIONS.md). Phase 2 full exit still pending Phase 1 formal sign-off and ADR-010 implementation.

| ADR-F4-02A-001 | Phase 4 sequencing | Staff quotation management ships in **F4-02A** per PO roadmap; master spec **F4-02** anonymous intake and **F4-03** full commercial client workflow remain scheduled—not deleted from spec | **APPROVED** 2026-11-24 | PO F4-02A authorisation; documented in `docs/architecture/F4_02A_QUOTATIONS.md` |

**F4-01 homepage overhaul (2026-11-25, product owner):**

- Homepage follows **P01** (hero, trust strip, services, our work, closing call to action, footer) **plus** short teasers from approved screens: **G03** "How we work" steps, **P09** industries, **P13** latest insights.
- Hero uses the prototype's **illustrated sea-and-vessel artwork** (P01/R01) instead of the AI photograph; `hero-maritime.jpg` stays in assets, unused.
- Header, footer and heading typography changes apply to **all public pages**; page bodies unchanged.
- Project and insight sections render **published records only** and are hidden when none exist; no sample project claims. Closing call to action links to Contact until the P19 quote form exists. No unconfirmed office location in the footer.

**F4-01A public content (2026-11-23):**

- **`services.status` workflow** extended to `draft`, `in_review`, `approved`, `published`, `archived` with `published_*` snapshot columns for live site reads (supersedes P2.3 catalogue three-value enum for marketing services in this app).
- **`public_site_pages` table** introduced for M03 static/homepage content — **not** STI on `content_pages` (aligns P2-OD-007 direction).
- Public marketing HTML remains plain text + sanitised rendering until Action Text is explicitly approved for a later slice.
