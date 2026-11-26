# ANT Marine — Shared UI components (P3-A2-UX)

Design references: **A01/A03/A05/A06** (fields), **M08** (invitations form), studio global **`.toast`**.

## Inventory

| Component | Location | Purpose |
|-----------|----------|---------|
| `ant_field` | [`app/helpers/ant_ui_helper.rb`](../../app/helpers/ant_ui_helper.rb) + [`app/views/shared/ui/_field.html.erb`](../../app/views/shared/ui/_field.html.erb) | Text, email, password inputs |
| `ant_rich_text_field` | [`_rich_text_field.html.erb`](../../app/views/shared/ui/_rich_text_field.html.erb) + [`_rich_text_toolbar.html.erb`](../../app/views/shared/ui/_rich_text_toolbar.html.erb) + [`trix_ant_marine_config.js`](../../app/javascript/trix_ant_marine_config.js) + [`rich_text_editor_controller.js`](../../app/javascript/controllers/rich_text_editor_controller.js) | Action Text / Trix (2.1.19): primary + **More** menus (underline, strike, indent, code block, clear formatting); shared across all staff long-form fields |
| **Editorial workspace** | [`staff/website/editorial_workspace/*`](../../app/views/staff/website/editorial_workspace/) + [`staff_editorial_wizard_controller.js`](../../app/javascript/controllers/staff_editorial_wizard_controller.js) + [`StaffEditorialWorkspaceHelper`](../../app/helpers/staff_editorial_workspace_helper.rb) | Multi-step staff CMS shell (matches service editor): stepper, cards, preview aside, page settings, save draft / save and continue |
| `staff-editorial-preview` | [`staff_editorial_preview_controller.js`](../../app/javascript/controllers/staff_editorial_preview_controller.js) + [`editorial/_draft_preview.html.erb`](../../app/views/staff/website/editorial/_draft_preview.html.erb) | Legacy single-page preview; superseded by editorial workspace previews for F4-01B types |
| `ant_select` / `ant_collection_select` | [`_select.html.erb`](../../app/views/shared/ui/_select.html.erb) | Custom listbox synced to native `<select>` |
| `toast-stack` | [`toast_stack_controller.js`](../../app/javascript/controllers/toast_stack_controller.js) | Global notifications |
| `form-submit` | [`form_submit_controller.js`](../../app/javascript/controllers/form_submit_controller.js) | Submit loading / disable |
| `ant_back_link` | [`_back_link.html.erb`](../../app/views/shared/ui/_back_link.html.erb) | Return navigation (studio **A05** outline + `left` icon) |
| `ant_empty_state` | [`_empty_state.html.erb`](../../app/views/shared/ui/_empty_state.html.erb) + [`_empty_state_icon.html.erb`](../../app/views/shared/ui/_empty_state_icon.html.erb) | Reusable empty / zero-results panel (studio **Empty** states) |
| `ant_page_header` | [`_page_header.html.erb`](../../app/views/shared/ui/_page_header.html.erb) | Studio **app-head** title, description, primary/secondary actions |
| `ant_section_tabs` | [`_section_tabs.html.erb`](../../app/views/shared/ui/_section_tabs.html.erb) | Section switcher (e.g. Services / Website pages) |
| `ant_status_badge` | [`_status_badge.html.erb`](../../app/views/shared/ui/_status_badge.html.erb) | Editorial status pill (uses `.ant-badge--*`) |
| `ant_content_record` | [`_content_record.html.erb`](../../app/views/shared/ui/_content_record.html.erb) | Studio **list-item** row: icon, title, status, guidance, actions |
| Staff quotations (F4-02A) | [`staff/quotations/*`](../../app/views/staff/quotations/), `Commercial::*` | S05 dashboard + 5-step editor; Prawn PDF; not website CMS |
| Staff workspace shell | [`layouts/staff_portal.html.erb`](../../app/views/layouts/staff_portal.html.erb), [`shared/staff/*`](../../app/views/shared/staff/) | Studio **S01** sidebar + header (staff routes only) |
| Client workspace shell | [`layouts/client_portal.html.erb`](../../app/views/layouts/client_portal.html.erb), [`shared/client/*`](../../app/views/shared/client/) | Studio **C01** sidebar + header (client routes) |
| Public site shell | [`layouts/public_site.html.erb`](../../app/views/layouts/public_site.html.erb), [`shared/public/*`](../../app/views/shared/public/) | Studio **P01** header/footer + homepage entry |
| `public_service_card` | [`shared/public/_service_card.html.erb`](../../app/views/shared/public/_service_card.html.erb) | Studio **P02/P03** service cards (icon, title, summary, learn-more link, hover/focus) |
| `public_empty_state` | [`shared/public/_empty_state.html.erb`](../../app/views/shared/public/_empty_state.html.erb) | Intentional empty catalogue states (icon circle, title, copy, optional CTA to Contact/Services) |
| `public_page_banner` | [`shared/public/_page_banner.html.erb`](../../app/views/shared/public/_page_banner.html.erb) | Studio **page-banner**; optional `primary_action` (e.g. service detail **Enquire about this service** → contact) |
| `public_hero_image` | [`shared/public/_hero_image.html.erb`](../../app/views/shared/public/_hero_image.html.erb) + `app/assets/images/public/hero-maritime.jpg` | AI-generated generic maritime hero (not a client vessel); SVG fallback in `_hero_art` |
| `public_content_card` | [`shared/public/_content_card.html.erb`](../../app/views/shared/public/_content_card.html.erb) | Premium patterned card shell (icon badge, CTA arrow hover) |
| `ant_icon_picker` | [`shared/ui/_icon_picker.html.erb`](../../app/views/shared/ui/_icon_picker.html.erb) + `icon_picker_controller.js` | Visual grid picker for `icon_key`; catalog in `PublicContent::IconCatalog` |
| `PublicUiHelper` | [`public_ui_helper.rb`](../../app/helpers/public_ui_helper.rb) | Single source for public primary/secondary nav and service labels |
| Styles | [`app/assets/tailwind/application.css`](../../app/assets/tailwind/application.css) | `.ant-control`, `.ant-select*`, `.ant-toast*`, `.ant-back-link`, `.staff-*` |

