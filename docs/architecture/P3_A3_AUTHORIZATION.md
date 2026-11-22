# P3-A3 — Roles, permissions and authorisation engine

**Status:** Implemented on `main` (local checkpoint). **Security acceptance reviewed** 2026-11-22. **Supersedes** interim invitation role lists as the primary gate; P3-A2 ceilings remain as a second layer.

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

Blocks transitions that would leave **zero** active `staff.super_administrator` (ANT Marine) or `client.org_owner` (client org). **Currently enforced in tests and callable API only** — suspend/demote/remove flows do not yet invoke `ensure_not_last_protected!` (Phase 3 follow-up / Team UI slice).

## Pundit

- Gem: `pundit` (ADR-012).
- `ApplicationPolicy` delegates to `EffectivePermissions`.
- `InvitationPolicy` requires `team.invite` then defers to `Invitations::Policy` for **P3-A2 ceilings** (super admin / org owner not inviteable via UI, ops manager staff targets, etc.).

Staff/client invitation controllers and sidebar nav use `team.invite`; they do **not** broaden authority beyond P3-A2.

## Session freshness (P2-OD-040 pattern)

`sessions.permission_epoch_at_issue` is set at login. On each request, `Authentication#resume_session` refreshes the stored epoch when `membership.permission_epoch` has changed (no forced logout). Password `security_version` behaviour is unchanged.

## Resource scope (Phase 4 contract)

`Authorization::ResourceScope` is a **stub** — returns `false` / not implemented for record-level checks until assignments and Phase 4 resources exist (P2-OD-042). Feature gates in P3-A3 use catalogue keys only.

## Catalogue initialization contract

| Environment | Command | Side effects |
|-------------|---------|--------------|
| **New / migrated DB** | `bin/rails db:prepare` then `bin/rails db:seed` | Upserts 71 `permissions` rows and `role_permissions` for 13 roles. **Does not** create users, organisations, or overrides. |
| **Existing development DB** | `bin/rails db:seed` when `permissions` empty or keys drift | Same as above; does not touch `memberships`, `users`, or `permission_overrides`. |
| **Test** | Automatic via `test_helper` (`parallelize_setup` + per-example guard) | Seeds **test database only** (isolated from development). Required because `db:prepare` does not run `db:seed` and `parallelize_setup` is skipped when worker count is 1. |

`Authorization::CatalogueSeeder`:

- Idempotent upsert by permission `key` and `RolePermission.find_or_create_by!`.
- `catalogue_present?` requires an **exact key-set match** to the generated registry and at least one role join per canonical role.
- Repeated `db:seed` does not duplicate rows (unique indexes on `permissions.key` and `(role_key, permission_id)`).
- Does **not** prune stale `role_permissions` if a key is removed from a future catalogue version (manual migration/review required).
- Metadata refresh when keys already match but labels change: run a deliberate catalogue version bump or temporary `catalogue_present?` failure path — routine seed is a no-op when present.

**Production contract (future):** run migrations, then `bin/rails db:seed` (or equivalent release task) before serving traffic that depends on `EffectivePermissions`.

## Test map

| Area | Files |
|------|--------|
| Catalogue | `test/lib/authorization/permission_catalogue_test.rb` |
| Role defaults | `test/lib/authorization/role_defaults_test.rb` |
| Effective permissions | `test/services/authorization/effective_permissions_test.rb` |
| Granter | `test/services/authorization/permission_granter_test.rb` |
| Owner protection | `test/services/authorization/owner_protection_test.rb` |
| Audit | `test/services/authorization/audit_test.rb` |
| Session epoch | `test/integration/permission_epoch_session_test.rb`, `permission_revocation_session_test.rb` |
| Invitations | `test/services/invitations/policy_test.rb`, invitation integration tests |
| Pundit | `test/policies/invitation_policy_test.rb` |
| Security regressions | `effective_permissions_security_test.rb`, `permission_granter_security_test.rb` |

## Security acceptance summary (2026-11-22)

| Area | Result |
|------|--------|
| Catalogue / matrix | 71 keys, 13 roles; seeded rows match `RoleDefaults`; sensitive defaults verified (ops without confidential, finance `billing.view_all` only, client member without admin grants). |
| Effective permissions | Fail-closed; deny \> allow \> role default; per-membership overrides; no global user role. |
| Granter | Same-org only; delegation bounds; protected/deny_only rules; no public API. |
| Session epoch | Bumps on override change; refreshes on resume; workspace switch syncs epoch snapshot. Revocation reflected on next request (live DB resolution, not session-cached grants). |
| Pundit / routes | `team.invite` + P3-A2 ceilings on invitation paths; portal domain gates unchanged. |
| Audit | JSONB metadata without secrets; override grant/remove in granter transaction. **Not** append-only / immutable storage. |
| Regressions | P3-A2 invitation matrix tests green. |

### Known limitations

- `Authorization::ResourceScope` stub (Phase 4).
- Owner protection not wired to membership status mutations.
- Seeder does not remove deprecated role grants automatically.
- Request-local memoization of `EffectivePermissions` deferred (per-request DB resolution is acceptable at current scale).

## Explicit exclusions (this slice)

Team & Permissions UI (M07/C15), Phase 4 domain models, production SMTP, MFA A04, GitHub push.