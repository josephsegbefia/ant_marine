# F4-02B — Public enquiries, quotation issuance and version revisions

Status: **code complete locally — product owner acceptance pending; not pushed, not deployed.**
Builds on F4-02A, F4-02A-H1 and F4-02A-H2, which the product owner accepted on 2026-11-25 (commit `1bfa652`). Their invariants are unchanged: four-eyes approval per version, current-version checks, frozen approved versions, no invented tax/deposit/legal terms.

Commits: `f323d2a` (enquiries), `f30ee7d` (versions), `bc8a85f` (issuance), `94bb91e` (acceptance fixes), plus this documentation commit.

## 1. Enquiry domain

`service_inquiries` (P2 schema name `ServiceInquiry`; "enquiry" in all user-facing text).

| Column group | Notes |
|---|---|
| `organization_id` | Always the ANT Marine organisation for public submissions |
| `client_organization_id` | Optional; empty for anonymous visitors. Not inferred from the email address |
| `service_id`, `service_title_snapshot` | Published service chosen, or both empty for "I'm not sure yet" |
| `reference_number` | `ANT-ENQ-YYYY-NNNNN`, advisory-locked allocation inside the save transaction, unique index |
| `channel` | `public_form` (others reserved: `contact_form`, `client_portal`, `staff`) — DB check |
| `current_status` | `submitted`, `under_review`, `needs_clarification`, `qualified`, `unqualified`, `merged`, `closed` — DB check. F4-02B only writes `submitted`; triage transitions belong to F4-03 |
| contact and work fields | company, name, email, phone (optional), project, vessel/facility, location, description, preferred date (optional, today or later) |
| `submission_token` | Unique; makes the POST idempotent |
| `submission_metadata` | `network_digest` (HMAC of IP, truncated — never the raw IP), `form_seconds`, `entry_service` |

Length limits are enforced in the model **and** a DB check. `quotes.service_inquiry_id` links a quotation to its enquiry, with a partial unique index allowing only one open (not withdrawn/superseded) quotation per enquiry. The link cannot be changed once set, and must belong to the same organisation.

Audit events: `service_inquiry.submitted`, `service_inquiry.quotation_started`, `quote.created_from_inquiry`.

### Routes

| Route | Purpose |
|---|---|
| `GET /request-a-quote` (`?service=slug` optional) | Four-step wizard (P19). Unknown or unpublished slugs are ignored |
| `POST /request-a-quote` | Submission |
| `GET /request-a-quote/received` | Confirmation; shows only the enquiry saved in this browser session |
| `GET /staff/enquiries`, `GET /staff/enquiries/:id` | Minimal staff list and detail |
| `POST /staff/enquiries/:id/prepare_quotation` | Start (or reopen) the draft quotation |

Entry points: the service page ("Enquire about this service" and "Request a quote", with the service preselected; "Contact the team" kept as a secondary link), featured service cards, the services index ("Describe your needs"), the homepage closing call to action ("Request a quote") and the contact page.

## 2. Public wizard

Steps: **Service → About the work → Your details → Review & send**. Server-rendered ERB with a Stimulus controller (`enquiry_wizard_controller.js`) that only shows/hides steps and runs the browser's own required-field checks before moving forward. Without JavaScript all fields render as one long form and submit normally. After a server error, the page reopens at the first step containing an error, keeps every answer, and shows an error summary linking to each field. No account is needed. No file uploads (storage gate) — the form says documents will be arranged securely after review.

## 3. Submission security

- **Server-side validation** of every field, including that the chosen service is published and belongs to ANT Marine (forged ids rejected).
- **Plain text only**: input is stored as typed and escaped on display; no HTML rendering.
- **Spam controls** without a new dependency: hidden honeypot field (`company_website`), signed "form opened at" stamp (minimum 3 seconds, maximum 12 hours) and Rails 8 `rate_limit` (5 submissions per 10 minutes per connection). Rejections re-render the form with a plain message and save nothing.
- **Idempotency**: a per-form token; refresh, back button or double click returns the already-saved enquiry.
- **No personal data in URLs**: the confirmation reads the id from the session; the redirect URL is fixed.
- **No caching**: `Cache-Control: no-store` on the wizard and confirmation.
- **Log filtering**: `filter_parameters` adds phone, names, company, vessel, project, location, description, date and form stamp (email and token were already filtered). Verified in the development log after restarting the web process.
- **Known development-only exposure**: at `debug` log level, SQL `INSERT` lines include bound values (this already happens for user emails). Production logs at `info`, which does not log SQL. Not changed in this slice.
- **Rate-limit store**: `Rails.cache`. In production this must be a shared cache (Solid Cache) so the limit holds across processes; confirm at deployment.

## 4. Staff access (minimal, not F4-03 triage)

