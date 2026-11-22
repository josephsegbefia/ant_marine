# Local setup & initial Rails boot (macOS + Cursor)

**This is a runnable setup plan, not evidence that setup has been performed on your Mac.** The attached starter bundle is a documentation/agent handoff, not an installed application. Run setup locally in Cursor's terminal, then ask the Cursor agent to perform the Rails initialization, verify its results, and commit the first working baseline.

## 1. Confirm source and working directory

Create an empty workspace/repository location, e.g. `~/Desktop/elorm/appsentrix/ant_marine`, or select the correct existing Git repository. **Do not run `rails new` in an unrelated or populated repository.** Use the repo name `ant_marine` for Rails application paths and avoid exposing private project docs publicly. Copy `AGENTS.md`, `.cursor/rules/`, `docs/` and `design/` from the handoff archive into the new app after scaffold generation.

## 2. Prerequisites to install before scaffolding

| Requirement | Purpose | How to validate |
|---|---|---|
| macOS with Xcode Command Line Tools | Ruby native gems/compiler | `xcode-select -p` |
| Homebrew | Local package manager | `brew --version` |
| `mise` | Isolated, reproducible Ruby version | `mise --version` |
| Ruby 3.4.x | Rails runtime; lock exact patch after validating | `mise exec -- ruby -v` |
| Bundler | Dependency lock/install | `mise exec -- bundle -v` |
| Rails 8.1.4.1 | Initial app generator, current verified patch baseline | `mise exec -- rails -v` |
| Docker Desktop (or compatible engine with Compose) | Local PostgreSQL | `docker info`; `docker compose version` |
| Git, Cursor | Source tracking and AI-agent implementation | `git --version`; open folder in Cursor |
| `libpq` | PostgreSQL native client for `pg` Ruby gem | `$(brew --prefix libpq)/bin/pg_config --version` |
| `vips` | Image processing and selected file previews | `vips --version` |

Ruby versions may evolve; if a newer supported Rails/Ruby patch is chosen, document and pin the exact working pair. Ruby on Rails 8.1 requires Ruby 3.2+, so 3.4 is a supported target. The project must use **the installed, locked version** in CI and deployment.

The supplied `scripts/bootstrap_macos.sh` performs safe prerequisites installation and version checks. Read it before executing. It does not connect to Hetzner, create a cloud server or edit production environments.

## 3. Initial local tool installation

```bash
# Run in a safe local folder after inspecting the script
bash scripts/bootstrap_macos.sh

# Use mise in the current shell, if not already activated
# Follow the activation command printed by the tool.
mise exec -- ruby -v
mise exec -- rails -v
```

If Docker Desktop is not installed or running, install/start it manually and confirm `docker info` succeeds. The script intentionally does not silently install/launch a large privileged desktop application.

## 4. Create Rails shell (Agent task B0.1)

From the parent directory of the final project folder, run once:

```bash
mise exec -- rails new ant_marine --database=postgresql --css=tailwind --javascript=importmap
cd ant_marine
```

This sets up standard Rails 8.1 foundations: ERB views, Propshaft, Importmap, Turbo/Stimulus, `tailwindcss-rails`, PostgreSQL, tests and the standard Dockerfile. Review the Gemfile/versions the generator actually created; don't assume all components are installed until verified.

**Important:** If you already created an `ant_marine/` directory containing the handoff, ask Cursor to inspect it and use a safe generator approach rather than clobbering files. Do not force overwrite.

Copy the starter's `AGENTS.md`, `.cursor/`, `docs/`, `design/`, `scripts/` and `templates/` into that fresh Rails repository. The archive root itself is **not** a generated Rails app. Commit the documentation to Git alongside the app.

## 5. Configure a separate local PostgreSQL instance

The supplied `templates/compose.dev.yml` is for **local only**. Copy it into the Rails root and start PostgreSQL:

```bash
cp templates/compose.dev.yml compose.dev.yml
```

Copy `.env.example` to `.env.local` (gitignored) and set `ANT_MARINE_DB_PASSWORD` to match your local choice, then start PostgreSQL:

```bash
docker compose --env-file .env.local -f compose.dev.yml up -d db
```

The integrated `compose.dev.yml` uses `${ANT_MARINE_DB_PASSWORD}` instead of a committed placeholder; keep `templates/compose.dev.yml` as the copy-from template with a documented example password.

Cursor must adjust **only the development/test connection sections** of the Rails-generated `config/database.yml` to use these variables while preserving Rails 8 production, queue/cache/cable database settings:

