# Phase 1 Design Change Request — Team & Permissions

**Status:** **Awaiting stakeholder approval** — **do not edit** [`ANT_Marine_Design_Studio_Phase_1.html`](ANT_Marine_Design_Studio_Phase_1.html) until this DCR is signed off
**Date:** 22 November 2026  
**Driver:** Product requirement for configurable RBAC ([`../architecture/ROLE_PERMISSION_SPEC.md`](../architecture/ROLE_PERMISSION_SPEC.md))

---

## Summary

The approved Phase 1 prototype includes **M07 — Team access** (staff) and **C15 — My company & team** (client) but does **not** fully specify dedicated **Team & Permissions** management flows (grouped permission toggles, effective access, permission history, sensitive confirmations).

This change request adds screen definitions for implementation without modifying the HTML studio until design sign-off.

---

## New / extended screens (proposed IDs)

### Staff — `Staff > Team & Permissions`

Extends **M07** into a sub-journey:

| Proposed ID | Name | Purpose |
|---|---|---|
| `M07a` | Team & Permissions — member list | List staff with role, status, last active |
| `M07b` | Invite staff member | Email, role, optional message |
| `M07c` | Staff member details | Profile, role, effective access summary |
| `M07d` | Change staff role | Role picker within allowed staff roles |
| `M07e` | Edit staff permissions | Grouped switches; show role defaults vs overrides |
| `M07f` | Effective access | Plain-English list of what they can do |
| `M07g` | Reset to role defaults | Confirm reset overrides |
| `M07h` | Pending invitations | Resend, revoke |
| `M07i` | Permission change history | Filter by user; link to M13 |
| `M07j` | Confirm sensitive change | Reauthentication step for super admin / bulk |

States: empty team, loading, save success, validation error, **access denied** (X04 pattern).

### Client — `Company Settings > Team & Permissions`

Extends **C15**:

| Proposed ID | Name | Purpose |
|---|---|---|
| `C15a` | Team & Permissions — member list | Colleagues, roles, status |
| `C15b` | Invite colleague | Invitation; role limited by inviter authority |
| `C15c` | Colleague details | Role, effective access |
| `C15d` | Change role | Owner/admin/manager boundaries |
| `C15e` | Edit permissions | Grouped switches; defaults vs custom |
| `C15f` | Effective access | Plain-English capabilities |
| `C15g` | Reset to role defaults | Confirm |
| `C15h` | Pending invitations | |
| `C15i` | Transfer ownership | Nominee + confirm (owner only) |
| `C15j` | Permission history | Org-scoped |

States: same as staff; copy in everyday English.

**Responsive:** Desktop and mobile layouts follow Phase 1 handoff patterns (`design/PHASE_1_DESIGN_HANDOFF.md`); touch targets and reduced-motion respected on M07a–j and C15a–j.

---

## Coverage confirmation (P2.1 reconciliation)

| Requirement | Staff (M07a–j) | Client (C15a–j) |
|---|---|---|
| Permission / team management (list, invite, role change) | M07a, M07b, M07d, M07h | C15a, C15b, C15d, C15h |
| Permission categories and switches | M07e | C15e |
| User effective permissions | M07f, M07c summary | C15f, C15c summary |
| Role defaults and overrides | M07e, M07g | C15e, C15g |
| Ownership protection | M07j (sensitive staff changes) | C15i transfer ownership; C15d role bounds |
| Permission history | M07i | C15j |
| Confirmation and error states | M07j; shared success/validation/denied | C15i confirm; shared success/validation/denied |
| Desktop and mobile | All proposed IDs | All proposed IDs |

---

## Copy principles

- No internal permission keys (`projects.view`) in UI.
- Show **“Included with your role”** vs **“Added for this person”** vs **“Removed for this person”**.
- Short explanation under each permission group (from catalogue display names).

---

## Traceability to existing screens

| Existing | Relationship |
|---|---|
| M07 Team access | Entry point → M07a |
| M08 Invitations | May merge with M07h / C15h or cross-link |
| M13 Security history | Linked from permission history |
| C15 My company & team | Entry → C15a |
| C16 My account | Unchanged (self profile) |

---

## Approval

- [ ] Product owner accepts new screen IDs and navigation  
- [ ] Updated HTML studio export scheduled after approval  
- [ ] Phase 4 slice for permission UI references this document