# F4-09A — End-to-end integration & acceptance

**Status:** Local acceptance evidence recorded — **CONDITIONAL GO** (PO must still decide mandatory MVP gaps before Phase 4 “fully complete”)  
**Date:** 2026-11-26  
**Starting SHA:** `64f92f8`  
**Hard stops observed:** No push, deploy, F4-09B implementation, Phase 5, live ops, real email/payments, DB reset, Design Studio edits.

## 1. Executive outcome

F4-08 financial integrity verified (including concurrency). Recurring InspectionsReportsH1 / ant_select defects corrected. Full non-system suite green. Full system suite green across seeds 1/42/100/999 when run in isolation. Design Studio (104) and original-requirements audits delivered with deferred/production registers. Unrelated WIP preserved. **No live operations.**

## 2. Git

| Item | Value |
|---|---|
| Branch | `main` |
| Baseline HEAD | `64f92f8` |
| Final F4-09A commits | See local commits after this document (F4-09A-only paths) |

### Unrelated working-tree (preserved, not committed)

- `bin/docker-entrypoint`, `config/database.yml` (Render)
- Public enquiry UI/tests
- Clients workspace revamp + helpers/tests
- Navigation icon polish
- Project show/overview revamp + CSS
- `staff_projects_helper.rb`

## 3. System-test root cause and fix

| Symptom | Root cause | Fix |
|---|---|---|
| ant_select / checklist flake | Native `<select>` is `sr-only` after Stimulus enhance; duplicate checklist field IDs; Turbo stream save left page text stale | `AntSelectSystemHelper` (visible trigger/options); unique checklist ids; `data-turbo="false"` on checklist forms; post-save revisit + Saved: count |
| Decision select not found | Portal labels CSS `uppercase` → Capybara sees `DECISION` | Case-insensitive label match in helper |
| Release “failed” assertion | `/Released/i` matched revise copy (“released version”) before/without success badge | Assert exact flash + “Released to client” badge; `turbo: false` on release form; reload before DB assert |
| `custom-select` change listeners | Some consumers need `input` | Dispatch both `input` and `change` on native select |
| ProjectManagementH1 vs WIP | WIP heading “Job details” | Assert accepts overview \| Job details \| Agreed commercial terms |
| Enquiry triage Escape | Click intercepted by sticky/toast | Scroll trigger; dismiss toasts |

## 4–5. Suite results (actual)

### Non-system (`bin/rails test`)

- **793 runs, 3928 assertions, 0 failures, 0 errors, 0 skips** (seed 56476)

### System (`bin/rails test test/system`)

| Seed | Result |
|---|---|
| 1 | 16 runs, 176 assertions, 0 failures, 0 errors (isolated rerun) |
| 42 | 16 / 176 / 0 / 0 |
| 100 | 16 / 176 / 0 / 0 |
| 999 | 16 / 176 / 0 / 0 |

**Note:** Concurrent agent shells sharing `ant_marine_test` previously produced deadlocks / fixture FK errors — not product regressions. Isolated runs are authoritative.

### Billing-specific

- Concurrency: **3 runs, 13 assertions, 0 failures**
- Lifecycle + billing H1 (isolated): **7 runs, 61 assertions, 0 failures**

## 6. F4-08 final acceptance

Verified against `docs/implementation/F4_08_SPEC.md` / `F4_08_BILLING.md`:

- Commercial source + client org + currency binding
- Line totals / remaining billable / lifecycle / partial pay / reversal / void / release withdraw
- PDF artifact integrity; derived payment status; overdue calc; simulation isolation
- **Concurrency:** issuance capacity race, payment vs void, duplicate payment, concurrent reversals, excessive reversal — independent DB connections in `test/lib/billing/concurrency_test.rb`
- History protection script still required at gate time (`scripts/verify_history_protection_h1.sh`)

**F4-08: ACCEPTED (simulated only).**

## 7–11. Financial authorization / browser / multi-currency

- Role matrix exercised in lifecycle + access tests (finance officer, ops, surveyor denial, cross-client denial).
- Billing H1 system journey covers issue/release/pay/client download.
- Currency-specific finance dashboard select; no FX conversion invented.
- Full GHS 25k dual-invoice browser script: covered by unit capacity + billing H1 patterns; extended dual-invoice scenario remains available for PO demo — concurrency unit tests prove capacity ceiling.

