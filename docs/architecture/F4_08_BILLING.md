# F4-08 — Billing architecture

**Status:** Implemented locally (simulated only)  
**Baseline:** `1e63669`  
**Spec:** `docs/implementation/F4_08_SPEC.md`

## Design Studio mapping

| Screen | Implementation |
|---|---|
| S19 Bills & balances | `/staff/finance`, `/staff/invoices` |
| S20 Prepare bill | `/staff/invoices/new`, edit draft |
| C13 Bills & payments | `/client/invoices` |
| C14 Bill details | `/client/invoices/:id` + download |

## Domain

| Model | Role |
|---|---|
| `Invoice` | `issue_status` draft/issued/void; payment/overdue derived |
| `InvoiceLineItem` | P2 invoice_lines concept; frozen after leave-draft |
| `InvoiceRelease` | Client visibility separate from issuance |
| `PaymentRecord` | Manual recording only (ADR-008) |
| `PaymentReversal` | Append-only full reversal for MVP |

Commercial source is the project’s accepted `QuoteRevision` / `QuoteResponse` / `commercial_snapshot`. Snapshots are not mutated by billing. Invoice binds operating organization, client organization, project, quote, revision, and response.

## Authorization matrix

Existing catalogue keys: `billing.view`, `billing.view_all`, `billing.manage`, `billing.record_payment`, `billing.adjust`.

| Actor | Metadata | Amounts | Draft/create | Issue/release/void | Record/reverse payment | Finance dashboard | Client PDF |
|---|---|---|---|---|---|---|---|
| Super Administrator / Ops Manager (with billing keys) | Yes | Yes | Yes (`manage`) | Yes | Yes | Yes | Staff download |
| Finance Officer | Yes | Yes | Yes | Yes | Yes | Yes | Staff download |
| Project Coordinator / Surveyor / Technical Reviewer (no billing keys) | No | No | No | No | No | No | No |
| Client Owner / Client Finance (`billing.view`) | Released only | Released only | No | No | No | No | Released exact artifact |
| Other client organizations | No | No | No | No | No | No | No |

Project assignment alone does not grant billing. Surveyors/reviewers without finance keys are denied. Enforced via `InvoicePolicy`, `Billing::Access`, and domain services.

## Simulation gates

`Billing::CreateDraft.available?` / issue / release / payment / reverse / void require non-production. Production refuses paths. UI and PDFs mark **SIMULATED — NOT PAYABLE**. Simulated records are never genuine receivables.

## Capacity and multiple invoices

Multiple invoices per project are allowed (initial/interim/final/full as descriptive labels only). Issued non-void totals cannot exceed accepted commercial amount. Drafts reserve capacity for over-commit checks; issuance revalidates under project/invoice locks. Concurrent over-invoicing is denied.

## Monetary precision and currency

Reuse `Commercial::Money` integer minor units. Invoice inherits commercial-source currency. Payments must match invoice currency. No FX conversion; never aggregate mixed currencies into one total. Server-side totals only; forms accept ordinary currency amounts.

## Invoice lifecycle

1. Explicit create draft (with confirmation)  
2. Edit draft  
3. Explicit issue → freeze content, generate PDF artifact, audit  
4. Explicit client release (separate)  
5. Manual payment recording (partial allowed; overpayment rejected)  
6. Payment reversal (append-only)  
7. Void only after payments reversed and release revoked  

Payment status and overdue are derived (not editable dropdowns). Overdue = issued + not void + positive balance + due date passed.

## Invoice numbering

Local simulated references via `Billing::Reference` (advisory lock). Uniqueness within reference_number. Voided numbers are not reused. Format is not claimed as regulatory-approved.

## Immutability

DB triggers protect issued invoice identity/amounts/artifact, line items after leave-draft, release identity, payment financial fields, and reversals (append-only). No application-accessible history bypass. Direct SQL mutation of protected fields is rejected (tested).

## PDF artifacts

Prawn via `Billing::PdfRenderer`; stored through restricted `application_generated` path (`Billing::ArtifactStore`). Exact issued bytes preserved; integrity verified before download (`Billing::SecureDownload`). Draft PDFs marked draft; all PDFs marked simulated / not payable. No invented banking or tax registration details.

## Client release and portal

Issuance ≠ portal visibility. Release requires issued immutable invoice, verified artifact, correct client org, permission, confirmation, simulation eligibility. Clients see only their org’s released invoices. No Pay now buttons. No email.

## Finance dashboard

`/staff/finance` shows scoped issued totals, net payments, outstanding, overdue, drafts, upcoming due dates, recent activity — by currency, with simulated totals identified. Drafts excluded from issued receivables. Voids and reversals accounted. Not a GL / P&L system.

## Notifications and audit

In-app staff events: invoice issued/released, payment recorded/reversed, invoice voided. Scoped to finance staff. `AuditEvent` records create/edit/issue/release/revoke/pay/reverse/void/download and relevant denials. Simulated classification preserved.

## Concurrency

Project/invoice locking and capacity revalidation on issue and payment. Idempotent-friendly issuance; failed operations leave no partial financial commit. Overpayment and concurrent over-allocation rejected.

## Deferred financial features

Online collection, external accounting, FX accounting, advanced allocation, live correction/credit-note policies, tax configuration, deposit schedules, banking details on PDFs, client billing email/SMS.

## Production gates (still open)

Formal tax/payment-term/numbering policies; live commercial acceptance; live project initiation; live invoicing; real email; ADR-010 storage; restricted DB role; design sign-off; deployment approval. Passing simulation does **not** authorize genuine financial operations.

## F4-09 handoff (not started)

End-to-end: enquiry → quote → acceptance → project → documents → inspection → report → invoice → release → payment recording. Cross-module integration and deferred original MVP inventory belong to F4-09.
