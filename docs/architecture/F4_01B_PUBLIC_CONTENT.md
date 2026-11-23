# F4-01B — Insights, case studies, training & resources

**Status:** Local on `main` only. **Not pushed.** Builds on F4-01A (`97326a2` baseline).

## Studio screen mapping

| Studio | Public route | Staff CMS |
|--------|--------------|-----------|
| P13 Insights index / P14 article | `GET /insights`, `GET /insights/:slug` | `staff/website/articles` (M04) |
| P10–P11 Our work / project story | `GET /projects`, `GET /projects/:slug` | `staff/website/case_studies` (M05) |
| P16–P17 Training | `GET /training`, `GET /training/:slug` | `staff/website/training_offerings` (M06) |
| P15 Resources | `GET /resources`, `GET /resources/:slug` | `staff/website/public_resources` |

Website hub tabs: Services, Website pages, Insights, Our work, Training, Resources.

## Data model (separate tables — P2-OD-007)

Four org-scoped editorial tables with F4-01A workflow + `published_*` snapshots:

- `articles` — category, title/summary/body, seo
- `case_studies` — service_category, industry, story fields, `release_basis` (staff-only permission note)
- `training_offerings` — audience, objectives/topics jsonb, delivery_format (no schedules/prices)
- `public_resources` — resource_category, `file_release_enabled` default **false** (no public file delivery in this slice)

Shared concern: `PublicContentEditorial` (slug generation via `PublicContent::ContentSlug`, `:editorial` validation on submit).

## Editorial workflow

Reuses `PublicContent::Transition`, `PublicContent::Snapshot`, `website_workflow_button` POST forms, `content.view_draft` / `content.manage` / `content.publish`.

## Public access

- Published catalogue only; draft/in_review/approved → **404** on public slug routes.
- Sitemap: section index paths + published slugs only.

## Resource file safety (blocker documented)

Public resource **metadata** only. `file_release_enabled` remains false by default; staff cannot enable via form. No Active Storage attachment on `PublicResource` in F4-01B. Download UI shows honest “not available yet” copy. Full release requires ADR-010 / P3 storage gate.

## Case study confidentiality

No `project_id` or client org linkage. `release_basis` is for internal editorial records only. No seeder auto-publish.

## F4-01A deferred acceptance (unchanged)

- Manual F4-01A published snapshot browser retest
- F4-01A visual PO sign-off

Automated F4-01A + snapshot tests must remain green.

## Action Text save fix (F4-01B corrective)

**Root cause:** Migration `20261123143000` removed `articles.body` (and other legacy text columns) after backfill to `action_text_rich_texts`. Fresh test processes load the correct schema, but a **long-running `bin/dev` Puma** could keep **stale `ActiveRecord` column metadata** that still included `body`, so `INSERT` referenced a non-existent column.

**Fix:** `HasPublicRichText#has_public_rich_text` sets **`ignored_columns`** for each rich-text name so legacy names are never written on the base table, plus `config/initializers/public_content_rich_text.rb` calls **`reset_column_information`** on prepare in development.

**Regression:** `test/models/action_text_persistence_test.rb`, `test/integration/staff/article_create_action_text_test.rb`.

## Rich text (Action Text / Trix) — F4-01B amendment

- Draft long-form fields stored in **Action Text** (`has_public_rich_text`); `published_*` columns remain frozen HTML snapshots on publish.
- Reusable staff control: `ant_rich_text_field` + `rich_text_editor` Stimulus (no file tools; `trix-file-accept` blocked).
- Direct Active Storage upload routes stay disabled; editor omits upload URLs.
- Public render: `public_render_rich_text` + `.public-rich-text` typography (matches public reading styles).
- Applies to: article body, case study story fields, training body, resource body, service body, website page body.
- Embedded attachments rejected/scrubbed server-side; snapshot HTML sanitized (`PublicContent::RichText`).
- Staff toolbar: shared `shared/ui/rich_text_toolbar` + `trix_ant_marine_config.js` (Trix 2.1.19). Primary: heading, bold/italic/underline/strike, lists, quote, link, undo/redo. **More:** indent, outdent, code block, clear formatting. **Not in scope:** text alignment, horizontal rules, tables, colours/fonts (Trix/sanitizer not approved).

## Out of scope

Training registration, public resource file downloads, image/file embedding in rich text (until ADR-010), F4-02 forms, production deploy.