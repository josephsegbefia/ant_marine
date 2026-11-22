# P2.5 — Phase 3 Implementation Readiness

**Version:** 1.0 — 22 November 2026  
**Already done (B0):** Rails 8.1 app, PostgreSQL 17 docker, CI, `verify_foundation.sh`, smoke tests — **do not repeat**.

---

## 1. Foundation before business features

| Capability | Must exist before |
|---|---|
| Users + sessions (ADR-017) | Any portal login |
| Organizations + memberships | Client/staff areas |
| Permission catalogue seeds | Policy checks |
| EffectivePermissions + ApplicationPolicy | All protected routes |
| Audit events on security writes | Permission/ownership changes |
| Layout shells (public/client/staff) | Feature UI |
| Current membership context | Org-scoped queries |

---

## 2. Dependency-ordered backlog

### Wave A — Identity & RBAC (no confidential files)

| ID | Work | Migrations | Depends |
|---|---|---|---|
| P3-A1 | Rails authentication generator + User extensions | users | B0 |
| P3-A2 | organizations, memberships | yes | P3-A1 |
| P3-A3 | permissions, role_permissions, seeds | yes | P3-A2 |
| P3-A4 | invitations | yes | P3-A2 |
| P3-A5 | permission_overrides, audit_events STI | yes | P3-A3 |
| P3-A6 | EffectivePermissions, PermissionGranter, Pundit base | code | P3-A5, ADR-012 proposed |
| P3-A7 | Auth integration tests (T-01,03,06,07,19,20) | tests | P3-A6 |
| P3-A8 | Portal layout shells + design tokens from Phase 1 HTML | views | Phase 1 tokens |

### Wave B — Infrastructure

| ID | Work | Notes |
|---|---|---|
| P3-B1 | Solid Queue production config | Existing gem |
| P3-B2 | Action Mailer + adapter stub | ADR-009 OPEN |
| P3-B3 | Active Storage **dev** bucket wiring | No confidential prod |
| P3-B4 | **P3-STORAGE-01** encryption PoC | ADR-010 gate |
| P3-B5 | CI: policy test job | Extend `.github/workflows/ci.yml` |

### Wave C — Schema foundations (post Wave A approval)

Per [`P2_3_MIGRATION_PLAN.md`](P2_3_MIGRATION_PLAN.md) slices 06–10 — **only after** stakeholder pack acknowledged.

| ID | Slice | Blocked by |
|---|---|---|
| P3-C1 | Commercial tables | ADR-014, 006 proposed |
| P3-C2 | Projects/assignments | P2-OD-043 |
| P3-C3 | Documents/reports schema | ADR-010 for go-live |
| P3-C4 | Billing/notifications | ADR-008 |
| P3-C5 | CMS tables | None |

### Wave D — Feature slices (Phase 4)

See master spec F4-03, F4-04, F4-04b — **after** Wave A + relevant Wave C.

---

## 3. What not to implement first

- Live payment capture  
- Confidential client file production path  
- Team & Permissions UI (ADR-013)  
- Full analytics (M12)  
- Vessel registry (P2-OD-024) unless approved

---

## 4. Suggested sprint 1 (CONDITIONAL GO)

1. P3-A1–A3 migrations + seeds in development only.  
2. P3-A6 read-only policy specs against fixtures.  
3. P3-A8 static shells matching design studio colours/typography from handoff.  
4. No commercial tables until ADR batch approved.

---

## 5. Exit evidence for Phase 3 partial gate

- `bin/rails test` includes cross-org denial + permission epoch.  
- Fresh clone + `verify_foundation.sh` pass.  
- Documented list of **intentionally deferred** items from stakeholder pack.