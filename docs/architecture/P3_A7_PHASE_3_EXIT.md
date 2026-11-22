# P3-A7 — Phase 3 foundation exit (local)

**Date:** 2026-11-22  
**Branch:** `main` (local only — **not pushed**)  
**Prior commits:** `862b23f` (P3-A6 PoC), `d9e2f14` (P3-A6 security acceptance), P3-A7 commit pending  

This document maps **master spec Phase 3 exit** criteria to evidence. Labels: **IMPLEMENTED**, **VERIFIED**, **NOT VERIFIED**, **BLOCKED**, **DEFERRED**.

## Phase 3 exit matrix (master spec §PHASE 3)

| Requirement | Implementation | Automated test | Runtime | Docs | Blocker / PO |
|-------------|----------------|----------------|---------|------|--------------|
| Rails 8.1 + PG + Hotwire + Tailwind | Yes | Full suite | `bin/dev` web | SETUP, README | — |
| Solid Queue / Cable / Cache topology | Yes | Job tests | Partial worker | P3_A5, P3_A7 | macOS fork+pg (mitigated) |
| Authentication + sessions | Yes | Session tests | Sign-in | P2_2 | — |
| Invitations | Yes | Integration tests | Staff UI | P3_A2 | — |
| Permission catalogue + Pundit | Yes | P3_A3 tests | `db:seed` | P3_A3 | — |
| Layout shells (public/client/staff) | Yes | View/integration | **NOT VERIFIED** browser matrix | P3_A4 | PO visual QA |
| Local Docker PostgreSQL | Yes | CI + verify | Container running | PHASE_PROGRESS | — |
| CI + lint/security | Yes | GitHub Actions (remote) | `verify_foundation.sh` | ci.yml | Push **NO-GO** |
| Active Storage encrypted PoC | Yes | Storage tests | Encrypted disk | P3_A6 | ADR-010 prod **BLOCKED** |
| Quarantine + scan job | Yes | EICAR, quarantine | Job finished in dev | P3_A6 | ClamAV **NOT VERIFIED** |
| Backup restore proof | Yes | Recovery test | `scripts/p3_storage_backup_drill.sh` | P3_A6 | Off-site **NOT VERIFIED** |
| Dockerfile web/worker split | Partial | — | Not built here | This doc | Worker CMD documented |
| Permission cross-org denial | Yes | Integration tests | — | P3_A3 | — |
| Fresh clone boot + tests | Yes | CI pattern | `verify_foundation.sh` local | SETUP | — |

**Master spec exit sentence:** *Fresh clone passes boot, migrations, tests, audit, assets, responsive shell smoke tests, permission enforcement, role-isolation, encrypted-storage acceptance gate.*

| Clause | Status |
|--------|--------|
| Boot/migrations/tests/audit | **VERIFIED** (195 tests, foundation script) |
| Responsive shell smoke | **NOT VERIFIED** (no 1440/390 browser sign-off this session) |
| Permission enforcement | **VERIFIED** |
| Encrypted storage gate | **VERIFIED** (automated); production storage **BLOCKED** |

## Runtime environment

| Item | Value |
|------|--------|
| Ruby | 3.4.13 (mise, arm64-darwin25) |
| Rails | 8.1.4.1 |
| PostgreSQL | Docker `ant_marine_postgres_dev`, port 5433 |
| pg gem | 1.7.0-arm64-darwin (libpq PG 180006) |
| Queue DB | `ant_marine_development_queue` |

## Worker segfault — diagnosis and fix

**Symptom:** `jobs.1` Ruby **SIGSEGV** during `PGconnectStart` after `fork` (DiagnosticReports: *multi-threaded process forked*, *crashed on child side of fork pre-exec*).

**Cause:** Solid Queue **fork** supervisor with ActiveRecord/libpq connections in a multi-threaded parent (not a Solid Queue logic bug).

**Mitigations (P3-A7):**

1. `config/initializers/solid_queue_fork_safety.rb` — clear all AR connections immediately before fork.
2. `Procfile.dev` — default `SOLID_QUEUE_SUPERVISOR_MODE=async` and unset `RUBY_DEBUG_*` for the worker child (debug open hooks + fork are unsafe).
3. `.env.example` documents `SOLID_QUEUE_SUPERVISOR_MODE`.

**Runtime evidence after fix:**

- `bin/jobs start` with `async` mode: process **stays alive** (no immediate segfault).
- `SolidQueue::Job` row for `Infrastructure::WorkerSmokeJob` reached **`finished_at`** in development (e.g. job id 5, 2026-11-22).
- `AuditEvent` `infrastructure.worker_smoke` rows recorded (metadata `source: solid_queue`).

**Remaining:** Developer must **restart `bin/dev`** to pick up Procfile changes. Fork mode on macOS should only be used with the fork-safety initializer; prefer **async** locally. Linux production may use **fork** (Docker).

