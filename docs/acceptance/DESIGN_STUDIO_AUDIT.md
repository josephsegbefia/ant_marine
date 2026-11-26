# Design Studio audit — F4-09A

**Source:** `design/PHASE_1_DESIGN_HANDOFF.md` (104 screen entries) + `design/ANT_Marine_Design_Studio_Phase_1.html`  
**Machine inventory:** `docs/acceptance/design_studio_inventory.csv`  
**Audit date:** 2026-11-26  
**Baseline commit:** `64f92f8` (+ F4-09A local work)

## Classification counts (evidence from CSV inventory)

| Classification | Count |
|---|---|
| COMPLETE | 68 |
| PARTIALLY IMPLEMENTED | 18 |
| NOT IMPLEMENTED | 9 |
| EXPLICITLY DEFERRED | 5 |
| PRODUCTION-GATED | 1 |
| NOT APPLICABLE | 3 |
| **Total screens** | **104** |

Counts are derived from the `functional_status` column in `design_studio_inventory.csv` (one row per handoff screen ID).

## Summary by group

| Group | Complete | Partial | Missing/Deferred/Other |
|---|---|---|---|
| Design guide (G) | 0 | 1 | 3 N/A |
| Public website (P) | 20 | 2 | 1 deferred (P23) + privacy partial |
| Access (A) | 5 | 0 | 1 deferred (A04 OTP) |
| Client portal (C) | 11 | 3 | 6 missing/deferred (messaging, vessels, help, preview, notifications) |
| Staff workspace (S) | 17 | 4 | 2 missing (S18 vessels, S23 conversations) |
| Company settings (M) | 6 | 6 | 2 deferred/missing (M09, M14) + M10 gated |
| Mobile (R) | 8 | 0 | 0 |
| Special states (X) | 4 | 1 | 0 |

## Critical journey coverage

| Journey | Screens | Status |
|---|---|---|
| Public inquiry | P01–P08, P19–P22 | Implemented (simulated enquiry) |
| Client quotation | C01–C04 | Implemented (simulated release/accept) |
| Client project/docs/reports/bills | C05–C08, C11–C14 | Implemented; C09/C10 deferred/missing |
| Staff intake | S01–S05 | Implemented |
| Staff delivery | S07–S15 | Implemented; calendar partial |
| Finance | S19–S20, C13–C14 | Implemented (simulated) |
| Admin CMS | M02–M06, M08 | Implemented; publish PO-gated |

## Fidelity notes

- Unrelated working-tree WIP (clients revamp, project overview, public enquiry CSS, nav icons) was **not** absorbed into this audit as “complete Design Studio fidelity.”
- Design Studio HTML was **not** modified.
- Placeholder or unpublished marketing content remains a PO editorial gate — not invented.

## Recommended next actions for F4-09B

1. Decide MVP treatment of **C10/C17/S23** (client messaging & notifications).
2. Decide **C09** document preview vs download-only.
3. Decide **P23** booking request vs existing schedule events.
4. Vessel register (**C18/C19/S18**) as post-MVP unless PO elevates.
5. Formal Design Studio sign-off against implemented routes.
