# P3-A4 — Public, client and administration UI foundations

**Design references:** Studio **P01** (public homepage), **C01** (client home shell), **S01** (staff workspace — unchanged width/palette), **M01–M13** (company settings — deferred).

## Layout map

| Surface | Layout | Studio ID |
|---------|--------|-----------|
| Public marketing entry | `layouts/public_site.html.erb` | **P01** (hero, trust bar, service teaser, contact honesty) |
| Client signed-in workspace | `layouts/client_portal.html.erb` + `shared/client/*` | **C01** shell (272px navy sidebar, org card, MY WORK nav) |
| Staff signed-in workspace | `layouts/staff_portal.html.erb` (unchanged) | **S01** |
| Access / auth | `layouts/access.html.erb` (unchanged) | **A01–A06** |

## Administration decision

Company settings (**M01–M13**) are **not** a separate Rails namespace in Phase 3. Administration will extend the **staff workspace** sidebar (studio `adminNav` items). P3-A4 documents the future **ADMINISTRATION** section on the staff sidebar only; no routes or CRUD.

Team invitations remain the implemented staff (**M07/M08** pattern) and client (**C15** partial) surfaces.

## Real-data rules

- Public pages use approved marketing copy only — no studio sample companies, figures, or project lists.
- Client home shows the signed-in user, role label, and organisation name from `Current.membership`.
- No dashboard metrics, project rows, or invoice counts until Phase 4 features exist.

## Navigation and authorization

- Client **Team invitations** nav link renders only when `team.invite` is effective for the current membership.
- Staff invitation nav unchanged (`staff_can_invite?`).
- Public header does not link to unbuilt marketing routes as operational pages.

## Components reused

`AntUiHelper`, toast stack, back links, portal cards, staff nav icons, `staff-shell` / new `client-shell` and `public-nav` Stimulus controllers, shared Tailwind tokens in `application.css`.

## Responsive behaviour

Public mobile menu and client/staff drawers follow the same 272px sidebar pattern with backdrop, Escape to close, and scroll lock (see reduced-motion rules in CSS).

## Deferred

- Full public site (P02–P24), client business screens (C02–C19), company settings UI (M01–M13), permission management UI (C15 full).