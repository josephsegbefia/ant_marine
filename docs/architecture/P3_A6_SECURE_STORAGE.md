# P3-A6 — Secure storage, encryption and recovery (PoC)

**Status:** Local foundation proof on `main`. **Final security acceptance (automated) 2026-11-22.** **Not pushed.** **No production storage.** ADR-010 production technique remains **OPEN** until product owner signs after this PoC.

## Objective

Prove server-mediated uploads, application-side encryption at rest, quarantine scanning, org-aware downloads, audit events, and isolated backup restoration using synthetic data only. No Phase 4 document UI, no Hetzner bucket, no Active Storage public routes.

Staff routes `staff/storage/proof_*` are **technical proof endpoints only** — not general production document upload UI.

## Encryption — verified properties (automated)

| Property | Status |
|----------|--------|
| AES-256-GCM via `ActiveSupport::MessageEncryptor` (Rails primitive) | **VERIFIED** |
| Unique nonce per `encrypt_and_sign` (library-managed) | **VERIFIED** (library contract) |
| Authentication tag validated on `decrypt_and_verify` | **VERIFIED** |
| Tampered / truncated ciphertext → `nil` / error, no partial plaintext | **VERIFIED** |
| Wrong `STORAGE_ENCRYPTION_KEY` → decrypt fails closed | **VERIFIED** |
| Missing key (non-test) → `Storage::KeyMaterial::MissingKey` | **VERIFIED** |
| Invalid envelope → `ArgumentError` rescued → `nil` | **VERIFIED** |
| Purpose `:storage_blob` binding | **VERIFIED** |
| Raw disk bytes ≠ plaintext | **VERIFIED** |
| Keys not stored in DB rows or API JSON | **VERIFIED** |
| `ScanStorageAssetJob.log_arguments = false` | **VERIFIED** |

**Not custom crypto** — only Rails `MessageEncryptor` + envelope prefix `AMST{version}.`.

**Large files:** `EncryptedDiskService#download` and `#download_chunk` decrypt the full object into memory before streaming or slicing. Enforce `STORAGE_MAX_UPLOAD_BYTES` at upload; production document flows need streaming design later.

**Checksum behaviour:** Active Storage blob `checksum` is **plaintext MD5**; encrypted disk stores ciphertext. `EncryptedDiskService#download` yields **plaintext string chunks** so `ActiveStorage::Downloader` integrity checks succeed (regression fixed in PoC).

## Active Storage layout

| Service name | Adapter | Encryption at rest | Production |
|--------------|---------|-------------------|------------|
| `test` / `local_encrypted` | `EncryptedDisk` | App-side AES-GCM | **Allowed** (default prod default name is `local_encrypted` until object store wired) |
| `encrypted_s3` | `EncryptedS3` | App-side AES-GCM before S3 PUT | **Allowed in gate**; **verified only when `MINIO_POC_ENABLED=1`** (local MinIO) |
| `local` | `Disk` | None | **Blocked** in production (`Storage::ProductionServiceGate`) |
| `private_s3` | `S3` (plain) | **None** — ACL private only | **Blocked** in production until PoC encrypted adapter selected |

- `config.active_storage.draw_routes = false` — `/rails/active_storage/*` returns **404** in tests.
- Custom service: `lib/active_storage/service/encrypted_disk_service.rb` (manual require path; `autoload_lib` ignores `active_storage/`).

**S3 / Hetzner:** **DOCUMENTED ONLY.** No credentials, no bucket, no verified encrypted S3 adapter. Selecting `private_s3` in production **raises on boot**.

**Future encrypted S3:** Subclass or mirror `EncryptedDiskService` (encrypt in `upload`, decrypt in `download`, disable direct URLs), reuse `Storage::Encryption`, private bucket + IAM; PO sign-off on ADR-010 technique.

## Metadata model (PoC)

`storage_assets` — not the future `Document` domain.

- `scan_status`: `pending_upload` → `scanning` → `available` | `rejected`
- `classification`: `standard` | `confidential` (`documents.access_confidential` for downloads)
- `byte_size` must be &gt; 0 (empty uploads rejected)
- Links `active_storage_blob_id`; opaque `storage_key` (UUID)

## Upload and scan

