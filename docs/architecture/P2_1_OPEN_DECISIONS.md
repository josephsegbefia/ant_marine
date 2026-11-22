# P2.1 — Open Architecture Decisions

**Status:** For stakeholder review  
**Registers:** Feed into [`../DECISIONS.md`](../DECISIONS.md) when marked APPROVED — do not silently approve here.

Legend:

- **CONFIRMED** — Already stated in master spec or ADR as direction (not yet formal APPROVED in DECISIONS).
- **PROPOSED** — P2.1 recommendation; needs sign-off.
- **OPEN** — Business or security choice required.

---

## 1. Confirmed direction (no new commitment)

| Ref | Topic | Statement |
|---|---|---|
| CD-001 | Monolith | One Rails 8.1 app (ADR-001) |
| CD-002 | Database | PostgreSQL (ADR-002) |
| CD-003 | Client isolation | Organization is security boundary (master spec §1) |
| CD-004 | Report gates | Technical approval separate from client release (ADR-007 proposed) |
| CD-005 | Anonymous inquiry | No account required for initial quote (master spec §2.2) |
| CD-006 | Remote monitoring | Informative page only; no telemetry domain (master spec §6) |

---

## 2. Proposals for review (P2.1 recommendations)

| ID | Decision | Recommendation | Impact if changed |
|---|---|---|---|
| P2-OD-001 | Inquiry aggregate name | Use `ServiceInquiry` as single funnel for P19–P22 and logged-in C02 “new request” | Renaming touches routes and copy |
| P2-OD-002 | Contact form P18 | Model general contact as `ServiceInquiry` with `channel: contact_form` rather than separate `ContactMessage` | One intake queue for staff S02 |
| P2-OD-003 | Quote revisions | Immutable `QuoteRevision` rows; never edit sent revision in place | Migration and PDF generation |
| P2-OD-004 | Project creation | **APPROVED 2026-11-22:** one `Project` per accepted `QuoteRevision` (unique FK); see P2-OD-043 | P2.5A product owner |
| P2-OD-005 | Report vs Document | Separate `Report` AR sharing version pattern with `Document`; optional `document_id` link for unified preview | Simpler policies if merged; clearer if split |
| P2-OD-006 | Authorization gem | Pundit with explicit policy per AR (master spec proposed) | Alternative: manual policy modules |
| P2-OD-007 | CMS modelling | Separate tables `Article`, `CaseStudy`, `TrainingOffering` vs STI under `ContentPage` | STI fewer tables; separate clearer for M01–M07 |
| P2-OD-008 | Conversation | One primary `Conversation` per `Project` | Multiple threads possible but UI shows one |
| P2-OD-009 | Notifications | Persist `Notification` rows + enqueue mail; audit remains source of truth | Can rebuild notifications from audit with effort |
| P2-OD-010 | Qualification | `QualificationRecord` table vs inquiry status only | Table gives structured history for S03 |
| P2-OD-011 | Primary keys | bigint serial PKs + public `reference_number` columns | UUID optional for external APIs later |

**Default if silent:** adopt recommendations P2-OD-001 through P2-OD-004, P2-OD-006, P2-OD-008, P2-OD-009, P2-OD-011 for P2.2 planning.

---

## 3. Unresolved — mapped from master spec §7 and DECISIONS.md

