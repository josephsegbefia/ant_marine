# F4-05 — Project management, assignments, tasks, milestones & scheduling

**Status:** Simulated F4-05 **accepted locally** after F4-05-H1 security verification
**Baseline:** F4-04B-H1 `afeb5b6` → F4-05 `c6397aa` → H1 corrections on `main`
**Domain namespace:** `Delivery::` (avoids Zeitwerk collision with `ProjectsController`)

See also: [`F4_05_H1_ACCEPTANCE.md`](F4_05_H1_ACCEPTANCE.md), [`../implementation/F4_05_H1_SPEC.md`](../implementation/F4_05_H1_SPEC.md).

## 1. Design Studio mapping

| Studio | Intent | Implemented |
|---|---|---|
| S07 All jobs | Staff project index | `/staff/projects` |
| S08 Job overview | Project workspace | `/staff/projects/:id` tabs |
| S09 Assign team | Assignments | Team tab + `Delivery::Assign` |
| S15 My tasks | Task list | `/staff/tasks` |
| S06 / S21 Calendar | Schedule agenda | `/staff/schedule_events` |
| C05 My projects | Client list | `/client/projects` |
| C06 Project overview | Client detail | `/client/projects/:id` |
| C07–C10 / S10 | Docs / messages / inspection | Deferred (F4-06 / F4-07) |

## 2. Domain model

| Table / model | Role |
|---|---|
| `projects` / `Project` | Delivery job; UNIQUE `quote_revision_id` + `quote_response_id`; mode `simulated` only |
| `assignments` / `Assignment` | Team membership; `access_scope` ∈ delivery/review/collaborator (P2-OD-042) |
| `project_milestones` / `ProjectMilestone` | Progress denominator; evidence-gated kinds for F4-07 |
| `tasks` / `Task` | Operational tasks |
| `schedule_events` / `ScheduleEvent` | Proposed vs confirmed activities |
| `project_status_events` | Lifecycle history |
| `project_updates` | Client/internal updates |

Reference format: `ANT-PRJ-YYYY-#####` via `Delivery::Reference` + advisory lock.

Commercial immutability: AR validations + trigger `projects_commercial_protect`.

## 3. Explicit initiation

- Service: `Delivery::CreateFromAcceptance`
- Never called from `Commercial::QuoteDecision`
- Requires accepted **simulated** `QuoteResponse`, active simulated portal release, frozen revision, active client org, `projects.create`, confirmation
- One project per acceptance (unique `quote_response_id`)
- Immutable `commercial_snapshot` (read-only agreed terms)
- Production: `available? == false`

## 4. Lifecycle (`Delivery::Transition`)

`planning` → `scheduled` / `in_progress` → `technical_review`* → `report_ready`* → `completed` → `closed`
Also: `on_hold`, `cancelled` (reason required).
`resume` restores prior status from the last `on_hold` event (ADR-F4-05-007).
\* Evidence-gated until F4-07 (actions hidden).

## 5. Authorization

Permissions reused: `projects.view_all`, `projects.view_assigned`, `projects.create`, `projects.manage`, `projects.assign`, `projects.view_org`, `assignments.participate`, `bookings.confirm`.

`ProjectPolicy` + `Delivery::Access`:

- Catalogue `projects.manage` **or** active **delivery** `access_scope` for operational manage.
- `review` / `collaborator` may show when assigned; they do **not** get manage via assignment alone (P2-OD-042).
- Commercial totals only with `quotes.view_all` / `billing.view_all`.
- Production scope excludes `mode: simulated`.

## 6. Simulation rules

- Projects clearly labelled simulated in staff + client UI
- Mode cannot change to live (AR + DB trigger)
- Production rejects creation and simulated access
- No invoices, report downloads, or live notifications

## 7. Downstream boundaries

- **F4-06** documents / uploads — see H1 document access contract
- **F4-07** inspections, technical review evidence, report release
- **F4-08** invoices / payments

## 8. Outstanding production gates

All prior gates remain open, plus: live acceptance policy, live project initiation, restricted DB runtime role, storage/malware/backup acceptance, design sign-off.