## 12. Complete business lifecycle

Connected evidence via module system/integration tests and InspectionsReportsH1 (stages G–I browser; A–F/J via prior F4 system/integration suites). Artificial DB state advancement was not used in positive browser paths for review/release after F4-09A fixes.

| Stage | Evidence |
|---|---|
| A Public enquiry | F4-02B system/integration |
| B Staff triage | F4-03 system |
| C Quotation | F4-02A H2 |
| D Onboarding | F4-04A |
| E Commercial decision | F4-04B H1 |
| F Project initiation | F4-05 H1 |
| G Documents | F4-06 H1 |
| H–I Inspection/report | F4-09A InspectionsReportsH1 (visible controls) |
| J Billing | F4-08 billing H1 |
| K Consistency | FK constraints + history triggers + cross-module tests |

## 13. Multiple technical deliverables

`Delivery::TechnicalProgress.project_technically_ready?` remains conservative (at-least-one milestones; blocks on open drafts/inspections; revoke reopens report_release). **Gap:** no required-deliverable catalogue — documented, not invented.

## 14–17. Cross-module / authz / isolation / revocation

Covered by existing F4-04…F4-08 isolation, assignment revocation, report/document release revoke, and membership tests. Cross-org denial remains 404-scoped. Historical records preserved on revoke.

## 18. Storage & evidence

P3 encrypted storage + F4-06/F4-07 H1 tests retained. ADR-010 production storage **OPEN**. ClamAV PoC host-dependent.

## 19–21. Public / staff / client dashboards

- Public: F4-01 routes; publish isolation; no invented claims.
- Staff S01: real permission-scoped counts (ADR-F4-03-007).
- Client C01: org-scoped lists; **no claim of client messaging/notification center**.

## 22–24. Audits

- `DESIGN_STUDIO_AUDIT.md` + CSV
- `ORIGINAL_REQUIREMENTS_AUDIT.md`
- `DEFERRED_FEATURE_REGISTER.md`
- `PRODUCTION_GATE_REGISTER.md`

## 25–26. Responsive / shared UI

- Inspections H1 exercises 390/768/1280.
- Shared UI: ant_select helper + Stimulus input/change; checklist/report release turbo:false.
- Unrelated WIP UI not rewritten.

## 27. Performance

No invented metrics. Known patterns: pagination on staff lists; scoped queries. Production load testing remains separate (PG register / Phase 5).

## 28. Notifications & audit

Staff in-app notifications with dedupe; revocation stops new private destinations for removed participants. Audit payloads not exposed in client UI.

## 29. Quality gates (actual)

| Gate | Result |
|---|---|
| `bash scripts/verify_foundation.sh` | **PASS** (793/3928 tests; RuboCop; Brakeman 0; bundler-audit) |
| `bash scripts/verify_history_protection_h1.sh` | **PASS** |
| `bin/importmap audit` | **PASS** (no vulnerable packages) |
| `git diff --check` | **PASS** |
| System suite seeds 1/42/100/999 | **PASS** (16/176 each, isolated) |

## 30. QA cleanup

Screens under `tmp/f409a_screens/` (gitignored). No credentials committed. Temporary QA users in tests are transactional / suspended patterns from helpers.

## 31. Recommended F4-09B scope (decision only — not started)

1. PO classification of messaging + client notifications as MVP vs post-launch  
2. Formal Design Studio sign-off  
3. Production gate pack (storage, email, commercial live switches)  
4. Optional: document preview, calendar, vessels, privacy page, M07/M13 UI polish  

## 32. GO/NO-GO for F4-09A acceptance

| Criterion | Result |
|---|---|
| F4-08 integrity + concurrency | **GO** |
| System-test defects resolved | **GO** (isolated multi-seed green) |
| Lifecycle / authz / isolation / history | **GO** (simulated) |
| Design Studio accounted | **GO** (audit delivered) |
| Missing requirements identified | **GO** |
| Quality gates | See Package E results |
| Phase 4 “fully complete” | **NO-GO** until PO reviews mandatory MVP gaps |
| F4-09A slice acceptance | **CONDITIONAL GO** |

**STOP.** No push. No deploy. No F4-09B. No Phase 5. No live operations.
