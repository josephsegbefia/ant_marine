# ANT Marine phase progress

| Gate | Status | Evidence required |
|---|---|---|
| Phase 1 — UI/UX | Delivered; final approval pending | Approved studio review export, corrected design HTML and signed-off wording |
| Preflight B0 — toolchain | **B0.0–B0.3 passed** | See B0 checkpoint log |
| Phase 2 — architecture | **Exit preparation complete — approval pending P2.5B trio** | `P2_5B_PHASE_2_EXIT_DECISIONS.md`; P2.5A in `08a5423` |
| Phase 3 — foundation | **P3-A1 locally accepted — awaiting PO merge approval** | Branch `feat/p3-a1-auth-organizations` @ `635f1d4` |
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
| P2.1 Domain architecture | 2026-11-22 | **Reconciled — awaiting stakeholder approval** | Tiered RBAC access, ADR proposed defaults, DCR awaiting approval |
| P2.2 Auth & permissions architecture | 2026-11-22 | **Designed** | `docs/architecture/P2_2_*`; finance/confidential matrix refinements |
| P2.3 Database architecture | 2026-11-22 | **Designed** | `docs/architecture/P2_3_*`; P2-OD-040–042 proposed |
| P2.4 Workflow architecture | 2026-11-22 | **Designed** | `docs/architecture/P2_4_*`; P2-OD-043–048 proposed |
| P2.5 Final architecture review | 2026-11-22 | **Complete — partial approval** | `docs/architecture/P2_5_*` |
| P2.5A Stakeholder decisions | 2026-11-22 | **Enumerated ADRs approved** | Commit `08a5423`; `P2_5A_STAKEHOLDER_DECISION_RECORD.md` |
| P2.5B Phase 2 exit prep | 2026-11-22 | **P2-OD-040–042 approved** | Product owner 2026-11-22; Phase 1 sign-off checklist still open |
| P3-A1 Auth & organisations | 2026-11-22 | **Locally accepted** | `635f1d4`; 46 tests green; A01/A05/A06 + reset edit aligned; A02–A04 deferred |
| P3-A1 Acceptance | 2026-11-22 | **Passed (agent checkpoint)** | Automated + integration journeys; restart stale Puma on :3000 before manual QA |

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