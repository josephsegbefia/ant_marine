# P2.3 — Schema Catalogue

**Status:** Design specification — not applied to `db/schema.rb`  
**Version:** 1.0 — 22 November 2026  
**Permission keys:** Must match [`PERMISSION_CATALOGUE.md`](PERMISSION_CATALOGUE.md) (71 keys including `billing.view_all`)

Column types use PostgreSQL. `?` = nullable unless stated.

---

## Platform — identity & RBAC

### `organizations`

| Column | Type | Null | Notes |
|---|---|---|---|
| id | bigint | PK | |
| kind | varchar | NOT NULL | CHECK ∈ `ant_marine`, `client` |
| name | varchar | NOT NULL | |
| slug | varchar | NOT NULL | UNIQUE |
| status | varchar | NOT NULL | `active`, `archived` |
| profile | jsonb | NULL | Client-visible profile |
| settings | jsonb | NULL | Org settings |
| archived_at | timestamptz | NULL | |
| created_at, updated_at | timestamptz | NOT NULL | |

**Indexes:** UNIQUE `(slug)`; INDEX `(kind, status)`.

**Proposal:** Partial UNIQUE on `kind` WHERE `kind = 'ant_marine' AND archived_at IS NULL` (single active staff org).

### `users`

| Column | Type | Null | Notes |
|---|---|---|---|
| id | bigint | PK | |
| email | varchar | NOT NULL | UNIQUE (normalized lower) |
| password_digest | varchar | NULL | Until invite complete |
| email_verified_at | timestamptz | NULL | |
| status | varchar | NOT NULL | `active`, `suspended` |
| security_version | integer | NOT NULL | Default 0; bump logout-all |
| created_at, updated_at | timestamptz | NOT NULL | |

**Indexes:** UNIQUE `(lower(email))`.

### `memberships`

| Column | Type | Null | Notes |
|---|---|---|---|
| id | bigint | PK | |
| user_id | bigint | FK users | NOT NULL |
| organization_id | bigint | FK organizations | NOT NULL |
| role_key | varchar | NOT NULL | e.g. `staff.surveyor`, `client.org_owner` |
| status | varchar | NOT NULL | `invited`, `active`, `suspended`, `removed` |
| permission_epoch | integer | NOT NULL | Default 0 |
| lock_version | integer | NOT NULL | Optimistic locking |
| invited_at, accepted_at | timestamptz | NULL | |
| created_at, updated_at | timestamptz | NOT NULL | |

**Indexes:** UNIQUE `(user_id, organization_id)`; INDEX `(organization_id, status)`; INDEX `(user_id, status)`.

**CHECK (proposed):** `role_key` matches domain of organization (`staff.*` only if org kind ant_marine) — app-enforced if CHECK too brittle.

### `invitations`

| Column | Type | Null | Notes |
|---|---|---|---|
| id | bigint | PK | |
| organization_id | bigint | FK | NOT NULL |
| email | varchar | NOT NULL | |
| role_key | varchar | NOT NULL | |
| token_digest | varchar | NOT NULL | UNIQUE among pending |
| status | varchar | NOT NULL | `pending`, `accepted`, `revoked`, `expired` |
| expires_at | timestamptz | NOT NULL | |
| invited_by_membership_id | bigint | FK memberships | NOT NULL |
| accepted_by_user_id | bigint | FK users | NULL | |
| accepted_at | timestamptz | NULL | |
| created_at, updated_at | timestamptz | NOT NULL | |

**Indexes:** UNIQUE `(token_digest)` WHERE `status = 'pending'`; INDEX `(organization_id, status)`.

### `permissions`

| Column | Type | Null | Notes |
|---|---|---|---|
| id | bigint | PK | |
| key | varchar | NOT NULL | UNIQUE stable key |
| display_name | varchar | NOT NULL | |
| category | varchar | NOT NULL | |
| domain | varchar | NOT NULL | `staff`, `client`, `staff,client` stored normalized |
| override_rule | varchar | NOT NULL | `yes`, `protected`, `deny_only` |
| catalogue_version | integer | NOT NULL | Denormalized from global version on seed |

### `role_permissions`

| Column | Type | Null | Notes |
|---|---|---|---|
| id | bigint | PK | |
| role_key | varchar | NOT NULL | One of 13 defaults |
| permission_id | bigint | FK permissions | NOT NULL |

**Indexes:** UNIQUE `(role_key, permission_id)`; INDEX `(permission_id)`.

### `permission_overrides`

| Column | Type | Null | Notes |
|---|---|---|---|
| id | bigint | PK | |
| membership_id | bigint | FK memberships | NOT NULL |
| permission_id | bigint | FK permissions | NOT NULL |
| effect | varchar | NOT NULL | CHECK ∈ `allow`, `deny` |
| granted_by_membership_id | bigint | FK memberships | NOT NULL |
| reason | text | NULL | Required for sensitive in app |
| created_at, updated_at | timestamptz | NOT NULL | |

