# P3-A6 — Secure storage, encryption and recovery (PoC)

**Status:** Local foundation proof on `main`. **Not pushed.** **No production storage.** ADR-010 technique remains **OPEN** until product owner signs after this PoC.

## Objective

Prove server-mediated uploads, application-side encryption at rest, quarantine scanning, org-aware downloads, audit events, and isolated backup restoration using synthetic data only. No Phase 4 document UI, no Hetzner bucket, no Active Storage public routes.

## Encryption (primary — implemented)

| Item | Choice |
|------|--------|
| Technique | AES-256-GCM via `ActiveSupport::MessageEncryptor` + `Marshal` serializer |
| Envelope | `AMST{version}.{ciphertext}` (`Storage::Encryption`) |
| Key material | `STORAGE_ENCRYPTION_KEY` + `STORAGE_ENCRYPTION_KEY_VERSION` |
| At rest on disk/S3 | Ciphertext only (`ActiveStorage::Service::EncryptedDiskService`) |
| Plaintext digest | `storage_assets.checksum_sha256` (pre-encrypt, in DB) |

**SSE-C (Hetzner/S3):** Documented alternative only in ADR-010; **not** implemented in this slice.

**Key loss:** Permanent object loss. Document in runbooks before production.

## Active Storage layout

| Service name | Adapter | Use |
|--------------|---------|-----|
| `test` / `local_encrypted` | `EncryptedDisk` | Dev + test (encrypted disk under `storage/` or `tmp/storage`) |
| `private_s3` | `S3` | Env-gated stub; **no bucket created** in PoC |

- `config.active_storage.draw_routes = false` — `/rails/active_storage/*` cannot bypass the download gateway.
- Custom service lives at `lib/active_storage/service/encrypted_disk_service.rb` (required by Active Storage configurator; excluded from Zeitwerk via `autoload_lib` ignore).

## Metadata model (PoC)

`storage_assets` — not the future `Document` domain.

- `scan_status`: `pending_upload` → `scanning` → `available` | `rejected`
- `classification`: `standard` | `confidential` (`documents.access_confidential` for downloads)
- Links `active_storage_blob_id`; opaque `storage_key` (UUID)

## Upload and scan

1. Staff proof endpoint: `POST staff/storage/proof_uploads` (`Storage::ProofUpload`).
2. Validate size, filename, Marcel MIME allowlist (plain, pdf, png, jpeg).
3. Write encrypted blob; create row in `pending_upload`; enqueue `ScanStorageAssetJob` after commit.
4. Scanner contract (`Storage::MalwareScanner`): EICAR rejection in tests; optional `STORAGE_SCAN_COMMAND` (e.g. ClamAV) in other envs; **fail-closed** without scanner in non-test.

**Malware scanning:** **VERIFIED BY AUTOMATED TEST** (EICAR + quarantine). **NOT VERIFIED** against real ClamAV unless `STORAGE_SCAN_COMMAND` is configured locally.

## Download gateway

- `GET staff/storage/proof_downloads/:id` — Pundit `Storage::AssetPolicy`; `Storage::SecureDownload` streams attachment with `Cache-Control: no-store`.
- Direct blob URLs and signed global IDs are not mounted on public routes.

## Audit events

`storage.proof_uploaded`, `storage.scan_passed`, `storage.scan_rejected`, `storage.download_allowed`, `storage.download_denied`, `storage.recovery_verified` — metadata only (no keys or raw content).

## Recovery proof

`test/integration/storage_recovery_proof_test.rb` copies DB row + ciphertext bytes to an isolated tmp tree and verifies decrypt + checksum. Label: **VERIFIED BY AUTOMATED TEST** (disk). **VERIFIED BY REAL S3:** not applicable in this slice.

## Environment (names in `.env.example`)

- `STORAGE_ACTIVE_STORAGE_SERVICE`
- `STORAGE_ENCRYPTION_KEY` / `STORAGE_ENCRYPTION_KEY_VERSION`
- `STORAGE_MAX_UPLOAD_BYTES`
- `STORAGE_S3_*` (commented stub)
- `STORAGE_SCAN_COMMAND` (optional)

## Production gates (still blocked)

| Gate | Status |
|------|--------|
| ADR-010 production encryption strategy | **BLOCKED** — PO after PoC |
| S3/Hetzner private bucket | **DOCUMENTED ONLY** |
| Live AV | **NOT VERIFIED** unless ClamAV configured |
| GitHub / deploy | **NO-GO** per slice instruction |

## Tests

`test/storage/`, `test/integration/storage_*`, `test/jobs/scan_storage_asset_job_test.rb` — encryption, upload validation, quarantine, authz, recovery, regression with full suite (177+ runs).