## Staff website list hub (F4-01A)

`staff/website/services` and `staff/website/pages` share:

- `staff/website/_management_header.html.erb` — `ant_page_header` + `ant_section_tabs`
- `staff/website/_content_list_panel.html.erb` — grouped records + footer notice
- `StaffBreadcrumb` concern — one breadcrumb in the staff header (no duplicate trail in the body)

```erb
<%= ant_page_header(
      title: "Manage website content",
      description: "Keep your services and website pages accurate and up to date.",
      primary_action: { label: "Create service", path: new_staff_website_service_path }
    ) %>
<%= ant_section_tabs(
      tabs: [
        { label: "Services", path: staff_website_services_path, active: true },
        { label: "Website pages", path: staff_website_pages_path, active: false }
      ]
    ) %>
<%= ant_content_record(
      title: service.title,
      description: service.summary,
      guidance: public_content_list_guidance(service.status),
      status_label: public_content_status_label(service.status),
      status_badge_class: public_content_status_badge_class(service.status),
      primary_action: service_list_primary_action(service),
      secondary_action: service_list_secondary_action(service),
      icon: :layers
    ) %>
```

Breadcrumbs: set in `Staff::Website::*` controllers via `assign_staff_breadcrumb` / `assign_website_section_breadcrumb` (rendered once in `shared/staff/_header.html.erb`).

F4-01B reuses the same hub (`staff/website/_website_hub_tabs`, `editorial/index`, `workflow_actions`, `website_workflow_button`) for articles, case studies, training offerings and public resources.

## Editorial workspace (F4-01B-UX)

Visual reference: **service editor** (`staff/website/services/_editor.html.erb`, `.staff-editor-*` in Tailwind).

Shared partials under `staff/website/editorial_workspace/`:

| Partial | Role |
|---------|------|
| `_editor.html.erb` | Page head, step tabs, two-column layout, form wrapper |
| `_footer.html.erb` | Step label, status pill, Back / Save draft / Save and continue |
| `_workflow_status.html.erb` | Review-step publishing actions (`workflow_actions`) |
| `_address_card.html.erb` | Public URL (fixed for site pages; slug after first save elsewhere) |
| `steps/_*.html.erb` | Per-model fields and `data-validate` rules |
| `previews/_*.html.erb` | Live aside preview (`staff-editorial-wizard` sanitizes HTML client-side) |

