# P3-A2 invitation authority (interim policy)

**Status:** Integrated in **P3-A3** — see [`P3_A3_AUTHORIZATION.md`](P3_A3_AUTHORIZATION.md). Ceiling and scope tables below remain authoritative for invitation **targets**; `team.invite` and `EffectivePermissions` gate **whether** issuance is allowed.

This document describes the explicit server-side rules that **persist as a second layer** on top of the catalogue.

## Expiry and tokens

- Default expiry: **7 days** (`Invitation::DEFAULT_EXPIRY`).
- Raw tokens are generated once, emailed once, stored only as **SHA-256 digests**.
- **GET** invitation pages never consume an invitation.

## Staff issuers (ANT Marine membership, active)

| Role | Invite to | Allowed target roles |
|------|-----------|-------------------|
| `staff.super_administrator` | ANT Marine org | All staff roles **except** `staff.super_administrator` (bootstrap only) |
| `staff.operations_manager` | ANT Marine org | Non-privileged staff (not super admin, not ops manager) |
| Same two roles | Client organisations | Client roles **except** `client.org_owner` |

## Client issuers (client org membership, active)

| Role | Scope |
|------|--------|
| `client.org_owner`, `client.org_administrator`, `client.client_manager` | Same organisation only; client roles except `client.org_owner`; never staff roles |

## Denied

- Suspended or inactive memberships.
- Cross-organisation targeting (clients cannot invite into another client org).
- Staff/client role mismatch for organisation kind.
- Inviting `staff.super_administrator` or `client.org_owner` through UI flows.

## Audit events (P2-OD-041)

Recorded on `audit_events`: `invitation.issued`, `invitation.reissued`, `invitation.revoked`, `invitation.accepted`, `membership.created_via_invitation`, `invitation.denied`. No secrets in metadata.

## P3-A3 integration

Replace `Invitations::Policy` checks with catalogue permissions (`team.invite`, role ceilings, org scope) via `EffectivePermissions` without changing invitation persistence or acceptance semantics.