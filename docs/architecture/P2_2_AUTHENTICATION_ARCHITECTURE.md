# P2.2 — Authentication Architecture

**Status:** Phase 2 design — documentation only (no implementation)  
**Version:** 1.0 — 22 November 2026  
**Prerequisites:** [`ROLE_PERMISSION_SPEC.md`](ROLE_PERMISSION_SPEC.md), [`P2_1_DOMAIN_ARCHITECTURE.md`](P2_1_DOMAIN_ARCHITECTURE.md), master spec §2.3, §3.1  
**Companion:** [`P2_2_AUTHORIZATION_ARCHITECTURE.md`](P2_2_AUTHORIZATION_ARCHITECTURE.md)

---

## 1. Purpose

Define how **individual human users** prove identity, maintain secure sessions, accept invitations, and recover access — independently of **authorisation** (roles, permissions, organisation context), which is covered in the authorization architecture document.

**Principle:** Authentication answers *who* is signed in; authorization answers *what they may do in which organisation*.

---

## 2. Identity model

| Concept | Description |
|---|---|
| `User` | One row per person; unique verified email; password digest optional until invite accepted |
| Global identity | Single `User` may hold **multiple** `Membership` rows (staff ANT Marine org + one or more client orgs) |
| No tenant in User | Tenancy lives on `Membership` + server-selected `Current` context — never trust a client-supplied org id alone |

**Public (unauthenticated) actors:** visitors on marketing site and anonymous inquiry forms (ADR-014 proposed) — no `User` row required.

---

## 3. Authentication options (evaluation)

| Approach | Summary | Pros | Cons |
|---|---|---|---|
| **Rails 8 `authentication` generator** (recommended default) | Official Rails 8.1+ generator: `User`, sessions, password reset, mailers wired to app conventions | Aligned with Rails 8.1 stack; minimal dependencies; team owns code; fits Solid Cache/Queue | Invitations, step-up, MFA built in Phase 3 slices |
| **authentication-zero** gem pattern | Generator + recipes for verify/2FA | Good security recipes; still app-owned code | Extra generator dependency; overlap with Rails 8 built-in |
| **Devise** | Mature omnibus auth gem | Confirmable, lockable, trackable modules; large community | Heavier; configuration surface; another dependency to secure and upgrade |
| **Rodauth** | Rack middleware + Rails integration | Strong security defaults | Different integration style; smaller Rails team familiarity |

### Recommendation (pending ADR-017 approval)

Adopt **Rails 8 native authentication generator** as the baseline for Phase 3:

1. Run `bin/rails generate authentication` during Phase 3 foundation slice (not in P2.2).
2. Extend generated models/controllers with ANT Marine-specific flows: invitation acceptance, suspension, organisation switch (session context), step-up challenges.
3. Re-evaluate **Devise** only if Phase 3 spike finds unacceptable gaps (e.g. mandated commercial MFA appliance) — document any switch in `DECISIONS.md`.

**Do not** mix two login stacks. **Do not** add auth gems in P2.2.

---

## 4. Credential and account lifecycle

### 4.1 Registration paths

| Path | Flow |
|---|---|
| Staff | Super Admin / delegated staff invites email → `Invitation` → accept → set password → staff `Membership` in `Organization` where `kind: ant_marine` |
| Client | After qualified engagement (ADR-005 proposed), Owner/Admin invites → accept → password → client `Membership` |
| Self-signup | **Not** default; public users submit inquiries without accounts (ADR-014 proposed) |

### 4.2 Email and password

- **Email:** unique, case-insensitive normalization; used as login identifier.
- **Password:** `has_secure_password` (bcrypt); minimum length and breach-check policy documented in Phase 3 (e.g. 12+ chars, common-password denylist).
- **Email verification:** required before first client/staff portal use; unverified users may only complete invite acceptance and password set.
- **Password recovery:** time-limited single-use token; invalidate active recovery tokens on password change; rate-limited request endpoint.

### 4.3 Account states

| State | Meaning |
|---|---|
| `pending` | Invited, not yet accepted |
| `active` | Normal use |
| `suspended` | Login blocked; memberships inactive for authorization |
| `locked` | Temporary lock after failed attempts (optional Phase 3) |

Suspension is enforced at **authentication** (cannot start session) and **authorization** (membership `status: suspended`).