```yaml
development:
  <<: *default
  database: ant_marine_development
  host: <%= ENV.fetch("ANT_MARINE_DB_HOST", "127.0.0.1") %>
  port: <%= ENV.fetch("ANT_MARINE_DB_PORT", 5433) %>
  username: <%= ENV.fetch("ANT_MARINE_DB_USER", "ant_marine_dev") %>
  password: <%= ENV.fetch("ANT_MARINE_DB_PASSWORD") %>

test:
  <<: *default
  database: ant_marine_test
  host: <%= ENV.fetch("ANT_MARINE_DB_HOST", "127.0.0.1") %>
  port: <%= ENV.fetch("ANT_MARINE_DB_PORT", 5433) %>
  username: <%= ENV.fetch("ANT_MARINE_DB_USER", "ant_marine_dev") %>
  password: <%= ENV.fetch("ANT_MARINE_DB_PASSWORD") %>
```

Use the generated application's existing `&default` definition; do not duplicate/replace the rest of the file. For a local-only test password, export it in your shell, or create a private untracked file and load it locally. The value should match the local Docker Compose example. Never commit actual secrets.

```bash
export ANT_MARINE_DB_PASSWORD='local-only-change-me'
mise exec -- bin/rails db:prepare
mise exec -- bin/rails test
mise exec -- bin/rails tailwindcss:build
mise exec -- bin/rails zeitwerk:check
mise exec -- bin/rails server
```

To verify the browser, open `http://localhost:3000`. It should show the generated Rails page or explicitly planned temporary root route. Stop with `Ctrl+C`. No production access is involved.

## 6. Agent configuration and development quality

- `.cursor/rules/ant-marine-core.mdc` applies to all work; `ant-marine-rails.mdc` applies on Rails-relevant files. Cursor project rules are version-controlled.
- `AGENTS.md` is an additional repo-wide working agreement.
- Standard Rails default testing and security tools should be inspected before adding gems; `bin/rubocop`, `bin/brakeman` and `bin/rails test` should be available or installed explicitly with an explained decision.
- CI: Ruby/Bundler lockfile install; PostgreSQL test database; lint/static analysis; migration checks; tests and assets build.
- Before implementing business models: agree Phase 2 architecture and role/permission decisions. At most create a basic welcome page for proof of boot.

## 7. Foundation checks and acceptance

Check from project root:

```bash
bash scripts/verify_foundation.sh
```

It checks local runtime, Rails boot, Postgres connectivity, tests, code loading and assets. Record actual command outputs. If a check fails, do not label the checkpoint complete.

**B0 acceptance:** project can be cloned; pinned Ruby/Rails and dependencies install; local Postgres starts; `db:prepare` succeeds; web process runs; baseline tests/lint/security and asset build pass; no credentials committed; Cursor rules and spec are readable; baseline Git commit exists.

## 8. P3-A1 — development authentication bootstrap

Rails 8 native authentication is enabled (`User`, database-backed `Session`, password reset mailer). **There is no public signup.** Provision the first Super Administrator only in development/test:

```bash
export ANT_MARINE_BOOTSTRAP_EMAIL="you@example.com"
export ANT_MARINE_BOOTSTRAP_PASSWORD="choose-a-strong-password"
mise exec -- bin/rails ant_marine:bootstrap_super_admin
```

The task is idempotent: it creates the single active `ant_marine` organisation if missing, creates the user if the email is new, and adds a `staff.super_administrator` membership without changing an existing user's password or silently promoting roles.

**Sessions (P2-OD-040):** cookie holds signed `session_id` only; rows store `security_version_at_issue`, `revoked_at`, `expires_at` (30-day absolute), and `last_active_at` (12-hour idle). Bumping `users.security_version` (password change, suspension) invalidates outstanding sessions. Production cookies use `Secure`; `HttpOnly` and `SameSite=Lax` always.

**Portals:** `/staff` requires an active ANT Marine membership; `/client` requires an active client-organisation membership. Users with both must choose a workspace at `/workspace`.

## 9. What NOT to provision yet

- Do **not** spin up production on Hetzner or move live client documents before storage encryption and backup design are approved.
- Do **not** create all business tables immediately; this is Phase 2 modeling and Phase 4 incremental delivery.
- Do **not** install a React stack, Node UI builder, Kafka, Redis, Elasticsearch or a full monitoring system speculatively.
- Do **not** set real SMTP, S3 access keys, Cloudflare tokens, Coolify secrets, or live payment credentials in the starter archive.

## 10. Deployment topology, to finalize in Phase 3 and harden in Phase 5

Cloudflare (proxied public web traffic) → Hetzner server running Coolify-managed Rails web + Rails background worker + PostgreSQL. Private S3-compatible object storage for files; separate off-server encrypted database and object backups. Test direct browser uploads carefully: Cloudflare upload limits and object-storage encryption may conflict with an assumption that every upload can be directly PUT to S3.

Staging must be isolated from production, with separate secrets, DB, object bucket and mail delivery mode. Require TLS, restricted admin access, job monitoring, restore drills and explicit release approval.
