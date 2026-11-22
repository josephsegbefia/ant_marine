# P2.3 — Data Integrity & Security

**Version:** 1.0 — 22 November 2026  
**Related:** [`P2_2_SECURITY_THREAT_MODEL.md`](P2_2_SECURITY_THREAT_MODEL.md)

---

## 1. Client organisation isolation

`client_organization_id` alone is **insufficient** — every read path must also:

1. Resolve `Current.membership` in client portal (session-bound).
2. Apply `policy_scope` filtering `organization_id = current_org.id`.
3. For staff, require feature permission + assignment or `view_all` path.

**Database assists:**

- NOT NULL FK on tenant-owned rows (`projects`, `documents`, `invoices`, `vessels`).
- CHECK `organizations.kind = 'client'` on client FKs (optional deferred trigger).
- No shared primary keys across tenants for client data.

**Limits:** JOIN mistakes and missing scopes require **Rails policy tests** (T-01).

---

## 2. Staff cross-client access

- `assignments` link `user_id` + `project_id`; project carries `client_organization_id`.
- Staff user listings: index `(user_id, active)` on assignments.
- Org-wide staff queries: index `(client_organization_id, internal_status)` on projects.

---

## 3. Uniqueness & concurrency

| Scenario | Strategy |
|---|---|
| Last Owner / Super Admin | `SELECT ... FOR UPDATE` on organization/membership counts inside transaction; advisory lock `pg_advisory_xact_lock(org_id)` |
| Invitation double-accept | UNIQUE token pending; update `status = accepted` with `WHERE status = pending` row count check |
| Permission override races | `memberships.lock_version` optimistic lock; retry UI |
| Quote → project idempotency | UNIQUE `projects.quote_revision_id`; job uses `insert on conflict do nothing` |
| Permission seed rerun | UPSERT role_permissions only; never delete overrides |

---

## 4. Immutable records

| Table | Rule |
|---|---|
| quote_revisions | INSERT only; no UPDATE |
| document_versions, report_versions | INSERT only |
| quote_responses, report_reviews, report_releases | INSERT only (append evidence) |
| audit_events | INSERT only |

Enforce via model `readonly?` + DB privileges (revoke UPDATE from app role) in production hardening phase.

---

## 5. Confidential documents

- `documents.classification = 'confidential'` requires `documents.access_confidential` effective permission (membership-scoped).
- DB cannot enforce permission keys — **policies mandatory**.
- Optional partial index: `WHERE classification = 'confidential'` for admin dashboards.

---

## 6. Report release integrity

- `report_releases.report_version_id` FK NOT NULL.
- Application validates approved `report_reviews` row exists for version before insert release.
- UNIQUE `(report_version_id, client_organization_id)` prevents duplicate client releases.

---

## 7. Signed URLs and storage

- Blob access only after policy pass; TTL 5–15 minutes proposed.
- **Limitation:** URLs issued before revocation remain valid until expiry — mitigate with short TTL and confidential classification gate.

---

## 8. Account suspension

- `users.status = suspended` → authentication layer blocks session create.
- `memberships.status = suspended` → EffectivePermissions empty for that org.
- Index `(user_id, status)` on memberships for switcher UI.

---

## 9. Audit retention

- Append-only `audit_events`; partition by `occurred_at` monthly (proposed Phase 5).
- Permission changes: STI type `AuditEvent::PermissionChange` with metadata keys matching catalogue.

---

## 10. Recommended indexes (summary)

| Query pattern | Index |
|---|---|
| Login | `users (lower(email))` UNIQUE |
| Current membership | `memberships (user_id, organization_id)` UNIQUE |
| Staff queue | `service_inquiries (current_status, created_at DESC)` |
| Client projects | `projects (client_organization_id, archived_at NULLS FIRST)` |
| User assignments | `assignments (user_id) WHERE active` |
| Quote history | `quote_revisions (quote_id, version_number)` |
| Document versions | `document_versions (document_id, version_number)` |
| Report queue | `report_reviews (decision, created_at)` |
| Finance lists | `invoices (client_organization_id, status, issued_at DESC)` |
| Notifications inbox | `notifications (user_id, read_at NULLS FIRST, created_at DESC)` |
| Audit investigation | `audit_events (organization_id, occurred_at DESC)` |

Avoid indexing every FK column; add on evidence from `EXPLAIN` in Phase 4.

---

## 11. Finance without project assignment

- `invoices.client_organization_id` NOT NULL; `project_id` optional.
- Finance Officer policies query invoices by org only when `billing.view_all` — no join to `assignments`.

---

## 12. Protected administration (DB vs app)

| Guarantee | Primary enforcer |
|---|---|
| Cannot delete last owner membership | App transaction + lock |
| Cannot assign client.org_owner via invitation | App PermissionGranter + invitation role_key allow-list |
| Staff permission on client membership | CHECK permission.domain vs membership org kind (optional) |
| Concurrent role changes | `lock_version` |

PostgreSQL cannot express “at least one owner” without triggers — **prefer app + tests** (T-20).