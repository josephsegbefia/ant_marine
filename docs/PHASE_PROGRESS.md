# ANT Marine phase progress

| Gate | Status | Evidence required |
|---|---|---|
| Phase 1 — UI/UX | Delivered; approval pending | Approved studio review export, corrected design HTML and signed-off wording |
| Preflight B0 — toolchain | **B0.0–B0.2 passed** (2026-11-22) | Ruby 3.4.13, Rails 8.1.4.1, OrbStack PostgreSQL 17 on 127.0.0.1:5433, `verify_foundation.sh`, browser root 200 |
| Phase 2 — architecture | Not started | Reviewed domain map, state transitions, permissions, decisions, implementation slices |
| Phase 3 — foundation | Not started | Rails baseline, auth/policies, design shells, CI/tests, secure file PoC |
| Phase 4 — features | Not started | End-to-end acceptance per vertical slice |
| Phase 5 — deployment | Not started | Staging checks, backup restoration, security/performance/SEO acceptance, launch approval |

## B0 checkpoint log

| Checkpoint | Date | Result | Notes |
|---|---|---|---|
| B0.0 Environment audit | — | Passed (prior session) | — |
| B0.1A Prerequisites | — | Passed (prior session) | mise Ruby 3.4.13, Rails 8.1.4.1 |
| B0.1B Rails application | 2026-11-22 | **Passed** | Commit `c448c4c`, module `AntMarine` |
| B0.2 Local PostgreSQL | 2026-11-22 | **Passed** | Container `ant_marine_postgres_dev`, volume `ant_marine_local_pg`, databases `ant_marine_development` / `ant_marine_test` |

## Local development quick reference

Paths assume project root `~/Desktop/ant_marine`. Credentials live in **gitignored** `.env.local` (not committed).

### Start PostgreSQL

```bash
cd ~/Desktop/ant_marine
docker compose --env-file .env.local -f compose.dev.yml up -d db
docker inspect -f 'health={{.State.Health.Status}}' ant_marine_postgres_dev
```

Wait until `health=healthy`.

### Stop PostgreSQL (keep data)

```bash
docker compose --env-file .env.local -f compose.dev.yml stop db
```

Do **not** use `docker compose down -v` (that would delete the named volume).

### Load environment for Rails

```bash
set -a && source .env.local && set +a
```

Or prefix one-off commands: `set -a && source .env.local && set +a && mise exec -- bin/rails …`

### Prepare databases

```bash
set -a && source .env.local && set +a
mise exec -- bin/rails db:prepare
mise exec -- bin/rails db:prepare RAILS_ENV=test
```

### Start Rails

```bash
set -a && source .env.local && set +a
mise exec -- bin/rails server
# or: mise exec -- bin/dev   # Rails + Tailwind watcher (requires PostgreSQL up)
```

Open [http://localhost:3000](http://localhost:3000).

### Run tests and foundation checks

```bash
set -a && source .env.local && set +a
bash scripts/verify_foundation.sh
```

The script sources `.env.local` and runs commands via `mise exec` when `mise.toml` is present.

### Troubleshooting database connections

| Symptom | Likely cause | Fix |
|---|---|---|
| `connection refused` / socket errors | DB container stopped | `docker compose --env-file .env.local -f compose.dev.yml up -d db` |
| `password authentication failed` | `.env.local` out of sync with container | Align `ANT_MARINE_DB_PASSWORD` with compose; recreate container only if you understand data impact |
| `KeyError: ANT_MARINE_DB_PASSWORD` | Env not loaded | `source .env.local` before Rails |
| Wrong Ruby / Bundler errors | System Ruby used | Use `mise exec --` or run `verify_foundation.sh` |

Update dates and links to test reports as work progresses.