Configuration: `StaffEditorialWorkspaceHelper::WORKSPACES` (steps, copy, path prefixes). Controllers: `StaffWebsiteEditorialController` + `StaffWebsiteEditorialWizard`; website **pages** use the same shell via `PagesController` (two steps: content → review).

**Save behaviour:** `commit=save_continue` validates the current step, saves, redirects to `edit_*?step=n+1`; `save_draft` requires title only; review step shows workflow POST buttons only (no nested forms).

**Responsive:** `.staff-editor-layout` — main column + `lg:` preview aside; step tabs stack on small screens.

**Services:** unchanged four-step service wizard (separate Stimulus controller).

## Empty state

Use when a list or section has nothing to show yet. The **parent page** supplies all copy, icons and routes — the component does not hardcode modules.

```erb
<%= ant_empty_state(
      icon: :layers,
      title: "No service pages yet",
      description: "Create a draft service page when you are ready to add to the public catalogue.",
      guidance: "Nothing is visible on the public website until a service is reviewed and published.",
      primary_action: policy(Service).create? ? { label: "Create a service", path: new_staff_website_service_path } : nil,
      secondary_action: { label: "View website pages", path: staff_website_pages_path },
      variant: :default,
      size: :spacious
    ) %>
```

```erb
<%= ant_empty_state(
      icon: :globe,
      title: "No website pages yet",
      description: "Homepage, about, industries and contact sections appear here once your team adds them.",
      secondary_action: { label: "View service pages", path: staff_website_services_path },
      variant: :muted,
      tone: :info
    ) %>
```

| Option | Values | Notes |
|--------|--------|--------|
| `variant` | `:default`, `:muted`, `:emphasis` | Surface style |
| `size` | `:compact`, `:default`, `:spacious` | Vertical padding |
| `tone` | `:neutral`, `:info` | Guidance emphasis |
| `icon` | `:layers`, `:globe`, `:folder`, `:mail`, `:search` | Decorative; `aria-hidden` on SVG |
| `primary_action` / `secondary_action` | `{ label:, path:, class: optional }` | Paths must be app-relative (`/`); omit when user lacks permission |

Markup uses `role="status"`, a single `h2` title, and responsive action stacking (`sm:flex-row`).

## Back navigation

```erb
<%= ant_back_link label: "Back to invitations", path: staff_invitations_path %>
```

- Uses a normal `link_to` to an **application path** only (`validate_back_path!` rejects external URLs).
- **Staff shell breadcrumb** (`staff-app-bread`) shows `Team workspace › {page title}` via `content_for :staff_page_title`, or a full trail when `assign_staff_breadcrumb` is used (website CMS).
- **Back links** provide a clear primary return action on nested staff/client pages.
- **Workspace rule (staff):** show `ant_back_link "Back to workspaces"` → `workspace_selection_path` and sidebar “Switch workspace” **only when** `Current.user.portal_eligible_memberships.size > 1`.
- **When to skip:** do not add a back link if it would duplicate the only navigation affordance with no added clarity (e.g. top-level auth entry with no safe parent).
- Studio reference: **A05** `btn outline` + **left** icon; **P19–P21** quote wizard back actions.

## Form fields

```erb
<%= ant_field form, :email, type: :email, label: "Work email", required: true, placeholder: "...", context: :portal %>
<%= ant_select form, :role_key, choices: RoleLabels.options_for_roles(@allowed_roles), label: "What can they do?", context: :portal %>
<%= ant_collection_select form, :organization_id, @client_organizations, :id, :name, searchable: true, selected: @organization&.id %>
```

- **`context: :access`** (default) uses `field-wrap` + A01 labels.
- **`context: :portal`** uses portal label styling.
- **`error:`** sets `aria-invalid` and `.ant-field__error`.

## Custom dropdown

