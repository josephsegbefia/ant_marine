# P2.2 — Authorization Architecture

**Status:** Phase 2 design — documentation only  
**Version:** 1.0 — 22 November 2026  
**Authoritative RBAC product spec:** [`ROLE_PERMISSION_SPEC.md`](ROLE_PERMISSION_SPEC.md) v1.1  
**Catalogue / matrix:** [`PERMISSION_CATALOGUE.md`](PERMISSION_CATALOGUE.md), [`DEFAULT_ROLE_MATRIX.md`](DEFAULT_ROLE_MATRIX.md)

---

## 1. Scope

Covers **membership**, **roles**, **permission resolution**, **resource scope**, **delegated administration**, **portal separation**, and the **Team & Permissions UI contract**.

Authentication is in [`P2_2_AUTHENTICATION_ARCHITECTURE.md`](P2_2_AUTHENTICATION_ARCHITECTURE.md).

---

## 2. Portal and domain boundaries

### 2.1 Shared identity, separate portals

One `User` may hold:

- Exactly one **staff** `Membership` in `Organization` where `kind = ant_marine` (typical employee), and/or
- One or more **client** `Membership` rows in distinct client organisations.

| Portal | Roles | Membership org kind |
|---|---|---|
| Client | Owner, Org Administrator, Client Manager, Client Member, Client Finance | `client` |
| Staff | Super Admin through General Staff | `ant_marine` |

**Hard rule (layer 1):** Effective permissions computed in client context **never** include staff-domain keys, and vice versa. Cross-domain grants are rejected at write time and denial at read time.

### 2.2 Namespace enforcement

```
Request → authenticate User
        → resolve Current.membership (server-side)
        → assert namespace matches membership.domain
        → EffectivePermissions + Policy
```

Client-supplied `organization_id` query params are **hints for UX only**; server loads membership from session-backed `Current.membership_id` validated against `user_id`.

---

## 3. Organisation membership

### 3.1 Entities (logical)

| Entity | Purpose |
|---|---|
| `Organization` | Tenant; `kind` ∈ `ant_marine`, `client` |
| `Membership` | `user_id`, `organization_id`, `role_key`, `status`, `permission_epoch` |
| `Invitation` | Pending membership; email, role_key, inviter, token, expires_at |

### 3.2 Multiple client memberships

- User may belong to Org A and Org B (e.g. consultant to two companies).
- **Active organisation** stored as `Current.membership_id` (client portal) after explicit switch (screen A06).
- All queries scoped: `where(organization_id: current_org.id)`.

### 3.3 Switching organisations

| Step | Behaviour |
|---|---|
| User selects org | POST switch endpoint |
| Server | Verify active `Membership` for target org; set session `current_membership_id`; bump request-local cache |
| Turbo | Full frame reload of client shell |
| Security | Previous org data not retained in instance variables; policy scope uses new org |

### 3.4 Suspension and removal

| Action | Effect |
|---|---|
| Suspend membership | `status: suspended`; deny authorization immediately; optional kill session if only membership |
| Remove membership | Soft-delete or `status: removed`; audit; revoke overrides |
| Suspend user globally | Block authentication; all memberships treated inactive |

### 3.5 Ownership transfer and last-holder rules

Per `ROLE_PERMISSION_SPEC` §6.4 and ADR-015 (proposed):

- Client: `team.transfer_ownership` only; cannot delete last Owner without nominee acceptance.
- Staff: cannot remove last `staff.super_administrator` without successor; Super Admin changes require step-up.

---

## 4. Permission engine

### 4.1 Resolution order (unchanged from P2.1)

1. Protected security restrictions  
2. Organisation and resource boundaries  
3. Explicit user **deny**  
4. Explicit user **grant**  
5. Default **role** permissions  
6. Deny by default  

Deny beats grant at the same layer. Layers 1–2 cannot be overridden by grants.

### 4.2 Rails structure (ADR-012 proposed)

```
app/
  models/
    permission.rb
    role_permission.rb
    permission_override.rb
    membership.rb
  policies/
    application_policy.rb
    project_policy.rb
    ...
  services/
    authorization/
      effective_permissions.rb      # catalogue + overrides + hierarchy
      permission_granter.rb         # delegation bounds validation
      current.rb                    # membership + org context
      resource_scope/
        project_access.rb
        billing_access.rb
        document_access.rb
        report_workflow.rb
```

