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
| ADR-F4-02A-002 | Quotation workflow hardening | Drafts may be incomplete; submit and approve require a complete quotation (client contact, scope, deliverables, exclusions, priced lines, future validity date, payment terms). Only `draft` and `returned_for_correction` are editable; `pending_review` is read-only; approved/issued versions are frozen in model guards and DB check constraints. Approve/return require `quotes.approve`, enforced inside `Commercial::QuoteTransition`. Issuing is disabled (`Commercial::QuoteIssuance.available? == false`) until a delivery channel is approved. No tax, deposit or legal terms are added automatically | **Implemented — PO review** 2026-11-25 | F4-02A-H1 brief; `docs/architecture/F4_02A_QUOTATIONS.md` |
| ADR-F4-02A-003 | Quotation reviewer separation, units and commercial policy | **Four-eyes approval:** the approver must hold `quotes.approve`, be able to view the quotation, act on the current version (revision id + lock version) and not be the preparer, submitter or any material editor of that specific version (by membership and user). Enforced in `Commercial::QuoteTransition`, mirrored in `QuotePolicy`, a model validation and DB check `quote_revisions_approver_is_independent`; no Super Admin bypass; refused attempts audited as `quote.approval_refused`; approved history not backfilled. **Units:** Each, Hour, Day, Visit, Survey, Report, Lot, plus Other with a validated custom label (30 chars); legacy free-text units kept exactly. **Commercial policy:** no VAT/tax rates, deposits or standard legal wording are configured or invented; only per-quotation typed terms appear; tax, deposit, legal terms and issuance channel need business approval before real issuance | **APPROVED (PO decisions) — implemented** 2026-11-25 | F4-02A-H2 brief; `docs/architecture/F4_02A_QUOTATIONS.md` |
| ADR-F4-02B-001 | F4-02A acceptance | F4-02A, H1 and H2 accepted by the product owner; F4-02B builds on commit `1bfa652` without changing their invariants | **ACCEPTED (PO)** 2026-11-25 | F4-02B brief |
| ADR-F4-02B-002 | Public enquiries | `service_inquiries` table (`ServiceInquiry`), public four-step wizard at `/request-a-quote` without an account, no file uploads, spam control by honeypot + signed form timing + Rails `rate_limit` (no new gem), idempotent submission token, session-only confirmation, `no-store`, personal fields filtered from logs. Minimal staff list/detail behind `inquiries.view_all`; triage is F4-03 | **Implemented — PO review** 2026-11-25 | `docs/architecture/F4_02B_ENQUIRIES_ISSUANCE.md` |
| ADR-F4-02B-003 | Enquiry → quotation | Staff "Prepare quotation" creates one open draft per enquiry (DB partial unique index), copying client facts only; no prices, terms or validity invented; link permanent; never creates a project | **Implemented — PO review** 2026-11-25 | Same |
| ADR-F4-02B-004 | Quotation versions | New version from an approved or issued quotation needs a reason and the current version reference; approval never inherited; earlier versions immutable. Approving version N supersedes earlier approved-unsent versions; an issued version stays the client's outstanding offer until a newer version is issued | **Implemented — PO review** 2026-11-25 | Same |
| ADR-F4-02B-005 | Quotation delivery | `quote_deliveries` records each attempt for one exact version; Action Mailer + Solid Queue (`mail` queue); claim-before-send, no automatic retries; truthful statuses ("accepted" is not "delivered"; `delivery_confirmed` needs provider evidence in the DB). Dispatch only outside production with the `:test`/`:file` adapters; production hard-off pending ADR-009 provider, sender domain, approved wording/terms and PO switch | **Implemented (test-only) — live delivery NOT approved** 2026-11-25 | Same |
| ADR-F4-02B-006 | History protection at database level | Triggers (needs `structure.sql`) or a restricted application role (needs production DB configuration) proposed; **not applied** — current protection is check constraints + model guards + regression tests | **OPEN — needs PO/infrastructure approval** | Same, §7 |

**F4-01 homepage overhaul (2026-11-25, product owner):**

- Homepage follows **P01** (hero, trust strip, services, our work, closing call to action, footer) **plus** short teasers from approved screens: **G03** "How we work" steps, **P09** industries, **P13** latest insights.
- Hero uses the prototype's **illustrated sea-and-vessel artwork** (P01/R01) instead of the AI photograph; `hero-maritime.jpg` stays in assets, unused.
- Header, footer and heading typography changes apply to **all public pages**; page bodies unchanged.
- Project and insight sections render **published records only** and are hidden when none exist; no sample project claims. Closing call to action links to Contact until the P19 quote form exists. No unconfirmed office location in the footer.

**F4-01A public content (2026-11-23):**

- **`services.status` workflow** extended to `draft`, `in_review`, `approved`, `published`, `archived` with `published_*` snapshot columns for live site reads (supersedes P2.3 catalogue three-value enum for marketing services in this app).
- **`public_site_pages` table** introduced for M03 static/homepage content — **not** STI on `content_pages` (aligns P2-OD-007 direction).
- Public marketing HTML remains plain text + sanitised rendering until Action Text is explicitly approved for a later slice.
