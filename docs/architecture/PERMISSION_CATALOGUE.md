# ANT Marine — Permission Catalogue

**Status:** Phase 2 product contract  
**Internal keys** are for engineering and policies only — **never shown in client or staff UI**.  
**Display name** and **explanation** are the user-facing strings.

Legend:

- **Domain:** `staff` | `client`
- **Override:** `yes` = administrators may grant/deny per user; `protected` = role-only, no override; `deny_only` = only explicit deny allowed
- **Restrictions:** additional notes (SoD, assignment, etc.)

---

## Service requests & inquiries

| Key | Display name | Explanation | Category | Domain | Override | Default roles (staff / client) | Restrictions |
|---|---|---|---|---|---|---|---|
| `inquiries.view_all` | View all service requests | See every new and open request in the queue | service_requests | staff | yes | ops_mgr, coordinator, super_admin / — | Staff domain only |
| `inquiries.view_assigned` | View assigned requests | See requests linked to your work | service_requests | staff | yes | surveyor, general_staff / — | |
| `inquiries.qualify` | Qualify service requests | Mark requests qualified or not, add intake notes | service_requests | staff | yes | coordinator, ops_mgr, super_admin / — | |
| `inquiries.create` | Submit a service request | Start a new request for your organisation | service_requests | client | yes | owner, org_admin, manager, member / — | Own org only |
| `inquiries.view_org` | View your organisation’s requests | See requests submitted by your company | service_requests | client | yes | all client roles / — | Own org only |

## Quotations

| Key | Display name | Explanation | Category | Domain | Override | Default roles | Restrictions |
|---|---|---|---|---|---|---|---|
| `quotes.view_all` | View all quotations | See quotes across client organisations | quotations | staff | yes | coordinator, ops_mgr, finance, super_admin | Assignment may still narrow list |
| `quotes.create` | Prepare quotations | Draft and revise quotes before sending | quotations | staff | yes | coordinator, ops_mgr, super_admin | |
| `quotes.send` | Send quotations to clients | Release a quote version to the client portal | quotations | staff | yes | coordinator, ops_mgr, super_admin | |
| `quotes.withdraw` | Withdraw quotations | Stop an outstanding quote from being accepted | quotations | staff | yes | coordinator, ops_mgr, super_admin | |
| `quotes.view_org` | View your quotes | See quotes sent to your organisation | quotations | client | yes | all client roles | Own org |
| `quotes.accept` | Accept a quotation | Accept a quote on behalf of your organisation | quotations | client | yes | owner, manager | Configurable; not member by default |
| `quotes.decline` | Decline a quotation | Decline a quote with a recorded response | quotations | client | yes | owner, manager | |

## Bookings

| Key | Display name | Explanation | Category | Domain | Override | Default roles | Restrictions |
|---|---|---|---|---|---|---|---|
| `bookings.view_all` | View booking calendar | See visit and survey scheduling across jobs | bookings | staff | yes | coordinator, ops_mgr, surveyor, super_admin | |
| `bookings.confirm` | Confirm visit dates | Turn a preferred date into a confirmed booking | bookings | staff | yes | coordinator, ops_mgr, super_admin | |
| `bookings.request` | Request a visit date | Ask for a preferred appointment (not yet confirmed) | bookings | client | yes | owner, manager, member | Public form uses unauthenticated flow |

## Projects & assignments

| Key | Display name | Explanation | Category | Domain | Override | Default roles | Restrictions |
|---|---|---|---|---|---|---|---|
| `projects.view_all` | View all projects | Browse every active client project | projects | staff | yes | ops_mgr, coordinator, super_admin | |
| `projects.view_assigned` | View assigned projects | See projects you are assigned to | projects | staff | yes | surveyor, reviewer, finance, general_staff | Requires `Assignment` (or org-wide `projects.view_all`); see ROLE_PERMISSION_SPEC §5 |
| `projects.create` | Create projects | Open a new project after quote acceptance | projects | staff | yes | coordinator, ops_mgr, super_admin | Idempotent guard on quote |
| `projects.manage` | Update project details | Edit internal and client-visible status and dates | projects | staff | yes | coordinator, ops_mgr, super_admin | |
| `projects.assign` | Assign team members | Add or change staff on a project | projects | staff | yes | coordinator, ops_mgr, super_admin | |
| `projects.view_org` | View your projects | See projects for your organisation | projects | client | yes | all client roles | Org boundary |
| `assignments.participate` | Work on assigned tasks | Act on tasks for projects you are assigned to | projects | staff | yes | surveyor, general_staff | Assignment required |

