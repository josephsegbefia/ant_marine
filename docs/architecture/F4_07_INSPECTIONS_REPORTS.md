# F4-07 — Inspections & technical reports

**Baseline:** `a79837a` (F4-07) → H1 acceptance
**Status:** Accepted locally — simulated only (see [`F4_07_H1_ACCEPTANCE.md`](F4_07_H1_ACCEPTANCE.md))
**Spec:** [`docs/implementation/F4_07_SPEC.md`](../implementation/F4_07_SPEC.md) · H1 [`docs/implementation/F4_07_H1_SPEC.md`](../implementation/F4_07_H1_SPEC.md)

## Design Studio mapping

| ID | Implementation |
|---|---|
| S10 | Staff inspection show — checklist, findings, evidence, submit |
| S12 | Staff reports index |
| S13 | Report show — draft edit, review, request changes, approve |
| S14 | Exact-version release / revoke confirmation |
| C11 | Client reports index (released only) |
| C12 | Client report show + protected PDF download |

## Domain

**Inspections:** versioned `InspectionTemplate` / `InspectionTemplateVersion` → `Inspection` → checklist responses, findings, `InspectionEvidenceLink` → exact `DocumentVersion` (quarantine-enforced).

**Reports:** `Report` / `ReportVersion` / `ReportReview` / `ReportRelease`. Approval ≠ release. Corrections use `Reports::Revise` (new draft version; predecessor recorded in `content_json.revision`). Approved PDF via trusted `Reports::ArtifactStore` (`scanner_adapter: application_generated`) — not ordinary upload path.

## Authorization

`Inspections::Access` / `Reports::Access` + catalogue `inspections.*` / `reports.*` + assignment `access_scope` (delivery vs review vs collaborator). Independent SoD on report approve (not author/submitter/same user). Collaborators cannot approve or release.

## Simulation

`mode: simulated` only. Production refuses create/release paths. PDFs watermarked **SIMULATED — NOT FOR OPERATIONAL OR CERTIFICATION USE**.

## Project milestones

`Delivery::TechnicalProgress` + `Delivery::Milestones` evidence gates: `technical_review` needs submitted/completed inspection; `report_release` needs active `ReportRelease`. No invoice creation.

## History protection

PostgreSQL triggers: `inspection_template_versions_protect`, `inspection_evidence_link_protect`, `report_versions_protect`, `report_releases_protect`. No application-accessible bypass GUCs.

## F4-08 handoff

Future billing may reference project, client org, accepted quotation amounts, currency, payment terms, and technical delivery status — never auto-invoice from inspection/report events.

## Outstanding decisions / production gates

Approved real inspection/report templates; technical competency / signature policy; ADR-010 storage; live certification; live commercial/document ops; production malware scanning; restricted DB role; F4-08 billing; formal design sign-off.