- Native `<select class="ant-select__native">` remains the submitted value.
- Stimulus [`custom-select`](../../app/javascript/controllers/custom_select_controller.js) enhances UI; without JavaScript the native control is shown (`.is-enhanced` is added on connect).
- **Helpers:**
  - `ant_select(form, method, choices:)` / `ant_collection_select` for form builders.
  - `ant_select_tag(name, choices, label:, selected:, include_blank:, searchable:, compact:, data:, …)` for fields outside a form builder (filters, quotation steps). `data:` and `aria:` go on the native select so Stimulus targets and actions keep working.
- Shared markup: [`shared/ui/_select_core`](../../app/views/shared/ui/_select_core.html.erb).
- **`searchable: true`** for longer lists (client invitations, enquiry assignee when many, qualify organisation, quotation client).
- Inside a `<dialog>`, the options panel is fixed to the viewport so it is not clipped.
- Disabled when the native select matches `:disabled` (including a disabled parent fieldset).
- Keyboard: Enter/Space, arrows, Home/End, Escape (does not close a surrounding dialog), Tab exits.

## Toasts and flash

| Flash key | Toast type |
|-----------|------------|
| `notice` | `success` |
| `alert` | `error` (assertive) |
| `warning` | `warning` |
| `info` | `info` |

Layouts [`access`](../../app/views/layouts/access.html.erb), [`portal`](../../app/views/layouts/portal.html.erb) (client), and [`staff_portal`](../../app/views/layouts/staff_portal.html.erb) mount `toast-stack` with `data-toast-stack-flash-value` JSON from `flash_toast_payload`.

Optional action (example): invitation success → “View invitations” (`staff_invitations_path`).

Lifecycle: auto-dismiss (5–12s by type), pause on hover/focus, cleared on `turbo:before-cache`.

## Turbo / forms

```erb
data: {
  controller: "form-submit",
  action: "turbo:submit-start->form-submit#busy turbo:submit-end->form-submit#idle turbo:submit-error->form-submit#idle",
  form_submit_loading_message_value: "Sending..."
}
```

## Limitations

- Studio HTML uses native selects; enhanced listbox is progressive enhancement with native fallback.
- Keyboard/a11y of listbox requires manual browser QA (390px / 1440px).
- No JavaScript unit test runner; coverage is integration + manual acceptance.
## Staff workspace shell (P3-A2-UX-C)

- Layout `staff_portal` wraps all `Staff::*` controllers; client portal stays on `portal`.
- Sidebar nav lists **implemented routes only**: Overview, Invitations (issuers only).
- Home overview shows real invitation metrics or honest empty state — no studio demo stats.
- Mobile: `staff-shell` Stimulus toggles sidebar nav below 1024px (`staff-mobile-nav-toggle`).

## Staff sidebar visual refinement (P3-A2-UX-D)

- **Width:** desktop sidebar `272px` (PO-refined from studio `236px` for label/icon comfort).
- **Colour:** background `#164f67` (softer maritime navy vs studio `#10324a`); active item `#2b6674` with subtle teal border.
- **Branding:** compact `ant-brand` block only — **no** duplicate org/workspace card in the sidebar.
- **Icons:** inline SVG (`shared/staff/_nav_icon.html.erb`), studio stroke `1.65` — `home` (Overview), `mail` (Invitations), `switch` (workspace change), `menu` (mobile toggle).
- **Workspace switch:** footer link when `portal_eligible_memberships.size > 1`; header back link unchanged.
- **Mobile drawer:** fixed panel `min(272px, 88vw)`, backdrop dismiss, `Escape` close, body scroll lock (`staff_shell_controller.js`).
- **Profile footer:** pinned to sidebar bottom via flex column (`staff-app-side__inner` + `flex-1` nav scroll region); scrollable nav body on small drawers.

## Public enquiry wizard (F4-02B)

- **Markup:** `public/service_inquiries/new.html.erb` with `.public-enquiry` (card, `__stepper` / `__step` with `is-current` / `is-done`, service choice cards, error summary) and `_field.html.erb` for labelled inputs with hint, "Optional" tag and inline error.
- **Behaviour:** Stimulus `enquiry-wizard` adds `is-enhanced` and shows one step at a time; `next` runs native required-field checks on the visible step and focuses the first invalid field; `reveal` (error summary links) opens the step containing a field. Without JavaScript the whole form shows as one page.
- **Confirmation:** `.public-enquiry-received` — reference, service and time only; "What happens next" makes no response-time or booking promise.
- **Nav state:** wizard pages set `content_for :public_nav, "enquiry"` so no header item is highlighted.

