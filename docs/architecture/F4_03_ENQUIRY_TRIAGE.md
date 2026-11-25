# F4-03 — Enquiry triage and commercial operations workspace

Status: **code complete locally — product owner acceptance pending; not pushed, not deployed.**
Builds on F4-02B (`f928dbf`). The F4-02A/H1/H2/F4-02B quotation rules are unchanged: four-eyes approval per version, current-version checks, frozen approved versions, one open quotation per enquiry, test-only delivery, no invented tax/deposit/legal terms.

Commits: `1397805` (transitions, assignment, notes, assigned-only access), `600a1fb` (clarifications, duplicates, timeline), `cfded27` (in-app notifications, pagination), `a5ef83c` (inbox and workspace UI, system tests), plus the acceptance/documentation commit.

PO decisions for this slice (2026-11-25):

- **Notifications:** minimal in-app staff notifications only; no email.
- **Qualification:** "Ready to quote" does **not** require a client organisation. Staff may optionally link an *existing active* client organisation; no account is ever created. "Prepare quotation" stays available from any open enquiry, with a hint recommending qualification first.

## 1. Design Studio mapping

| Screen | Implementation |
|---|---|
| **S02** Incoming requests | `/staff/enquiries`: summary cards, view tabs, filter toolbar, table (desktop ≥1024px) / cards (below), Open link, pagination |
| **S03** Request details | `/staff/enquiries/:id`: main column (request information, what they need, related requests, questions for the client, quotation, internal notes, activity) and sidebar (status, responsible, next steps) |
| **S01** overview teasers | Unchanged; the inbox counts reuse the same scoped relation |

S03's "Next steps" (Review the request, Ask a question, Prepare quotation) and "Internal notes" box are kept. The prototype's "Ask" button is implemented as *prepare* a question and *record* contact made outside the system, because nothing is sent; S03's single static list became state-aware actions. The Design Studio file was not modified.

## 2. State model

Approved Phase 2 names (`P2_4_STATE_TRANSITIONS.md`), all already in the `service_inquiries_status_check` constraint.

| Status | Label | Reached by |
|---|---|---|
| `submitted` | New | Public form |
| `under_review` | Under review | Start review; answer recorded; reopen |
| `needs_clarification` | Awaiting information | Contact recorded for a prepared question (internal action, never chosen directly) |
| `qualified` | Ready to quote | Qualify (blocked while a question is still waiting for the client) |
| `unqualified` | Outside our scope | Mark outside scope (explanation required) — ends the enquiry |
| `merged` | Duplicate | Mark duplicate (reference of the original required) — ends the enquiry |
| `closed` | Closed | Close with reason: Cancelled by the client / Client is no longer proceeding / Other reason (explanation required) |

- Reopen (reason required) returns any ended enquiry to Under review; the previous closing reason and duplicate link stay in the audit history.
- **No "accepted" state.** Client decisions are F4-04.
- **Ending guard:** outside-scope, duplicate and close are refused while an open quotation exists. The message points to the separate Withdraw action on the quotation page; offers are never withdrawn silently.
- Quotation progress is **derived**, not stored: Not quoted yet / draft being prepared / waiting for approval / returned for changes / approved, not sent / issued, not sent / sent in test mode — no real email was sent / sent — delivery not confirmed / Quotation withdrawn — none in progress.

## 3. Database

Migrations `20261125210000`, `20261125220000`, `20261125230000` (`schema.rb` kept).

- **`service_inquiries`** gains `assigned_membership_id`, `duplicate_of_id` (self), `lock_version`, `review_started_at`, `qualified_at`, `qualification_note`, `closure_reason`, `closure_note`, `closed_at`, index `(organization_id, assigned_membership_id, current_status)`. Checks: ended states have a reason and time (and nothing else does); `closed` reasons limited to the three closing reasons; `unqualified` has an explanation; `merged` has a different original; `other` has an explanation; note lengths.
- **`service_inquiry_assignments`** — append-only history (previous, new, actor, reason ≤ 500). Check that something actually changed.
- **`service_inquiry_notes`** — append-only plain-text notes (≤ 4,000), `corrects_note_id` unique (one correction per note). Nothing is updated or deleted.
- **`service_inquiry_clarifications`** — subject, questions, prepared message; status `prepared` / `contacted_outside_system` / `answered` / `withdrawn` (no "sent" status); contact channel (phone, email from own mailbox, in person, other); answer text, source, received date and who recorded it; withdrawal; checks that each status carries its evidence.
- **`staff_notifications`** — recipient membership, kind (DB check), polymorphic subject, `audit_event_id`, title ≤ 200 (reference and company only), `read_at`; unique `(recipient_membership_id, dedupe_key)`.