## Vessels

| Key | Display name | Explanation | Category | Domain | Override | Default roles | Restrictions |
|---|---|---|---|---|---|---|---|
| `vessels.view_all` | View vessel register | See vessel records across clients | vessels | staff | yes | coordinator, surveyor, ops_mgr, super_admin | Often assignment-scoped |
| `vessels.manage` | Manage vessel records | Add and edit vessels for clients | vessels | staff | yes | coordinator, surveyor, super_admin | |
| `vessels.view_org` | View your vessels | See vessels registered to your organisation | vessels | client | yes | owner, manager, member | |
| `vessels.manage_org` | Manage your vessels | Add and edit your organisation’s vessels | vessels | client | yes | owner, manager | |

## Inspections & checklists

| Key | Display name | Explanation | Category | Domain | Override | Default roles | Restrictions |
|---|---|---|---|---|---|---|---|
| `inspections.view` | View inspections | See inspection records for accessible projects | inspections | staff | yes | surveyor, coordinator, reviewer, ops_mgr | Assignment or view_all project |
| `inspections.edit` | Complete checklists | Fill in inspection checklists and findings | inspections | staff | yes | surveyor | Assignment required |
| `inspections.view_client` | View inspection summary | See client-appropriate inspection progress | inspections | client | yes | manager, member | Released/safe summary only |

## Documents

| Key | Display name | Explanation | Category | Domain | Override | Default roles | Restrictions |
|---|---|---|---|---|---|---|---|
| `documents.upload` | Upload documents | Add files to a project or request | documents | staff, client | yes | surveyor, coordinator / owner, manager, member | Org + project |
| `documents.download` | Download documents | Download files you are allowed to see | documents | staff, client | yes | broad staff / all client | Policy per classification |
| `documents.preview` | Preview documents | View allowed previews in the browser | documents | staff, client | yes | broad staff / all client | Scan must pass |
| `documents.manage` | Manage document records | Change categories, workflow state, internal metadata | documents | staff | yes | coordinator, surveyor, super_admin | |
| `documents.access_confidential` | View confidential documents | Access highly restricted file classifications | documents | staff, client | deny_only | super_admin / owner | Ops manager via explicit grant only (P2.2 least privilege); see §5 confidential path |
| `documents.request_upload` | Request files from client | Ask the client to upload specific materials | documents | staff | yes | coordinator, surveyor | |

## Reports

| Key | Display name | Explanation | Category | Domain | Override | Default roles | Restrictions |
|---|---|---|---|---|---|---|---|
| `reports.draft` | Draft reports | Create and edit report drafts | reports | staff | yes | surveyor | Assignment |
| `reports.review` | Review reports | Open reports in technical review | reports | staff | yes | technical_reviewer, ops_mgr | |
| `reports.approve` | Approve reports | Approve a report version for release consideration | reports | staff | protected | technical_reviewer | SoD: not own draft |
| `reports.release` | Send reports to clients | Release an approved report to the client portal | reports | staff | protected | coordinator, ops_mgr, super_admin | Separate from approve |
| `reports.view_org` | View released reports | Download reports released to your organisation | reports | client | yes | all client roles | Requires ReportRelease |
| `reports.view_draft_staff` | View draft reports | See in-progress reports internally | reports | staff | yes | surveyor, reviewer, coordinator | Not client |

## Billing

| Key | Display name | Explanation | Category | Domain | Override | Default roles | Restrictions |
|---|---|---|---|---|---|---|---|
| `billing.view` | View invoices | See invoices for accessible projects or org | billing | staff, client | yes | coordinator, ops_mgr / owner, client_finance, manager | Project-scoped; minimal detail |
| `billing.view_all` | View company billing | List and view invoices across client organisations | billing | staff | yes | finance_officer, super_admin | No project assignment required; see P2_2 §5.1 |
| `billing.manage` | Manage invoices | Create and edit invoice records | billing | staff | yes | finance_officer, super_admin | |
| `billing.adjust` | Adjust issued invoices | Change amounts or status after issue | billing | staff | protected | finance_officer, super_admin | Reauth + reason |
| `billing.record_payment` | Record payments | Log payment received against an invoice | billing | staff | yes | finance_officer | |

## Messages & notifications

