# P2.3 — Database Architecture Overview

**Status:** Phase 2 design — documentation only (no migrations)  
**Version:** 1.0 — 22 November 2026  
**Engine:** PostgreSQL 17 (per B0.2); Rails 8.1 `config/database.yml` primary + Solid Cache/Queue/Cable DBs in production  
**Sources:** P2.1 domain, P2.2 auth/authz, [`ROLE_PERMISSION_SPEC.md`](ROLE_PERMISSION_SPEC.md), master spec §3.2

**Companion docs:**

| Document | Contents |
|---|---|
| [`P2_3_SCHEMA_CATALOGUE.md`](P2_3_SCHEMA_CATALOGUE.md) | Tables, columns, constraints, indexes |
| [`P2_3_RELATIONSHIP_DIAGRAMS.md`](P2_3_RELATIONSHIP_DIAGRAMS.md) | Mermaid ERDs by context |
| [`P2_3_MIGRATION_PLAN.md`](P2_3_MIGRATION_PLAN.md) | Phase 3 slice sequence |
| [`P2_3_DATA_INTEGRITY_SECURITY.md`](P2_3_DATA_INTEGRITY_SECURITY.md) | Tenancy, concurrency, retention |

---

## 1. Confirmed vs proposed

| Layer | Confirmed (stakeholder / master spec) | Proposed (pending approval) |
|---|---|---|
| Tenancy | `organizations.kind` ∈ `ant_marine`, `client`; client data FK to client org | — |
| Identity | One `users` row; many `memberships` | ADR-017 Rails authentication generator |
| RBAC | Catalogue keys, 13 roles, overrides per membership | ADR-012 Pundit + EffectivePermissions |
| Commercial | Immutable `quote_revisions`; accept links revision | ADR-014 anonymous inquiry; ADR-006 accept actor |
| Reports | `report_releases` → approved `report_version_id` | — |
| Sessions | — | P2-OD-040 cookie sessions (proposed) |
| Audit shape | — | P2-OD-041 `audit_events` STI (proposed) |

Do not treat **PROPOSED** rows as implementation mandates until `DECISIONS.md` shows `APPROVED`.

---

## 2. Naming and Rails conventions

- Table names: plural `snake_case` (`service_inquiries`).
- Primary keys: `bigint` `id` (P2-OD-011 proposed).
- Foreign keys: `*_id bigint NOT NULL` with `ON DELETE` restrictions documented per table.
- Timestamps: `created_at`, `updated_at` `timestamptz NOT NULL`.
- Money: `amount_cents bigint`, `currency char(3)` NOT NULL.
- Enums: PostgreSQL `varchar` + `CHECK` constraints (Rails 8 enum or string columns) — avoid opaque integer enums in DB for audit readability.
- Public references: `reference_number varchar` UNIQUE per table family.
- JSON: `jsonb` for settings/metadata; not for permission resolution (use relational seeds).

---

## 3. Nine business contexts (table ownership)

| # | Context | Primary tables | Org scoping |
|---|---|---|---|
| 1 | Platform | `organizations`, `users`, `memberships`, `invitations`, `permissions`, `role_permissions`, `permission_overrides`, `audit_events` | Mixed |
| 2 | Public | `services`, `articles`, `case_studies`, `training_offerings`, `public_resources`, `resource_downloads` | None / global |
| 3 | Commercial | `service_inquiries`, `quotes`, `quote_revisions`, `quote_responses`, `booking_requests`, `booking_confirmations` | Nullable → client org |
| 4 | Delivery | `projects`, `assignments`, `tasks`, `vessels`, `project_vessels`, `inspections`, `inspection_findings`, `project_status_events` | Client org + project |
| 5 | Documents | `documents`, `document_versions`, `document_access_grants`, `upload_requests` | Client org (+ project) |
| 6 | Reports | `reports`, `report_versions`, `report_reviews`, `report_releases` | Client org via project |
| 7 | Billing | `invoices`, `invoice_lines`, `payment_records` | Client org |
| 8 | Collaboration | `conversations`, `messages`, `notifications` | Project / user |
| 9 | Administration | `document_rules`, CMS tables | Staff org / global |

**Content:** Separate CMS tables per P2-OD-007 proposed default — not STI `content_pages` for MVP planning.

