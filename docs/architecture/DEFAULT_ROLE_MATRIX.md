# ANT Marine — Default Role Permission Matrix

**Status:** Phase 2 — default at role assignment; overrides per [`ROLE_PERMISSION_SPEC.md`](ROLE_PERMISSION_SPEC.md)

**Catalogue:** [`PERMISSION_CATALOGUE.md`](PERMISSION_CATALOGUE.md)
**P2.1 reconciliation:** 22 November 2026 — reviewer assignment-only; finance tightened project visibility.

**P2.2 refinements:** `billing.view_all` for finance; Ops Manager confidential removed from default; reviewer `access_scope` in authorization architecture.

Abbreviations in tables: **Y** = granted by default, **—** = not granted (may grant if `Override: yes`).

---

## ANT Marine staff defaults

### `staff.super_administrator` — Super Administrator

| Area | Permissions (default Y) |
|---|---|
| All staff catalogue | All `staff` domain permissions including `team.manage_staff_roles`, `team.manage_staff_permissions`, `team.bulk_permission_change`, `company.settings_manage_staff`, `audit.view_staff`, `audit.view_permission_changes` |
| Sensitive | `reports.release`, `reports.approve` (delegable), `billing.adjust` |
| Typical deny override | None for protected keys |

### `staff.operations_manager` — Operations Manager

Org-wide project oversight (`projects.view_all`). Confidential documents require explicit grant (not default).

| Permission keys |
|---|
| `inquiries.view_all`, `inquiries.qualify`, `quotes.view_all`, `quotes.create`, `quotes.send`, `quotes.withdraw`, `bookings.view_all`, `bookings.confirm`, `projects.view_all`, `projects.create`, `projects.manage`, `projects.assign`, `vessels.view_all`, `vessels.manage`, `inspections.view`, `documents.manage`, `documents.request_upload`, `documents.download`, `documents.preview`, `reports.review`, `reports.release`, `reports.view_draft_staff`, `billing.view`, `billing.manage`, `messages.view`, `messages.send`, `analytics.view_business`, `analytics.export`, `team.view`, `team.invite`, `team.suspend`, `audit.view_staff`, `company.settings_manage_staff` |

Not default: `documents.access_confidential` (grant when justified).

Not default: `team.manage_staff_roles`, `team.manage_staff_permissions`, `reports.approve` (unless granted), `content.publish`.

### `staff.project_coordinator` — Project Coordinator

| Permission keys |
|---|
| `inquiries.view_all`, `inquiries.qualify`, `quotes.view_all`, `quotes.create`, `quotes.send`, `quotes.withdraw`, `bookings.view_all`, `bookings.confirm`, `projects.view_all`, `projects.create`, `projects.manage`, `projects.assign`, `vessels.view_all`, `vessels.manage`, `documents.upload`, `documents.download`, `documents.preview`, `documents.manage`, `documents.request_upload`, `reports.view_draft_staff`, `reports.release`, `billing.view`, `messages.view`, `messages.send`, `team.view`, `training.manage` |

### `staff.surveyor` — Surveyor / Consultant

| Permission keys |
|---|
| `inquiries.view_assigned`, `projects.view_assigned`, `assignments.participate`, `bookings.view_all`, `vessels.view_all`, `inspections.view`, `inspections.edit`, `documents.upload`, `documents.download`, `documents.preview`, `reports.draft`, `reports.view_draft_staff`, `messages.view`, `messages.send`, `team.view`, `notifications.manage_preferences` |

Not default: `reports.approve`, `reports.release`, `quotes.send`.

### `staff.technical_reviewer` — Technical Reviewer

Assignment-only — `Assignment` with `access_scope: review` (report-focused scope per P2_2 authorization architecture).

| Permission keys |
|---|
| `projects.view_assigned`, `inspections.view`, `documents.download`, `documents.preview`, `reports.review`, `reports.approve`, `reports.view_draft_staff`, `messages.view`, `team.view`, `notifications.manage_preferences` |

