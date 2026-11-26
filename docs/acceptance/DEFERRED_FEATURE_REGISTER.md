# Deferred feature register — F4-09A

All items below are **not implemented in this slice**. Do not treat deferral as deletion of the original requirement.

| Feature | Original source | Current implementation | Deferral reason | Dependency | Security implications | Business importance | Complexity | Recommended release | Acceptance criteria | MVP class |
|---|---|---|---|---|---|---|---|---|---|---|
| Client–staff messaging | Questionnaire; C10; S23 | None | Scope boundary through F4-08 | Authz, audit, retention | Cross-org leakage risk if mis-scoped | High for ops | High | F4-09B decision | Org-scoped threads; no cross-client leak; audit | **Mandatory MVP gap** (PO confirm) |
| Client notification center | C17; questionnaire | Staff `staff_notifications` only | Explicit F4-06/F4-07 ADRs | Messaging or event bus | Must honour revocation | High | Medium | F4-09B decision | Read/unread; no leak after revoke | **Mandatory MVP gap** (PO confirm) |
| Document previews | C09; ADR-F4-06-005 | Download + metadata only | XSS/malware surface | Clean scan; content-type allowlist | High if HTML/SVG preview | Medium | Medium | Optional post-MVP | Safe preview for allowlisted types only | Optional |
| Document category administration | M09; ADR-F4-06-006 | Seeded `Document::CATEGORIES` | Admin UX deferred | Permissions | Misconfig could over-expose | Medium | Low–Med | F4-09B optional | CRUD with audit; no silent ACL change | Optional |
| Interactive calendar | S06/S21; questionnaire | Schedule event agenda/list | Delivery slice chose list | Assignments | Assignment visibility | Medium | High | Post-MVP | Conflict checks retained | Optional |
| External calendar integration | Questionnaire | None | No provider approved | OAuth, secrets | Token custody | Low–Med | High | Post-launch | Opt-in; revoke works | Optional |
| Offline inspection workflows | Questionnaire / R08 intent | Online checklist only | Device/sync architecture absent | Storage, conflict | Stale evidence risk | Medium | Very high | Post-launch | Sync integrity; no silent overwrite | Optional |
| Electronic signatures | Questionnaire | None | Legal/policy undefined | Identity proofing | Non-repudiation claims | Medium–High | High | Policy-first | Approved e-sign standard | Policy-dependent |
| Commercial amendments | Questionnaire | New quote version / revise patterns | Live amendment policy open | History protection | Must not mutate frozen accepted revision improperly | High | High | After live commercial | Append-only amendments; audit | Production-gated |
| Cancellation workflows | Questionnaire / project cancel exists staff-side | Project cancel; quote withdraw; limited client cancel UX | Client-facing cancel incomplete | Commercial policy | Financial side-effects | High | Medium | F4-09B / live policy | Clear refund/invoice rules | Partial / policy |
| Retention and legal holds | M14; questionnaire | None | Policy + storage ADR open | ADR-010 | Premature deletion risk | High | High | Production readiness | Hold blocks delete; audit | Production-gated |
| Controlled document deletion | Questionnaire | Restrictive deletes; history triggers | Legal hold absent | Retention policy | Bypass risk | High | Medium | With retention | Soft-delete + audit; no history rewrite | Production-gated |
| Online payment collection | Questionnaire; ADR-008 | Manual `PaymentRecord` simulated | No gateway approved | PCI / provider | Card data forbidden in-app | High commercially | High | Post-MVP | Provider webhook integrity; no card storage | Optional / gated |
| Accounting integration | Questionnaire | None | No ledger vendor | Chart of accounts | Financial misstatement | Medium | High | Post-launch | Idempotent export | Optional |
| Foreign-exchange accounting | Questionnaire | Multi-currency display; no conversion | Explicit F4-08 rule | FX rates source | Invented FX forbidden | Medium | Medium | Post-launch | Auditable rate source | Optional |
| Advanced payment allocation | Questionnaire | Per-invoice payments only | MVP simplicity | Invoices | Allocation disputes | Medium | Medium | Post-MVP | Allocate across invoices safely | Optional |
| Financial correction procedures | Questionnaire; F4-08 | Void + reversal only | Correction policy open | Finance roles | Must not rewrite issued history | High | Medium | Live finance policy | Correction docs; audit; no silent edit | Production-gated |

## Distinction

- **Mandatory MVP gaps (pending PO):** client messaging, client notification center — original portal expectations; currently absent by ADR, not by accident.
- **Optional enhancements:** preview, calendar polish, vessels, online pay, accounting/FX, offline inspections.
- **Production-gated:** retention/holds, live amendments, live financial corrections, e-sign policy.
