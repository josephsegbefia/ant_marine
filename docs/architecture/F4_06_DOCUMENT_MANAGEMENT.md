# F4-06 — Secure document management

**Checkpoint:** F4-06 (local, not pushed)  
**Baseline:** `bc0402b` (F4-05-H1)  
**Status:** Local engineering implementation complete — simulated projects only  

## Design Studio mapping

| Screen | Role |
|---|---|
| S11 Job documents | Staff project documents (`/staff/projects/:id/documents`) |
| C07 Files we need | Client upload requests |
| C08 Documents & files | Client document library |
| C09 Document preview | Metadata, versions, protected download (no unsafe HTML/SVG preview) |
| R05 / X03 | Mobile upload / failed-upload UX (reuse forms) |
| M09 Document rules | Deferred — categories seeded in `Document::CATEGORIES` |
| S10 / C11–C12 / S12–S14 | Out of scope (F4-07) |
| C10 | Messages — not documents |

## Storage audit (reuse P3 — no parallel stack)

| Concern | Implementation |
|---|---|
| Encrypted bytes | `Storage::Asset` + `EncryptedDisk` / AES-256-GCM (`Storage::Encryption`) |
| Validation | `Storage::ContentValidator` (PDF/PNG/JPEG/plain; `STORAGE_MAX_UPLOAD_BYTES`) |
| Quarantine | `scan_status`: pending_upload → scanning → available \| rejected |
| Scanner | `Storage::MalwareScanner` + `ScanStorageAssetJob`; builtin EICAR in test; ClamAV via `STORAGE_SCAN_COMMAND` when configured; production without command → error (not clean) |
| Downloads | `Documents::SecureDownload` → `Storage::SecureDownload`; `Cache-Control: no-store` |
| Active Storage routes | Disabled (`draw_routes = false`); redirect URLs 404 |
| Proof endpoints | Technical PoC only; product path is `Documents::Upload` |

Sensitive bytes are never stored plaintext in the persistent disk service when using encrypted services. Temporary plaintext may exist only in memory during scan/download; failed/timeout scans remain blocked.

## Domain model

Phase 2 names plus F4-06 exact-version extension:

- `Document` — project-owned metadata, workflow, visibility intent  
- `DocumentVersion` — immutable file identity → `storage_assets`  
- `UploadRequest` — staff request / client submit lifecycle  
- `DocumentReview` — exact-version approve / changes requested  
- `DocumentRelease` — exact-version client share + revoke  
- `DocumentAccessGrant` — collaborator narrow grants  

**Decision:** Document review/release mirror the Report pattern because F4-05-H1 requires exact-version release distinct from approval. Document-level `workflow_status` remains for UX summaries.

Visibility intent (`internal` / `client_submitted` / `for_client_release`) is **not** download permission.

## Authorization matrix (summary)

| Actor | List/meta | Upload | Request | Download clean | Review | Release |
|---|---|---|---|---|---|---|
| view_all / documents.manage | Org projects | Yes | Yes | Yes* | Yes | Yes |
| Delivery assignment / coordinator | Assigned project | Yes | Yes | Yes* | No† | If manage/release perm |
| Review assignment | Approval-required / for-release only | No | No | Yes* | Yes (independent) | No |
| Collaborator | Grant-limited | No | No | Grant-limited* | No | No |
| Unassigned staff | No | No | No | No | No | No |
| Client org member | Own submissions + active releases | Against open request | No | Released exact version / own submission if clean | No | No |
| Other client org | Deny | Deny | Deny | Deny | Deny | Deny |

\* Confidential needs `documents.access_confidential`.  
† Unless also review-scoped with catalogue permission.

Entry point: `Documents::Access` + Pundit policies. Controllers use `visible_documents_for_project` so unauthorized titles are not listed.

## Workflows

1. **Upload** → quarantined asset → scan job → available/rejected  
2. **Submit for review** (staff) requires available scan  
3. **Review** on exact version; approval-required categories need independent reviewer  
4. **Release** exact version with confirmation; simulated-only locally; production gate on  
5. **Revoke** sets `revoked_at` + reason; preserves history; blocks later downloads  
6. Upload request: requested → submitted → under_review → changes_required → satisfied (on release) / cancelled — **upload alone does not satisfy**

## Notifications & audit

Staff in-app only (`StaffNotification` / `Notifications::StaffPublisher`): uploaded, review required, changes requested, approved, released, revoked, upload requested. No email. Access rechecked when opening notification links.

Audit events under `documents.*` — identifiers only; never file bytes or keys.

## Simulation & production gates

- Projects remain `mode: simulated`  
- Upload/release refuse simulated ops in **production**  
- ADR-010 production encryption/custody **OPEN**  
- No Hetzner/S3 activation, no public URLs, no quarantine bypass  
- Live commercial acceptance / project initiation still off  

## F4-07 integration contract

Future inspections/reports may reference `document_versions.id` for evidence attachments. Document approval must **not** auto-approve a technical report. Report review/release remains a separate aggregate.

## Evidence

- Automated: document unit/integration + full suite (see PHASE_PROGRESS)  
- System: `test/system/document_management_test.rb`; screenshots `tmp/f406_screens/`  
- History: `document_versions_protect`, `document_releases_protect`; `verify_history_protection_h1.sh` PASS  