## Staff enquiries and quotation versions (F4-02B)

- **Enquiries:** list uses the staff list-hub cards; detail uses `.staff-enquiry-facts` (label/value grid) and `.staff-enquiry-description` (escaped plain text, paragraphs preserved).
- **Versions panel:** `.staff-quote-versions` in the quotation editor — one row per version with status badge, who/when and reason; current row marked; each opens the read-only version page.
- **Delivery status:** `QuoteDelivery#status_label` / `#badge_variant` (`ant-badge--blue|teal|good|warn|muted`); `quote_delivery_summary` helper for the editor summary.
- **Issuance screen:** existing `ant-card` / `ant-btn-*`; test-mode notice always visible; confirmation checkboxes before Prepare.

## Date picker

- **Helper:** `ant_date_field(name, label:, value:, min:, max:, placeholder:, range_start_for:, range_end_for:, …)` → [`shared/ui/_date_picker`](../../app/views/shared/ui/_date_picker.html.erb).
- Without JavaScript: a real `<input type="date">` with the same `name`, `min` and `max` (ISO dates).
- With JavaScript: Stimulus `ant-date-picker` hides the native input, shows a trigger (calendar icon, formatted date or placeholder, clear button) and opens a centred native `<dialog>` calendar (year and month arrows, Monday-first grid, Today / Cancel, blurred navy backdrop).
- Keyboard: arrow keys, Home/End, PageUp/PageDown (Shift for year), Enter/Space to select; Escape closes without closing a surrounding dialog.
- Linked ranges: `range_start_for` / `range_end_for` take the paired field id so "from" cannot pass "to".
- Used on: enquiry received from/to, clarification answer date, quotation valid-until, and the public request-a-quote preferred date.

## Project documents (F4-06)

- Staff S11: [`staff/project_documents`](../../app/views/staff/project_documents/) — `ant_page_header`, summary cards, filters, `ant_empty_state`, upload form, request dialog (`ant_dialog`), version/review/release actions on show.
- Client C07–C09: [`client/upload_requests`](../../app/views/client/upload_requests/), [`client/project_documents`](../../app/views/client/project_documents/), [`client/documents`](../../app/views/client/documents/) — request list, library, metadata + protected download only (no unsafe in-app preview).
- Labels: [`DocumentsHelper`](../../app/helpers/documents_helper.rb) for workflow/security/upload-request status wording.
- Quarantine copy must stay truthful: uploaded files show security checks pending until `storage_assets.scan_status = available`.

## Staff overview (S01)

- [`Staff::OverviewSummary`](../../app/models/staff/overview_summary.rb) gathers permission-aware stats, work waiting and recent notifications through the same policy scopes as the full pages.
- View: [`staff/home/show`](../../app/views/staff/home/show.html.erb) — greeting by time of day, summary cards, work list and recent updates. Team invitations stay in the sidebar / Invitations pages. No jobs, reports or schedule cards until those domains exist.
- Styles: `.staff-overview-stats`, `.staff-overview-grid`, `.staff-overview-row`.

## Enquiry triage workspace (F4-03)

- **Pagination:** `Pagination.new(scope, page:, per_page: 25)` (offset; malformed or out-of-range pages clamp to a valid page) + `ant_pagination(pagination, label:, path_for: ->(page) { ... })` → `shared/ui/_pagination.html.erb` ("Showing 1–25 of N", Previous/Next, `aria-label="Pages"`). Used by enquiries, notifications and invitation lists (6 per page inside the fixed-height Recent invitations card; Active/All filter; Cancel/Resend on pending only).