## 4. Services (`lib/intake/`, `lib/notifications/`)

| Service | Responsibility |
|---|---|
| `Intake::InquiryTransition` | Rules table (from-states, to-state, ends?); row lock; `TriageGuard.authorize!` (`triage?` = `inquiries.qualify`) and `ensure_current!` (expected `lock_version`, stale pages refused); open-quotation guard; audit `service_inquiry.<action>`. `STAFF_ACTIONS` excludes the internal `await_information` / `information_received`. `available_actions` drives the Next steps list |
| `Intake::InquiryAssignment` | Assign/reassign/unassign to an active staff membership in the same organisation with an active user and `inquiries.view_all` or `inquiries.view_assigned`. Reason required when someone is already responsible. History row + audit + notification. `start_review` assigns the reviewer when nobody is responsible |
| `Intake::InquiryClarifications` | Prepare → record contact made outside the system (moves to Awaiting information) → record answer (returns to Under review when nothing else is waiting) or withdraw. Nothing is sent |
| `Intake::InquiryNotes` | Add and correct (correction = new note; original kept and marked corrected) |
| `Intake::DuplicateFinder` | Suggestions only: same contact email or company name within 180 days, inside the viewer's own scope and organisation, max 5 |
| `Intake::InquiryTimeline` | Allow-list of audit event types → plain sentences, for the enquiry and its linked quotations (including test-mode delivery wording). Raw metadata is never rendered |
| `Notifications::StaffPublisher` | In-app notifications created in the same transaction as the audit event |

Audit metadata holds the reference, from/to status, reason codes, ids, closing explanations and assignment/reopen reasons (shown in the timeline). It never holds internal note bodies, clarification questions or answers, emails or descriptions.

## 5. Authorization

`ServiceInquiryPolicy`:

- **Scope:** `inquiries.view_all` → whole organisation; `inquiries.view_assigned` only → enquiries assigned to that membership; anything else → none. Out-of-scope ids return 404 (`policy_scope(...).find`).
- `triage?` / `assign?`: visible and `inquiries.qualify`.
- `note?`: visible and (`inquiries.qualify` or assigned with `inquiries.view_assigned`).
- `prepare_quotation?`: unchanged from F4-02B (`view_all` + `quotes.create`, not ended).

Default roles: coordinator and operations manager triage; surveyor and general staff see only assigned enquiries and may add notes; finance officer has no enquiry access. Services re-check permissions inside their transactions; controllers accept only whitelisted parameters, and `step` must be one of `STAFF_ACTIONS` (no generic status parameter).

## 6. Notifications (in-app only)

| Kind | Recipients |
|---|---|
| `new_enquiry` | Active staff with `inquiries.view_all` and `inquiries.qualify` |
| `enquiry_assigned` | New assignee, unless they made the change |
| `enquiry_reassigned_away` | Previous assignee, unless they made the change |
| `clarification_answered` | Assignee, unless they recorded it |

`dedupe_key = kind:audit_event_id`, inserted with `insert_all(unique_by:)`, so retries never notify twice. `/staff/notifications` lists the member's own notifications (newest first, paginated) with "mark read" (opening one marks it read) and "mark all read"; unread count in the sidebar. `Notifications::Events` catalogue marks these kinds `in_app`; email remains limited to invitations and password reset. **No email is sent for any F4-03 event.**

## 7. UI

- **Inbox:** five summary cards (New, Assigned to me, Unassigned, Awaiting information, Ready to quote; the two team cards are hidden for assigned-only staff), tabs (All, Assigned to me, Unassigned, Awaiting information, Closed — Closed covers closed, outside scope and duplicate), filters (search ≤ 100 characters over reference, company, contact and email; status; responsible; received from/to — invalid values ignored), 25 per page.
- **Workspace:** sidebar first in source order (status first on phones). Every action opens a native `<dialog>` (`ant_dialog`) asking only for what that action needs. The original request is read-only ("cannot be edited — add an internal note"). An email address is shown with the note that it does not prove organisation membership or authority to accept an offer.
- **Quotation ↔ enquiry:** quotation card on the enquiry (all quotations including withdrawn, with stage) and the existing enquiry link in the quotation editor. Prepare quotation behaviour unchanged.
- **Responsive:** table from 1024px; two-column cards 640–1023px; single column below. Filter buttons at natural width at every size (also fixes the full-width Apply on the quotations list).

