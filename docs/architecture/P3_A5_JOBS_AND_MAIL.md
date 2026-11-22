# P3-A5 — Background jobs, email and notification delivery

**Status:** Local foundation with acceptance hardening. No live SMTP. No inbox, SMS, or product reminders.

## Queue

| Environment | Adapter | Database |
|-------------|---------|----------|
| Development | Solid Queue | `ant_marine_development_queue` (`config/database.yml` `queue`) |
| Test | Active Job `:test` | None. No network. |
| Production | Solid Queue | `ant_marine_production_queue` |

`config/queue.yml` runs one worker process (`JOB_CONCURRENCY`, default 1) with 3 threads on the `mail` and `default` queues. Finished jobs are cleared hourly in production via `config/recurring.yml`.

Web and worker are separate processes. `bin/dev` starts `bin/jobs`. Do **not** set `SOLID_QUEUE_IN_PUMA` at the same time, or two workers will share the development queue. Puma loads Solid Queue only when `SOLID_QUEUE_IN_PUMA` is present **and non-blank** (`config/puma.rb`), which is for a later single-container deploy.

## Local commands

```bash
bin/dev                         # web, Tailwind, and one worker
bin/jobs                        # worker only, if bin/dev is not already running it
```

`Procfile.dev` processes: `web` (`SOLID_QUEUE_IN_PUMA=` so Puma does not embed a worker), `css`, `jobs`.

Stop the worker with SIGTERM (Ctrl-C). Solid Queue finishes the current job and exits.

Unhandled job exceptions stay in `solid_queue_failed_executions` on the queue database. Inspect them from a Rails console in development:

```ruby
SolidQueue::FailedExecution.order(:id).last&.exception_class
SolidQueue::FailedExecution.last.retry
```

There is no public queue dashboard. `DeliverInvitationEmailJob` sets `log_arguments = false`, so failed rows do not repeat the sealed envelope in routine logs.

## Mail

| Environment | Delivery |
|-------------|----------|
| Development | `:file` under `tmp/mails`. No SMTP password. |
| Test | `:test` (`ActionMailer::Base.deliveries`) |
| Production | SMTP when `SMTP_ADDRESS` is set **and** `delivery_method` is `:smtp`. Otherwise outbound mail is **not** ready. |

### Production readiness (fail closed)

Check before deploy or when debugging mail:

```ruby
Notifications::MailDelivery.configured?   # => true/false
Notifications::MailDelivery.readiness_label  # => "ready" | "missing_smtp"
```

Required for production send:

- `SMTP_ADDRESS` (and usual `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` as needed)
- `MAIL_FROM`, `APP_HOST`, `APP_PROTOCOL` for correct links

When `SMTP_ADDRESS` is absent in production:

- `action_mailer.delivery_method` stays `:test` (no accidental network delivery).
- `raise_delivery_errors` is **true**.
- `Notifications::Dispatch` and `Notifications::MailDelivery.ensure_ready!` raise `Notifications::MailDelivery::NotConfigured` — invitations are **not** enqueued and password reset does **not** queue.
- An Action Mailer interceptor runs the same guard on any `deliver_*` path.

Development and test skip the guard.

Optional environment variables, none of which are committed:

- `MAIL_FROM` — default `ANT Marine W.A. <no-reply@localhost>`
- `APP_HOST`, `APP_PROTOCOL` — links in production mail
- `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`

No email provider is chosen in this slice. Do not send real mail until the product owner approves a provider and DNS.

## Invitation delivery

`Invitations::Issue` commits the invitation, then `Notifications::Dispatch.invitation!` enqueues `DeliverInvitationEmailJob`.

The job argument is an **encrypted** envelope (`Notifications::InvitationTokenSeal`), not the raw token:

- AES-256-GCM via `ActiveSupport::MessageEncryptor` and a purpose-specific key from `key_generator`.
- Authenticated encryption: tampered ciphertext is rejected; envelope honours `expires_at` with the invitation.
- Queue rows and job logs must not contain the raw token (`log_arguments = false`).
- Anyone with `secret_key_base` can decrypt (same trust boundary as the app). Base64 inspection of the envelope does not reveal the token.

Before sending, the job reloads the invitation. Revoked, expired, accepted, or missing invitations are skipped. Resend revokes the prior pending row; a delayed job for the old id cannot email. A retry cannot revive them. Sending does not change invitation status. Provider delivery is at-least-once: a retry after a timeout can send a second copy of the same link. Exactly-once delivery is not claimed.

The job calls `InvitationsMailer.invite(...).deliver_now` — it does **not** enqueue a second `MailDeliveryJob` bearing the token.

Jobs wait for the surrounding transaction to commit (`enqueue_after_transaction_commit`). A rolled-back invitation is not emailed.

Password reset still uses `PasswordsMailer` with the user id only. The reset token is created when the message is rendered, not stored on the job.

## Retries

Transient timeouts, deadlocks, and `Net::SMTPServerBusy` / `Net::SMTPUnknownError` retry up to 5 times with polynomial backoff. Permanent SMTP failures (`Net::SMTPFatalError`, `Net::SMTPSyntaxError`) are **discarded inside ActiveJob** (`report: true` + redacted `permanent_smtp_discard` log line with `invitation_id` only). They do **not** create `solid_queue_failed_executions` rows because the exception is handled before the queue marks the job failed. Missing records are discarded.

Operators identify permanent SMTP discards via Rails logs, `discard.active_job` instrumentation, and the error reporter — not via the failed-executions table.

## Notifications

`Notifications::Events` lists the two access emails that exist today: `invitation.issued` and `password.reset_requested`. There is no notifications table, inbox, preference screen, or product event yet. The approved inbox table stays deferred until the first in-app notification slice.

## Acceptance evidence (P3-A5 final)

| Area | Evidence |
|------|----------|
| Token encryption | `test/lib/notifications/invitation_token_seal_test.rb` |
| Queue confidentiality | `test/jobs/deliver_invitation_email_job_test.rb` |
| Production mail guard | `test/lib/notifications/mail_delivery_test.rb` |
| Transaction / resend | Rollback enqueue test; resend + stale seal test in job tests |
| Quality | `verify_foundation.sh`, Brakeman, bundler-audit after acceptance commit |

Worker smoke: `Procfile.dev` verified in repo; live `jobs.1` foreman output **not re-verified** in this acceptance session (prior `bin/dev` log showed `web.1` and `css.1` only).

## Deployment order

1. Migrate the primary database.
2. Prepare the queue database (`db/queue_schema.rb` via the `queue` connection).
3. Seed the permission catalogue before serving permission-gated traffic.
4. Confirm `Notifications::MailDelivery.configured?` before enabling invitation traffic in production.
5. Start the web process and a separate `bin/jobs` process.
6. Set SMTP variables only after provider approval.