1. `POST staff/storage/proof_uploads` — staff portal only (`Staff::BaseController`); Pundit `Storage::ProofPolicy` (`documents.upload`); active membership required.
2. Org bound to `Current.membership.organization` — no client-chosen org id.
3. `Storage::ProofUpload` validates MIME (Marcel), size, filename; UUID `storage_key` prevents cross-org overwrite.
4. `ScanStorageAssetJob` after commit; scanner via `Storage::MalwareScanner`.

| Scanner context | Behaviour |
|-----------------|-----------|
| Test / development (no `STORAGE_SCAN_COMMAND`) | EICAR rejected; otherwise **builtin_signature_only** (PoC convenience — **not** AV) |
| Production without command | `:error` → asset **rejected** (fail-closed) |
| `STORAGE_SCAN_COMMAND` | Scans tempfile path only (no user filename in shell) |

**REAL MALWARE SCANNING NOT VERIFIED** without operational ClamAV or equivalent. EICAR proves quarantine boundary only.

**Job safety:** Missing blob, integrity errors, nil scan result → `rejected`; `:clean` never assumed on error paths.

## Download gateway

- `GET staff/storage/proof_downloads/:id` — `Storage::AssetPolicy` (org match, `documents.download`, `available`, confidential gate).
- `Storage::SecureDownload` re-checks quarantine + SHA256 vs `checksum_sha256`; maps decrypt failures to generic errors.
- Headers: `Cache-Control: no-store`, `Content-Disposition: attachment`, `X-Content-Type-Options: nosniff`.

## Proof endpoint exposure

| Audience | Upload | Download |
|----------|--------|----------|
| Anonymous | Denied | Denied |
| Client portal | Staff area denied | Staff area denied |
| Cross-org staff | Denied | Denied |
| Suspended membership | Portal blocked | Portal blocked |
| Quarantined asset | N/A | Policy denied (not `available`) |

## Audit events

`storage.proof_uploaded`, `storage.scan_passed`, `storage.scan_rejected`, `storage.download_allowed`, `storage.download_denied`, `storage.recovery_verified` — metadata only (no keys or raw content).

## Recovery proof

`test/integration/storage_recovery_proof_test.rb` — isolated tmp copy of ciphertext + DB row; **VERIFIED BY AUTOMATED TEST** (disk).

**Not demonstrated:** Real off-site DB + object store restore, production backup drill, or key rotation without downtime.

**Key custody:** Keys via env / secret manager only; loss = permanent object loss. Version field supports future rotation (decrypt old version, re-encrypt new).

## Development configuration

- `bin/dev` sources `.env.local` (not tracked; `/.env*` gitignored).
- No secrets echoed; missing `ANT_MARINE_DB_PASSWORD` exits with message only.

## Worker execution evidence

| Evidence | Status |
|----------|--------|
| `perform_enqueued_jobs` / `ScanStorageAssetJob.perform_now` in Minitest | **VERIFIED** |
| Live `bin/jobs` under Foreman | **NOT VERIFIED** in acceptance session (worker process crashed with Ruby segfault in local `bin/dev`) |

## Environment (names in `.env.example`)

- `STORAGE_ACTIVE_STORAGE_SERVICE`
- `STORAGE_ENCRYPTION_KEY` / `STORAGE_ENCRYPTION_KEY_VERSION`
- `STORAGE_MAX_UPLOAD_BYTES`
- `STORAGE_S3_*` (stub)
- `STORAGE_SCAN_COMMAND` (optional)

## ADR-010 / production readiness

| Gate | Status |
|------|--------|
| PoC objective (bounded upload/encrypt/quarantine/gateway) | **VERIFIED** (automated) |
| ADR-010 production encryption strategy approval | **BLOCKED** — PO after PoC review |
| Encrypted S3 / Hetzner | **DOCUMENTED ONLY** |
| Operational AV | **NOT VERIFIED** |
| GitHub publication | **Pending PO GO** |
| Production confidential storage | **NO-GO** |

## Tests (post–security acceptance)

**193 runs, 721 assertions, 0 failures** (includes prior foundation + new storage regression tests).

Coverage emphasis: encryption edge cases, production service gate, scanner fail-closed, quarantine downloads, authz, recovery/wrong key, headers, Active Storage route bypass.