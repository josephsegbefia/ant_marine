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
- `QuoteLineItem` — decimal quantity × unit price (cents); server-side totals.

Statuses: `draft` → `pending_review` → `approved_for_issuance` → `issued` | `withdrawn` | `superseded`.

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

## F4-02B recommended

- Public enquiry funnel (master F4-02), quote–inquiry linking, revision branching, issuance mailer, client portal C04.