# P2.5A — Stakeholder Decision Record

**Date:** 22 November 2026  
**Approval source:** Product owner explicit conversational go-ahead to the **enumerated recommendations** listed below (not blanket Phase 2 approval).  
**Authority:** [`P2_5_STAKEHOLDER_APPROVAL_PACK.md`](P2_5_STAKEHOLDER_APPROVAL_PACK.md)

---

## 1. Approved decisions (ADR)

| ID | Approved direction | Documented match? | Status |
|---|---|---|---|
| ADR-005 | Invitation-only client portal onboarding after qualification | Yes | **APPROVED** 2026-11-22 |
| ADR-006 | Organisation Owner or user with explicit `quotes.accept` may accept a quotation | Yes (matrix defaults owner + manager; member via override) | **APPROVED** 2026-11-22 |
| ADR-008 | MVP manual payment records; live online payments deferred | Yes | **APPROVED** 2026-11-22 |
| ADR-012 | Pundit + central `Authorization::EffectivePermissions` | Yes | **APPROVED** 2026-11-22 |
| ADR-013 | Team & Permissions mandatory in staff/client portals; **DCR approved** to add screens to HTML studio (not final pixel sign-off) | Yes — see §3 | **APPROVED** 2026-11-22 |
| ADR-014 | Public service inquiries and quote requests without account | Yes | **APPROVED** 2026-11-22 |
| ADR-015 | Last Owner / Super Admin protection + succession/recovery | Yes | **APPROVED** 2026-11-22 |
| ADR-016 | 13 predefined roles + overrides; custom roles deferred | Yes | **APPROVED** 2026-11-22 |
| ADR-017 | Rails 8 native authentication + app-owned extensions | Yes | **APPROVED** 2026-11-22 |

### ADR-010 (partial)

| Scope | Status |
|---|---|
| Security objective: confidential production files blocked until proven controls | **APPROVED** 2026-11-22 |
| Bounded **P3-STORAGE-01** PoC plan | **APPROVED** 2026-11-22 |
| Encryption method verified / production-ready | **NOT APPROVED** — remains OPEN until PoC evidence |

---

## 2. Approved open decisions (P2-OD)

| ID | Approved direction | Status |
|---|---|---|
| P2-OD-004 | One `Project` per accepted `QuoteRevision` (unique FK) | **APPROVED** 2026-11-22 (with P2-OD-043) |
| P2-OD-043 | MVP: one accepted quotation revision → one delivery project; multi-vessel/inspection/assignment on project; change orders / multi-project = future design | **APPROVED** 2026-11-22 |
| P2-OD-020 | Invitation onboarding (ADR-005) | **RESOLVED** → ADR-005 |
| P2-OD-021 | Accept actor (ADR-006) | **RESOLVED** → ADR-006 |
| P2-OD-023 | Records-only payments (ADR-008) | **RESOLVED** → ADR-008 |
| P2-OD-031 | Public inquiry without account (ADR-014) | **RESOLVED** → ADR-014 |
| P2-OD-032 | Defer custom roles (ADR-016) | **RESOLVED** → ADR-016 |
| P2-OD-006 | Pundit (ADR-012) | **RESOLVED** → ADR-012 |

---

## 3. Design change request status

| Item | Status |
|---|---|
| [`PHASE_1_DESIGN_CHANGE_REQUEST_TEAM_PERMISSIONS.md`](../design/PHASE_1_DESIGN_CHANGE_REQUEST_TEAM_PERMISSIONS.md) | **Change request APPROVED** 2026-11-22 |
| Update `ANT_Marine_Design_Studio_Phase_1.html` | **Pending** — not modified in P2.5A |
| Final screen designs / pixel copy | **Not approved** — requires future design review |
| Phase 1 studio overall | **Not fully signed off** — no formal approval export on record |

**UI rule reaffirmed:** ANT Marine HTML Design Studio is the sole implementation blueprint; no external design copies.

---

## 4. Retained PROPOSED / OPEN (not approved in P2.5A)

| ID | Why still open |
|---|---|
| ADR-001–003 | “Proposed direction agreed in conversation” — not part of P2.5A list (unchanged) |
| ADR-004 | Storage host choice pending PoC |
| ADR-007 | Report role split — not in approval list (Proposed) |
| ADR-009 | Email provider OPEN |
| ADR-010 (implementation) | Encryption technique unproven |
| ADR-011 | Product **REQUIRED** (spec) — not a stakeholder flip |

---

## 5. Outstanding decision register (all unresolved P2-OD)

