# F4-02A — Quotation management foundation

## Roadmap reconciliation (PO 2026-11-24)

| Source | Placement |
|--------|-----------|
| `docs/ANT_MARINE_MASTER_SPEC.md` | F4-02 public intake; **F4-03** staff quotation workflow |
| Current PO roadmap | **F4-02A** quotation management; public intake remains future |

**Decision:** Implement staff quotation foundation in **F4-02A** without removing master-spec F4-02 anonymous intake (still deferred). See `docs/DECISIONS.md` ADR-F4-02A-001.

## Domain model (P2.1 aligned)

- `Quote` — parent record (`reference_number`, `status`, `delivery_state`, org ownership, optional `client_organization`, `prospective_client` JSON).
- `QuoteRevision` — versioned commercial content; **frozen** after approve/issue (`frozen_at`).
- `QuoteLineItem` — decimal quantity × unit price (stored as integer minor units, entered as ordinary amounts); server-side totals.

Statuses: `draft` → `pending_review` → `approved_for_issuance` → `issued` | `withdrawn` | `superseded`, with `pending_review` → `returned_for_correction` → `pending_review` for reviewer corrections (added in F4-02A-H1).

## Permissions

- `quotes.view_all`, `quotes.create`, `quotes.approve` (new), `quotes.send`, `quotes.withdraw`
- Website `content.*` does **not** grant quotation access.

## Calculations

- `Commercial::QuoteCalculator` — integer cents; no VAT until approved configuration exists.

## PDF

- `Commercial::QuotePdfRenderer` (Prawn); authenticated `GET /staff/quotations/:id/pdf`; draft watermark.

## Delivery & client acceptance

- `delivery_state` tracks preparation only; **no** outbound email in F4-02A.
- Client portal acceptance **gated** until F4-03/F4-04 identity contracts.

## F4-01 deferred acceptance

- Public hero/cards/editorial content visual sign-off remains open in `docs/PHASE_PROGRESS.md` — not closed by F4-02A.

## Quotation editor routing & policy (2026-11-24 fix)

**Root cause:** `Staff::QuotationsController#edit` called `authorize @quote` (implicit `edit?`) but `QuotePolicy` had no `edit?`, raising `NoMethodError`.

**Policy mapping:** `edit?` → `view?` (open workspace for review/PDF/workflow); `update?` → `manage_draft?` (mutable draft only). Explicit queries on controller actions.

**New quotation:** `GET /staff/quotations/new` renders a begin screen only; `POST /staff/quotations` creates the draft via `QuoteBuilder` and redirects to step 1. No record on GET `new` or refresh.

## F4-02A-H1 workflow hardening (2026-11-25)

Starting point: `18eb179`. Each audit finding was reproduced with a failing test before it was fixed.

| Finding | Root cause | Fix |
|---------|------------|-----|
| A. `editable?` included `pending_review` | Status list reused for "not frozen" | `Quote::EDITABLE_STATUSES = draft, returned_for_correction`; review content is read-only |
| B. Incomplete quotation could be approved | No completeness rule | `Commercial::QuoteReadiness` checked on submit **and** approve |
| C. Return-for-correction permission mismatch | Policy and transition checked different things | Single `QuotePolicy#review?` (`quotes.approve` + pending status), called inside every transition |
| D. Issuing claimed delivery | Status implied sending | `Commercial::QuoteIssuance.available?` is `false`; issue route refused; UI says "Approved — not sent" |
| E. Unit price entered in cents | Raw column exposed | `Commercial::Money.parse_minor` (BigDecimal) behind a virtual `unit_price` field |
| F. Blank required pricing row | Form built an empty line | No pre-built line; empty new rows are ignored; partial drafts save |
| G. Saves not atomic | Quote and revision saved separately | Both validated, then saved in one transaction with optimistic locking |
| H. Weak immutability | Only UI hid controls | Model guards on revision, line items and recipient; `restrict_with_exception`; DB check constraints |
| I. Reference race | `max + 1` without a lock | `pg_advisory_xact_lock` per organisation and year, plus retry on unique violation |
| J. Unscoped client/service ids | Ids accepted as submitted | Validated against active client organisations and the organisation's published services |

### Readiness rules (submit and approve)

1. Client: existing client organisation or company name; contact name; valid contact email.
2. Scope: title (not the placeholder), scope of work, deliverables, exclusions (write "None" if nothing is excluded).
3. Pricing: supported currency (GHS, USD, EUR, GBP), at least one line, every line described with quantity above zero, stored totals matching the lines, total above zero.
4. Terms: valid-until date not in the past; payment terms.

No tax rates, deposits or legal terms are added. Payment terms are required as entered text only.

### Pricing conversion

Staff enter ordinary amounts ("1,250.00"). Values are parsed with BigDecimal and stored as integer minor units. Negative values, more than two decimal places, values above 999,999,999.99 and non-numbers are rejected with plain messages. Quantity allows up to three decimals (max 1,000,000). Line total = round(quantity × unit price) in minor units; the browser preview uses the same integer arithmetic. Lines can be added, removed and reordered; at most 100 lines per version.

### Immutability and concurrency

- Approved/issued revisions require `frozen_at` (DB check `quote_revisions_approved_are_frozen`). Content, line items and recipient cannot change once frozen. Only approved→issued/superseded and issued→superseded status metadata may change.
- Approval stores a recipient snapshot; PDFs of frozen versions render from the snapshot.
- Transitions lock the quote and revision rows. Editor saves use `lock_version`; a stale save is refused and nothing is written.

### Issuance activation conditions

Issuing stays disabled until all of these are approved: a delivery channel (email or client portal), a sender identity and template, client-facing acceptance rules (F4-03/F4-04), and an audit trail for what was sent. Approval never sends anything.

### Deployment note

Environments seeded before F4-02A must run `Authorization::CatalogueSeeder.seed!` (idempotent) so `quotes.approve` exists.

### Open decisions for the product owner

- Whether the preparer may approve their own quotation (currently allowed when they hold `quotes.approve`).
- Tax, deposit and standard legal terms.
- A fixed list of units (currently free text, 30 characters).
- Database triggers are not used because the schema is kept in `schema.rb`; protection is in model guards plus check constraints.

### Evidence

`verify_foundation.sh` PASS, 413 tests. Browser: preparer journey (create, client, scope, pricing with live totals, reorder, validation errors, terms, review, submit) at 1440px; read-only pricing at 768px and 390px; PDF rendered and inspected. Reviewer approve/return in the browser is **unverified** (covered by integration tests).

## F4-02B recommended

- Public enquiry funnel (master F4-02), quote–inquiry linking, revision branching, issuance mailer, client portal C04.