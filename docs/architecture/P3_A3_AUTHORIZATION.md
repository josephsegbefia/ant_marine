# P3-A3 — Roles, permissions and authorisation engine

**Status:** Implemented on `main` (local checkpoint). **Supersedes** interim invitation role lists as the primary gate; P3-A2 ceilings remain as a second layer.

## Sources of truth

| Layer | Location |
|-------|----------|
| Permission keys (71) | `docs/architecture/PERMISSION_CATALOGUE.md` → `Authorization::GeneratedPermissionDefinitions` |
| Role defaults (13) | `docs/architecture/DEFAULT_ROLE_MATRIX.md` → `Authorization::RoleDefaults` |
| Resolution rules | `docs/architecture/ROLE_PERMISSION_SPEC.md` §4–6 |
| ADRs | `docs/DECISIONS.md` — ADR-012 (Pundit + EffectivePermissions), ADR-015 (last owner) |

Catalogue rows live in `permissions`; defaults in `role_permissions`; per-membership changes in `permission_overrides`.

## Resolution (`Authorization::EffectivePermissions`)

Fail-closed order for an **active** membership in an **active** organisation:

1. Key must exist in the catalogue and be **applicable** to the membership domain (staff vs client).
2. Client memberships never receive **staff-only** permission rows (`ProtectedRules`).
3. **Deny** override wins.
4. **Allow** override grants even when role default is absent.
5. Otherwise role default from `role_permissions` for `membership.role_key`.

Suspended/removed memberships deny all catalogue checks.

## Overrides (`Authorization::PermissionGranter`)

Internal service only — **no routes or UI** in P3-A3.

- `grant_allow!`, `grant_deny!`, `remove_override!`
- Actor must be active in the **same org** as the target.
- Staff actors need `team.manage_staff_permissions`; client actors need `team.manage_permissions` or (for non-`protected` keys) `team.manage_team_delegated`.
- Cannot grant allow for keys the actor does not hold.
- `override_rule`: `protected` → no overrides; `deny_only` → allow overrides rejected.

Each change bumps `memberships.permission_epoch` and writes `audit_events` (`permission.override_granted`, `permission.override_removed`, `permission.change_rejected`).

## Owner protection (`Authorization::OwnerProtection`)

Blocks transitions that would leave **zero** active `staff.super_administrator` (ANT Marine) or `client.org_owner` (client org). Used by granter hooks and tests; full membership lifecycle wiring continues in later slices.

## Pundit

- Gem: `pundit` (ADR-012).
- `ApplicationPolicy` delegates to `EffectivePermissions`.
- `InvitationPolicy` requires `team.invite` then defers to `Invitations::Policy` for **P3-A2 ceilings** (super admin / org owner not inviteable via UI, ops manager staff targets, etc.).

Staff/client invitation controllers and sidebar nav use `team.invite`; they do **not** broaden authority beyond P3-A2.

## Session freshness (P2-OD-040 pattern)

`sessions.permission_epoch_at_issue` is set at login. On each request, `Authentication#resume_session` refreshes the stored epoch when `membership.permission_epoch` has changed (no forced logout). Password `security_version` behaviour is unchanged.

## Resource scope (Phase 4 contract)

`Authorization::ResourceScope` is a **stub** — returns `false` / not implemented for record-level checks until assignments and Phase 4 resources exist (P2-OD-042). Feature gates in P3-A3 use catalogue keys only.

## Seeding

`Authorization::CatalogueSeeder.seed!` (from `db/seeds.rb` and `test_helper` parallel setup) idempotently upserts permissions and role permissions. Safe to re-run after `db:prepare`.

## Test map

| Area | Files |
|------|--------|
| Catalogue | `test/lib/authorization/permission_catalogue_test.rb` |
| Role defaults | `test/lib/authorization/role_defaults_test.rb` |
| Effective permissions | `test/services/authorization/effective_permissions_test.rb` |
| Granter | `test/services/authorization/permission_granter_test.rb` |
| Owner protection | `test/services/authorization/owner_protection_test.rb` |
| Audit | `test/services/authorization/audit_test.rb` |
| Session epoch | `test/integration/permission_epoch_session_test.rb` |
| Invitations | `test/services/invitations/policy_test.rb`, invitation integration tests |
| Pundit | `test/policies/invitation_policy_test.rb` |

## Explicit exclusions (this slice)

Team & Permissions UI (M07/C15), Phase 4 domain models, production SMTP, MFA A04, GitHub push.