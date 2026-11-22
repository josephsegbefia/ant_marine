# ANT Marine — Role & Permission Architecture Specification

**Status:** Product requirement (Phase 2 design) — implementation in Phase 3 foundation, before dependent business features  
**Version:** 1.0 — 22 November 2026  
**Related:** [`PERMISSION_CATALOGUE.md`](PERMISSION_CATALOGUE.md), [`DEFAULT_ROLE_MATRIX.md`](DEFAULT_ROLE_MATRIX.md), [`../ANT_MARINE_MASTER_SPEC.md`](../ANT_MARINE_MASTER_SPEC.md)

---

## 1. Requirement summary

ANT Marine **must** provide **configurable role-based access control (RBAC)** with:

- Two **strictly separated permission domains** (ANT Marine staff vs client organisations).
- A **versioned permission catalogue** with plain-English labels in the UI (internal identifiers never shown to end users).
- **Default roles** plus **per-user grants and denials** within eligible bounds.
- **Server-side enforcement** on every request and file action; deny by default.
- **Dedicated Team & Permissions** experiences in staff and client portals (Phase 1 design change request — see [`../design/PHASE_1_DESIGN_CHANGE_REQUEST_TEAM_PERMISSIONS.md`](../design/PHASE_1_DESIGN_CHANGE_REQUEST_TEAM_PERMISSIONS.md)).
- **Audit** of role and permission changes; immediate effect without forcing re-login.

This is foundational: Phase 3 must deliver permission infrastructure **before** Phase 4 business slices that depend on authorization.

---

## 2. Permission domains

| Domain | `organization.kind` | Who |
|---|---|---|
| **Staff** | `ant_marine` | Employees and contractors of ANT Marine W.A. |
| **Client** | `client` | Users authorised by a client company |

**Hard rule:** A client organisation user **cannot** receive staff-domain permissions through role assignment, custom grants, or cross-organisation edits. A Client Organisation Owner is **not** a Super Administrator.

Membership rows bind `user_id` + `organization_id` + **domain-specific role** + optional permission overrides.

---

## 3. Default roles

### 3.1 ANT Marine staff roles

| Role key | Display name (UI) | Summary |
|---|---|---|
| `staff.super_administrator` | Super Administrator | Full staff permission management; safeguarded last-owner rules |
| `staff.operations_manager` | Operations Manager | Cross-team operations, assignments, scheduling oversight |
| `staff.project_coordinator` | Project Coordinator | Inquiries, quotes, projects, client coordination |
| `staff.surveyor` | Surveyor / Consultant | Assigned field work, drafts, uploads; no self-approval |
| `staff.technical_reviewer` | Technical Reviewer | Report technical review; not sole release authority |
| `staff.finance_officer` | Finance Officer | Invoices and payment records; minimal project detail |
| `staff.content_manager` | Content Manager | Public content draft/review/publish |
| `staff.general_staff` | General Staff | Limited read/participate on assigned work |

### 3.2 Client organisation roles

| Role key | Display name (UI) | Summary |
|---|---|---|
| `client.org_owner` | Organisation Owner | Highest client authority; team and permission management for own org |
| `client.org_administrator` | Organisation Administrator | Delegated admin within limits; cannot create owners |
| `client.client_manager` | Client Manager | Quotes, team invites (if granted), project oversight |
| `client.client_member` | Client Member | Projects, uploads, messages per assignment |
| `client.client_finance` | Client Finance | Invoices and payment visibility |

Default permission sets: [`DEFAULT_ROLE_MATRIX.md`](DEFAULT_ROLE_MATRIX.md).

---

## 4. Permission resolution hierarchy

Effective permission for action `A` on resource `R` in organisation context `O`:

1. **Protected security restrictions** — cannot be overridden (e.g. client cannot gain `staff.*`; no cross-org grants; separation of duties on report approve/release).
2. **Organisation and resource boundaries** — user must belong to `O`; project/document must belong to `O`; staff must have assignment or elevated staff permission for client data.
3. **Explicit user denial** — `PermissionOverride` with `effect: deny` on eligible permission.
4. **Explicit user grant** — `PermissionOverride` with `effect: allow` on eligible permission.
5. **Default role permissions** — union of permissions linked to the user’s role in `O`.
6. **Deny by default** — if none of the above allow, refuse.

**Conflicts:** Deny beats grant at the same layer. Grants cannot override layer 1–2. If grant and deny both exist for the same permission, **deny wins**.

**Session freshness:** Permission cache (if any) is cleared or version-bumped on membership/override change; next request reloads effective permissions (no logout required).

---

## 5. Project-level and resource-level access

Feature permission **does not** imply access to all projects.

| Layer | Rule |
|---|---|
| Client | `projects.view` + membership in client org + project belongs to org |
| Client (optional tighten) | Project participant list if enabled |
| Staff | `projects.view` + (`projects.view_all` **or** `Assignment` on project) |
| Documents | Policy checks classification + workflow state + org/project match |
| Reports | Client sees version only if `ReportRelease` exists; staff by role + assignment |

Multi-org users: `Current.organization_id` selects tenant; queries always scoped; switching org (A06) reloads context.