## Deployment topology (future Coolify/Hetzner — not deployed)

| Process | Command | Notes |
|---------|---------|--------|
| Web | `bin/thrust bin/rails server` (Dockerfile default) or `bin/rails server` | `db:prepare` via `bin/docker-entrypoint` |
| Worker | `bin/jobs` or `bin/rails solid_queue:start` | Entrypoint runs `db:prepare` when argv is `bin/jobs` |
| DB | `ant_marine_production` + queue/cache/cable DBs | `config/database.yml` |
| Storage | `local_encrypted` until encrypted object store approved | `Storage::ProductionServiceGate` blocks plain S3 |

**Required env (names only):** see `.env.example` (DB, mail, `STORAGE_*`, `SOLID_QUEUE_SUPERVISOR_MODE`, `JOB_CONCURRENCY`).

## Database initialization order

1. `bin/rails db:prepare` (primary + queue schemas)
2. `bin/rails db:migrate`
3. Queue migrations under `db/queue_migrate` (via prepare)
4. **`bin/rails db:seed`** — `Authorization::CatalogueSeeder` (71 permissions, 13 roles) — **required before permission-protected traffic**
5. Optional bootstrap user (documented in SETUP; not auto-run)

Production must fail readiness if catalogue missing (`GET /ready`).

## Health and readiness

| Endpoint | Semantics | Status |
|----------|-----------|--------|
| `GET /up` | **Liveness** (Rails boot) | **VERIFIED** (browser + tests) |
| `GET /ready` | **Readiness** (DB, permission catalogue, mail label, storage gate) | **VERIFIED** (integration test); no secrets in JSON |

Mail: production readiness **503** until SMTP configured (`Notifications::MailDelivery`).

## Storage and scanner (unchanged gates)

| Area | Status |
|------|--------|
| App-side AES-GCM + EncryptedDisk | **VERIFIED** (tests) |
| Plain `private_s3` | **BLOCKED** in production boot |
| Encrypted S3 / MinIO proof | **NOT VERIFIED** (no isolated MinIO in this session) |
| ClamAV | **NOT VERIFIED** (`clamscan` absent) |
| Real confidential uploads | **BLOCKED** |

## Backup / recovery

- **VERIFIED BY AUTOMATED TEST:** `test/integration/storage_recovery_proof_test.rb`
- **Script:** `scripts/p3_storage_backup_drill.sh` runs that test as a drill wrapper
- **NOT VERIFIED:** off-site production restore, RPO/RTO numbers

## CI and fresh clone

- `.github/workflows/ci.yml` + `scripts/verify_foundation.sh` — **VERIFIED** locally (195 tests, RuboCop, Brakeman, bundler-audit).
- CI does not require `.env.local` or paid object storage credentials.

## Browser acceptance (P3-A4 outstanding)

| Screen | Automated | Visual browser (1440/768/390) |
|--------|-----------|-------------------------------|
| P01 public | Partial | **NOT VERIFIED** this session |
| S01 / M08 staff | Partial | **NOT VERIFIED** |
| C01 client | Partial | **NOT VERIFIED** |

`GET /up` and `GET /ready` reached on local port 3000. DOM/auth flows not re-signed-off against Design Studio in this pass.

## Authorization / Owner protection

- P3-A3 engine: **VERIFIED** by existing tests.
- **OwnerProtection** not wired to membership suspend/demote/remove APIs — **no such routes yet** (safe boundary). Mandatory before first lifecycle mutation APIs (Phase 4 Team slice).

## Operational runbooks (summary)

| Scenario | Action |
|----------|--------|
| Start app | `docker compose … up -d db`; copy `.env.local`; `bin/dev` |
| Worker crash (macOS) | Set `SOLID_QUEUE_SUPERVISOR_MODE=async`; restart Foreman; ensure fork-safety initializer loaded |
| Queue backlog | `bin/rails runner 'SolidQueue::Job.where(finished_at: nil).count'`; inspect `solid_queue_failed_executions` |
| Missing permissions | `bin/rails db:seed` |
| Storage decrypt failure | Check `STORAGE_ENCRYPTION_KEY` version; never log key |
| Scanner outage | Assets remain quarantined; do not set fake `:clean` in production |
| Deploy rollback | Revert image + migrate down only with PO approval (not exercised) |

## Phase 3 exit decision (local)

| Decision | Outcome |
|----------|---------|
| **Phase 3 foundation acceptance** | **CONDITIONAL GO** — code, tests, and most infra gates pass; visual browser matrix, ClamAV, encrypted S3, and production deploy **not verified** |
| **GitHub push (combined Phase 3)** | **NO-GO** until PO explicit approval (per instruction) |
| **Phase 4 planning** | **Allowed to plan**; **do not implement** until PO opens Phase 4 |

## Automated test baseline (P3-A7)

**195 runs, 729 assertions, 0 failures** (includes readiness + worker smoke job tests).