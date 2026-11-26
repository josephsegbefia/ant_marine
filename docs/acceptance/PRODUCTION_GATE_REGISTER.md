# Production gate register — F4-09A

Consolidated outstanding production requirements. **None resolved in F4-09A without authorization.**

| ID | Description | Status | Decision-maker | Required evidence | Dependency | Launch-blocking |
|---|---|---|---|---|---|---|
| PG-001 | Hosting architecture (Render vs Hetzner/Coolify/Cloudflare) | OPEN | PO + ops | Written architecture choice | — | Yes |
| PG-002 | Production PostgreSQL provisioned | OPEN | Ops | Connection, backups, privileges | PG-001 | Yes |
| PG-003 | Restricted runtime DB role (non-owner) | OPEN | Ops | `scripts/verify_history_protection_h1.sh`-class proof on prod role | PG-002; ADR-F4-04B-006 | Yes |
| PG-004 | Email provider + domain verification | OPEN | PO + ops | ADR-009; SPF/DKIM; provider | — | Yes (for live mail) |
| PG-005 | ADR-010 confidential storage decision | OPEN | PO + security | SeaweedFS/S3-compatible choice; encryption custody | P3-A6 PoC | Yes (for live files) |
| PG-006 | Encryption key custody | OPEN | Security | Key rotation, access list, recovery | PG-005 | Yes |
| PG-007 | Malware scanning operations | OPEN | Ops | ClamAV/service SLAs; allowlist | PG-005 | Yes (for live uploads) |
| PG-008 | Backup and recovery | OPEN | Ops | Restore drill evidence | PG-002/005 | Yes |
| PG-009 | Document retention policy | OPEN | PO + legal | Retention schedule; legal holds | PG-005 | Yes |
| PG-010 | Commercial terms templates | OPEN | PO + legal | Approved wording | — | Yes (live quotes) |
| PG-011 | Tax treatment | OPEN | PO + finance | Rates/exemptions or explicit none | — | Yes (live invoices) |
| PG-012 | Deposit policies | OPEN | PO + finance | Written rules or explicit none | — | Conditional |
| PG-013 | Invoice numbering policy | OPEN | Finance | Sequence rules; void reuse ban already coded | — | Yes (live invoices) |
| PG-014 | Payment instructions | OPEN | Finance | Bank details; no invented data | — | Yes (live invoices) |
| PG-015 | Financial correction procedures | OPEN | Finance | Beyond void/reversal | F4-08 | Yes (live finance) |
| PG-016 | Technical templates (regulatory) | OPEN | Technical lead | Non-synthetic published templates | F4-07 | Yes (live inspections) |
| PG-017 | Technical reviewer competency | OPEN | Ops manager | Named reviewers; SoD staffing | F4-07 | Yes |
| PG-018 | Signature requirements | OPEN | PO + legal | Wet/e-sign policy | — | Conditional |
| PG-019 | Live commercial operations switch | OFF | PO | Flip only after PG-010+ | F4-04B | Yes |
| PG-020 | Live project initiation | OFF | PO | After live acceptance | F4-05 | Yes |
| PG-021 | Live document operations | OFF | PO | After PG-005–007 | F4-06 | Yes |
| PG-022 | Live technical reporting / certification claims | OFF | PO | After PG-016–018 | F4-07 | Yes |
| PG-023 | Live invoicing / payments | OFF | PO | After PG-011–015 | F4-08 | Yes |
| PG-024 | Formal Design Studio approval | OPEN | PO | Signed review export | Phase 1 | Yes (product completeness claim) |
| PG-025 | Editorial approval (public content) | OPEN | PO | Published snapshots reviewed | F4-01 | Yes (public site claims) |
| PG-026 | Deployment acceptance | OPEN | PO + ops | Staging checks; no prod deploy from F4-09A | Phase 5 | Yes |

## Notes

- Application code already **refuses** production simulated create/release paths for commercial, documents, reports, and billing where `*.available?` / env guards exist.
- F4-09A does **not** enable any live switch.
- Phase 5 must not start until this register is explicitly reviewed.
