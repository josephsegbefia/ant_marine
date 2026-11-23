# P3-A7 — Phase 3 foundation exit (local)

**Date:** 2026-11-23 (final local acceptance pass)  
**Branch:** `main` (local only — **not pushed**)  

Labels: **IMPLEMENTED**, **VERIFIED**, **NOT VERIFIED**, **BLOCKED**, **DEFERRED**.

## Final local acceptance evidence (2026-11-23)

| Gap | Result |
|-----|--------|
| Solid Queue runtime (3× smoke, no segfault) | **VERIFIED** — `scripts/verify_solid_queue_runtime.sh` → 3/3; no `Segmentation fault` in worker log |
| `bin/dev` Foreman + worker | **VERIFIED** — `foreman` via Bundler; `mise exec` wrapper; `web`/`css`/`jobs` on **:3000**; async supervisor in `Procfile.dev` |
| Encrypted S3-compatible API | **VERIFIED** — **SeaweedFS** (`compose.seaweedfs-poc.yml`, port **8333**); `encrypted_s3_storage_poc_test.rb` (4 tests) with `S3_POC_ENABLED=1` |
| ClamAV integration | **VERIFIED** — Homebrew `clamav` + `freshclam`; `scripts/clamav_local_scan.sh`; `clamav_scanner_poc_test.rb` (3 tests) with `CLAMAV_POC_ENABLED=1` |
| P01 browser | **VERIFIED** — live `http://127.0.0.1:3000/` @ ~1440 / 768 / 390 (Design Studio hero, nav, CTAs) |
| S01 / M08 / C01 authenticated | **NOT VERIFIED (agent)** — `/staff` correctly redirects to `/session/new`; dev DB has staff super-admins only (no client org); PO must sign in with `.env.local` bootstrap credentials (not in repo) |
| Recovery drill | **VERIFIED** — `scripts/p3_storage_backup_drill.sh` |
| Foundation script | **VERIFIED** — `scripts/verify_foundation.sh` (all checks pass) |

## Phase 3 exit matrix (master spec §PHASE 3)

| Requirement | Status |
|-------------|--------|
| Fresh clone tests + audit | **VERIFIED** — **203 runs, 741 assertions, 0 failures** with PoC env; **730 assertions, 7 skips** without PoC env (CI default) |
| Permission enforcement | **VERIFIED** |
| Encrypted storage (disk) | **VERIFIED** |
| Encrypted storage (S3 API) | **VERIFIED** (local SeaweedFS; not Hetzner) |
| Real AV scanner | **VERIFIED** (host `clamscan`; optional Docker PoC retained) |
| Responsive shell browser matrix | **PARTIAL** — P01 + unauthenticated auth gate; signed-in S01/M08/C01 **open** |
| Solid Queue worker | **VERIFIED** (runtime script + stable `jobs.1` under `bin/dev`) |

## Worker runtime (final)

- **Root cause (macOS):** fork + `pg` + threaded parent — see `solid_queue_fork_safety.rb`, `Procfile.dev` async mode.
- **Evidence:** `scripts/verify_solid_queue_runtime.sh` — worker stays up, **no segfault** in log, **3/3** jobs `finished_at` + `infrastructure.worker_smoke` audit rows.
- **`bin/dev`:** sources `.env.local`, re-execs via `mise exec`, `bundle exec foreman`; avoid bare `bin/dev` on system Ruby 2.6.

## Encrypted S3 PoC (code path)

- `lib/active_storage/service/encrypted_s3_service.rb` — app-side encrypt before `S3Service` upload; decrypt on download; no direct URLs.
- **Local server:** `compose.seaweedfs-poc.yml` + `config/seaweedfs_s3_poc.json` (arm64-maintained image `chrislusf/seaweedfs`).
- `scripts/s3_poc_bootstrap.sh` — idempotent bucket create (`ant-marine-encrypted-poc`).
- `config/storage.yml` — `S3_POC_*` env (legacy `MINIO_POC_*` aliases).
- Tests: `test/integration/encrypted_s3_storage_poc_test.rb` — ciphertext at rest, round-trip, tamper, wrong key, route bypass.

**Hetzner production:** **BLOCKED** — no live bucket; local PoC does not replace planned production provider.

**MinIO compose:** retained as deprecated alternative; image pull was unreliable on this host.

## ClamAV PoC

| Mode | Command | Notes |
|------|---------|-------|
| **Host (verified)** | `brew install clamav`; edit `/opt/homebrew/etc/clamav/freshclam.conf` (comment `Example`); `freshclam`; `CLAMAV_POC_SCAN_COMMAND=scripts/clamav_local_scan.sh` | DB under `/opt/homebrew/var/lib/clamav` |
| Docker (optional) | `compose.clamav-poc.yml`, `scripts/clamav_poc_scan.sh` | arm64 image not verified here |

- `Storage::MalwareScanner` — `FOUND` / `Infected files: N` → rejected; non-zero without infection signature → error (never fake clean).
- Integration tests: clean synthetic file, EICAR path, forced scanner failure.

## Health / readiness

- `GET /up` — liveness  
- `GET /ready` — DB, permission catalogue, mail label, storage gate (no secrets)

## Authenticated browser QA (PO manual)

1. Ensure `bin/dev` running and PostgreSQL up.
2. Open `http://127.0.0.1:3000/session/new`.
3. Sign in with the **bootstrap super administrator** from your `.env.local` (`ANT_MARINE_BOOTSTRAP_EMAIL` / password you set at provision time — not stored in Git).
4. After workspace selection, verify **S01** at `/staff`, **M08** at `/staff/invitations`.
5. **C01** requires a client organization membership (none in current dev DB); invite a client user via M08/C15 flow, accept invitation, then verify `/client`.

## Phase 3 exit decision (local)

| Decision | Outcome |
|----------|---------|
| Foundation acceptance | **CONDITIONAL GO** — integration gaps closed locally; production Hetzner/ADR-010 and full authenticated browser matrix remain PO-owned |
| GitHub push | **NO-GO** (per PO) |
| Phase 4 implementation | **NO-GO** |

## Automated test baseline

| Profile | Count |
|---------|--------|
| CI default (no PoC env) | 203 runs, 730 assertions, 0 failures, 7 skips |
| Full acceptance (`S3_POC_ENABLED=1`, `CLAMAV_POC_ENABLED=1`) | 203 runs, 741 assertions, 0 failures, 0 skips |