**Pundit:** `authorize record, :action?` where `action?` maps to catalogue key + `EffectivePermissions#allows?(:projects, :view_all)` etc.

**Policy scope:** Every index query runs through `policy_scope` with org + assignment + classification rules.

### 4.3 Stable permission keys

- Seeded from [`PERMISSION_CATALOGUE.md`](PERMISSION_CATALOGUE.md); `permissions.key` immutable once shipped.
- UI displays **Display name** only.

### 4.4 Overrides

| Field | Values |
|---|---|
| `effect` | `allow`, `deny` |
| `permission_key` | must exist in catalogue for membership domain |
| `granted_by` | membership_id of granter |
| Override eligibility | catalogue `Override` column: `yes`, `protected`, `deny_only` |

UI states: **Inherit** (no row), **Allow**, **Deny**.

### 4.5 Effective permission calculation

```ruby
# Pseudocode — not implementation
EffectivePermissions.new(membership).allows?(:billing, :view_all)
# 1. return false if protected restriction blocks
# 2. return false if org boundary fails (wrong Current)
# 3. return false if explicit deny
# 4. return true if explicit grant
# 5. return true if role_permission join includes key
# 6. false
```

For **resource actions**, policies call `allows?` **then** `ResourceScope::*`.

### 4.6 Caching and invalidation

| Cache | Scope | Invalidate when |
|---|---|---|
| Request memo | Single request | N/A |
| Solid Cache (optional) | `membership_id` + `catalogue_version` | override/role change, membership suspend, `permission_epoch` bump |
| Session | `permission_epoch` snapshot | mismatch → reload permissions |

**Next request rule:** after grant/revoke, increment `membership.permission_epoch` (or global user epoch); following HTTP request sees new effective set without logout.

### 4.7 Protected permissions

Catalogue `protected` and `deny_only` keys — only eligible granters (Super Admin for `team.manage_staff_*`). Enforced in `PermissionGranter` before save.

### 4.8 Delegated administration

`PermissionGranter` enforces §6.5: granter holds permission or parent admin right; no owner creation by org admin; no staff keys to clients.

### 4.9 Audit

`PermissionChangeEvent` / `AuditEvent`: actor, subject membership, org, key, before/after, reason, IP (optional), timestamp UTC.

---

## 5. Resource-level authorisation (two layers)

See `ROLE_PERMISSION_SPEC` §5. Summary with **P2.2 refinements**:

| Path | Feature | Resource scope |
|---|---|---|
| Staff org-wide | `projects.view_all`, etc. | Client org on project FK |
| Assigned delivery | `projects.view_assigned`, `assignments.participate` | `Assignment` kind `surveyor`, `lead_surveyor`, … |
| Review (scoped) | `projects.view_assigned`, `reports.review`, `reports.approve` | `Assignment` with `access_scope: review` — **limited** to report artefacts and linked inspection summaries; not full project admin |
| Collaborator | `projects.view_assigned` + grant | `Assignment` kind `collaborator` or `DocumentAccessGrant` |
| Client org-wide | `projects.view_org` | `project.organization_id == current_org` |
| Client project tighten (future) | `projects.view_org` | Optional `ProjectParticipant` |
| Confidential docs | `documents.download` + `documents.access_confidential` | Classification flag |
| Report client view | `reports.view_org` | `ReportRelease` exists |
| Report staff draft | `reports.view_draft_staff` | Assignment or view_all + workflow state |
| Approve / release | `reports.approve`, `reports.release` | Separate workflow transitions; layer 1 SoD |

### 5.1 Refinement A — Finance Officers and billing

**Problem:** Finance must manage invoices without delivery `Assignment` or `projects.view_all`.

**Design:**

- Add catalogue key **`billing.view_all`** — view and list invoice records across client organisations for authorised finance staff (resource scope: invoice `organization_id` + finance role; **no** project assignment required).
- **`billing.view`** remains for project-scoped invoice visibility (coordinators, assigned staff).
- Policies expose **minimal** project fields on invoice screens (reference, client name) — not technical delivery detail.
- **`InvoicePolicy#show?`** uses `billing.view_all` OR (`billing.view` AND project accessible).

