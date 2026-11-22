# P3-A5 — Background jobs, email and notification delivery

**Status:** Local foundation. No live SMTP. No inbox, SMS, or product reminders.

## Queue

| Environment | Adapter | Database |
|-------------|---------|----------|
| Development | Solid Queue | `ant_marine_development_queue` (`config/database.yml` `queue`) |
| Test | Active Job `:test` | None. No network. |
| Production | Solid Queue | `ant_marine_production_queue` |

`config/queue.yml` runs one worker process (`JOB_CONCURRENCY`, default 1) with 3 threads on the `mail` and `default` queues. Finished jobs are cleared hourly in production via `config/recurring.yml`.

Web and worker are separate processes. `bin/dev` starts `bin/jobs`. Do **not** set `SOLID_QUEUE_IN_PUMA` at the same time, or two workers will share the development queue. Puma only loads Solid Queue when that variable is set, which is for a later single-container deploy.

## Local commands

```bash
bin/dev                         # web, Tailwind, and one worker
bin/jobs                        # worker only, if bin/dev is not already running it
```

Stop the worker with SIGTERM (Ctrl-C). Solid Queue finishes the current job and exits.

Failed jobs stay in `solid_queue_failed_executions` on the queue database. Inspect them from a Rails console in development:

```ruby
SolidQueue::FailedExecution.order(:id).last&.exception_class
SolidQueue::FailedExecution.last.retry
```

There is no public queue dashboard.

## Mail

| Environment | Delivery |
|-------------|----------|
| Development | `:file` under `tmp/mails`. No SMTP password. |
| Test | `:test` (`ActionMailer::Base.deliveries`) |
| Production | SMTP only when `SMTP_ADDRESS` is set. Otherwise mail is not sent. |

Optional environment variables, none of which are committed:

- `MAIL_FROM` — default `ANT Marine W.A. <no-reply@localhost>`
- `APP_HOST`, `APP_PROTOCOL` — links in production mail
- `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`

No email provider is chosen in this slice. Do not send real mail until the product owner approves a provider and DNS.

## Invitation delivery

`Invitations::Issue` commits the invitation, then `Notifications::Dispatch.invitation!` enqueues `DeliverInvitationEmailJob`.

The job argument is a signed envelope (`Notifications::InvitationTokenSeal`), not the raw token. `log_arguments` is false, so routine enqueue logs omit it. The envelope expires with the invitation. A worker that has `secret_key_base` can still open the envelope. That is the same trust boundary as the application secret. The queue row does not contain the raw token in plaintext.

Before sending, the job reloads the invitation. Revoked, expired, accepted, or missing invitations are skipped. A retry cannot revive them. Sending does not change invitation status. Provider delivery is at-least-once: a retry after a timeout can send a second copy of the same link. Exactly-once delivery is not claimed.

Jobs wait for the surrounding transaction to commit (`enqueue_after_transaction_commit`). A rolled-back invitation is not emailed.

Password reset still uses `PasswordsMailer` with the user id only. The reset token is created when the message is rendered, not stored on the job.

## Retries

Transient timeouts, deadlocks, and `Net::SMTPServerBusy` / `Net::SMTPUnknownError` retry up to 5 times with polynomial backoff. Permanent SMTP failures (`Net::SMTPFatalError`, `Net::SMTPSyntaxError`) are discarded. Missing records are discarded.

## Notifications

`Notifications::Events` lists the two access emails that exist today: `invitation.issued` and `password.reset_requested`. There is no notifications table, inbox, preference screen, or product event yet. The approved inbox table stays deferred until the first in-app notification slice.

## Deployment order

1. Migrate the primary database.
2. Prepare the queue database (`db/queue_schema.rb` via the `queue` connection).
3. Seed the permission catalogue before serving permission-gated traffic.
4. Start the web process and a separate `bin/jobs` process.
5. Set SMTP variables only after provider approval.
