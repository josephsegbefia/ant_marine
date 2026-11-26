# F4-04B — Commercial decisions, quotation release & database history protection

**Status:** Code complete (F4-04B + F4-04B-H1) — simulated decisions only; live commercial acceptance **disabled**

**Baseline:** F4-04A at `3e5ce04`; H1 baseline `6b52389`

**Schema format:** `config.active_record.schema_format = :sql` → `db/structure.sql`

## 1. Purpose

Complete the commercial workflow for **exact-version** client decisions against **explicit portal releases**, with PostgreSQL trigger-based history protection for frozen quotation content and append-only decision records.

Hard stops for this checkpoint:

- No live commercial release or binding acceptance
- No real email
- No automatic project creation (F4-05)
- No production DB privilege changes

## 2. F4-04A acceptance completion

Completed during F4-04B preflight:

| Check | Result |
|---|---|
| Invitation activate / expire / revoke / consume | Covered by existing invitation + portal tests; contacts managed without portal Users |
| Authenticated session revocation | Membership / portal access rechecked at request time |
| Non-user business contacts | `ClientContact` + staff Clients Access tab (`Clients::ManageContact`) |
| Responsive client/staff commercial UI | Automated + browser spot-check @1440 / 1280 / 768 / 390 |

## 3. Client contact architecture

- `client_contacts` belongs to a **client** `Organization`
- Staff can add / archive contacts **without** creating `User` / `Membership`
- Portal accounts remain invitation-only (Phase 3 / F4-04A)
- Contacts are not a parallel authentication model

## 4. Database history protection

### Functions (in `db/structure.sql`)

| Function | Role |
|---|---|
| `ant_marine_reject(text)` | Raises integrity violation |
| `ant_marine_quote_revision_protect()` | Blocks delete / unfreeze / commercial field changes on frozen revisions |
| `ant_marine_quote_line_item_protect()` | Blocks insert/update/delete when OLD or NEW parent revision is frozen; locks parent `FOR UPDATE` |
| `ant_marine_quote_response_protect()` | Append-only decisions (no UPDATE/DELETE) |

**F4-04B-H1:** `ant_marine_history_bypass_enabled()` and all GUC bypass branches were **removed**. Ordinary roles can `SET` custom GUCs, so a GUC gate was not a privilege boundary.

### Triggers

- `quote_revisions_history_protect` BEFORE UPDATE OR DELETE
- `quote_line_items_history_protect` BEFORE INSERT OR UPDATE OR DELETE
- `quote_responses_history_protect` BEFORE UPDATE OR DELETE

### Protected commercial fields (frozen revisions)

title, scope, deliverables, exclusions, additional requirements, currency, subtotal/total, valid_until, payment terms, commercial exclusions, additional conditions, internal notes, recipient_snapshot, approval attribution/timestamps, preparer/submitter/contributors, predecessor, revision reason, version_number, quote_id, frozen_at.

### Legitimate metadata transitions (frozen revisions)

Allowed `revision_status` changes only:

- `approved` → `issued` | `superseded`
- `issued` → `superseded`

Other lifecycle fields used by issuance / delivery / withdrawal services remain outside the commercial-content blocklist where already modelled; commercial content itself cannot change.

### Bypass / admin policy (F4-04B-H1)

- **No** application-callable bypass GUC or SECURITY DEFINER escape hatch
- Test helper `with_history_protection_admin` may `DISABLE TRIGGER` only in `Rails.env.test?` as the table owner (fixture/cleanup). Application connections must never call it
- Prefer `travel_to` / pre-freeze setup over mutating frozen rows in tests
- `REVOKE TRUNCATE … FROM PUBLIC` on protected tables; table owners retain TRUNCATE until production uses a non-owner runtime role
- Disposable verification: `scripts/verify_history_protection_h1.sh`

## 5. SQL schema migration

- Removed `db/schema.rb` as the primary schema source
- `db/structure.sql` is the source of truth (includes functions + triggers)
- Queue DB continues to use its own structure dump (`db/queue_structure.sql` when present)
- Fresh disposable DB load verified: functions + triggers present after `psql -f db/structure.sql`
- CI continues to use `bin/rails db:prepare` (loads SQL schema)
- **Rollback:** restoring a pre-F4-04B `schema.rb` era will **not** recreate triggers — restore must use matching `structure.sql` and verify trigger presence

