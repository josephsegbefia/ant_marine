# Original requirements audit — F4-09A

**Sources reconciled (precedence):** approved ADRs in `docs/DECISIONS.md` > questionnaire / master spec for factual product scope > Phase 1 design handoff for UI > incidental suggestions.

**Audit date:** 2026-11-26  
**Baseline:** `64f92f8` + F4-09A local fixes

## Coverage counts (evidence-based)

Classification applied to **distinct original capability themes** drawn from the questionnaire themes, master-spec Phase 4 modules, permission catalogue, and Design Studio journeys (not one row per every sentence in the questionnaire).

| Classification | Count | Basis |
|---|---|---|
| Complete (implemented + tested, simulated where gated) | 42 | F4-01…F4-08 modules with automated evidence |
| Partial | 16 | Present but incomplete UX/policy (see below) |
| Missing (original intent not shipped) | 9 | Messaging, vessels, help, OTP, retention UI, etc. |
| Deferred by approved ADR / explicit decision | 11 | Preview, M09 rules, interactive calendar, live channels |
| Production-gated | 14 | Live email, storage ADR-010, live commercial/docs/billing, etc. |
| Superseded / N/A | 6 | Design-guide-only, demo prototype behaviours |

**Evidence anchors:** module acceptance docs under `docs/architecture/F4_*`, `docs/acceptance/design_studio_inventory.csv`, automated suites recorded in `F4_09A_INTEGRATION.md`.

## Complete (representative)

- Public marketing site + enquiry wizard (no account, spam controls)
- Staff enquiry triage, clarifications (recorded, not sent), notes
- Quotation prepare/review/approve with four-eyes; PDF; simulated issuance prep
- Client onboarding via invitation; simulated quote portal release + accept/decline/changes
- Explicit simulated project creation from acceptance; assignments with `access_scope`
- Encrypted document upload, quarantine, exact-version review/release/revoke
- Inspections with versioned templates, checklist, findings, evidence links
- Technical reports with SoD review, immutable PDF artifact, separate release
- Simulated invoicing, payments, reversals, capacity locks, client bills
- Staff in-app notifications; audit events; org/role authorization engine

## Partial

| Theme | Gap |
|---|---|
| Staff/client dashboards | Real scoped data; some Design Studio widgets absent |
| Schedule / calendar | Agenda/list exists; interactive calendar & external sync absent |
| Client team/account | Invites work; full C15/C16 profile/alerts incomplete |
| Permissions admin UI | Engine complete; M07 console incomplete |
| Activity / security history | Events stored; unified M13 UI incomplete |
| Resources downloads | Listing exists; file serving disabled |
| Privacy page | Copy/policy page not dedicated |
| Analytics / insights | Finance currency totals; full M12 export incomplete |
| Company settings | Permissions exist; dedicated M11 UI thin |
| Technical multi-deliverable completion | Conservative `project_technically_ready?`; no required-deliverable catalogue |
| Public booking (P23) | Not implemented; schedule events cover staff side only |
| Client request clarification UX | Staff clarifications recorded; client reply surface limited |
| Password reset mailbox | Code present; historical PO mailbox verification open |
| Editorial richness | CMS complete; published content PO-gated |

## Missing (not silently dropped)

| Theme | Source | Notes |
|---|---|---|
| Client–staff messaging | Questionnaire / C10 / S23 | No message model in app |
| Client notification center | C17 / questionnaire | Staff notifications only (ADR-F4-06-H1-004 / F4-07-008) |
| Vessel register | C18/C19/S18 | Not modelled in Phase 4 delivery |
| Help & support hub | C20 | Absent |
| OTP / step-up (A04) | Design Studio | Deferred |
| Archive & retention UI | M14 | Policy + UI open |
| Online payment collection | Questionnaire / ADR-008 | Explicitly out; manual simulated only |
| Accounting / FX integration | Questionnaire | Out of MVP |
| Document in-app preview | C09 | Deferred ADR-F4-06-005 |

## Approved scope changes (do not treat as silent omissions)

- Simulation-only commercial, document, report, and billing operations until live policy
- Quotation delivery hard-off in production
- No automatic project from acceptance
- Approve ≠ release for documents and reports
- No invented tax/deposit/legal defaults
- Document categories seeded; M09 admin deferred
- Client notifications not shipped in F4-06/F4-07

## Production-gated (see PRODUCTION_GATE_REGISTER.md)

Hosting, runtime DB role, email provider, ADR-010 storage, ClamAV ops, backups, retention, commercial terms, live switches for every operational module, formal design/editorial approval.

## Product-owner decisions required before declaring Phase 4 “fully complete”

1. Which missing items are **mandatory MVP** vs post-launch (especially messaging & client notifications).
2. Formal Design Studio sign-off vs implemented routes.
3. Live-operations policy pack (commercial, storage, email).
4. Required technical deliverable catalogue (or accept conservative gate).
