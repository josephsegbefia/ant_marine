# Cursor Agent — First implementation prompt (B0 only)

Paste the text below into Cursor's **built-in Agent**, in the fresh Rails project folder. Do not use Codex CLI.

---

You are the Rails foundation agent for **ANT Marine W.A.** We are at the **B0 prerequisite/toolchain checkpoint, before Phase 2**, not at feature development.

Before changing code, read all of:
- `AGENTS.md`
- `docs/ANT_MARINE_MASTER_SPEC.md`
- `docs/SETUP_AND_BOOTSTRAP.md`
- `docs/PHASE_PROGRESS.md`
- `design/PHASE_1_DESIGN_HANDOFF.md`

Verify the Rails application root and existing files before doing anything. Do not overwrite or recreate any existing application. If Rails has not yet been scaffolded, **stop and report what is missing**, then propose the exact safe `rails new` command and correct working directory.

B0 objective: confirm this repo is a clean **Rails 8.1 + Ruby 3.4.x + PostgreSQL + Hotwire/Turbo/Stimulus + importmap + Tailwind** modular-monolith baseline suitable for implementing ANT Marine. Prefer Rails-native defaults and do not add React, Node frontend bundlers, Redis or unrelated services.

Tasks:
1. Audit Ruby, Rails, Bundler, Docker Compose, PostgreSQL connectivity, Rails defaults, `bin/dev`, generated Dockerfile and Gemfile; report actual versions.
2. Ensure the project-local Ruby version is pinned consistently, and Gemfile.lock is committed. Preserve the generated Rails Solid Queue/Cache/Cable production configuration.
3. Configure **local-only** PostgreSQL in development/test using `templates/compose.dev.yml`, without committing live secrets. Ensure the test database is different from development.
4. Verify Hotwire (Turbo + Stimulus), Tailwind via `tailwindcss-rails` v4, Propshaft, Importmap, Active Storage, Action Mailer, test runner, RuboCop and Brakeman. Install only a missing **baseline** dependency, and explain why.
5. Provide a safe health route or simple welcome page only if boot verification needs one. Do not generate business models, schema or customer accounts yet.
6. Run and document actual command outcomes: Rails boot, PostgreSQL preparation, `bin/rails test`, `bin/rails zeitwerk:check`, CSS build, lint and security check (if installed), basic browser visit and `git diff --check`.
7. Report security and configuration concerns, exact files changed, failure causes, and the next gate. Update `docs/PHASE_PROGRESS.md` only with verified evidence.

Never install/provision cloud services or alter Hetzner, Coolify, Cloudflare, production database, real S3 buckets or email providers. If local installations require administrator approval, explain the command and request approval at that point.

**STOP after B0.** Do not begin Phase 2 domain modeling or Phase 4 features until the user reviews the B0 result.

---