- **Dialog:** `ant_dialog(id:, title:, trigger_label:, trigger_class:, description:) { form }` → `shared/ui/_dialog.html.erb`; native `<dialog>` opened with `showModal` by Stimulus `ant-dialog` (focus first field, backdrop click and close button dismiss, Escape native, focus returns to the opener). Use for any action that needs a reason or extra input; put warnings inside the dialog body.
- **Filter toolbar:** `.ant-filter-toolbar` grid of labelled fields + `.ant-filter-toolbar__actions` (Apply `ant-btn-primary--compact`, Clear link only when filters are active). Buttons keep their natural width at every size. `.ant-btn-outline--compact` must come after `.ant-btn-outline` in the stylesheet (this was the cause of the full-width mobile Apply button).
- **Stat cards:** `.staff-enquiry-stat` links with `aria-label="Label: N. caption"`.
- **List:** `.staff-enquiry-table` from `lg` (1024px); `.staff-enquiry-cards` below (two columns from `sm`).
- **Workspace:** `.staff-enquiry-workspace` with `__aside` first in source (status first on phones, sticky right column on desktop) and `__main`; `.staff-enquiry-facts` label/value grid; `.staff-enquiry-actions` stacked full-width buttons.
- **Timeline:** `ol.ant-timeline` > `li.ant-timeline__item--{kind}` with `__title`, `__detail`, `__meta` ("Name · 25 Nov 19:32"; "Website" for public submissions). Fed by `Intake::InquiryTimeline` entries only — never raw audit data.
- **Notification list:** `/staff/notifications`, unread items emphasised, "Mark all as read", opening an item marks it read; sidebar item shows the unread count in its accessible name ("Notifications, 1 unread").

## Project management (F4-05 / F4-05-H1)

- **Staff projects:** `/staff/projects` list + filtered views; `/staff/projects/:id` section tabs (overview/team/milestones/tasks/schedule/activity); create wizard from accepted quotation decision panel.
- **Lifecycle actions:** immediate transitions use compact `button_to`; hold / resume / cancel require a reason field (H1).
- **Activity updates:** visibility select — client-visible vs internal only.
- **My tasks / Schedule:** `/staff/tasks`, `/staff/schedule_events` agenda lists (no heavy calendar gem).
- **Client projects:** `/client/projects` + show; simulated banners; no internal notes or staff assignment history.
- Simulation labelling required on staff and client surfaces until live policy is approved.
- Responsive evidence: `tmp/f405_h1_screens/` (gitignored).

## Commercial decisions (F4-04B)

- **Client quotation detail / decide:** extends F4-04A show with Accept / Request changes / Decline (permission-gated), confirmation page (`client/quotations/decide`), decision history, unmistakable simulated banners; exact PDF download retained.
- **Staff decisions panel:** `staff/quotations/_decisions.html.erb` — decision status, actor, timestamp, reason, project-setup guidance (no Create project control).
- **Contacts:** staff Clients Access tab manages `ClientContact` rows without portal accounts.
- Live binding acceptance UI remains disabled (`Commercial::QuoteDecision.available?` false in production).

## Client onboarding & portal (F4-04A)

- **Staff Clients:** `/staff/clients` reuses enquiry list panel + `ant_pagination`, summary stats, and client detail tabs via `ant_section_tabs` (Overview / Contacts & access / Service requests / Quotations / Activity). Side panels use `shared/ui/side_panel_head`.
- **Onboarding:** `/staff/enquiries/:id/onboard` — guided form (organisation, representative, portal role, confirmation); roles from `Invitations::Policy` + `client_portal_role_options`.
- **Client shell:** nav Overview / Service requests / Quotations / Account only (future modules omitted). Helpers: `ClientPortalHelper` (`client_can_view_requests?`, `client_can_view_quotations?`, `client_request_status_label`, `client_money`).
- **Client mobile drawer (F4-04B-H1):** closed drawer and backdrop use `pointer-events: none`; Stimulus `client-shell` applies `inert`/`aria-hidden` when closed below `lg`, closes on `turbo:before-visit` / `turbo:before-cache` (not `turbo:load`, which races menu open after navigation), Escape, backdrop click, and sidebar link click. An open drawer must be dismissed before page content receives clicks; a closed drawer must never intercept commercial actions.
- **Quotations:** simulated offers show a warn notice; PDF download; F4-04B adds simulated Accept / Request changes / Decline for authorised representatives.
- **Pagination:** staff clients and client request/quotation lists use `ant_pagination` with `path_for` lambdas (same contract as F4-03).

## Limitations (continued)

- Client portal keeps the existing client shell (not the staff sidebar pattern).
- Live commercial portal release and binding acceptance remain disabled; see F4-04B.