`ServiceInquiryPolicy`: list and detail need an active staff membership with `inquiries.view_all`, scoped to the staff member's organisation. Preparing a quotation also needs `quotes.create` and an enquiry that is not closed. General staff, client users and anonymous visitors are refused (integration and policy tests). No status changes, assignment, notes or merging — those are F4-03.

## 5. Enquiry → quotation linkage

`Commercial::QuoteFromInquiry` (row lock on the enquiry plus the partial unique index):

- creates a draft through the existing `QuoteBuilder`, links `service_inquiry_id`, copies the client's company, contact name, email and phone into `prospective_client`;
- copies the service only if it is still published;
- suggests a title (service — vessel/project) and writes the enquiry facts into **internal notes**;
- does **not** set prices, line items, scope, deliverables, exclusions, payment terms or validity;
- repeated or concurrent requests open the existing open quotation; a withdrawn quotation allows a fresh one;
- **never creates a project.**

## 6. Revisions

`Commercial::QuoteRevisionCreator` opens version N+1 from an `approved_for_issuance` or `issued` quotation:

- requires `quotes.create`, a reason (max 500 characters) and the current revision id + lock version (stale pages refused);
- refused while the current version has a prepared, queued or sending delivery;
- copies content and line items; validity is copied only if still in the future;
- the new version is a draft with its own preparer; **approval is never inherited** and the four-eyes rule applies again;
- `predecessor_revision_id`, `revision_reason`, `superseded_by_revision_id`, `superseded_at` record lineage; DB checks require lineage for every version after 1 and a timestamp on superseded versions;
- audit: `quote.revision_created`.

**Supersession is explicit** (`Commercial::QuoteSupersession`):

- approving version N supersedes earlier *approved, never sent* versions;
- an earlier *issued* version remains the client's outstanding offer until version N is itself issued (accepted by the mail system) — then it becomes superseded;
- withdrawal follows the existing F4-02A rules.

The staff editor shows a "Versions" panel (number, status, who/when, reason) and each version opens read-only at `/staff/quotations/:id/versions/:n`. When a new unsent version exists, the summary says "Version N was sent earlier and is still the client's offer".

## 7. History protection

Current protection:

- DB checks: approved/issued content frozen (`quote_revisions_approved_are_frozen`), independent approver, lineage, superseded timestamp, delivery status set, `delivery_confirmed` needs `confirmed_at` + provider message id, one live delivery per version (partial unique index).
- Model guards: frozen versions accept only status/issue/supersession columns; line items of frozen versions cannot change; enquiry link permanent.
- Regression tests: editing the new version never changes the approved version; approved versions cannot be edited after a newer version exists; exact-version PDFs render the requested content; delivery confirmation without evidence is rejected by the database.

**Remaining gap (documented, not applied):** a privileged database user can still `UPDATE`/`DELETE` frozen rows with raw SQL. Options, both requiring approval because they change the schema format or production database privileges:

1. **Triggers** on `quote_revisions`, `quote_line_items`, `quote_deliveries` and `audit_events` rejecting content changes to frozen rows and all deletes. Needs `config.active_record.schema_format = :sql` (`structure.sql`).
2. **Restricted application role**: the app connects as a role without `DELETE` on history tables and without `UPDATE` on `audit_events`; migrations run as a separate owner role. Needs Coolify/Hetzner database configuration.

Recommendation: option 1 first (versioned with the code), option 2 at production hardening.

## 8. Exact-version PDFs

`GET /staff/quotations/:id/pdf?version=N` and the version page link render the stored snapshot of that version (content, recipient and lines from that revision). Authenticated staff only (`QuotePolicy#pdf?` / `#version?`), `Cache-Control: private, no-store`, shown inline; unknown version numbers return not found; unfrozen versions are labelled `-DRAFT`. No public or signed download URLs. The email attachment is rendered from the same revision at send time.

## 9. Issuance preparation

`/staff/quotations/:id/issuance` (requires `quotes.send` and the quotation to be approved or to have a delivery record). The screen shows the exact approved version, recipient, total, validity, the PDF link, the delivery method and a test-mode notice. Blockers are listed in plain English (dispatch switched off, no permission, not approved, no independent approval, expired or missing validity, missing/invalid recipient email, archived client organisation). Preparing requires ticking confirmation checks and the current revision id + lock version.

Steps: **Prepare** (records a `QuoteDelivery` in `prepared`; nothing sent) → **Send now** (moves to `queued`, enqueues `DeliverQuoteJob` on the `mail` queue) or **Cancel** (only while prepared).

## 10. Delivery architecture