**Matrix change (P2.2):** Finance Officer defaults: `billing.view_all`, `billing.manage`, `billing.record_payment`, `billing.adjust`; **remove** `projects.view_assigned` from defaults.

### 5.2 Refinement B — Operations Manager confidential documents

**Problem:** Least privilege — confidential classification should not be org-wide default for Ops Manager.

**Design:**

- **Remove** `documents.access_confidential` from Operations Manager **default** role in matrix.
- Ops Manager retains `documents.download` / `preview` on **non-confidential** classifications per policy.
- Super Administrator (and explicit override grant) may grant confidential access when operations oversight requires it; audited.

**Matrix change (P2.2):** Update `staff.operations_manager` row and catalogue **Default roles** column for `documents.access_confidential` (remove `ops_mgr` from defaults).

### 5.3 Refinement C — Technical Reviewer scoped assignments

**Design:**

- `Assignment` attributes (proposed): `assignment_kind`, **`access_scope`** ∈ `delivery`, `review`, `collaborator`.
- Reviewers receive **`access_scope: review`** only:
  - May view assigned project **header** (status, client ref) — not manage project or assignments.
  - Document/report policies filter to categories: `report_draft`, `report_supporting`, `inspection_summary` (exact taxonomy in P2.3).
  - No `projects.manage`, `projects.assign`, `inspections.edit` unless separate assignment.

Default role remains assignment-only (`projects.view_assigned`); enforcement is policy + `access_scope`, not optional `view_all`.

---

## 6. Permission management UI contract

Implements ADR-013 intent; screen IDs from [`PHASE_1_DESIGN_CHANGE_REQUEST_TEAM_PERMISSIONS.md`](../design/PHASE_1_DESIGN_CHANGE_REQUEST_TEAM_PERMISSIONS.md) — **HTML studio unchanged** until DCR approved.

### 6.1 Staff > Team & Permissions (M07a–j)

| Screen | Behaviour contract |
|---|---|
| Member list | Role, status, last active; filter; no data from other domains |
| Invite | Email, role picker capped by inviter; send invitation |
| Role change | Allowed roles only; block protected self-promotion |
| Permission switches | Grouped by catalogue category; each switch **Inherit / Allow / Deny**; protected keys read-only unless granter eligible |
| Effective preview | Plain-English merged role + overrides; optional “why denied” for support |
| Restore defaults | Clears overrides for membership; confirm dialog |
| Save | Validation errors inline; success toast; audit row written |
| History | Paginated permission events; link M13 |
| Sensitive confirm | M07j step-up before bulk or super-admin grants |
| Suspension | Suspend membership → immediate revocation message; optional session end |

### 6.2 Company Settings > Team & Permissions (C15a–j)

Same patterns; **Owner** boundaries on C15d/C15e; C15i transfer ownership with dual confirm; org admin cannot select Owner role in picker.

### 6.3 Accessibility and responsive

- 44px touch targets; keyboard operable switches; labels from catalogue display names; errors announced to screen readers; reduced-motion safe transitions per Phase 1 handoff.

---

## 7. Catalogue and matrix updates (P2.2)

| Change | File |
|---|---|
| Add `billing.view_all` | `PERMISSION_CATALOGUE.md`, `DEFAULT_ROLE_MATRIX.md` |
| Finance defaults without `projects.view_assigned` | `DEFAULT_ROLE_MATRIX.md` |
| Remove Ops Mgr default confidential | `DEFAULT_ROLE_MATRIX.md`, catalogue default roles for `documents.access_confidential` |
| Document `Assignment.access_scope` | `P2_2_DATABASE_HANDOFF.md`, cross-ref `ROLE_PERMISSION_SPEC` §5 |

---

## 8. Document map

| Doc | Role |
|---|---|
| `ROLE_PERMISSION_SPEC.md` | Product RBAC requirements |
| `P2_2_SECURITY_THREAT_MODEL.md` | Attacks and acceptance tests |
| `P2_2_DATABASE_HANDOFF.md` | Persistence candidates |