| ID | Exact question | Recommendation | Alternatives | Business consequence | Blocks Wave A? | Blocks confidential prod? | Deferrable? |
|---|---|---|---|---|---|---|---|
| P2-OD-001 | Inquiry aggregate name `ServiceInquiry`? | Single funnel P19–P22 + C02 | Separate aggregates | Route/copy consistency | No | No | Yes (Phase 3 C) |
| P2-OD-002 | Contact P18 as `ServiceInquiry` channel? | Merge into inquiry queue | Separate `ContactMessage` | One staff queue | No | No | Yes |
| P2-OD-003 | Immutable quote revisions? | Yes | Editable sent rows | Legal audit | No | No | Yes |
| P2-OD-005 | Separate Report vs Document AR? | Split | Merge | Policy complexity | No | No | Prefer before report tables |
| P2-OD-007 | CMS separate tables vs STI? | Separate tables | STI `ContentPage` | Admin UX | No | No | Yes |
| P2-OD-008 | One conversation per project? | One primary | Many threads | C10 simplicity | No | No | Yes |
| P2-OD-009 | Persist notifications? | Yes + audit SoT | Ephemeral only | Inbox rebuild cost | No | No | Yes |
| P2-OD-010 | QualificationRecord table? | Optional table | Status only | S03 history | No | No | Yes |
| P2-OD-011 | bigint PKs + reference_number? | Yes | UUID PKs | Public refs | No | No | Yes (Wave A uses bigint) |
| P2-OD-022 | Booking vs quote date modelling? | Both inquiry VO + `BookingRequest` | Single field | P23 vs inquiry | No | No | Yes |
| P2-OD-024 | Vessel registry in MVP? | Phase 4 follow-on | MVP | C vessel screens | No | No | Yes |
| P2-OD-025 | Report templates structured vs upload? | Upload-first MVP | DB templates | S12 depth | No | No | Yes |
| P2-OD-026 | Email provider | TBD Phase 3 | — | Deliverability | No | No | Yes (stub mailer) |
| P2-OD-027 | Storage encryption approach | No prod confidential until PoC | Various | Launch gate | No | **Yes** | No — PoC required |
| P2-OD-028 | Retention / legal hold | DocumentRule configurable | Fixed defaults | Compliance | No | Partial | Yes |
| P2-OD-029 | Staff access tiering | ROLE_PERMISSION_SPEC §5 | Assignment-only all | Security model | No | No | Effectively adopted in spec; formal APPROVED optional |
| P2-OD-030 | Multi-org client groups | Single org per company | Parent/subsidiary | Enterprise | No | No | Yes |
| P2-OD-040 | Session storage | Encrypted cookie + security_version | DB sessions | Logout inventory | **Prefer before auth deploy** | No | Wave A can prototype cookie |
| P2-OD-041 | Audit shape | STI `audit_events` | Typed tables | M13 queries | No | No | Yes (Wave A audit migration) |
| P2-OD-042 | assignment `access_scope` | varchar CHECK enum | Join table | Reviewer scope | No | No | Yes before assignment policies |
| P2-OD-044 | Quote internal review before send | Optional checklist | Formal gate | Send quality | No | No | Yes |
| P2-OD-045 | Surveyor assignment ack | Optional `acknowledged_at` | Required ack | Field UX | No | No | Yes |
| P2-OD-046 | Report post-release amendment | New version + release | Edit released | Client trust | No | No | Yes |
| P2-OD-047 | Invoice internal approval | Finance single-step issue | Dual approval | Controls | No | No | Yes |
| P2-OD-048 | Project `suspended` state | Add enum | Skip | S07/C05 | No | No | Yes |

---

## 6. Phase 2 exit status

| Area | Status |
|---|---|
| Documented architecture P2.1–P2.5 | Complete |
| Enumerated business ADRs (P2.5A list) | **Approved** |
| Phase 2 **fully approved** gate | **No** — ADR-010 implementation, Phase 1 formal sign-off, P2-OD-040–042 not closed |
| Phase 3 Wave A | **GO** — see §7 |

---

## 7. Phase 3 Wave A prerequisites

**Ready to begin** (2026-11-22) with approved ADR-017, 012, 005, 015, 016:

| Checkpoint | Prerequisite | Met? |
|---|---|---|
| P3-A1 Rails authentication generator | ADR-017 APPROVED | Yes |
| P3-A2 organizations / memberships | ADR-005, 015 APPROVED | Yes |
| P3-A3 permission seeds | ADR-012, 016 APPROVED | Yes |
| P3-A4 invitations | ADR-005 APPROVED | Yes |
| P3-A6 Pundit + EffectivePermissions | ADR-012 APPROVED | Yes |
| P3-A8 layout shells | Phase 1 HTML exists; **not** full sign-off | Yes with prototype fidelity disclaimer |

**Still blocked for later waves:** confidential production uploads (ADR-010 PoC), commercial schema if P2-OD-022 disputed, live payments (explicitly deferred).

First implementation checkpoint: **P3-A1** per [`P2_5_PHASE_3_READINESS.md`](P2_5_PHASE_3_READINESS.md).