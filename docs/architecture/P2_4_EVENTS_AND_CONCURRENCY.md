# P2.4 — Events, Notifications & Concurrency

**Version:** 1.0 — 22 November 2026  
**Jobs:** Solid Queue + Action Mailer after **commit** (ADR-009 provider OPEN)

---

## 1. Notification catalogue

| Event key | Trigger transition | Recipients | Channel | Required? |
|---|---|---|---|---|
| `inquiry.submitted` | inquiry submit | Staff queue role | email + in-app | Required business |
| `inquiry.clarification` | needs_clarification | Contact email | email | Required |
| `quote.sent` | quote send | Client managers/owners | email + portal | Required |
| `quote.accepted` | accept | Staff coordinator | email + in-app | Required |
| `quote.declined` | decline | Staff | in-app | Required |
| `booking.confirmed` | booking confirm | Client contact | email | Required |
| `project.created` | project create | Client org | portal | Required |
| `assignment.created` | assign | Surveyor | in-app | Optional reminder |
| `upload.requested` | upload_request create | Client | email | Required |
| `document.uploaded` | version created | Coordinator | in-app | Optional |
| `report.submitted_for_review` | submit | Reviewers assigned | in-app | Required |
| `report.approved` | approve | Releasers | in-app | Required |
| `report.released` | release | Client org | email + portal | Required |
| `invoice.issued` | issue | client_finance, owner | email | Required |
| `payment.recorded` | record_payment | client + finance | in-app | Required |
| `invitation.sent` | invite | invitee | email | Required |
| `permission.changed` | override/grant | subject user | in-app | Required |
| `membership.suspended` | suspend | subject user | email | Required |

**Idempotency:** `notifications` UNIQUE `(user_id, dedupe_key)` where dedupe_key = `event_key + subject_id + version`.

Mail: `deliver_later` with job args carrying `audit_event_id` for traceability.

---

## 2. Concurrency scenarios (Task 12)

| Scenario | Safeguard |
|---|---|
| Two clients accept same quote | Transaction + `quotes.current_status` lock; second accept fails if not `sent` |
| Accept superseded revision | Accept must reference revision id; reject if not latest sent |
| Duplicate project creation | UNIQUE `projects.quote_revision_id`; service `INSERT` idempotent key |
| Concurrent assignment | Last write wins on inactive flag; audit both |
| Simultaneous report approve | Row lock on `report_version`; one `report_reviews` approved per version |
| Release during new draft | Release only on approved version id; new draft does not affect released version |
| Duplicate invoice issue | UNIQUE `reference_number`; issue transition once from draft |
| Duplicate payment notify | Idempotency key on payment_record id |
| Concurrent permission edits | `memberships.lock_version` optimistic; retry |
| Suspension mid-action | Next request epoch check; in-flight form submit may 403 after commit order defined |
| Job retry | Jobs must tolerate at-least-once delivery; notifications dedupe |

---

## 3. Transaction pattern

```text
ActiveRecord::Base.transaction do
  # 1. Row lock aggregate if needed
  # 2. Validate state + policy
  # 3. Update state + child rows
  # 4. Insert audit_events
  # 5. Bump permission_epoch if needed
end
# after_commit { NotificationJob.perform_later(...) }
```

**Never** send email or call storage before commit.

---

## 4. Idempotency keys (proposed columns)

| Transition | Key source |
|---|---|
| Client accept quote | `quote_revision_id` + `membership_id` |
| Create project | `quote_revision_id` |
| Record payment | `invoice_id` + `amount_cents` + `recorded_at` date bucket |

HTTP: `Idempotency-Key` header on accept/create endpoints (Phase 4).

---

## 5. Failure handling

| Failure | User message | Recovery |
|---|---|---|
| Stale state | “This quote is no longer available.” | Refresh |
| Policy deny | X04 pattern | — |
| Lock conflict | “Please try again.” | Retry |
| Job mail failure | UI still shows success; job retries | Solid Queue DLQ monitor |

---

## 6. Signed URL concurrency

Release does not revoke outstanding download URLs until TTL expiry — document in client copy; keep TTL short.