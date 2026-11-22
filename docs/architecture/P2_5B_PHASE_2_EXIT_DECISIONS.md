# P2.5B — Phase 2 Exit Preparation

**Date:** 22 November 2026  
**Purpose:** Final unresolved decisions for product-owner approval before Phase 3 implementation (documentation only).

**P2.5A verification (Task 1):** Commit `08a5423` accurately records **only** the enumerated approvals (ADR-005, 006, 008, 010 objective+PoC, 012–017, P2-OD-004/043, DCR). No broadening beyond that scope. Files in that commit match [`P2_5A_STAKEHOLDER_DECISION_RECORD.md`](P2_5A_STAKEHOLDER_DECISION_RECORD.md).

---

## 1. Decisions awaiting final approval

### Priority — closes Phase 2 technical trio (P2-OD-040–042)

| ID | Question | P2.5B recommended default | Status |
|---|---|---|---|
| **P2-OD-040** | How are authenticated sessions stored and revoked? | **Database-backed revocable sessions** (see §2) | **PROPOSED** |
| **P2-OD-041** | How are audit events modelled? | **`event_type` + JSONB `metadata`** (see §2) | **PROPOSED** |
| **P2-OD-042** | How is reviewer/collaborator scope enforced on assignments? | **Explicit `access_scope` + CHECK** (see §2) | **PROPOSED** |

### Secondary — does not block Phase 2 exit or P3-A1

| ID | Question | Recommended default | Class |
|---|---|---|---|
| P2-OD-011 | Primary keys | bigint + `reference_number` | D |
| P2-OD-001–003, 005, 007–010 | Modelling defaults per P2.1 §2 | Adopt P2.1 recommendations | B/D |
| P2-OD-022 | Booking modelling | Inquiry date + `booking_requests` | B |
| P2-OD-024–025, 029–030 | Feature timing | P2.1 proposed defaults | D |
| P2-OD-026 | Email provider | Configure in Phase 3 with stub | D |
| P2-OD-027 | Encryption technique | P3-STORAGE-01 outcome | **C** |
| P2-OD-028 | Retention rules | Counsel + `document_rules` | D |
| P2-OD-044–048 | Workflow refinements | P2.4 proposed | D |
| ADR-007 | Report approver roles | Confirm with SoD matrix | B |
| ADR-009 | Mail provider | Defer with SMTP stub | D |
| ADR-004 | Object store host | Hetzner candidate + PoC | C (confidential path) |

---

## 2. Technical proposals (Tasks 2) — detailed evaluation

### P2-OD-040 — Session storage

**Current documented wording (P2.1 §7):** “Encrypted cookie session + `users.security_version`; optional `sessions` table only if compliance requires inventory.”

**Alternative under evaluation (P2.5B):** **Database-backed, revocable sessions** with security-version invalidation.

| Criterion | Cookie-only | **DB sessions (recommended)** |
|---|---|---|
| Revoke all devices | Bump `users.security_version` | Bump version **and** invalidate `sessions` rows |
| Suspend user mid-session | Next request via epoch (membership) | Same + delete/revoke session row |
| Audit “who is logged in” | Weak | Query active sessions |
| Ops complexity | Lower | Moderate |
| Rails 8 auth fit | Default cookie store | Custom `Session` model + cookie holds `session_id` |

**Recommended design (PROPOSED):**

- Table `sessions`: `id`, `user_id`, `token_digest`, `ip_address`, `user_agent`, `security_version_at_issue`, `membership_context` jsonb nullable, `revoked_at`, `expires_at`, timestamps.
- Cookie stores opaque session id (signed/encrypted).
- On login: create session row; store `security_version_at_issue = users.security_version`.
- On request: reject if `users.security_version` changed or `revoked_at` set.
- Permission changes: still use `memberships.permission_epoch` (no full logout).

