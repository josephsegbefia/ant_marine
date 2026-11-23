# F4-01A — Public website and editorial foundation

**Status:** Local on `main` (baseline `95d9c31`). **Not pushed.** **217 tests / 781 assertions.** `scripts/verify_foundation.sh` passed 2026-11-23.

## Scope delivered

| Studio | Public route | Staff CMS |
|--------|--------------|-----------|
| P01 Homepage | `GET /` | `staff/website/pages` → `homepage` |
| P02 Services index | `GET /services` | `staff/website/services` |
| P03–P08 Service detail (6 cards) | `GET /services/:slug` | M02 edit per slug |
| P09 Industries | `GET /industries` | M03 `industries` |
| P12 About | `GET /about` | M03 `about` |
| How we work (checkpoint) | `GET /how-we-work` | M03 `how_we_work` |
| P18 Contact | `GET /contact` | M03 `contact` (display only; no submit) |
| — | `GET /sitemap.xml`, `GET /robots.txt` | — |

**Deferred:** P10–P17, P19–P24, quote/inquiry (F4-02), articles/case studies/training URLs (F4-01B), footer links for Projects/Training/Insights.

### Staff service editor (UX correction — local)

| Before | After |
|--------|--------|
| Single long admin form with raw slug/list text areas | Four-step guided editor: Basics → Details → Scope & process → Review |
| Staff entered slug; draft save failed validation | Page address generated on first save; stable thereafter |
| Minimal field help | Plain-English labels, hints, step validation, and missing-item checklist |
| No in-context preview | Staff-only live draft preview + search snippet (not a public route) |
| Breadcrumb showed only “Overview” on page | In-page trail: Team workspace › Website › Services › current service |

Publishing workflow, permissions, and `published_*` snapshot semantics are unchanged. **Product owner visual acceptance pending.**

### Staff list UX (M02/M03 alignment — local)

- Unified hub header: **Manage website content** with Services / Website pages tabs (studio M02/M03 navigation pattern).
- Populated lists use shared `ant_content_record` rows (studio **list-item**): title, summary, status badge, plain-English guidance, authorized actions — no prominent slugs.
- Single breadcrumb trail via `StaffBreadcrumb` in the staff header (`Team workspace › Website › Services`).
- Empty states remain `ant_empty_state`; populated and empty are mutually exclusive per collection.

**Public nav (PO):** Home, Services, About, Industries, How we work, Contact, Sign in — working routes only.

## Data model

### `services`

Organisation-scoped (`organization_id` → ANT Marine). Editorial workflow:

`draft` → `in_review` → `approved` → `published` → `archived` (CHECK constraint; supersedes catalogue `draft/published/archived` for this slice — see `docs/DECISIONS.md`).

On **publish**, draft fields are copied into `published_*` snapshot columns. Public site reads snapshots only for `status == published`. Draft, in review and approved rows return **404** by slug (no numeric-ID IDOR).

Content: `title`, `slug`, `summary`, `body`, `category`, `audience`, `scope_items` / `process_steps` (jsonb string arrays), `display_order`, `seo` jsonb, `icon_key`, workflow timestamps and `*_by_membership_id` attribution.

### Draft save validation correction (2026-11-23)

**Root cause (six PO errors):**

| Error | Cause | Fix |
|-------|--------|-----|
| Slug can't be blank / invalid | Staff form left slug empty; no server generation; slug still permitted | `PublicContent::ServiceSlug.generate` on **create**; slug removed from staff strong params; read-only “Page address” in UI |
| Scope/process/published_* “is reserved” | `validates :*_items, exclusion: { in: [nil] }` — Rails treats **empty arrays** as excluded | Removed broken exclusions; `normalize_list_columns` coerces lists to `[]` |
| Draft save mirrored into published snapshots | Controller copied draft JSONB into `published_*` on every save | Removed mirror; snapshots updated only via `PublicContent::Snapshot` on **publish** |

**Validation contexts:**

- Default (`create`/`update`): title required; lists may be empty; slug system-managed.
- `:editorial`: summary, body, audience, category required — enforced on **submit for review** (`PublicContent::Transition`).

**System-managed (not in staff `service_params`):** `slug`, `display_order` (defaulted on create), `status`, all `published_*`, workflow timestamps, attribution ids.

### `public_site_pages`

Separate from STI `content_pages` (P2-OD-007). Unique `page_key`: `homepage`, `about`, `industries`, `how_we_work`, `contact`. Same status workflow and published snapshot pattern. Homepage uses `page_data` (hero, CTAs, intro blocks). Contact stores nullable verified channels only; public view shows honest empty-state copy when unset.

**Rendering:** plain text + `PublicContentHelper` sanitize / `simple_format` allowlist — no Action Text in this slice.

## Editorial permissions

Catalogue keys only:

| Action | Permission |
|--------|------------|
| View drafts | `content.view_draft` |
| Create / edit / submit / withdraw | `content.manage` |
| Approve / publish / unpublish / archive | `content.publish` |

`PublicContent::Transition` enforces transitions; `AuditEvent` records `public_content.submitted`, `.approved`, `.published`, `.unpublished`, `.archived` (metadata only — no body text).

Policies: `ServicePolicy`, `PublicSitePagePolicy`.

## Public vs authenticated home

- Anonymous visitors: public layout, CMS-driven homepage + published services grid.
- Signed-in staff/client with portal access: `GET /` redirects to staff or client workspace (preserves pre–public-site behaviour).

## Six public services and questionnaire mapping

Ten questionnaire specialty areas are grouped into **six** studio service URLs (not ten separate pages):

| Slug | Studio group | Questionnaire areas absorbed (examples) |
|------|--------------|----------------------------------------|
| `marine-surveys` | Marine surveys | Warranty, hull/machinery, pre-purchase, on/off-hire, incident, project cargo surveys |
| `project-support` | Project support | Ship-in-service, drydock, sea trials, construction coordination, technical assurance |
| `environmental-safety` | Environmental & safety | Environmental assessments, ISM/MLC/ISPS audits, compliance, biodiversity advice |
| `naval-design-modifications` | Naval design | Architectural support, retrofits, modifications, installation reviews |
| `technical-reports` | Technical reports | Inspection/condition reports, findings, project records |
| `training` | Training | Workshops, compliance awareness, custom training (public detail page only — no training portal in F4-01A) |

## Seeds

`PublicContent::CatalogueSeeder` (via `db/seeds.rb`): idempotent upsert of six **draft** services and five draft site pages from studio-aligned structure. **Does not auto-publish.** No fabricated clients, stats or credentials.

## Content approval blockers (not code)

Publishable copy for leadership, contact numbers/email, and marketing claims requires product-owner approval before `published` status on any row.

## Out of scope (unchanged)

F4-01B marketing expansions, F4-02 forms, M11 company settings CRUD, Design Studio HTML edits, production deploy.