**Indexes:** UNIQUE `(membership_id, permission_id)`.

### `audit_events` (STI — P2-OD-041 proposed)

| Column | Type | Null | Notes |
|---|---|---|---|
| id | bigint | PK | |
| type | varchar | NOT NULL | STI class name |
| organization_id | bigint | FK | NULL for global |
| actor_membership_id | bigint | FK | NULL if system |
| subject_type, subject_id | varchar, bigint | NULL | Polymorphic |
| action | varchar | NOT NULL | |
| metadata | jsonb | NOT NULL | Default `{}` |
| occurred_at | timestamptz | NOT NULL | |
| created_at | timestamptz | NOT NULL | |

**Indexes:** INDEX `(organization_id, occurred_at DESC)`; INDEX `(type, occurred_at)`; INDEX `(subject_type, subject_id)`.

### `app_settings` (proposed singleton)

| Column | Type | Null | Notes |
|---|---|---|---|
| id | bigint | PK | |
| permissions_catalogue_version | integer | NOT NULL | Cache bust |

---

## Commercial

### `services` (catalogue)

| Column | Type | Null | Notes |
|---|---|---|---|
| id | bigint | PK | |
| slug | varchar | UNIQUE | NOT NULL |
| title | varchar | NOT NULL | |
| summary, body | text | NULL | |
| status | varchar | NOT NULL | draft, published, archived |
| seo | jsonb | NULL | |
| published_at | timestamptz | NULL | |

### `service_inquiries`

| Column | Type | Null | Notes |
|---|---|---|---|
| id | bigint | PK | |
| reference_number | varchar | UNIQUE | NOT NULL |
| channel | varchar | NOT NULL | `public_form`, `contact_form`, `client_portal` |
| service_id | bigint | FK services | NULL |
| client_organization_id | bigint | FK organizations | NULL | Linked after qualification |
| submitted_by_user_id | bigint | FK users | NULL | Logged-in client |
| contact_name, contact_email, contact_phone, company_name | varchar | NOT NULL/NULL | Snapshot |
| location, description | text | NULL | |
| preferred_date | date | NULL | |
| current_status | varchar | NOT NULL | |
| created_at, updated_at | timestamptz | NOT NULL | |

**Indexes:** INDEX `(current_status, created_at)`; INDEX `(client_organization_id)`.

### `quotes`

| Column | Type | Null | Notes |
|---|---|---|---|
| id | bigint | PK | |
| reference_number | varchar | UNIQUE | NOT NULL |
| client_organization_id | bigint | FK | NOT NULL |
| service_inquiry_id | bigint | FK | NULL | |
| current_status | varchar | NOT NULL | |
| created_at, updated_at | timestamptz | NOT NULL | |

### `quote_revisions` (immutable)

| Column | Type | Null | Notes |
|---|---|---|---|
| id | bigint | PK | |
| quote_id | bigint | FK quotes | NOT NULL |
| version_number | integer | NOT NULL | |
| amount_cents | bigint | NOT NULL | |
| currency | char(3) | NOT NULL | |
| valid_until | date | NULL | |
| scope_summary, deliverables, exclusions | text | NULL | |
| sent_at | timestamptz | NULL | |
| created_at | timestamptz | NOT NULL | No updated_at (immutable) |

**Indexes:** UNIQUE `(quote_id, version_number)`.

### `quote_responses`

| Column | Type | Null | Notes |
|---|---|---|---|
| id | bigint | PK | |
| quote_revision_id | bigint | FK | NOT NULL |
| response | varchar | NOT NULL | `accepted`, `declined` |
| responded_by_membership_id | bigint | FK | NOT NULL | ADR-006 proposed |
| responded_at | timestamptz | NOT NULL | |
| notes | text | NULL | |
| created_at | timestamptz | NOT NULL | |

### `booking_requests` / `booking_confirmations`

| Table | Key columns |
|---|---|
| booking_requests | `reference_number`, `service_inquiry_id`?, `client_organization_id`?, `preferred_date`, `status` |
| booking_confirmations | `booking_request_id` FK UNIQUE, `confirmed_by_membership_id`, `confirmed_at`, `appointment_at` |

---

## Delivery

### `projects`

| Column | Type | Null | Notes |
|---|---|---|---|
| id | bigint | PK | |
| reference_number | varchar | UNIQUE | NOT NULL |
| client_organization_id | bigint | FK | NOT NULL |
| service_id | bigint | FK | NULL | |
| quote_revision_id | bigint | FK quote_revisions | NULL | UNIQUE when set |
| client_status | varchar | NOT NULL | Simple client label |
| internal_status | varchar | NOT NULL | |
| archived_at | timestamptz | NULL | |

### `assignments`

| Column | Type | Null | Notes |
|---|---|---|---|
| id | bigint | PK | |
| project_id | bigint | FK | NOT NULL |
| user_id | bigint | FK users | NOT NULL |
| assignment_kind | varchar | NOT NULL | lead_surveyor, surveyor, coordinator, technical_reviewer, collaborator |
| access_scope | varchar | NOT NULL | CHECK ∈ delivery, review, collaborator (P2-OD-042) |
| active | boolean | NOT NULL | Default true |
| created_at, updated_at | timestamptz | NOT NULL | |

