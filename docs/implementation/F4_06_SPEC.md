# F4-06 — Secure Document Management (implementation specification)

**Checkpoint:** F4-06  
**Baseline:** `bc0402b` (F4-05-H1)  
**Branch:** local `main`  
**Hard stops:** no push, no deploy, no F4-07/F4-08, no live email, no live commercial/project initiation, no DB reset, no Design Studio edits, no quarantine bypass, no public document URLs, no external storage activation.

Full self-contained requirements are in the approved implementation brief delivered for this checkpoint. Architecture and acceptance evidence live in:

- [`docs/architecture/F4_06_DOCUMENT_MANAGEMENT.md`](../architecture/F4_06_DOCUMENT_MANAGEMENT.md)
- [`docs/DECISIONS.md`](../DECISIONS.md) (ADR-F4-06-*)
- [`docs/PHASE_PROGRESS.md`](../PHASE_PROGRESS.md)

## Design Studio mapping

| Screen | Role in F4-06 |
|---|---|
| S11 Job documents | Staff project documents |
| C07 Files we need | Client upload requests |
| C08 Documents & files | Client library |
| C09 Document preview | Metadata / versions / protected download |
| R05 / X03 | Mobile upload / failed upload UX |
| M09 | Deferred (categories seeded in code) |
| S10, C11–C12, S12–S14 | Out of scope (F4-07) |
| C10 | Messages — not documents |

## Domain (approved Phase 2 names + F4-06 extension)

- `Document`, `DocumentVersion`, `UploadRequest`, `DocumentAccessGrant`
- F4-06 exact-version extension: `DocumentReview`, `DocumentRelease` (mirrors report review/release pattern; required by F4-05-H1 access contract)
- Encrypted bytes + quarantine: reuse `Storage::Asset` / P3 AES-GCM / `ScanStorageAssetJob`

## Packages

A Foundation → B Staff + requests → C Review/release/download → D Client + notifications → E QA / docs / local commit only.
