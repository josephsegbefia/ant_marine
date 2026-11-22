# ANT Marine — Shared UI components (P3-A2-UX)

Design references: **A01/A03/A05/A06** (fields), **M08** (invitations form), studio global **`.toast`**.

## Inventory

| Component | Location | Purpose |
|-----------|----------|---------|
| `ant_field` | [`app/helpers/ant_ui_helper.rb`](../../app/helpers/ant_ui_helper.rb) + [`app/views/shared/ui/_field.html.erb`](../../app/views/shared/ui/_field.html.erb) | Text, email, password inputs |
| `ant_select` / `ant_collection_select` | [`_select.html.erb`](../../app/views/shared/ui/_select.html.erb) | Custom listbox synced to native `<select>` |
| `toast-stack` | [`toast_stack_controller.js`](../../app/javascript/controllers/toast_stack_controller.js) | Global notifications |
| `form-submit` | [`form_submit_controller.js`](../../app/javascript/controllers/form_submit_controller.js) | Submit loading / disable |
| `ant_back_link` | [`_back_link.html.erb`](../../app/views/shared/ui/_back_link.html.erb) | Return navigation (studio **A05** outline + `left` icon) |
| Staff workspace shell | [`layouts/staff_portal.html.erb`](../../app/views/layouts/staff_portal.html.erb), [`shared/staff/*`](../../app/views/shared/staff/) | Studio **S01** sidebar + header (staff routes only) |
| Styles | [`app/assets/tailwind/application.css`](../../app/assets/tailwind/application.css) | `.ant-control`, `.ant-select*`, `.ant-toast*`, `.ant-back-link`, `.staff-*` |

## Back navigation

```erb
<%= ant_back_link label: "Back to invitations", path: staff_invitations_path %>
```

- Uses a normal `link_to` to an **application path** only (`validate_back_path!` rejects external URLs).
- **Staff shell breadcrumb** (`staff-app-bread`) shows `Team workspace › {page title}` via `content_for :staff_page_title`.
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
- Stimulus [`custom-select`](../../app/javascript/controllers/custom_select_controller.js) enhances UI; on `disconnect` or `data-custom-select-fallback-value="true"`, native control is shown.
- **`searchable: true`** — client organisation picker only (`/staff/client_invitations/new`).
- Keyboard: Enter/Space, arrows, Home/End, Escape, Tab exit (no focus trap).

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

## Limitations (continued)

- Client portal does not yet use the full staff sidebar pattern.