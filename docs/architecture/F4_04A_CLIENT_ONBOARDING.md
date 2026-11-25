# F4-04A — Client onboarding, organization management & client portal

**Status:** Code complete — local `main` only (not pushed)  
**Baseline:** `bf25897`  
**Prior accepted checkpoint:** F4-03 `fe4cf5d` (UI commits after F4-03 preserved)  
**Hard stops observed:** no push, deploy, live email, commercial acceptance, automatic projects, F4-04B/F5, Design Studio edits, DB reset, schema-format switch.

## 1. Product outcome

Authorized staff manage client organisations, onboard clients from qualified enquiries with an explicit confirmation, prepare secure invitations through the existing Phase 3 invitation foundation, and activate client accounts through normal authentication.

Authenticated clients use a read-only portal to view organisation-scoped service requests and **explicitly released** quotations (simulated mode only in this checkpoint), including exact-version PDF download. Accept/decline and project conversion remain disabled.

## 2. Design Studio mapping

| Studio ID | Intent | Implemented route / surface |
|---|---|---|
| S16 Client directory | List client organisations | `/staff/clients` |
| S17 Client profile | Organisation detail, contacts, requests, quotes | `/staff/clients/:id` (tabs: overview, access, requests, quotations, activity) |
| Enquiry-led onboarding | Set up client access | `/staff/enquiries/:id/onboard` (qualified only) |
| A02/A03 Invitation activation | Existing activation flow | Unchanged Phase 3 invitation accept routes |
| C01 Client home | Overview | `/client` |
| C02 My requests | Request list | `/client/requests` |
| C03 Request details | Request detail (client-facing fields) | `/client/requests/:id` |
| C04 Review quotation | Read-only quote; **no Accept** in F4-04A | `/client/quotations/:id` + `/client/quotations/:id/pdf` |
| Account | Profile / sign out | `/client/account` |

Future modules (projects, documents, reports, invoices, messages) are omitted or described as unavailable — never presented as working.

## 3. Existing identity architecture (reused)

No parallel auth/membership/invitation systems.

| Concept | Implementation |
|---|---|
| ANT Marine org | `Organization.kind = ant_marine` |
| Client org | `Organization.kind = client` + optional `reference_number` (`CLT-YYYY-NNNN`) + `profile` jsonb |
| Contact without portal | Organisation profile fields / enquiry contact; **not** a User |
| Authenticated client | `User` + active `Membership` with client `role_key` |
| Invitation | Existing `Invitation` + `Invitations::Issue` / accept / digest token |
| Permissions | Existing catalogue; client view via `inquiries.view_org` / `quotes.view_org` |
| Audit | `AuditEvent.record!` |

Email match alone never grants membership. Membership alone never grants commercial acceptance UI. Organisation linkage alone never exposes quotations.

## 4. Models and migrations

Migration `db/migrate/20261126010000_f4_04a_client_portal.rb`:

- `organizations.reference_number` (unique partial index where present)
- `quote_portal_releases` — explicit portal visibility for one exact `quote_revision` to one `client_organization`
  - `mode` check constraint: `'simulated'` only in this checkpoint
  - unique `(quote_revision_id, client_organization_id)`
  - optional revoke columns

Services under `app/services/clients/`:

- `CreateOrganization` / `UpdateOrganization`
- `OnboardFromEnquiry` (transactional link + invite)
- `ReleaseQuoteToPortal` (simulated; refused in production)
- `PortalQuoteVisibility` (client-scoped active releases)
- `MembershipLifecycle` (suspend / revoke + session revoke)

## 5. Staff clients workspace

Routes: `/staff/clients`, `/new`, `/:id`, `/:id/edit`, membership suspend/revoke, nested simulated portal release create.

Authorization: `OrganizationPolicy` — staff with `inquiries.qualify` / `inquiries.view_all` / `quotes.view_all` (index/show); create/update need qualify; access management needs `team.invite` / lifecycle needs `team.suspend`.

Summary cards use genuine scoped counts only.

## 6. Enquiry-led onboarding

