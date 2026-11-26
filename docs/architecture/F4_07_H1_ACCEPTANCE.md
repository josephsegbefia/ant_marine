# F4-07-H1 — Technical reporting final acceptance

**Baseline:** `a79837a`  
**Status:** Accepted locally — simulated only  
**Spec:** [`docs/implementation/F4_07_H1_SPEC.md`](../implementation/F4_07_H1_SPEC.md)

## Coverage audit (vs F4-07)

| Area | Status |
|---|---|
| Versioned templates + immutability | Complete |
| Inspection checklist / findings / submit | Complete |
| Exact-version evidence + quarantine | Complete |
| Report prepare / revise / SoD approve | Complete |
| Trusted `application_generated` PDF path | Hardened in H1 (`trusted_application_generated` flag) |
| Immutable approved PDF digests | Complete + download integrity check |
| Release / revoke | Complete; revoke reopens `report_release` milestone |
| Multi-deliverable readiness | Conservative `project_technically_ready?` (at-least-one milestones documented) |
| Connected browser journey | H1 system test (review steps via domain services; UI for inspection/report/client/revoke) |
| Full system suite stability | Fixed (session rate-limit skip in test + waiting sign-in) |

## System-test root cause

`SessionsController` rate-limited create to 10 / 3 minutes. The full system suite performed many form sign-ins and intermittently redirected to `/session/new` (“Try again later” / stuck “Signing in…”).  

**Fix:** dedicated test MemoryStore; `unless: -> { Rails.env.test? }` on session rate limit; `sign_in_through_form` waits for Turbo navigation (`assert_no_current_path`) and prefers Sign out over blind reset when a session exists.

## Trusted artifact

`Storage::Asset#mark_available!` rejects `scanner_adapter: application_generated` unless `trusted_application_generated: true`. Only `Reports::ArtifactStore` passes that flag. Ordinary uploads cannot claim trusted provenance.

## F4-08 billing contract (no implementation)

Future invoices require explicit authorised initiation referencing: project, client organisation, exact accepted quotation revision / commercial snapshot, amount, currency, approved payment terms, required delivery milestones, and actual technical delivery status (`Delivery::TechnicalProgress`). A released report is not a billing instruction. Simulated invoices must never promote to genuine receivables.

## Production gates (still open)

Real approved templates; competency / signature policy; ADR-010; live certification; live commercial/document ops; production scanning / key custody; restricted DB role; F4-08; formal design sign-off.
