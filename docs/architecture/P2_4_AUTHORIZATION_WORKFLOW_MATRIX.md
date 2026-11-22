# P2.4 — Authorization Workflow Matrix

**Version:** 1.0 — 22 November 2026  
**Catalogue:** [`PERMISSION_CATALOGUE.md`](PERMISSION_CATALOGUE.md)  
**Resolution:** [`ROLE_PERMISSION_SPEC.md`](ROLE_PERMISSION_SPEC.md) layers 1–6 + resource scope

---

## 1. Rules

1. Every transition requires **authentication** (except public inquiry submit).
2. **Feature permission** from matrix below **plus** resource scope where noted.
3. **Protected** catalogue keys cannot be granted by non–Super Admin without explicit override rules.
4. Client actors never hold `staff.*` keys.

---

## 2. Commercial

| Transition | Staff roles (default) | Client roles (default) | Scope |
|---|---|---|---|
| Submit inquiry (public) | — | — | — |
| Submit inquiry (portal) | — | member+ | own org future |
| Qualify inquiry | coordinator, ops_mgr | — | `inquiries.view_all` |
| Create/send quote | coordinator, ops_mgr | — | view_all |
| Accept quote | — | owner, manager | org + sent revision |
| Decline quote | — | owner, manager | org |
| Withdraw quote | coordinator, ops_mgr | — | view_all |

Override: member with `quotes.accept` grant (ADR-006 proposed).

---

## 3. Project & assignment

| Transition | Staff | Scope |
|---|---|---|
| Create project | coordinator, ops_mgr, super_admin | quote client org |
| Manage status | coordinator, ops_mgr, assignee coordinator | view_all or assign |
| Assign staff | coordinator, ops_mgr | `projects.assign` + project |
| Participate fieldwork | surveyor | assignment delivery |
| Review report | technical_reviewer | assignment review |

---

## 4. Documents & files

| Transition | Staff | Client | Scope |
|---|---|---|---|
| Upload | surveyor, coordinator | owner, manager, member | project/org |
| Download | policy + classification | same | scan available |
| Confidential view | + `documents.access_confidential` | owner default | classification |
| Request upload | coordinator, surveyor | — | assignment |

Ops manager confidential: **not** default; grant only (P2.2).

---

## 5. Reports

| Transition | Role | Permission | SoD |
|---|---|---|---|
| Draft / submit | surveyor | `reports.draft` | assignment |
| Review | technical_reviewer | `reports.review` | assignment review |
| Approve | technical_reviewer | `reports.approve` | ≠ sole author |
| Release | coordinator, ops_mgr | `reports.release` | separate from approve |
| Client view | client roles | `reports.view_org` | release exists |

---

## 6. Billing

| Transition | Staff | Scope |
|---|---|---|
| View invoices | finance_officer | `billing.view_all` — **no** assignment |
| Manage / issue | finance_officer | org |
| Adjust / void | finance_officer, super_admin | protected + step-up |
| Client view | client_finance, owner, manager | org |

---

## 7. Team & permissions

| Transition | Staff portal | Client portal |
|---|---|---|
| Invite staff | super_admin, ops_mgr (`team.invite`) | — |
| Invite client | — | owner, delegated admin |
| Change role | super_admin (`team.manage_staff_roles`) | owner (`team.manage_roles`) |
| Edit permissions | super_admin | owner |
| Transfer ownership | — | owner (`team.transfer_ownership`) |
| Bulk change | super_admin / owner | step-up |

Org administrator **cannot** assign `client.org_owner`.

---

## 8. Security invariants (workflow-level)

| ID | Invariant |
|---|---|
| W-01 | No `report_release` without `approved` review on same version |
| W-02 | No download when `scan_status != available` |
| W-03 | No project create without `quote_responses.response = accepted` |
| W-04 | No client accept on withdrawn/expired quote |
| W-05 | Permission change bumps `membership.permission_epoch` before commit returns |
| W-06 | Client admin UI cannot call staff controllers |