**Schema implications:** Migration `sessions` in P3-A1 or P3-A3; index `(user_id, revoked_at)`; partial index active sessions.

**Acceptance tests (Phase 3):**

- Login creates session row.
- `security_version` bump invalidates session on next request.
- Admin revoke session → 401.
- Suspended user cannot create session.

**Blocks P3-A1?** **No for local scaffolding**; **yes before production auth** — approve P2-OD-040 before production deploy.

---

### P2-OD-041 — Audit events

**Current documented wording (P2.1 §7 / P2.3):** `audit_events` **STI** with `type` column.

**Alternative under evaluation (P2.5B):** Single table with **`event_type` (string)** + **`metadata` (JSONB)**; no Rails STI.

| Criterion | STI subclasses | **event_type + JSONB (recommended)** |
|---|---|---|
| Query all security events | One table | One table |
| Schema migrations per event | New class/columns | Add constants + JSON schema in docs |
| Policy tests | Familiar Rails pattern | Explicit `event_type` switch in readers |
| M13 / permission history | STI types | Filter `event_type IN (...)` |
| Validation | Per subclass | JSON schema or service-layer validation |

**STI advantages:** Rails conventions, typed Ruby objects. **Disadvantages:** Migration churn, wider rows, STI load-order coupling.

**Recommended design (PROPOSED):**

```text
audit_events:
  id, organization_id nullable, actor_membership_id nullable,
  event_type varchar NOT NULL,   -- e.g. permission.changed, quote.sent
  subject_type, subject_id polymorphic nullable,
  metadata jsonb NOT NULL DEFAULT '{}',
  occurred_at timestamptz NOT NULL
```

Indexes: `(organization_id, occurred_at DESC)`, `(event_type, occurred_at)`.

**Acceptance tests:** Permission change writes `permission.changed` with before/after in metadata; quote send writes `quote.sent`; append-only.

**Blocks P3-A1?** **No** — audit table can land P3-A5; **approve before** permission UI history (M07i).

---

### P2-OD-042 — Assignment access scope

**Current wording:** `assignments.access_scope` varchar CHECK ∈ `delivery`, `review`, `collaborator`.

**Recommended design (PROPOSED — unchanged intent, explicit enforcement):**

| `access_scope` | Meaning | Policy effect |
|---|---|---|
| `delivery` | Surveyor / field | Full assigned project delivery actions per role |
| `review` | Technical reviewer | Report/checklist artefacts; no `projects.manage` |
| `collaborator` | Narrow assist | Documents/messages per grant |

PostgreSQL: `CHECK (access_scope IN ('delivery', 'review', 'collaborator'))`.

Rails: `Assignment` validation + `ProjectPolicy` / `ReportPolicy` consult scope.

**Schema implications:** Already in P2.3 catalogue; migration with `assignments` table (P3-C2).

**Acceptance tests:** Reviewer without `review` scope cannot approve; surveyor `delivery` cannot access unassigned project; collaborator limited to grants.

**Blocks P3-A1?** **No**. **Blocks** assignment/report policies in Phase 3/4 — approve before `F3-DB-07` reviewer tests.

---

## 3. Remaining decisions — classification (Task 3)

| Class | Meaning | Examples |
|---|---|---|
| **A** | Blocks Phase 3 authentication/RBAC foundation | *None* after P2.5A (ADR-017, 012 approved). P2-OD-040 blocks **production** auth only |
| **B** | Blocks specific later business features | P2-OD-005 before report tables; ADR-007 before report role UI; P2-OD-022 before booking slice |
| **C** | Blocks confidential **production** data | ADR-010 implementation, P2-OD-027, ADR-004 |
| **D** | Safe to defer | CMS shape, vessels MVP, email provider, workflow 044–048 |

Foundation work must not wait for **B/D** items unrelated to auth.

---

## 4. Phase 1 design readiness (Task 4)

