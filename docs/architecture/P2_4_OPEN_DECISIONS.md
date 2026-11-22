# P2.4 — Open Decisions & Design Gaps

**Version:** 1.0 — 22 November 2026  
**Rule:** PROPOSED until stakeholder marks ADR APPROVED.

---

## 1. New workflow decisions (PROPOSED)

| ID | Question | Recommendation | Reasoning |
|---|---|---|---|
| P2-OD-043 | One accepted `quote_revision` → multiple `projects`? | **PROPOSED default (not approved):** 1:1 — UNIQUE `projects.quote_revision_id`; multi-phase via new quote/change order | Prevents duplicate jobs; stakeholder may require 1:N |
| P2-OD-044 | Quote internal review before send | **Optional checklist** — no extra DB state; coordinator marks ready in notes; optional second staff user audit flag in metadata | Avoid scope creep; S05 covers send |
| P2-OD-045 | Surveyor assignment acceptance | **Informational only** — `assignments.acknowledged_at` optional; no blocking state | Field teams may not use portal immediately |
| P2-OD-046 | Report amendment after client release | **New version + new release**; client sees latest release pointer | Immutable history |
| P2-OD-047 | Invoice internal approval gate | **`draft` → `issued`** single approver for MVP (finance); second approver deferred | ADR-008 |
| P2-OD-048 | Project `suspended` state | **Add** to internal_status enum in Phase 3 | Handoff lacks dedicated screen — use S07 status control |

---

## 2. Carried from P2.1 / ADRs (unchanged status)

| Ref | Topic | Status |
|---|---|---|
| ADR-005 | Invite-based client onboarding | PROPOSED |
| ADR-006 | Quote accept actor | PROPOSED |
| ADR-008 | Payments records-only MVP | OPEN / records default |
| ADR-010 | Confidential files production | OPEN / blocker |
| ADR-012–017 | Auth/RBAC stack | PROPOSED |
| P2-OD-040–042 | Sessions, audit STI, access_scope | PROPOSED |

---

## 3. P2.3 schema consistency (Task 13)

| Check | Result | Amendment |
|---|---|---|
| A. role_key + role_permissions | Sufficient for 13 roles | None |
| B. Sessions + suspension | `permission_epoch` + `security_version` | None |
| C. Audit STI | Adequate for workflow transitions | Metadata `transition_key` required |
| D. quote_revision_id unique | **PROPOSED** pending P2-OD-043 approval (aligns P2.3 schema if approved) | Do not treat as locked until stakeholder signs off |
| E. Overrides per membership | Confirmed | None |
| F. Finance without assignment | `billing.view_all` | Confirmed |

**Optional P2.3 amendment (not applied):** Add `assignments.acknowledged_at` column — note in Phase 3 migration slice 07.

---

## 4. Design gaps / change requests (HTML unchanged)

| Gap | Screens | Proposed CR |
|---|---|---|
| Inquiry duplicate merge | S02 | **DCR-P2.4-001** — merge UI with target inquiry search |
| Quote internal ready-to-send | S05 | Optional sub-state badge; copy only |
| Surveyor assignment ack | S07 | Optional banner “New assignment” |
| Invoice void confirmation | S15, C14 | Step-up reuse M07j pattern |
| Project suspended label | C05, S07 | Add client-safe label mapping |
| Team & Permissions | M07/C15 | Existing DCR — awaiting approval |

Do **not** edit `ANT_Marine_Design_Studio_Phase_1.html` in P2.4.

Record CRs in `docs/design/` when stakeholder approves documentation pass.

---

## 5. Stakeholder actions

1. Approve P2-OD-043 (1:1 quote-project) or choose multi-project model before Phase 4 project slice.
2. Approve design gaps CR list or defer.
3. Promote ADRs when ready — workflows assume proposed defaults only.