---

## 4. Cross-cutting rules

### 4.1 Ownership

- **Client tenant:** `client_organization_id` (or `organization_id` where kind = client) required on client-visible aggregates.
- **Staff context:** Users never store permissions on `users`; only on `memberships`.
- **Staff cross-client access:** No shared row; staff queries join through assignments or org-wide policy — not a duplicate `organization_id` on user.

### 4.2 Retention and archival

- Prefer `archived_at` + `status` over `DELETE` on projects, documents, quotes, organizations.
- `audit_events`: append-only; no hard delete in application (partition by month in production — proposed).
- Invitations: soft-cancel; retain for audit.

### 4.3 Deletion restrictions

| Parent | Child | ON DELETE |
|---|---|---|
| `organizations` | `memberships` | RESTRICT (archive org first) |
| `projects` | `assignments` | RESTRICT / cascade only via archive workflow |
| `documents` | `document_versions` | RESTRICT (immutable chain) |
| `quote_revisions` | `quote_responses` | RESTRICT |

### 4.4 Migration sequencing (summary)

See [`P2_3_MIGRATION_PLAN.md`](P2_3_MIGRATION_PLAN.md). Order: identity → RBAC → audit → commercial → delivery → documents/reports → billing/collaboration → public content.

---

## 5. Active Storage (reference only)

- `active_storage_blobs`, `active_storage_attachments`, `active_storage_variant_records` — Rails framework tables.
- Business metadata on `document_versions.active_storage_attachment_id` or blob id; **authorization uses `documents` / policies**, not blob id alone.
- Signed URLs: short TTL; revocation is logical (policy deny) — may not invalidate already-issued URL until expiry (P2.2 threat model).

---

## 6. Seed and catalogue versioning

| Seed | Idempotency |
|---|---|
| `permissions` | UPSERT on `key`; `catalogue_version` integer on singleton config row |
| `role_permissions` | UPSERT `(role_key, permission_id)`; seed task must not delete `permission_overrides` |
| ANT Marine org | Single row `kind = ant_marine` |
| Super Admin bootstrap | One-time rake guarded by env flag |

`permission_overrides` never truncated by role seed reruns.

---

## 7. PostgreSQL vs application enforcement

| Guarantee | DB | App |
|---|---|---|
| Unique email | UNIQUE index | Normalization |
| One membership per user+org | UNIQUE | — |
| Client cannot have staff-only permission in overrides | CHECK on permission domain vs membership org kind | PermissionGranter |
| Last owner / last super admin | Partial indexes aid detection | Advisory lock + transaction |
| Quote one project per revision | UNIQUE `projects.quote_revision_id` | Idempotent job |
| Release → approved version | FK + CHECK via app validation | Policy |

Details: [`P2_3_DATA_INTEGRITY_SECURITY.md`](P2_3_DATA_INTEGRITY_SECURITY.md).

---

## 8. Handoff resolutions (P2-OD-040–042) — PROPOSED

Documented in [`P2_1_OPEN_DECISIONS.md`](P2_1_OPEN_DECISIONS.md) §7; not APPROVED.

| ID | Recommendation |
|---|---|
| P2-OD-040 | **Cookie session store** (encrypted) + `users.security_version` + `memberships.permission_epoch`; defer `sessions` table unless compliance requires server-side session inventory |
| P2-OD-041 | **`audit_events` STI** (`type` column): `AuditEvent::PermissionChange`, `::ReportRelease`, etc.; single table for admin queries |
| P2-OD-042 | **`assignments.access_scope`** `varchar` CHECK ∈ `delivery`, `review`, `collaborator` alongside `assignment_kind` |

---

## 9. ADR database implications (not approved unless stated)

| ADR | Schema note |
|---|---|
| ADR-005 | `invitations` required before client `memberships` active |
| ADR-006 | `quote_responses.responded_by_membership_id` |
| ADR-012 | No extra tables; policies use seeded permissions |
| ADR-014 | `service_inquiries.client_organization_id` NULL allowed |
| ADR-016 | No `custom_roles` table in v1 |
| ADR-017 | `users` columns align with Rails authentication generator |

---

## 10. Document map

P2.1/P2.2 remain authoritative for **behaviour**; this package is authoritative for **relational design** pending stakeholder sign-off.