# ANT Marine phase progress

| Gate | Status | Evidence required |
|---|---|---|
| Phase 1 — UI/UX | Delivered; final approval pending | Approved studio review export, corrected design HTML and signed-off wording |
| Preflight B0 — toolchain | **B0.0–B0.3 passed** | See B0 checkpoint log |
| Phase 2 — architecture | **In progress** — P2.1 reconciled with RBAC; stakeholder approval pending | Reviewed domain map, tiered project access, permissions, ADR proposed defaults, DCR |
| Phase 3 — foundation | Not started | Rails baseline, auth/policies, design shells, CI/tests, secure file PoC |
| Phase 4 — features | Not started | End-to-end acceptance per vertical slice |
| Phase 5 — deployment | Not started | Staging checks, backup restoration, security/performance/SEO acceptance, launch approval |

## B0 checkpoint log

| Checkpoint | Date | Result | Notes |
|---|---|---|---|
| B0.0 Environment audit | — | **Passed** | Toolchain and workspace audit |
| B0.1A Prerequisites | — | **Passed** | mise Ruby 3.4.13, Rails 8.1.4.1 |
| B0.1B Rails application | 2026-11-22 | **Passed** | Commit `c448c4c`, module `AntMarine` |
| B0.2 Local PostgreSQL | 2026-11-22 | **Passed** | Commit `70a44f4`; PostgreSQL 17, `ant_marine_development` / `ant_marine_test`, `db:prepare`, HTTP 200, read/write verification |
| B0.3 Development quality | 2026-11-22 | **Passed** | Commit `28a1b2b`; smoke tests (4), `scripts/verify_foundation.sh`, `.env.example`, README, `.github/workflows/ci.yml` |

## P2 checkpoint log

| Checkpoint | Date | Result | Notes |
|---|---|---|---|
| P2.1 Domain architecture | 2026-11-22 | **Reconciled — awaiting stakeholder approval** | Tiered RBAC access, ADR proposed defaults, DCR awaiting approval; see `git log -1` on main |

## Local development quick reference

Paths assume project root containing `Gemfile` (e.g. `~/Desktop/elorm/appsentrix/ant_marine`). Credentials: copy `.env.example` → `.env.local` (gitignored).

### Start PostgreSQL

```bash
docker compose --env-file .env.local -f compose.dev.yml up -d db
docker inspect -f 'health={{.State.Health.Status}}' ant_marine_postgres_dev
```

### Stop PostgreSQL (keep data)

```bash
docker compose --env-file .env.local -f compose.dev.yml stop db
```

Do **not** use `docker compose down -v` (deletes volume `ant_marine_local_pg`).

### Load environment

```bash
set -a && source .env.local && set +a
```

### Foundation verification

```bash
bash scripts/verify_foundation.sh
```

See `README.md` for Rails server and full setup links.

### Troubleshooting database connections

| Symptom | Likely cause | Fix |
|---|---|---|
| `connection refused` | DB container stopped | `docker compose --env-file .env.local -f compose.dev.yml up -d db` |
| `password authentication failed` | `.env.local` out of sync with container | Align `ANT_MARINE_DB_PASSWORD`; avoid recreating volume unless intended |
| `KeyError: ANT_MARINE_DB_PASSWORD` | Env not loaded | `source .env.local` before Rails |
| Wrong Ruby | System Ruby used | `mise exec --` or `verify_foundation.sh` |

Update dates and links as gates complete.