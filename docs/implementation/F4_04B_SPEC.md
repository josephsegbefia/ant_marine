# F4-04B — Implementation specification (execution anchor)

**Checkpoint:** Commercial decisions, quotation release & database history protection  
**Baseline HEAD at start:** `3e5ce04`  
**Prior checkpoint:** F4-04A Client Onboarding & Portal  
**Branch:** `main` (local commits only — **do not push**)

The full self-contained implementation prompt authorised this checkpoint. Outcome architecture:

→ [`docs/architecture/F4_04B_COMMERCIAL_DECISIONS.md`](../architecture/F4_04B_COMMERCIAL_DECISIONS.md)

## Hard stops

- No push or deploy; no F4-05
- No real email; no live commercial release; no binding client acceptance
- No automatic project creation
- No database reset; no Design Studio edits; no production DB privilege changes
- No invented legal/commercial terms
- Local PostgreSQL history protection and reviewed `structure.sql` switch **are authorised**

## Work packages completed

| Package | Scope |
|---|---|
| A | F4-04A remaining acceptance (contacts without portal users; invitation lifecycle regressions; responsive spot-check) |
| B | Trigger history protection; `schema.rb` → `structure.sql`; local least-privilege role verification |
| C | `QuoteResponse` + `Commercial::QuoteDecision`; authority; exact-version eligibility; concurrency/idempotency |
| D | Client decide UI; staff decisions panel; in-app notifications; enquiry/project guidance boundary |
| E | Automated tests; browser QA (`tmp/f404b_screens/`); docs; local commits; implementation report |

## Production gates remaining

Live release/acceptance, approved commercial wording, production email/domain, encrypted storage/malware/backups, **production restricted runtime DB privileges**, formal design sign-off, F4-05 project conversion.