| ID | Question | Options | P2.1 recommendation | Blocks |
|---|---|---|---|---|
| P2-OD-020 | Client signup (ADR-005) | Invite-only after qualified work vs self-registration | **RESOLVED** — ADR-005 APPROVED 2026-11-22 | Portal launch |
| P2-OD-021 | Quote acceptance actor (ADR-006) | Owner only vs manager vs any member vs staff-on-behalf | **RESOLVED** — ADR-006 APPROVED 2026-11-22 | C04 policy |
| P2-OD-022 | Booking vs quote date | Single preferred date on inquiry vs separate booking AR | **Both**: VO on inquiry + `BookingRequest` for P23 | S06 scheduling |
| P2-OD-023 | Deposits / live payment (ADR-008) | Invoice record only vs integrated PSP | **RESOLVED** — ADR-008 APPROVED (manual records MVP) | Finance slice |
| P2-OD-024 | Vessel registry MVP | Phase 4 slice vs MVP | **Phase 4 follow-on** unless client requests; schema nullable in P2.2 | C vessel screens |
| P2-OD-025 | Report templates | Free-form upload vs structured checklist in DB | **Upload-first** MVP; checklist entities exist for inspections | S12 |
| P2-OD-026 | Email provider (ADR-009) | SMTP provider TBD | Document in Phase 3; domain has `Notification` | Mail deliverability |
| P2-OD-027 | Storage encryption (ADR-010) | SSE-C / client-side / alternate host | **No confidential production files** until PoC approved | File go-live |
| P2-OD-028 | Retention / legal hold | Per category rules in `DocumentRule` | Admin-configurable periods; default TBD with counsel | M09, compliance |
| P2-OD-029 | Staff partial access | Assignment-only vs tiered org-wide | **PROPOSED default:** tiered model in ROLE_PERMISSION_SPEC §5 — org-wide (`projects.view_all`), assignment-based delivery, explicit reviewer/collaborator assignment | S01 security tests |
| P2-OD-030 | Multi-org client groups | Parent holding company with subsidiaries | **Single org per client company** initially; link later if needed | Enterprise clients |
| P2-OD-031 | Public quote without account | Account required vs anonymous inquiry only | **RESOLVED** — ADR-014 APPROVED 2026-11-22 | P19–P22 |
| P2-OD-032 | Custom roles in UI | User-defined roles vs fixed catalogue | **RESOLVED** — ADR-016 APPROVED 2026-11-22 | F4-04b |

---

## 4. P2.2 migration blockers vs non-blockers

| ID | Must approve before first business migration? | Safe default for planning |
|---|---|---|
| P2-OD-020 | Yes (auth design) | Invitation-based onboarding (proposed) |
| P2-OD-021 | Yes (quote accept policy) | Owner or member with `quotes.accept` (proposed) |
| P2-OD-027 | Yes before real client files in production | Dev/staging only until PoC |
| P2-OD-024 | No | Vessels optional FK |
| P2-OD-023 | No | Invoice without PSP |
| P2-OD-007 | No | Separate CMS tables |
| P2-OD-005 | Prefer yes before report tables | Split Report aggregate |

---

## 5. Role & permission system

Configurable RBAC is now a **master spec requirement** (§3.1). Detailed catalogue and matrices: [`ROLE_PERMISSION_SPEC.md`](ROLE_PERMISSION_SPEC.md), [`PERMISSION_CATALOGUE.md`](PERMISSION_CATALOGUE.md), [`DEFAULT_ROLE_MATRIX.md`](DEFAULT_ROLE_MATRIX.md).

P2-OD-006 (Pundit) aligns with ADR-012. Client quote acceptance (P2-OD-021) should be expressed as `quotes.accept` default roles in the matrix.

---

## 7. P2.3 schema handoff (PROPOSED — not approved)

| ID | Question | P2.3 recommendation | Tradeoff |
|---|---|---|---|
| P2-OD-040 | Session storage | **Encrypted cookie session** + `users.security_version`; optional `sessions` table only if compliance requires inventory | Cookie: simpler ops; DB session: easier forced logout audit |
| P2-OD-041 | Audit events shape | **`audit_events` STI** with `type` discriminator | Single query surface; wide table rows |
| P2-OD-042 | Assignment access_scope | **`varchar` column** with CHECK ∈ `delivery`, `review`, `collaborator` on `assignments` | Simpler than join table; extensibility via migration |

Promote to ADR or APPROVED after stakeholder review. See [`P2_3_DATABASE_ARCHITECTURE.md`](P2_3_DATABASE_ARCHITECTURE.md).

---

## 6. Sync with DECISIONS.md

When stakeholders approve items above:

1. Add or update ADR rows in [`../DECISIONS.md`](../DECISIONS.md) with status `APPROVED`, date, and owner.
2. Remove resolved items from §3 here or mark **RESOLVED** with link to ADR.

**P2.1 does not change ADR status lines** — review meeting required.