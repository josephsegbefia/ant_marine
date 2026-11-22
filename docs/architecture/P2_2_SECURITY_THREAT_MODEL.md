# P2.2 — Security Threat Model (AuthN / AuthZ)

**Status:** Phase 2 design  
**Version:** 1.0 — 22 November 2026  
**Scope:** Identity, membership, RBAC, invitations, documents, reports, billing  
**Related:** [`P2_2_AUTHENTICATION_ARCHITECTURE.md`](P2_2_AUTHENTICATION_ARCHITECTURE.md), [`P2_2_AUTHORIZATION_ARCHITECTURE.md`](P2_2_AUTHORIZATION_ARCHITECTURE.md), [`ROLE_PERMISSION_SPEC.md`](ROLE_PERMISSION_SPEC.md)

---

## 1. Assets and trust boundaries

| Asset | Boundary |
|---|---|
| Client org data (projects, documents, messages) | Client tenant |
| Staff operational data | ANT Marine staff context |
| Credentials, sessions, invitation tokens | Auth subsystem |
| Permission catalogue, overrides | Admin-only writes |
| Billing records | Finance + scoped staff/client |
| Released reports | Client view via `ReportRelease` only |

**Trust:** Browser and client JSON are **untrusted**. Server enforces all access.

---

## 2. Threat scenarios and mitigations

| ID | Threat | Attack scenario | Mitigation | Testable criterion |
|---|---|---|---|---|
| T-01 | Cross-organisation access | User guesses `/client/projects/123` for another org | Policy scope on `organization_id`; deny if not member | Integration: member of Org A cannot load Org B project |
| T-02 | Cross-org staff leakage | Staff without path views client data | Two-layer authz; assignment or `view_all` + org FK | Deny staff without assignment on surveyor role |
| T-03 | Privilege escalation (client→staff) | Client grants self staff permission | Layer 1 domain separation; write-time rejection | Cannot save override with staff key on client membership |
| T-04 | Self-promotion | User edits own role to Owner / Super Admin | UI + `PermissionGranter` deny; protected keys | Self-edit role change 403 |
| T-05 | IDOR (insecure direct reference) | Download by document id only | Policy on `Document` before signed URL | Revoked permission → 404/403 on direct URL |
| T-06 | Stale session permissions | Admin revokes; user keeps working | `permission_epoch` invalidation next request | Revoke then GET → deny |
| T-07 | Invitation token reuse | Attacker reuses accept URL | Single-use or signed expiry; bind to email | Second accept fails |
| T-08 | Invitation role injection | Tamper role in POST | Server loads role from `Invitation` row, not params | Tampered role param ignored |
| T-09 | Ownership takeover | Admin creates second owner without transfer | Owner role protected; transfer flow only | Org admin invite as Owner rejected |
| T-10 | Concurrent permission edits | Two admins race on overrides | DB transaction + optimistic lock on membership version | Last write consistent audit |
| T-11 | Unauthorised document download | Broad `download` without confidential gate | `access_confidential` + classification | Confidential doc without grant denied |
| T-12 | Report approve without assignment | Reviewer approves unrelated project | `access_scope: review` assignment required | Approve without assignment denied |
| T-13 | Report release bypass | Release without approval workflow | Layer 1 workflow state machine | Release blocked if not approved |
| T-14 | Unauthorised billing adjust | Non-finance adjusts invoice | `billing.adjust` protected + step-up | Finance-only adjust test |
| T-15 | Finance overreach | Finance views full project technical data | `billing.view_all` + minimal fields policy | Finance cannot open inspection checklist |
| T-16 | Org switch injection | Client sends `organization_id=other` | `Current` from session membership only | Param ignored for authz |
| T-17 | Session fixation | Attacker fixes session pre-login | Regenerate session id on login | Session id changes after auth |
| T-18 | Bulk permission without confirm | Script bulk grants | `team.bulk_permission_change` + step-up | Bulk without step-up blocked |
| T-19 | Grant beyond authority | Manager grants permission they lack | `PermissionGranter` delegation bounds | Granter without key → 422 |
| T-20 | Last Super Admin removal | Accidental lockout | Succession guard in service | Cannot remove last super admin |

---

## 3. Security requirements (Phase 3–5)

- Deny-by-default policies on all portal controllers.
- Brakeman + custom authorization integration tests in CI.
- Audit all permission and ownership changes.
- Signed short-lived download URLs **after** policy pass.
- Rate limits on auth and invite endpoints.

---

## 4. Acceptance criteria (checklist)

Phase 3 foundation must verify at minimum:

- [ ] T-01, T-02, T-03, T-05, T-06 automated tests pass
- [ ] T-07, T-08 invitation flow tests
- [ ] T-09 owner protection tests
- [ ] T-11 confidential classification tests
- [ ] T-12, T-13 report workflow tests
- [ ] T-14, T-15 finance scope tests
- [ ] T-19 delegation bounds unit tests
- [ ] T-20 last-holder tests

Phase 5 expands to full table regression.

---

## 5. Out of scope (P2.2)

Infrastructure threats (DDoS, host compromise), ADR-010 encryption PoC, email provider spoofing — tracked separately.