---

## 5. Session management

### 5.1 Session store

- **Server-side session** (cookie stores session id only); prefer encrypted, httponly, secure, same-site cookies.
- **Rotation:** regenerate session id on login and privilege-sensitive actions (step-up success).

### 5.2 Session payload (logical)

| Key | Purpose |
|---|---|
| `user_id` | Authenticated user |
| `session_version` | Bumped on global security events (password change, global logout) |
| `permission_epoch` | Copy of `user.permission_epoch` at login; compared each request — mismatch forces reload or re-auth |
| `step_up_verified_at` | Timestamp for sensitive UI window (e.g. 15 minutes) |

Organisation context (`current_membership_id` or `current_organization_id`) is resolved **server-side** from allowed memberships — see authorization doc.

### 5.3 Secure logout

- Destroy server session; clear cookies; optional Turbo redirect to public home.
- **Logout all devices:** increment `users.security_version` to invalidate other sessions on next request.

### 5.4 Session revocation triggers

Without forcing re-login on routine permission edits (master spec), still bump `permission_epoch` on:

- Membership role change
- Permission override grant/revoke
- Membership suspend/remove
- Organisation ownership transfer affecting actor

Next HTTP request reloads effective permissions or denies if membership gone.

---

## 6. Step-up authentication

Required before (non-exhaustive):

- Bulk permission changes (`team.bulk_permission_change`)
- Super Administrator role grant/revoke
- Organisation ownership transfer (client)
- `billing.adjust` and similar protected catalogue keys

**Mechanism (Phase 3):** re-enter password; optional TOTP when MFA enabled. Store `step_up_verified_at` in session; reject if stale.

---

## 7. Optional future MFA

- **Phase 3:** design `User#otp_secret` (encrypted) and backup codes table hook; feature-flagged.
- **Not required** for initial portal launch; document in threat model.
- Prefer WebAuthn/passkeys as a later slice if stakeholders require phishing-resistant MFA.

---

## 8. Invitation acceptance

| Field / rule | Specification |
|---|---|
| Token | Signed or high-entropy single-use; bound to `invitation_id` |
| Expiry | Default 7 days (configurable); expired invites reversible by admin |
| Email match | Accepting user must authenticate as invitee email (or verify email change flow) |
| Role ceiling | Inviter cannot assign role above inviter authority (authorization layer) |
| Domain | Invitation carries `organization_id` + `role_key` + domain staff/client |

Acceptance flow: validate token → create or link `User` → create `Membership` → verify email if needed → audit `InvitationAccepted`.

---

## 9. Portal routing (authentication boundary)

| Surface | URL namespace (proposed) | After login |
|---|---|---|
| Public | `/`, `/services`, inquiry forms | Session optional |
| Client portal | `/client/...` | Must have active **client** membership in `Current` org |
| Staff portal | `/staff/...` | Must have active **staff** membership in ANT Marine org |
| Admin / content | `/staff/...` sub-areas | Staff membership + feature permissions |

**Gate:** `AuthenticatedController` concerns verify `User` session; portal concerns verify membership **kind** matches namespace. A user with both staff and client memberships uses explicit **workspace switch** (A06) — never infer portal from email alone.

---

## 10. Rate limiting and abuse

- Login, password reset, invitation accept: throttle per IP and per email (Rack::Attack or Rails 8 rate limit — Phase 3).
- Generic error messages on failed login (no account enumeration).
- CSRF on all state-changing auth endpoints.

---

## 11. Phase 3 implementation map (not in scope now)

| Slice | Deliverable |
|---|---|
| F3-auth-01 | Rails authentication generator + User model extensions |
| F3-auth-02 | Invitation model, mailers, accept flow |
| F3-auth-03 | Session versioning + permission epoch |
| F3-auth-04 | Step-up challenge + audit hooks |
| F3-auth-05 | Suspension + forced logout |

---

## 12. References

- ADR-005, ADR-014 — onboarding and public intake (proposed)
- [`P2_2_AUTHORIZATION_ARCHITECTURE.md`](P2_2_AUTHORIZATION_ARCHITECTURE.md) — membership and permissions
- [`P2_2_SECURITY_THREAT_MODEL.md`](P2_2_SECURITY_THREAT_MODEL.md) — invitation and session threats