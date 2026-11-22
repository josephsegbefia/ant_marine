# ANT Marine W.A.

Modular Rails application for ANT Marine’s public website, client portal, and staff workspace. Phase 1 UI is defined in the design studio; implementation follows `docs/ANT_MARINE_MASTER_SPEC.md`.

## Technology stack

- **Ruby** 3.4.13 (via [mise](https://mise.jdx.dev))
- **Rails** 8.1 (Hotwire Turbo/Stimulus, Importmap, Propshaft)
- **PostgreSQL** 17 (local Docker)
- **Tailwind CSS** via `tailwindcss-rails`
- **Tests & quality:** Minitest, RuboCop (Omakase), Brakeman, bundler-audit

## Prerequisites

- macOS with Xcode Command Line Tools, Homebrew, mise, Docker (Desktop or OrbStack)
- See `docs/SETUP_AND_BOOTSTRAP.md` and `scripts/bootstrap_macos.sh` for first-time setup

## Local setup

1. Copy environment template:

   ```bash
   cp .env.example .env.local
   # Edit .env.local if needed — never commit it.
   ```

2. Start PostgreSQL (keeps data in Docker volume `ant_marine_local_pg`):

   ```bash
   docker compose --env-file .env.local -f compose.dev.yml up -d db
   docker inspect -f 'health={{.State.Health.Status}}' ant_marine_postgres_dev
   ```

3. Prepare databases and install gems:

   ```bash
   set -a && source .env.local && set +a
   mise exec -- bundle install
   mise exec -- bin/rails db:prepare
   mise exec -- bin/rails db:prepare RAILS_ENV=test
   ```

## Run the application

```bash
set -a && source .env.local && set +a
mise exec -- bin/rails server
# or: mise exec -- bin/dev
```

Open [http://localhost:3000](http://localhost:3000). Health check: [http://localhost:3000/up](http://localhost:3000/up).

## Automated checks

From the project root (loads `.env.local` when present):

```bash
bash scripts/verify_foundation.sh
```

Runs bundle check, database prepare (dev + test), Minitest, Zeitwerk, Tailwind build, RuboCop, Brakeman, and bundler-audit. CI runs the same checks (with GitHub-hosted PostgreSQL) in `.github/workflows/ci.yml`.

## Documentation

| Document | Purpose |
|---|---|
| [`AGENTS.md`](AGENTS.md) | AI agent working agreement |
| [`docs/ANT_MARINE_MASTER_SPEC.md`](docs/ANT_MARINE_MASTER_SPEC.md) | Master specification and phased roadmap |
| [`docs/PHASE_PROGRESS.md`](docs/PHASE_PROGRESS.md) | Checkpoint status |
| [`design/PHASE_1_DESIGN_HANDOFF.md`](design/PHASE_1_DESIGN_HANDOFF.md) | Screen inventory and journeys |
| [`design/ANT_Marine_Design_Studio_Phase_1.html`](design/ANT_Marine_Design_Studio_Phase_1.html) | Interactive Phase 1 design studio |
| [`docs/SETUP_AND_BOOTSTRAP.md`](docs/SETUP_AND_BOOTSTRAP.md) | Detailed bootstrap steps |