---

## 6. Administrative authority

### 6.1 ANT Marine staff

- Only users with `team.manage_staff_roles` / `team.manage_staff_permissions` (typically Super Administrator; Operations Manager with delegation) may change **staff** roles and overrides.
- Cannot modify **client** org memberships from staff UI except invitations/workflows defined in product (separate permissions).

### 6.2 Client organisations

- **Organisation Owner** manages roles and permissions for users in **their** org only.
- **Organisation Administrator** may manage team with subset of permissions if owner grants `team.manage_team_delegated`.
- Cannot grant staff-domain permissions; cannot elevate users to Owner without `team.transfer_ownership` safeguard flow.

### 6.3 Prohibited actions (enforced in application layer + tests)

- Cross-organisation permission changes.
- Client acquiring staff access.
- Self-promotion to Super Administrator or Organisation Owner via permission editor.
- Removing last active Super Administrator or last active Organisation Owner without succession flow.
- Bulk permission changes without `team.bulk_permission_change` + confirmation.

### 6.4 Ownership transfer and recovery

| Flow | Safeguards |
|---|---|
| Transfer client org ownership | Current owner initiates; nominee accepts; audit; cannot leave zero owners |
| Transfer / add Super Admin | Existing Super Admin + reauthentication; audit; minimum one remains |
| Locked out owner | Documented break-glass: support procedure + audit (business process, not bypass in code) |

---

## 7. Sensitive operations

| Operation | Safeguards |
|---|---|
| Technical report approval | `reports.approve`; reviewer ≠ sole author where configurable; audit |
| Final report release | `reports.release`; separate from approve; explicit recipient confirmation |
| Organisation ownership transfer | Dual confirmation + audit |
| Super Administrator role change | Reauthentication + second Super Admin approval when >1 exists |
| Bulk permission change | Confirmation step + audit reason |
| Sensitive document access | Classification flag + extra permission `documents.access_confidential` |
| Invoice adjustment after issue | `billing.adjust` + finance role + audit reason |

**Separation of duties:** Users must not approve their own report version (configurable exception only for single-person org in staff domain — default **off**).

**Reauthentication:** Step-up verification (password or MFA when enabled) before high-risk UI actions.

---

## 8. Audit and security

Every role or permission change writes `PermissionChangeEvent` (or `AuditEvent` subtype) with:

- Actor user id  
- Affected user id  
- Organization id  
- Permission key or role key  
- Previous and new value  
- Timestamp (UTC)  
- Reason (required for bulk and sensitive grants)

Enforcement:

- Pundit-style policy per resource; `authorize` in controllers and service objects.
- Signed/expiring URLs for downloads **after** policy pass.
- Denial tests in CI for cross-org URLs, direct ID guessing, and revoked permissions.

---

## 9. Rails implementation proposal (no code in this task)

| Concept | Proposed model / component |
|---|---|
| User identity | `User` |
| Organisation | `Organization` (`kind: ant_marine \| client`) |
| Membership | `Membership` (`role_key`, `status`) |
| Permission catalogue | `Permission` (seeded from catalogue; stable `key`) |
| Role ↔ permission | `RolePermission` (join; domain + role_key) |
| User overrides | `PermissionOverride` (`membership_id`, `permission_key`, `effect`, `granted_by`) |
| Effective permissions | `Authorization::EffectivePermissions` service; memoized per request |
| Resource auth | `ApplicationPolicy` subclasses + `Scope` |
| Project assignment | `Assignment` gates staff project access |
| Permission versioning | `permissions_catalog_version` for cache busting |

**Avoid:** single giant role enum in code without catalogue; external permission SaaS; hardcoded checks scattered in views.

**Gem:** Pundit [PROPOSED] — confirm in Phase 3.

**UI:** Staff route namespace `Staff::TeamPermissions`; client `Client::Company::TeamPermissions` — aligned with design change request.

---

## 10. Acceptance criteria (verifiable)

- [ ] Default roles assign documented permissions at invite/accept.
- [ ] Admins grant/revoke only **eligible** permissions for that domain.
- [ ] Changes affect only targeted membership in one organisation.
- [ ] Client owners manage only their organisation.
- [ ] No client user effective staff permission.
- [ ] Last owner / last super admin protections work.
- [ ] Audit history shows permission changes.
- [ ] Direct URL access denied when permission revoked (same request after cache bust).
- [ ] Report approve/release cannot bypass workflow.
- [ ] UI uses plain-English permission labels from catalogue.
- [ ] Dedicated Team & Permissions pages exist in both portals (Phase 4).

---

## 11. Document map

| Document | Contents |
|---|---|
| [`PERMISSION_CATALOGUE.md`](PERMISSION_CATALOGUE.md) | All permission keys, labels, categories, domains, defaults |
| [`DEFAULT_ROLE_MATRIX.md`](DEFAULT_ROLE_MATRIX.md) | Role → permission mapping |
| [`P2_1_DOMAIN_ARCHITECTURE.md`](P2_1_DOMAIN_ARCHITECTURE.md) | Domain entities and org boundary |