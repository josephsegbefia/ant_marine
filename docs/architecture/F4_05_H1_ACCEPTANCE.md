# F4-05-H1 — Project management acceptance evidence

**Status:** Local acceptance **GO** for simulated F4-05 closure (security hardening + evidence). Production / live initiation remain **blocked**.

**Starting SHA:** `86a52e3` (includes F4-05 `c6397aa`)
**Corrections:** access_scope enforcement (P2-OD-042), resume-from-hold, reason-required lifecycle UI, commercial SQL protect trigger, high-risk automated tests, system + screenshot evidence.

## Implementation coverage audit

| Area | Status |
|---|---|
| Models / tables (7) | Complete |
| `Delivery::CreateFromAcceptance` | Complete; uniqueness + rollback |
| Lifecycle `Delivery::Transition` | Complete; evidence gates; resume restores prior |
| Assignments + access_scope | Complete **and enforced** in policy/services |
| Tasks / milestones / schedule | Complete; conflict detection; gated milestone kinds |
| Staff UI S07/S08/S09/S15/S06 | Complete (agenda schedule, not calendar grid) |
| Client C05/C06 | Complete; org isolation |
| Project updates visibility | Complete (client vs internal) |
| Live initiation / docs / invoices | Out of scope (deferred) |

## Authorization matrix (P2-OD-042)

| Actor | Show | Manage delivery | Assign | Transition | Commercial totals |
|---|---|---|---|---|---|
| Ops / coordinator (`projects.manage`) | Y | Y | if `projects.assign` | Y | if quotes/billing view |
| Delivery-scope surveyor | Y | Y (ops) | N | N | N |
| Review-scope technical reviewer | Y | **N** | N | N | N |
| Collaborator scope | Y | **N** | N | N | N |
| Unassigned surveyor | N | N | N | N | N |
| Finance without project perms | N | N | N | N | N |
| Client owning org | Y | N | N | N | N (client terms only) |
| Other client org | N (404 via scope) | N | N | N | N |

Assignment revocation: active assignment removed → `policy_scope` 404 on project/task routes; historical assignment rows retained.

## Commercial snapshot

- AR validation blocks mutation of commercial FKs + `commercial_snapshot` + mode.
- DB trigger `projects_commercial_protect` rejects SQL updates to those columns (no app-accessible bypass GUC).

## Progress denominator

`Project#progress_summary`: count milestones with `counts_toward_progress` and status ≠ `cancelled`. Evidence-gated kinds (`technical_review`, `report_release`) are seeded with `counts_toward_progress: false` and cannot be completed until F4-07.

## F4-06 document access contract

Documents (not implemented here) must honour:

1. Project ownership (`operating_organization` / `client_organization`).
2. Client org scope for portal downloads of **released** versions only.
3. Staff access via `projects.view_all` **or** active assignment; `access_scope`:
   - `delivery` — upload/request operational docs per catalogue.
   - `review` — review artefacts only; no project admin / unrestricted uploads.
   - `collaborator` — grant-limited only.
4. Quarantine + malware scan before any release (P3 storage).
5. Exact-version release separate from draft; audit every access.
6. Assignment revocation must immediately deny document routes for that user.

## Outstanding production gates

Live acceptance policy; live project initiation; restricted DB runtime role; storage/malware/backup acceptance; design studio sign-off; Render/env secrets; no simulation promotion to live.
