# P2.5 — Requirements Traceability Matrix

**Version:** 1.0 — 22 November 2026  
**Sources:** Master spec §2, questionnaire (via design handoff), P2.1–P2.4

Legend: **C** = covered in architecture; **P** = partial / proposed default; **G** = gap / deferred

| Requirement area | Spec / questionnaire | Architecture | Phase 3/4 slice (planned) | Status |
|---|---|---|---|---|
| Public maritime website | §2.1, P01–P18 | P2.1 public context, CMS tables | F3-DB-10, F4 public CMS | C |
| Service inquiries (no account) | §2.2, P19–P22 | `service_inquiries`, ADR-014 proposed | F3-DB-06, F4-03 | P |
| Contact / quote funnels | P18, P19–P22 | P2-OD-002 merge contact→inquiry | F4-03 | P |
| Client orgs & users | §2.3, C01–C16 | Membership model, ADR-005 | F3-DB-01–03 | P |
| Staff operations | §2.4, S01–S21 | Staff portal, assignments | F4-03, F4-04 | C |
| RBAC 13 roles | §3.1 | ROLE_PERMISSION_SPEC, seeds | F3-DB-02, F3-DB-05 | C (approval pending) |
| Team & Permissions UI | §3.1, DCR M07/C15 | DCR awaiting approval | F4-04b | G until DCR |
| Booking / scheduling | §2.2, P23, S06 | `booking_*`, P2.4 workflows | F3-DB-06, F4-03 | C |
| Quotations & revisions | §2.2, C03–C04 | Immutable revisions, P2.4 | F3-DB-06, F4-03 | C |
| Quote acceptance authority | §2.2 OPEN | ADR-006 proposed | Policy F4-03 | P |
| Quote → project | P2-OD-043 | UNIQUE FK proposed | F3-DB-07 | P |
| Projects & assignments | §2.4, C05–C08 | P2.3, tiered access | F3-DB-07, F4-04 | C |
| Vessels | Questionnaire, C vessels | P2-OD-024 follow-on | F4 vessel slice | G optional MVP |
| Inspections / checklists | S08–S09 | inspections tables | F4 delivery | C |
| Confidential documents | §2.6 | classification + `access_confidential` | F3-DB-08, policies | P |
| Malware scan / quarantine | §2.6 | scan_status workflow | Job slice + ADR-010 | P |
| Report review / release | §2.4, C11–C12 | SoD, separate release | F3-DB-08, F4 report | C |
| Billing / invoices | §2.4, C14 | MVP records only ADR-008 | F3-DB-09, F4 finance | P |
| Live payments / cards | Questionnaire commercial | Not in MVP | Future ADR | G |
| Notifications / email | §2.7 | P2.4 events; ADR-009 OPEN | F3 mail config | P |
| CMS / content | §2.5, M01–M07 | Separate article/case/training | F3-DB-10, F4 admin | C |
| Analytics | M12, questionnaire | `resource_downloads`, staff analytics perms | F4 admin | P |
| Audit history | §2.6, M13 | audit_events STI proposed | F3-DB-04 | P |
| Remote monitoring dashboard | Master §6 exclusion | Service page only | None | G (explicit exclusion) |
| Multi-org client groups | Enterprise | P2-OD-030 defer | Later | G |
| Encryption at rest | §2.6, ADR-010 | PoC required | P2.5 storage gate | G until PoC |
| Hosting / Coolify | ADR-003 | Documented | Phase 5 | C design |

---

## Gaps requiring stakeholder acknowledgement

1. **Team & Permissions screens** — design DCR not approved; ADR-013 blocks UI implementation.  
2. **Storage encryption** — no verified PoC; confidential production files blocked.  
3. **Payment integration** — records-only MVP.  
4. **Vessel registry** — optional Phase 4.  
5. **Remote monitoring product** — out of scope.  
6. **Inquiry merge UI** — DCR-P2.4-001 documented, not in HTML studio.

---

## Journey → screen → data trace (summary)

| Journey | Screens | Primary tables |
|---|---|---|
| Public quote | P19–P22 | service_inquiries |
| Staff qualify | S01–S03 | service_inquiries, organizations |
| Quote lifecycle | S04–S05, C04 | quotes, quote_revisions, quote_responses |
| Project delivery | S07–S14, C05–C12 | projects, assignments, reports |
| Permissions | M07a–j (DCR) | memberships, permission_overrides |