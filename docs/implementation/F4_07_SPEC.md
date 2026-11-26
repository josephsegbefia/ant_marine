# F4-07 — Inspections, technical findings, evidence & technical reports

**Checkpoint:** F4-07 (F4-07A + F4-07B)  
**Baseline:** `4cf2b6e` (F4-06-H1)  
**Branch:** local `main`  
**Hard stops:** no push, no deploy, no F4-08, no live commercial/document/certification ops, no real invoices, no external storage, no real email, no DB reset, no Design Studio edits, no quarantine/history bypass. Simulated projects only.

Full self-contained requirements are in the approved implementation brief delivered for this checkpoint. Architecture and acceptance evidence live in:

- [`docs/architecture/F4_07_INSPECTIONS_REPORTS.md`](../architecture/F4_07_INSPECTIONS_REPORTS.md)
- [`docs/DECISIONS.md`](../DECISIONS.md) (ADR-F4-07-*)
- [`docs/PHASE_PROGRESS.md`](../PHASE_PROGRESS.md)

## Design Studio mapping

| Screen | Role in F4-07 |
|---|---|
| S10 | Staff inspection checklist / fieldwork |
| S12 | Staff reports to review |
| S13 | Independent technical review |
| S14 | Exact-version client release |
| C11 | Client report library |
| C12 | Client final report detail / protected download |

## Domain

- Templates: `InspectionTemplate`, `InspectionTemplateVersion` (exact version on each inspection)
- Fieldwork: `Inspection`, `InspectionChecklistResponse`, `InspectionFinding`, `InspectionEvidenceLink` → exact `DocumentVersion`
- Reports: `Report`, `ReportVersion`, `ReportReview`, `ReportRelease`
- PDF: Prawn + `Reports::ArtifactStore` trusted generated path (`application_generated`)
- Revision: `Reports::Revise` creates a new draft version; never mutates approved content

## Packages

A Domain/auth/templates → B Inspection workspace/evidence → **internal gate** → C Report editor/PDF → D Review/release/client → E Tests/browser/docs/local commit only.

## F4-08 handoff

Do not auto-invoice from inspection or report events. Billing remains a separate authorised workflow.