- `quote_deliveries`: one row per attempt for one exact revision, frozen recipient, adapter name, idempotency key, timestamps for each stage, provider message id/response, failure reason.
- `Commercial::QuoteDispatcher` re-checks everything under row locks at prepare and dispatch; a version can never have two live deliveries.
- `DeliverQuoteJob` (Solid Queue, `mail` queue, arguments not logged): claims the row by moving it to `sending` and committing **before** contacting the mail system; re-checks that the quotation is still approved and the version still current (otherwise cancels with "nothing was sent"). Only on acceptance does the version become `issued` and the quotation `issued`, followed by supersession. **No automatic retries.**
- `QuotesMailer#quotation`: plain wording, subject "Quotation REF (version N) from ANT Marine W.A.", PDF attachment of that version. No acceptance link and no legal wording.
- Audit: `quote.delivery_prepared`, `quote.delivery_queued`, `quote.delivery_cancelled`, `quote.delivery_accepted`, `quote.delivery_failed`, `quote.delivery_outcome_unknown`.

### Delivery status meanings (shown to staff)

| Status | Label | Meaning |
|---|---|---|
| `prepared` | Prepared — not sent | Recorded and checked; nothing sent |
| `queued` | Queued — not sent yet | Waiting for the background worker |
| `sending` | Sending — waiting for the mail system | Worker has claimed it |
| `accepted_by_provider` | Accepted by the test mail system — no real email was sent (local adapters) / Accepted by the mail provider — delivery not confirmed | The mail system took the message. **Not proof of receipt** |
| `failed` | Delivery failed — not sent | The mail server refused it; quotation not marked sent |
| `outcome_unknown` | Outcome unknown — check with the recipient before sending again | Timeout or ambiguous error; blocks resending |
| `delivery_confirmed` | Delivery confirmed by the mail provider | Requires provider evidence (not wired yet; DB-enforced) |
| `cancelled` | Cancelled — not sent | Cancelled by staff or because the quotation changed |

## 11. Live gate

`Commercial::QuoteIssuance.dispatch_available?` is true only when **not production**, `QUOTE_DISPATCH_DISABLED` is unset **and** the Action Mailer adapter is `:test` or `:file`. Production is hard-off; an SMTP adapter outside production is also refused (tested). The old one-click "mark as issued" (`available?`) stays off. Development writes mail to `tmp/mails`; no real email was sent during this slice.

**Before production dispatch** (all required): provider choice (ADR-009), sender domain with SPF/DKIM/DMARC, approved email and PDF wording, approved legal/acceptance terms, decision on attaching the PDF vs. a portal link (depends on ADR-010 storage), bounce/complaint webhook for `delivery_confirmed`, an explicit environment switch reviewed by the product owner, and a confirmed running Solid Queue worker.

## 12. Client decision boundary

Not built in F4-02B. No acceptance links, no unauthenticated decisions, and an email address is not treated as proof of authority. Contract for F4-03/F4-04: a client decision must come from an authenticated client membership with `quotes.accept` (ADR-006) in the quotation's client organisation, against a specific issued revision id, and be recorded with an audit event. A prospective client (enquiry without a client organisation) must first be onboarded by invitation (ADR-005) — this is the client onboarding dependency.

## 13. F4-03 integration contract

- Triage statuses already exist on `service_inquiries.current_status`; F4-03 adds transitions, assignment, internal notes and client clarification.
- `quotes.service_inquiry_id` + `ServiceInquiry#open_quote` are the link; one open quotation per enquiry is DB-enforced.
- A quotation's outstanding offer is the latest `issued` revision; `quote_deliveries` is the evidence of sending.
- Project creation must be an explicit staff action after a recorded client decision — never automatic.

## 14. Outstanding commercial decisions

Unchanged from F4-02A-H2 (tax, deposits, legal terms) plus: issuance email wording and sender, default validity period, whether a sent offer can be withdrawn by email, and acceptance rules.

## 15. Deferred F4-01 items (preserved)

F4-01 final visual and editorial acceptance remains open. Observed during this slice and not changed: the development Hull Cleaning service summary contains raw `**` markdown (content data), and the staff enquiry filter "Apply" button is full width on mobile like other staff filters.

## 16. Operational notes

- After deploying new job classes, restart the Solid Queue worker; a worker booted before the class existed fails with `ClassMissingError` (seen once locally; the delivery stayed honestly "Queued — not sent yet").
- After changing `filter_parameter_logging.rb`, restart the web process.

## 17. Evidence

Automated: 525 runs, 0 failures (see the implementation report for the final gate run). Browser (local development, temporary QA staff identities later suspended with rotated passwords and sessions ended):

- service page → wizard with the service preselected; server-side validation kept answers; confirmation `ANT-ENQ-2026-00001`, reload did not duplicate;
- staff list/detail; Prepare quotation created `ANT-Q-2026-00006` with client facts only;
- separate reviewer approved; issuance screen; Prepared → Queued → Accepted by the test mail system (file adapter);
- version 2 with a reason; version history shows version 1 as the outstanding sent offer; version 2 approved and not sent;
- exact-version PDFs private and matching;
- 1440, 1280, 768 and 390px checks, including the mobile "not sure" journey (`ANT-ENQ-2026-00002`) and staff enquiry pages at 390px, with no horizontal overflow.
