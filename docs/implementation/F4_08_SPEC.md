# F4-08 — Invoicing, payment recording, accounts receivable & client billing

**Status:** Implementation specification (saved from execution brief)  
**Project:** `/Users/josephelormsegbefia/Desktop/elorm/appsentrix/ant_marine`  
**Branch:** `main`  
**Expected committed baseline:** `1e63669`  
**Hard stops:** No push, deploy, F4-09, genuine receivables, real payments, live invoicing, real email, payment gateways, automatic invoice creation, invented tax/payment policies, DB reset, Design Studio edits, history-protection weakening, production privilege changes, or external storage activation.

## Objective

Implement simulated invoice management, payment recording, receivable tracking, finance reporting, and a client billing portal. Complete local tests, authenticated browser acceptance, documentation, and local commits only.

## Design Studio mapping

| Screen | Role | Route intent |
|---|---|---|
| S19 — Bills & balances | Staff finance | `/staff/finance` + invoice index |
| S20 — Prepare bill | Staff finance | Invoice create/edit wizard |
| C13 — Bills & payments | Client | `/client/invoices` |
| C14 — Bill details | Client | `/client/invoices/:id` |

## Approved permissions (existing catalogue)

`billing.view`, `billing.view_all`, `billing.manage`, `billing.record_payment`, `billing.adjust`

## Domain entities (implemented)

- `Invoice` — issue status draft/issued/void; payment/overdue derived
- `InvoiceLineItem` — P2 `invoice_lines` concept
- `InvoiceRelease` — client visibility separate from issuance
- `PaymentRecord` — manual recording only
- `PaymentReversal` — append-only correction

## Simulation

All F4-08 paths require non-production environment and simulated commercial/project sources. Production refuses creation, issuance, release, payment recording, and reversal.

## Deferred (see architecture doc)

Online collection, FX, tax configuration, statutory credit notes, full GL, live financial approval policies.