**Indexes:** UNIQUE `(project_id, user_id, assignment_kind)` WHERE `active`; INDEX `(user_id, active)`.

### `vessels`, `project_vessels`, `tasks`, `inspections`, `inspection_findings`

| Table | Key FKs |
|---|---|
| vessels | `client_organization_id` NOT NULL |
| project_vessels | `project_id`, `vessel_id` UNIQUE |
| tasks | `project_id`, `assignee_user_id`?, `due_at`, `status` |
| inspections | `project_id`, `inspected_at`, `location` |
| inspection_findings | `inspection_id` |

### `project_status_events`

| Column | Type | Notes |
|---|---|---|
| project_id | FK | |
| from_status, to_status | varchar | |
| actor_membership_id | FK | |
| reason | text | |
| occurred_at | timestamptz | |

---

## Documents & reports

### `documents`

| Column | Type | Null | Notes |
|---|---|---|---|
| id | bigint | PK | |
| client_organization_id | bigint | FK | NOT NULL |
| project_id | bigint | FK | NULL |
| category | varchar | NOT NULL | |
| classification | varchar | NOT NULL | `standard`, `confidential`, … |
| scan_status | varchar | NOT NULL | |
| workflow_status | varchar | NOT NULL | |
| current_version_id | bigint | FK document_versions | NULL |

### `document_versions` (immutable)

| Column | Type | Notes |
|---|---|---|
| document_id | FK | |
| version_number | integer | UNIQUE per document |
| filename, content_type, byte_size | | |
| checksum | varchar | NOT NULL |
| uploaded_by_membership_id | FK | |
| created_at | timestamptz | |

Active Storage: `has_one_attached` on version or document — store attachment id reference.

### `document_access_grants`

| Column | Type | Notes |
|---|---|---|
| document_id | bigint | FK NULL | XOR project_id |
| project_id | bigint | FK NULL | |
| user_id | bigint | FK users | |
| granted_by_membership_id | FK | |
| expires_at | timestamptz | NULL |

### `upload_requests`

| Column | Type | Notes |
|---|---|---|
| project_id | FK | |
| requested_by_membership_id | FK | |
| document_category | varchar | |
| due_at | date | |
| status | varchar | |

### `reports`, `report_versions`, `report_reviews`, `report_releases`

| Table | Purpose |
|---|---|
| reports | `project_id` FK NOT NULL |
| report_versions | Immutable; `report_id`, version_number |
| report_reviews | `report_version_id`, `reviewer_membership_id`, `decision`, `decided_at` |
| report_releases | `report_version_id` FK NOT NULL; `released_by_membership_id`; `client_organization_id`; UNIQUE one release per version to client |

**Constraint (app + FK):** `report_releases.report_version_id` must reference version with `approved` review.

---

## Billing & collaboration

### `invoices`

| Column | Type | Notes |
|---|---|---|
| reference_number | UNIQUE | |
| client_organization_id | FK NOT NULL | Finance `billing.view_all` scope |
| project_id | FK NULL | Optional link |
| status | varchar | |
| issued_at, due_at | date | |
| total_cents | bigint | |

### `invoice_lines`

| Column | Type | Notes |
|---|---|---|
| invoice_id | FK | |
| description | text | |
| amount_cents | bigint | |
| position | integer | |

### `payment_records`

| Column | Type | Notes |
|---|---|---|
| invoice_id | FK | |
| amount_cents | bigint | |
| recorded_by_membership_id | FK | |
| recorded_at | timestamptz | |
| method | varchar | No card PAN |

### `conversations`, `messages`, `notifications`

| Table | Scope |
|---|---|
| conversations | UNIQUE `project_id` (P2-OD-008 proposed) |
| messages | `conversation_id`, `author_membership_id`, body |
| notifications | `user_id`, `organization_id`?, `notification_type`, `read_at`, `payload` jsonb |

---

## Public content (CMS)

Separate tables per P2-OD-007 proposed:

| Table | Shared columns pattern |
|---|---|
| articles | slug, title, body, status, seo jsonb, published_at |
| case_studies | + optional `project_id` for reference only |
| training_offerings | schedule fields jsonb |
| public_resources | file via Active Storage; not confidential |

Avoid mega `content_pages` STI unless ADR changes.

---

## `document_rules`

| Column | Type | Notes |
|---|---|---|
| category | varchar | |
| max_byte_size | bigint | |
| allowed_content_types | varchar[] | |
| retention_days | integer | NULL |

---

## Permission key coverage

All catalogue keys resolve against `permissions.key`; default grants in `role_permissions` per [`DEFAULT_ROLE_MATRIX.md`](DEFAULT_ROLE_MATRIX.md). Seeds must include **`billing.view_all`** (P2.2).