| Key | Display name | Explanation | Category | Domain | Override | Default roles | Restrictions |
|---|---|---|---|---|---|---|---|
| `messages.view` | View project messages | Read conversation on accessible projects | messages | staff, client | yes | assigned staff / all client | Project scope |
| `messages.send` | Send project messages | Post messages on accessible projects | messages | staff, client | yes | assigned staff / member+ | |
| `notifications.manage_preferences` | Manage alert preferences | Choose which email or in-app alerts you receive | notifications | staff, client | yes | all | Self only |

## Training & public content

| Key | Display name | Explanation | Category | Domain | Override | Default roles | Restrictions |
|---|---|---|---|---|---|---|---|
| `content.view_draft` | View draft website content | See unpublished pages and articles | content | staff | yes | content_manager, super_admin | |
| `content.publish` | Publish website content | Make approved content live | content | staff | protected | content_manager, super_admin | |
| `content.manage` | Edit website content | Change drafts of services, articles, training | content | staff | yes | content_manager | |
| `training.manage` | Manage training catalogue | Edit course listings and sessions | training | staff | yes | content_manager, coordinator | |

## Analytics

| Key | Display name | Explanation | Category | Domain | Override | Default roles | Restrictions |
|---|---|---|---|---|---|---|---|
| `analytics.view_business` | View business insights | See inquiry, booking and turnaround metrics | analytics | staff | yes | ops_mgr, super_admin, content_manager | No PII in aggregates |
| `analytics.export` | Export summaries | Download aggregate reports for management | analytics | staff | yes | ops_mgr, super_admin | |

## Team & company settings

| Key | Display name | Explanation | Category | Domain | Override | Default roles | Restrictions |
|---|---|---|---|---|---|---|---|
| `team.view` | View team members | See people in your organisation | team | staff, client | yes | all staff / all client | Same org |
| `team.invite` | Invite team members | Send invitations to join your organisation | team | staff, client | yes | super_admin, ops_mgr / owner, org_admin, manager | Client cannot invite staff domain |
| `team.manage_roles` | Change member roles | Set another member’s role within allowed types | team | client | protected | owner | Org admin limited by delegation |
| `team.manage_staff_roles` | Change staff roles | Set ANT Marine staff roles | team | staff | protected | super_admin | |
| `team.manage_permissions` | Manage team permissions | Grant or remove individual permissions | team | client | protected | owner | |
| `team.manage_staff_permissions` | Manage staff permissions | Grant or remove staff permissions | team | staff | protected | super_admin | |
| `team.manage_team_delegated` | Manage team (delegated) | Limited team admin on behalf of owner | team | client | yes | org_admin | Cannot assign `client.org_owner`; use transfer flow only |
| `team.suspend` | Suspend team members | Temporarily disable a member’s access | team | staff, client | yes | super_admin, ops_mgr / owner, org_admin | |
| `team.transfer_ownership` | Transfer organisation ownership | Hand highest client authority to another member | team | client | protected | owner | Confirmation flow |
| `team.bulk_permission_change` | Bulk permission changes | Apply permission changes to many users at once | team | staff, client | protected | super_admin / owner | Reauth |
| `company.settings_view` | View company settings | See organisation profile and preferences | company_settings | client | yes | all client | |
| `company.settings_manage` | Manage company settings | Update organisation details visible in the portal | company_settings | client | yes | owner, org_admin | |
| `company.settings_manage_staff` | Manage ANT Marine company settings | Update internal company configuration | company_settings | staff | yes | super_admin, ops_mgr | |

## Audit & history

| Key | Display name | Explanation | Category | Domain | Override | Default roles | Restrictions |
|---|---|---|---|---|---|---|---|
| `audit.view_org` | View activity history | See significant actions for your organisation | audit | client | yes | owner, org_admin, manager | Filtered |
| `audit.view_staff` | View security history | See staff and system security events | audit | staff | yes | super_admin, ops_mgr | |
| `audit.view_permission_changes` | View permission changes | See who changed roles and access | audit | staff, client | yes | super_admin / owner | |

---

## Protected staff-only permissions (never assignable to client domain)

- All keys with domain `staff` only (no client column in defaults).
- `team.manage_staff_roles`, `team.manage_staff_permissions`
- `inquiries.view_all`, `quotes.create`, `reports.release` (client never)

## Catalogue maintenance

- New permissions require migration/seed + matrix update + policy hooks.
- Deprecate keys rather than reuse identifiers.
- Version catalogue in `permissions_catalog_version` when seeds change.