## 8. Internal notes privacy

Notes, clarifications and closing explanations live only in staff tables and are rendered only on the staff workspace. They are not copied by `Commercial::QuoteFromInquiry`, and an integration test asserts note text is absent from the created quotation (record, internal notes, scope, title) and from its PDF (`QuotePdfRenderer`). The quotation email uses fixed wording plus that version's PDF, so it has no path to notes; there is no separate email assertion. Note, clarification and reason parameters are filtered from logs.

## 9. Hull Cleaning raw Markdown (investigation)

The development `services` row for Hull Cleaning has `summary` / `published_summary` text beginning `**Hull Cleaning**` followed by a blank line. Summaries are plain text by design (F4-01A), so the marks are shown exactly as typed. **Authored content, not a rendering defect.** Published content was not changed. The service editor hint now says formatting marks such as `**` are shown as typed. Editorial correction (remove the marks and the repeated title) is for the content owner, as part of F4-01 editorial acceptance.

## 10. Operational notes

- **Restart the web process after these migrations.** A Puma process booted before the migration kept stale column information and wrote enquiry updates without the new columns (seen once locally; one QA enquiry was repaired by hand). Fresh processes and the test suite are unaffected.
- **System tests** (`test/system`) need Chrome and, on first run, network access for `selenium-manager` to download the matching chromedriver. `ApplicationSystemTestCase` works around Capybara 3.40's `Storage.clearDataForOrigin origin:"*"` reset, which Chrome 158 rejects. `bin/rails test` does not run system tests; use `bin/rails test test/system` or `bin/rails test:system`.
- **Production configuration (unchanged, deployment gates):** rate limiting uses `Rails.cache` — production's `solid_cache_store` is shared across processes; `assume_ssl` / `force_ssl` and trusted proxies for Cloudflare + Coolify must be confirmed at deployment so client IPs and HTTPS detection are correct.

## 11. F4-04 boundary

Not built: client decisions on quotations, client portal enquiry views, client replies, conversion to project, automatic client accounts, any outbound message. Contract carried forward from F4-02B §12: a client decision must come from an authenticated client membership with `quotes.accept` in the quotation's client organisation, against a specific issued revision, audited. Linking a client organisation at qualification is a staff record only and grants nobody access.

## 12. Carried-forward gates (unchanged)

- F4-01 final visual and editorial acceptance (including the Hull Cleaning summary text).
- Commercial policy: tax, deposits, legal/acceptance terms, default validity, issuance wording and sender.
- Live email: production dispatch hard-off; needs ADR-009 provider, sender domain (SPF/DKIM/DMARC), approved wording and an explicit PO switch.
- Database immutability: ADR-F4-02B-006 (triggers or restricted role) still open; F4-03 history tables (`service_inquiry_assignments`, `service_inquiry_notes`, `staff_notifications`, `audit_events`) are protected by model guards and checks only.
- Storage: ADR-010 production storage blocked; no enquiry attachments.

## 13. Evidence

Automated: see the implementation report for the final gate run. Browser (local development, temporary QA staff identities later suspended with rotated passwords and sessions ended; screenshots in `tmp/f403_screens/`, not committed):

- 1440px: inbox; new enquiry; start review (reviewer becomes responsible); prepare question → record contact (Awaiting information) → record answer (Under review); note added; ready to quote (only outside scope / duplicate / close remain); Prepare quotation created `ANT-Q-2026-00007` with no notes copied; ending refused while the quotation is open, with the warning in the dialog; notifications page; timeline in plain sentences.
- `ANT-ENQ-2026-00002`: marked outside our scope (Closed view lists it) → reopened with a reason → assigned to the general-staff QA account, which then saw only that enquiry, no team tabs or Next steps, could add a note, got 404 for another enquiry and was redirected away from forged state-change and assignment requests (enquiry unchanged).
- 1280px inbox and workspace; 768px inbox (two-column cards) and workspace; 390px inbox (Apply 69px wide, Apply and Clear side by side), quotations list Apply 69px, workspace (status first) and a dialog (fits, focus on first field). No horizontal overflow at any width.

QA data left in development (local only, clearly labelled): `ANT-ENQ-2026-00001`–`00003`, quotations `ANT-Q-2026-00006` and `00007`.
