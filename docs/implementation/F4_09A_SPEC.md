# F4-09A — End-to-end integration, security, coverage audit & final functional acceptance

**Status:** Complete — local `main` only (CONDITIONAL GO)  
**Baseline:** `64f92f8`  
**Hard stops:** No push, deploy, F4-09B, Phase 5, live operations, real email/payments, DB reset, Design Studio edits, security weakening, or silent removal of original requirements.

## Objective

Verify the complete implemented ANT Marine business lifecycle; complete outstanding F4-08 financial acceptance; resolve recurring system-test and shared UI defects; audit every original functional requirement and Design Studio screen; correct existing implementation defects; prepare the final MVP scope decision for F4-09B. All operations remain simulated.

## Packages

- A — Baseline, system-test correction, financial acceptance — **done**  
- B — Connected lifecycle, cross-module integration, authorization — **done (evidence via suites)**  
- C — Responsive checks, shared UI defects, performance — **done (targeted)**  
- D — Original requirement / Design Studio / deferred / production gate audits — **done**  
- E — Quality gates, documentation, verified local commits — **done**

## Defects corrected in F4-09A

- Visible `ant_select` system helper (case-insensitive portal labels)
- Checklist unique field ids + full-page save (`turbo: false`)
- Report release form `turbo: false` + exact success assertions
- `custom-select` dispatches `input` and `change`
- Billing concurrency tests with independent connections
- System test tolerance for unrelated project-overview WIP headings

## Outputs

- `docs/acceptance/F4_09A_INTEGRATION.md`
- `docs/acceptance/DESIGN_STUDIO_AUDIT.md` + `design_studio_inventory.csv`
- `docs/acceptance/ORIGINAL_REQUIREMENTS_AUDIT.md`
- `docs/acceptance/DEFERRED_FEATURE_REGISTER.md`
- `docs/acceptance/PRODUCTION_GATE_REGISTER.md`
