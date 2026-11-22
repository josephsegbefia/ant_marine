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
| Styles | [`app/assets/tailwind/application.css`](../../app/assets/tailwind/application.css) | `.ant-control`, `.ant-select*`, `.ant-toast*`, `.ant-back-link` |

## Back navigation

```erb
<%= ant_back_link label: "Back to invitations", path: staff_invitations_path %>
```

- Uses a normal `link_to` to an **application path** only (`validate_back_path!` rejects external URLs).
- **Breadcrumbs** (`portal-topnav`) show hierarchy; **back links** provide a clear primary return action (both may appear on nested portal pages).
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

Layouts [`access`](../../app/views/layouts/access.html.erb) and [`portal`](../../app/views/layouts/portal.html.erb) mount `toast-stack` with `data-toast-stack-flash-value` JSON from `flash_toast_payload`.

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
- Full M07 sidebar / dashboard chrome not included.