# P3-A7 — Phase 3 foundation exit

**Date:** 2026-11-23 (publication pass)
**Branch:** `main`

Labels: **IMPLEMENTED**, **VERIFIED**, **NOT VERIFIED**, **BLOCKED**, **DEFERRED**.

## Phase 3 local engineering — ACCEPTED (2026-11-23)

| Decision | Outcome |
|----------|---------|
| Phase 3 foundation (engineering) | **ACCEPTED** — Product Owner closure of local foundation |
| Production deployment | **NOT AUTHORISED** |
| External production integrations | **PENDING SEPARATE ACCEPTANCE** |
| Phase 1 formal stakeholder sign-off | **Open** (unchanged) |
| Phase 4 implementation | **NO-GO** until PO directs |

## Product Owner browser acceptance (2026-11-23)

**Authority:** Product Owner
**Evidence:** PO manual browser acceptance (not agent-automated retest on this pass)

| # | Check | Status |
|---|--------|--------|
| 1 | Staff sign-in and **S01** | **Accepted (PO)** |
| 2 | **M08** invitations | **Accepted (PO)** |
| 3 | Responsive staff navigation | **Accepted (PO)** |
| 4 | Development client invitation | **Accepted (PO)** |
| 5 | Authenticated **C01** client dashboard | **Accepted (PO)** |
| 6 | Staff/client access separation | **Accepted (PO)** |

## Engineering verification evidence (automated / scripts)

| Gap | Result |
|-----|--------|
| Solid Queue runtime (3× smoke, no segfault) | **VERIFIED** — `scripts/verify_solid_queue_runtime.sh` |
| `bin/dev` Foreman + worker | **VERIFIED** — mise + Bundler `foreman`; async `Procfile.dev` |
| Encrypted S3-compatible API | **VERIFIED** — SeaweedFS PoC + integration tests |
| ClamAV integration | **VERIFIED** — host `clamscan` + integration tests (when `CLAMAV_POC_ENABLED=1`) |
| Recovery drill | **VERIFIED** — `scripts/p3_storage_backup_drill.sh` |
| Foundation script | **VERIFIED** — `scripts/verify_foundation.sh` |

## Phase 3 exit matrix (master spec §PHASE 3)

| Requirement | Status |
|-------------|--------|
| Fresh clone tests + audit | **VERIFIED** |
| Permission enforcement | **VERIFIED** |
| Encrypted storage (disk) | **VERIFIED** |
| Encrypted storage (S3 API) | **VERIFIED** (local PoC; not Hetzner production) |
| Real AV scanner | **VERIFIED** (local PoC; production config separate) |
| Responsive shell browser matrix | **VERIFIED (PO)** — see browser table |
| Solid Queue worker | **VERIFIED** |

## Production activation gates (remain BLOCKED)

Do **not** treat these as satisfied by Phase 3 engineering acceptance:

- **ADR-010** final production encryption approval
- **Verified encrypted Hetzner** (or approved production object store)
- **Production encryption key custody** (KMS / secret manager, rotation runbook)
- **Production ClamAV** (or equivalent) + `STORAGE_SCAN_COMMAND` in each environment
- **Production SMTP** readiness (not dev `letter_opener` / test adapter only)
- **Off-site** database and object backup with tested restore
- **Real disaster recovery** exercise (RPO/RTO decisions recorded)
- **Deployment secrets** and hosting wiring (Coolify/Hetzner per ADRs)
- **OwnerProtection** before future membership-mutation endpoints
- **Formal Phase 1** design stakeholder sign-off

Fail-closed storage, quarantine, and `Storage::ProductionServiceGate` behaviour **must not** be weakened for convenience.

## Worker runtime

- macOS: `solid_queue_fork_safety.rb`, `SOLID_QUEUE_SUPERVISOR_MODE=async` in `Procfile.dev`.
- Evidence: `scripts/verify_solid_queue_runtime.sh` — 3/3 smoke jobs + audit events.

## Encrypted S3 PoC (non-production)

- `compose.seaweedfs-poc.yml`, `EncryptedS3Service`, `encrypted_s3_storage_poc_test.rb`.
- Local credentials in `config/seaweedfs_s3_poc.json` are **disposable PoC only**.

## ClamAV PoC (non-production)

- Host: Homebrew `clamav` + `freshclam`; `scripts/clamav_local_scan.sh`.
- Docker optional: `compose.clamav-poc.yml`.

## Health / readiness

- `GET /up` — liveness
- `GET /ready` — DB, permission catalogue, mail label, storage gate (no secrets)

## Automated test baseline

| Profile | Count |
|---------|--------|
| CI default (no PoC env) | 203 runs, 730 assertions, 0 failures, 7 skips (optional PoC integrations) |
| Full local acceptance (`S3_POC_ENABLED=1`, `CLAMAV_POC_ENABLED=1`) | 203 runs, 741 assertions, 0 failures, 0 skips |