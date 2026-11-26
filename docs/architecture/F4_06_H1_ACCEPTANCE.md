# F4-06-H1 — Document security final acceptance

**Baseline:** `1f00cc6` (F4-06)  
**Status:** Local security verification complete — simulated only  
**Hard stops respected:** no push, no deploy, no F4-07, no live document ops  

## Implementation coverage audit

| Area | F4-06 | H1 |
|---|---|---|
| Encrypted storage + quarantine | Done | Hardened (digest-bound scan, asset freeze) |
| Staff S11 / client C07–C09 | Done | Retained; authorize `:download?` |
| Exact-version review/release | Done | Exact review required; no workflow bypass |
| Client visibility ADR-003 | Partial | Fixed — release or own submission only |
| Scanner allowlist / timeout | Weak | Allowlist + timeout + fail-closed |
| Storage::Asset immutability | Missing | Trigger + AR guards |
| DocumentAccessGrant org check | Missing | Validated |
| High-risk automated tests | Partial | Expanded H1 suite |
| Authenticated browser | Partial | H1 system + screenshots |
| Live ClamAV | Optional PoC | Verified when `CLAMAV_POC_ENABLED=1` |
| Client in-app notifications | Absent | Documented limitation (portal lists only) |
| ADR-010 production | Open | Remains open |

## Security deficiencies corrected

1. Freeze `storage_assets` identity after `available`/`rejected`; require `scanned_checksum_sha256`.
2. Bind clean scans to content digest; downloads re-check scan digest.
3. Fail-closed scanner: unconfigured production, non-allowlisted commands, timeouts, errors → reject (never clean).
4. Client metadata no longer treats `for_client_release` alone as access.
5. Upload/request production gate via `Documents::Upload.available?`.
6. Release requires `DocumentReview` on the exact version when approval-required.
7. Review re-validates downloadable under lock; independent reviewer by user.
8. Grant targets must belong to granter operating organisation.
9. Download endpoints authorize `:download?`.

## Scanner architecture

| Adapter | When | Provenance |
|---|---|---|
| `builtin_eicar` | EICAR bytes | Rejection only |
| `builtin_dev` | test/development without `STORAGE_SCAN_COMMAND` | **Simulated** — not genuine AV |
| `clamscan` / `clamdscan` / `scripts/clamav_*.sh` | allowlisted `STORAGE_SCAN_COMMAND` | External / PoC |
| `none` / `denied` / `timeout` / `error` | misconfig / fail | Fail-closed → rejected |

Content validation (MIME/size) is **not** malware scanning.

## F4-07 evidence contract (documentation only)

Future inspection evidence must reference exact `document_versions.id`, `storage_asset_id`, `checksum_sha256`, scan provenance (`scanned_checksum_sha256`, `scanner_adapter`, `scanned_at`), project, client org, uploader, timestamp. Never “latest” pointer. Document approval/release ≠ report approval/release. Simulated (`builtin_dev`) scans must never support genuine certification.

## Remaining production gates

ADR-010; production object store + key custody; operational ClamAV; encrypted backup/DR; live document ops; live commercial/project initiation; M09 admin rules; client notification channel; Phase 1 design sign-off.

## GO/NO-GO

**CONDITIONAL GO** to close F4-06 locally (simulated).  
**NO-GO** production documents, push, deploy, F4-07.
