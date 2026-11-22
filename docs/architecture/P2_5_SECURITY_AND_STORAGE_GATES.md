# P2.5 — Security & Storage Gates

**Version:** 1.0 — 22 November 2026

---

## 1. Security invariants → tests

| Invariant | Source | Phase 3 tests | Phase 5 tests |
|---|---|---|---|
| Staff/client domain separation | ROLE_PERMISSION_SPEC §2, W-06 | Unit EffectivePermissions | T-03 regression |
| Org isolation | P2.3 §1 | Policy scope integration | T-01 |
| 13 roles + overrides per membership | P2.3 | Seed + override tests | Matrix regression |
| Protected Super Admin / Owner | ADR-015 | PermissionGranter | T-09, T-20 |
| Delegation bounds | §6.5 | Unit | T-19 |
| Project resource scopes | §5 | Assignment policy | T-02, T-12 |
| Confidential docs | `access_confidential` | Document policy | T-11 |
| Report SoD | W-01 | Report transition service | T-12, T-13 |
| Permission revoke next request | §4 | epoch test | T-06 |
| Invitation token | P2.2 auth | Integration | T-07, T-08 |
| Billing without assignment | `billing.view_all` | Invoice policy | T-15 |
| Audit evidence | audit_events | Create on transition | M13 parity |

Full threat IDs: [`P2_2_SECURITY_THREAT_MODEL.md`](P2_2_SECURITY_THREAT_MODEL.md).

---

## 2. Session & invitation (P2-OD-040)

**Proposed:** encrypted cookie sessions + `users.security_version` + `memberships.permission_epoch`.

**Gate:** Phase 3 F3-auth-03 must demonstrate suspension revokes access on next request.

---

## 3. ADR-010 storage protection

### Requirements (master spec §2.6)

- Private bucket; no public ACL.  
- Policy before preview/download.  
- Scan before `available`.  
- Encryption **verified**, not assumed.  
- Backups separate from primary; restore tested.

### Current status

| Topic | Status |
|---|---|
| Security objective + P3-STORAGE-01 plan | **APPROVED** 2026-11-22 (ADR-010 partial, P2.5A) |
| Active Storage + private object store | **Designed** (ADR-004 proposed) |
| Hetzner default encryption at rest | **Not verified** — master spec caveat |
| SSE-C / client-side encryption | **OPEN** — requires PoC |
| Malware scanner | **Designed** workflow; vendor TBD |
| Signed URL TTL | 5–15 min proposed |
| Revocation vs TTL | **Limitation documented** |
| Production confidential files | **BLOCKED** until PoC pass |

### Bounded PoC plan (checkpoint **P3-STORAGE-01**)

**Scope:** isolated dev/staging bucket; synthetic non-confidential test files only.

| Step | Evidence |
|---|---|
| 1. Provision dev bucket credentials in `.env.local` (no commit) | Config doc |
| 2. Active Storage direct upload + server policy deny without document row | Integration test |
| 3. Implement chosen encryption approach (candidate: client-side or SSE-C per ADR-010 decision) | PoC report markdown |
| 4. Verify object bytes unreadable without keys on provider console | Screenshot/log redacted |
| 5. Backup copy to second location + one restore drill | Runbook + timestamp |

**Exit:** ADR-010 updated with APPROVED approach **or** explicit waiver for non-confidential-only launch.

**Do not** use real client documents in PoC.

---

## 4. Gate summary

| Gate | Blocks |
|---|---|
| G1 RBAC ADRs (005, 006, 012, 017) | Client onboarding, auth implementation choices |
| G2 ADR-013 / DCR | Permission UI |
| G3 ADR-010 PoC | Confidential production uploads |
| G4 P2-OD-043 | Unique quote_revision FK migration |
| G5 Phase 1 design sign-off | Production UI parity claims |