Not default: `projects.view_all`, `reports.release`, `reports.draft` (unless also surveyor).

### `staff.finance_officer` — Finance Officer

Billing-first via `billing.view_all` — no project assignment required for invoice work; policies expose minimal project reference fields only.

| Permission keys |
|---|
| `billing.view_all`, `billing.view`, `billing.manage`, `billing.record_payment`, `billing.adjust`, `documents.download` (invoice attachments only via policy), `team.view`, `notifications.manage_preferences` |

Not default: `projects.view_all`, `projects.view_assigned`, `documents.access_confidential`.

### `staff.content_manager` — Content Manager

| Permission keys |
|---|
| `content.view_draft`, `content.manage`, `content.publish`, `training.manage`, `analytics.view_business`, `team.view`, `notifications.manage_preferences` |

### `staff.general_staff` — General Staff

| Permission keys |
|---|
| `inquiries.view_assigned`, `projects.view_assigned`, `assignments.participate`, `documents.download`, `documents.preview`, `messages.view`, `team.view`, `notifications.manage_preferences` |

---

## Client organisation defaults

### `client.org_owner` — Organisation Owner

| Permission keys |
|---|
| All client-domain permissions for the org: `inquiries.*` (org), `quotes.view_org`, `quotes.accept`, `quotes.decline`, `bookings.request`, `projects.view_org`, `vessels.view_org`, `vessels.manage_org`, `documents.upload`, `documents.download`, `documents.preview`, `documents.access_confidential`, `reports.view_org`, `billing.view`, `messages.view`, `messages.send`, `team.view`, `team.invite`, `team.manage_roles`, `team.manage_permissions`, `team.suspend`, `team.transfer_ownership`, `team.bulk_permission_change`, `company.settings_view`, `company.settings_manage`, `audit.view_org`, `audit.view_permission_changes`, `notifications.manage_preferences` |

### `client.org_administrator` — Organisation Administrator

| Permission keys |
|---|
| Same as owner **except** not default: `team.manage_roles`, `team.manage_permissions`, `team.transfer_ownership`, `team.bulk_permission_change` unless `team.manage_team_delegated` granted |

Default includes: `team.invite`, `team.suspend`, `team.view`, `quotes.accept`, `company.settings_manage`, `audit.view_org`, plus standard project/document/message permissions.

### `client.client_manager` — Client Manager

| Permission keys |
|---|
| `inquiries.create`, `inquiries.view_org`, `quotes.view_org`, `quotes.accept`, `quotes.decline`, `bookings.request`, `projects.view_org`, `vessels.view_org`, `vessels.manage_org`, `documents.upload`, `documents.download`, `documents.preview`, `reports.view_org`, `billing.view`, `messages.view`, `messages.send`, `team.view`, `team.invite` (if enabled), `company.settings_view`, `notifications.manage_preferences` |

### `client.client_member` — Client Member

| Permission keys |
|---|
| `inquiries.create`, `inquiries.view_org`, `quotes.view_org`, `bookings.request`, `projects.view_org`, `vessels.view_org`, `documents.upload`, `documents.download`, `documents.preview`, `reports.view_org`, `messages.view`, `messages.send`, `team.view`, `notifications.manage_preferences` |

Not default: `quotes.accept`, `team.invite`, `billing.view`.

### `client.client_finance` — Client Finance

| Permission keys |
|---|
| `billing.view`, `projects.view_org` (limited fields), `documents.download` (invoice-related), `team.view`, `notifications.manage_preferences` |

---

## Cross-domain denial matrix (always enforced)

| Actor | Cannot receive |
|---|---|
| Any client role | Any permission with domain `staff` only |
| Client via override | `team.manage_staff_*`, `reports.release`, `inquiries.view_all`, etc. |
| Staff via client org membership | Client `team.manage_permissions` on staff org |

---

## Review checklist

- [ ] Each Phase 4 slice lists required permission keys  
- [ ] Policy tests cover default deny for each role  
- [ ] UI “effective access” screen matches resolution hierarchy  