## 6. Database privilege boundary

Triggers raise the cost of accidents; they do **not** stop a table owner / superuser.

Local disposable verification (not production):

- Runtime role without ownership **cannot** `DISABLE TRIGGER` on `quote_revisions`
- Runtime role **cannot** `DROP FUNCTION ant_marine_reject`

**Production gate (still open):** separate migration/admin role vs least-privilege app runtime role; no ALTER/DROP/TRUNCATE of historical tables; never grant ownership of protected tables to the runtime role.

## 7. Commercial decision model (`QuoteResponse`)

Append-only record identifying:

- Quotation + exact `QuoteRevision`
- Explicit `QuotePortalRelease`
- Client organisation + responding membership/user
- Response: `accepted` | `declined` | `changes_requested`
- `confirmed_at`, reason (required for decline / changes)
- `mode` = `simulated` only in F4-04B
- Server `idempotency_key`, `offer_snapshot`, `confirmation_evidence`

Service: `Commercial::QuoteDecision`

- Re-checks authority at execution (`quotes.accept` / `quotes.decline`)
- Staff cannot act as client representatives
- Locks release → revision → quote; refuses conflicting terminals
- Idempotent on identical key; conflict on competing decisions
- `available?` is **false in production**

### Offer eligibility

Rejects decisions against draft / unreleased / inactive release / wrong org / superseded / withdrawn / expired (`valid_until < Time.zone.today`) / non-simulated (live not enabled).

Expiration boundary: offer is invalid once the calendar date in the app timezone is **after** `valid_until` (i.e. expired when `valid_until < Time.zone.today`).

### Decision effects

| Decision | Effect |
|---|---|
| Accept | Terminal; simulated notice; **no** project creation; guidance for F4-05 |
| Decline | Terminal with reason; offer closed for further decisions |
| Request changes | Non-terminal; notifies staff; previous offer remains until withdrawn/superseded/expired; staff may create a **new** revision (independent approval) |

Accepted commercial content remains frozen; no silent withdraw/supersede/amount change of an accepted exact version without separately approved business rules (unsupported operations blocked).

## 8. UI

- Client quotation detail: summary, PDF, decision actions (authorised only), history, simulated banners
- Confirmation page (`decide`) before accept / decline / changes — explicit confirm checkbox; acceptance not preselected
- Staff quotation details: `_decisions` panel with actor, time, reason, next-step guidance
- Internal notifications via `Notifications::StaffPublisher.quote_decision` (in-app only)

## 9. Enquiry & project boundary

- Enquiry statuses are not auto-closed by a commercial decision
- Accepted simulated offer → staff-visible decision + “project setup is the next step” copy
- **No** `Project` model or Create project control in F4-04B

### F4-05 integration contract (prepared, not implemented)

**Do not implement Project models in F4-04B-H1.**

| Path | Rules |
|---|---|
| **LIVE** | Requires a valid **live** acceptance, approved commercial policy, active client organisation, and authorised staff initiation |
| **SIMULATION** | May later create an **explicitly simulated** project only inside isolated development/test QA organisations. Simulation must **never** establish live operational eligibility |

Both paths must bind:

- Exact accepted quotation revision
- Recorded decision evidence
- Client organisation
- Related enquiry where applicable
- Immutable commercial scope
- Agreed currency and amount
- Explicit staff authorization

**No automatic project creation** from acceptance alone.

## 10. Simulated restrictions

- Portal releases remain `simulated` only for client-visible offers in this checkpoint
- Decisions force `mode: simulated`
- Production refuses `QuoteDecision.available?`
- Simulated acceptance must not become live commercial eligibility or production project eligibility

## 11. Audit

Events such as `quote.decision.accepted|declined|changes_requested` with release/version/mode metadata. No tokens, passwords or unnecessary PII.

## 12. Tests

- Model/domain/policy/integration coverage for authority, eligibility, concurrency, triggers (direct SQL)
- Full suite + system tests + `scripts/verify_foundation.sh` required before checkpoint claim

## 13. Outstanding production gates

Formal design sign-off; F4-01 visual/editorial; approved commercial terms / tax / deposit / acceptance wording; client decision authority policy; production email + sender domain; **live** quotation release; **live** commercial acceptance; encrypted storage / malware / backup acceptance; **restricted runtime DB privileges in production**; deployment acceptance.
