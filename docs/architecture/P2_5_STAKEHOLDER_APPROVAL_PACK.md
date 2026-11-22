# P2.5 — Stakeholder Approval Pack

**Audience:** Product owner / authorized stakeholders  
**Date:** 22 November 2026  
**Instruction:** Confirm, reject, or defer each item; mark `APPROVED` in `docs/DECISIONS.md` only after explicit confirmation.

---

## Design readiness checklist

| Item | Status | Action |
|---|---|---|
| Phase 1 HTML studio (104 screens) | Delivered, sign-off pending | Approve journeys & copy |
| Design handoff G01–G04, P*, C*, S*, M*, A*, X* | Documented | Map to Phase 4 slices |
| Team & Permissions DCR (M07a–j, C15a–j) | **Awaiting approval** | Approve before HTML update |
| P2.4 design gaps (merge inquiry, etc.) | Documented | Optional CRs |
| Implement UI from **ANT Marine** HTML only | Rule affirmed | No external template replacement |

**Permission UI in implementation scope:** Yes — **after** DCR approval (ADR-013).

---

## Pending decisions (approval form)

### ADR-005 — Client portal onboarding

| | |
|---|---|
| **Plain English** | After ANT Marine qualifies work, clients join by **email invitation**, not self-registration. |
| **Recommended** | Invitation-based onboarding |
| **Alternatives** | Self-service signup; hybrid |
| **Business impact** | Stronger tenant control; slower first login |
| **Technical impact** | `invitations` required before portal |
| **Blocks Phase 3?** | **Yes** for client portal features |

---

### ADR-006 — Who may accept a quotation?

| | |
|---|---|
| **Plain English** | Only people authorised to commit the client company can accept a quote. |
| **Recommended** | Organisation Owner and Client Manager by default; other members only if granted |
| **Alternatives** | Any member; staff-on-behalf |
| **Business impact** | Contractual authority |
| **Technical impact** | `quotes.accept` + `quote_responses.membership_id` |
| **Blocks Phase 3?** | **Yes** before quote acceptance feature |

---

### ADR-008 — Payments

| | |
|---|---|
| **Plain English** | MVP records invoices and **manual** payment entries; no card processing. |
| **Recommended** | Records only |
| **Alternatives** | Integrated PSP |
| **Blocks Phase 3?** | No for schema; Yes for live payments |

---

### ADR-010 — Confidential file storage

| | |
|---|---|
| **Plain English** | Real client confidential files cannot go to production until encryption approach is **proven** in a bounded PoC. |
| **Recommended** | Complete P3-STORAGE-01 before confidential go-live |
| **Blocks Phase 3?** | **Yes** for confidential production uploads |

---

### ADR-012 — Authorization implementation

| | |
|---|---|
| **Recommended** | Pundit + central `EffectivePermissions` |
| **Blocks Phase 3?** | **Yes** before protected routes |

---

### ADR-013 — Team & Permissions UI

| | |
|---|---|
| **Recommended** | Approve DCR; implement F4-04b |
| **Blocks Phase 3?** | No for auth foundation; **Yes** for permission UI |

---

### ADR-014 — Public inquiries without account

| | |
|---|---|
| **Recommended** | Allow P19–P22 without login |
| **Blocks Phase 3?** | Yes before public funnel |

---

### ADR-015 — Ownership safeguards

| | |
|---|---|
| **Recommended** | Transfer flow; last owner/super admin protection |
| **Blocks Phase 3?** | Yes before team management |

---

### ADR-016 — Custom roles

| | |
|---|---|
| **Recommended** | Defer; fixed 13 roles + overrides |
| **Blocks Phase 3?** | No |

---

### ADR-017 — Authentication stack

| | |
|---|---|
| **Recommended** | Rails 8 authentication generator |
| **Blocks Phase 3?** | **Yes** at slice P3-A1 |

---

### P2-OD-040 — Session storage

| | |
|---|---|
| **Recommended** | Encrypted cookie + security_version |
| **Blocks Phase 3?** | Yes at auth slice |

---

### P2-OD-041 — Audit events shape

| | |
|---|---|
| **Recommended** | Single `audit_events` STI table |
| **Blocks Phase 3?** | Yes at audit migration |

---

### P2-OD-042 — Assignment access scope

| | |
|---|---|
| **Recommended** | Column on `assignments` |
| **Blocks Phase 3?** | Yes before reviewer policies |

---

### P2-OD-043 / P2-OD-004 — Quote revision to project count

| | |
|---|---|
| **Plain English** | When a client accepts a quote, how many projects can that acceptance create? |
| **Recommended (PROPOSED — not approved)** | **One project per accepted revision** (unique FK); multi-phase work = new quote |
| **Alternatives** | Multiple projects per acceptance |
| **Business impact** | Simpler client portal; may need change orders later |
| **Technical impact** | UNIQUE `projects.quote_revision_id` |
| **Blocks Phase 3?** | Yes before project creation migration |

---

### P2-OD-021 — (same thread as ADR-006)

Align quote acceptance actor with ADR-006 approval.

---

### Phase 1 design sign-off

| | |
|---|---|
| **Required for** | Production UI fidelity claims |
| **Blocks Phase 3?** | No for shells; **Yes** for customer-facing feature complete |

---

## Risk register (summary)

| ID | Severity | Issue | Resolution | Owner |
|---|---|---|---|---|
| R1 | **Critical** | No encryption PoC | P3-STORAGE-01 | Technical lead |
| R2 | **Must before P3 business** | ADRs 005,006,012,017 open | Stakeholder meeting | Product owner |
| R3 | **Must before confidential prod** | ADR-010 | PoC evidence | Infra |
| R4 | **Must before permission UI** | DCR approval | Design review | Product owner |
| R5 | Later slice | Vessels MVP optional | P2-OD-024 | Product |
| R6 | Later slice | Email provider | ADR-009 | Ops |
| R7 | Later slice | 1:N quote-project if rejected | Schema change | Architecture |

---

## Sign-off record (to be completed by stakeholders)

| Area | Name | Date | Decision |
|---|---|---|---|
| Architecture package P2.1–P2.4 | | | Pending |
| Stakeholder pack (this doc) | | | Pending |
| Phase 2 exit → Phase 3 start | | | **Pending** |
| Phase 1 design HTML | | | Pending |

---

## After approval

1. Update `DECISIONS.md` status rows.  
2. Update `PHASE_PROGRESS.md` Phase 2 gate.  
3. Begin Phase 3 Wave A per [`P2_5_PHASE_3_READINESS.md`](P2_5_PHASE_3_READINESS.md).