| Requirement | Status |
|---|---|
| Exclusive blueprint | [`design/ANT_Marine_Design_Studio_Phase_1.html`](../../design/ANT_Marine_Design_Studio_Phase_1.html) — **no external templates** |
| Team & Permissions DCR | **Approved** — incorporate M07a–j, C15a–j in HTML (**not done**) |
| Other design changes | P2.4 gaps (inquiry merge, etc.) — optional CRs before HTML pass |
| Review | Stakeholder walkthrough of updated HTML + handoff JSON export |
| **Final Phase 1 sign-off** | Formal record: approved HTML snapshot + review export in repo or `docs/` evidence |

**Phase 2 exit does not require HTML update** — only **approved plan** to update. Implementation fidelity follows after sign-off.

---

## 5. Encryption gate (Task 5)

| Statement | Confirmed |
|---|---|
| P3-STORAGE-01 PoC plan | **Approved** (P2.5A / ADR-010 partial) |
| Confidential production uploads | **Blocked** until PoC passes |
| Phase 2 closure | Does **not** require Phase 3 PoC **completion** — only approved plan |
| Objective acceptance tests | Listed in [`P2_5_SECURITY_AND_STORAGE_GATES.md`](P2_5_SECURITY_AND_STORAGE_GATES.md) §3 and §4 gate G3 |

---

## 6. Phase 3 entry criteria (Task 6)

### Approved (may start P3-A1)

- ADR-005, 006, 008, 012, 014, 015, 016, **017** — APPROVED  
- P2-OD-043/004 — APPROVED  
- B0.0–B0.3 — passed  
- Architecture docs P2.1–P2.5 — complete  

### Pending (do not block P3-A1 local foundation)

- P2-OD-040–042 — recommend defaults above; **PROPOSED**  
- Phase 1 full HTML sign-off  
- HTML DCR **implementation**  
- P3-STORAGE-01 **execution**  

### First slice (prepared, not executed)

**P3-A1 — Authentication foundation**

1. `bin/rails generate authentication` (ADR-017).  
2. `organizations` seed row (`ant_marine`).  
3. **If P2-OD-040 approved:** `sessions` table + revocation hooks; else interim cookie store **dev-only** documented.  
4. Minitest: login, logout, suspended user denied.  
5. No Pundit gem install until slice plan accepted (ADR-012 allows next slice).

**Evidence for Phase 3 gate:** commit + tests green + no scope beyond A1.

---

## 7. GO / CONDITIONAL GO / NO-GO

| Gate | Verdict |
|---|---|
| **Phase 3 Wave A (P3-A1) start** | **GO** — approved ADRs sufficient; implement interim sessions only if P2-OD-040 pending (document debt) |
| **Phase 2 full exit** | **CONDITIONAL GO** — pending product-owner approval of P2-OD-040–042 recommendations + Phase 1 sign-off process defined |
| **Confidential production files** | **NO-GO** until P3-STORAGE-01 evidence |
| **Production deploy** | **NO-GO** until P2-OD-040 approved for session model |

---

## 8. Product-owner approval form (P2.5B)

Approve recommended defaults? (does not auto-apply — update `DECISIONS.md` on confirmation)

- [ ] P2-OD-040 — DB-backed revocable sessions  
- [ ] P2-OD-041 — `event_type` + JSONB audit (no STI)  
- [ ] P2-OD-042 — `access_scope` CHECK + policies  
- [ ] Phase 2 architecture **full exit** with above three **APPROVED**  
- [ ] Authorize **P3-A1** implementation slice  

---

## References

- [`P2_5A_STAKEHOLDER_DECISION_RECORD.md`](P2_5A_STAKEHOLDER_DECISION_RECORD.md)  
- [`P2_5_PHASE_3_READINESS.md`](P2_5_PHASE_3_READINESS.md)  
- [`P2_3_SCHEMA_CATALOGUE.md`](P2_3_SCHEMA_CATALOGUE.md) (update after 040–042 approval)