Eligible when enquiry `current_status == qualified`, actor holds `inquiries.qualify` + `team.invite`.

Steps in one staff form: organisation (create or select + advisory duplicates), representative, portal role (`client.*` only), explicit confirmation.

Creates/links organisation, sets `service_inquiries.client_organization_id`, issues invitation via `Invitations::Issue`, audits `enquiry.linked_to_client_organization` and `client_onboarding.completed`.

Refuses staff emails, active duplicate memberships, forged org/role IDs, unqualified enquiries. Does not create projects or commercial decisions.

## 7. Commercial release semantics

| Concept | Rule in F4-04A |
|---|---|
| Approved quotation | Staff-visible; **not** client-visible |
| Test-mode email issuance (F4-02B) | Still not a portal release |
| `QuotePortalRelease` simulated | Client-visible when active; labelled simulated; no accept |
| Live portal release | Not implemented; production refuses simulated path |

PDF: authenticated client, active membership, `quotes.view_org`, active release for that org/version, `Cache-Control: private, no-store`, filename may include `-SIMULATED`.

## 8. Access revocation

`MembershipLifecycle.revoke!` / `suspend!` set membership status, bump permission epoch, revoke related sessions. Subsequent portal requests redirect to sign-in or workspace selection. Historical quotes/enquiries remain.

## 9. Hard stops preserved

- No Accept / Decline / commercial revision / project conversion UI or records
- No live SMTP; invitations use existing isolated delivery
- No automatic project creation
- Internal enquiry notes never rendered on client request/quote pages

## 10. Database history protection proposal (for F4-04B — not implemented)

See § Database history protection proposal below (ADR-F4-02B-006). F4-04A delivers the proposal only.

## 11. Migration / restart

1. `bin/rails db:migrate` (development + test)
2. Restart Puma / Solid Queue so schema cache sees `reference_number` and `quote_portal_releases`
3. Permission catalogue needs no new keys for core F4-04A views (`inquiries.view_org` / `quotes.view_org` already in client roles)

## 12. F4-04B integration boundary

Before enabling acceptance:

- Authenticated representative with explicit decision authority (`quotes.accept` alone is insufficient without workflow)
- Active membership + exact released **live** offer version
- Valid outstanding commercial offer (not simulated)
- Informed confirmation, atomic/idempotent decision record, immutable history, audit
- No project creation without separate authorized conversion rules

## 13. Outstanding production gates (unchanged)

F4-01 visual acceptance, design sign-off, editorial content, tax/deposit/legal terms, acceptance wording, delivery policy, production email/domain, storage encryption/malware/backups, DB history protection, restricted DB privileges, deployment acceptance.

## Database history protection proposal (ADR-F4-02B-006)

**Goal:** defend approved quotation content against privileged raw SQL and accidental updates, beyond application guards.

### Recommended approach (combined)

1. **Switch to `structure.sql`** so PostgreSQL triggers and check constraints dump/restore faithfully (`config.active_record.schema_format = :ruby` today cannot express triggers).
2. **Triggers** on `quote_revisions` / `quote_line_items` (and recipient snapshot columns) blocking UPDATE/DELETE when `version_frozen` / approved/issued; allow only whitelisted metadata transitions (issuance timestamps, supersession flags) via `SET LOCAL` session variables or a dedicated SECURITY DEFINER function called from app services.
3. **Append-only** future client decision tables (F4-04B) with no UPDATE/DELETE for ordinary roles.
4. **Least-privilege runtime DB role** for the app: DML on business tables, no DROP/ALTER; migrations run as a separate admin role.
5. **CI:** restore from `structure.sql` in CI; add a test that connects as the app role and asserts direct SQL UPDATE on a frozen revision fails; keep existing model-level regression tests.
6. **Rollback limitations:** trigger migrations are reverse-order DROP TRIGGER; restoring older `schema.rb` eras will not recreate triggers — document restore verification.
7. **Honest limit:** triggers do not stop a superuser or owner role; they raise the cost of accidents and constrain the runtime app role.

**Do not** implement the schema-format switch or production privilege changes in F4-04A.
