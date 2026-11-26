# F4-04B-H1 — Commercial security & final acceptance

**Baseline:** `6b52389` (F4-04B)  
**Branch:** `main` (local only — do not push)  
**Hard stops:** No push/deploy; no real email; no live release; no binding acceptance; no projects; no F4-05; no DB reset; no Design Studio edits; no production DB privilege changes.

## Objectives

1. Remove insecure `ant_marine.history_bypass` GUC gate from history protect functions.
2. Prove non-owner runtime cannot disable triggers, drop functions, truncate history, or mutate frozen content via SET GUC.
3. Correct client mobile navigation so a closed drawer never intercepts commercial actions.
4. Complete invitation activation and mobile commercial browser acceptance.
5. Document commercial decision rules and F4-05 conversion contract (no Project implementation).

## History bypass findings

- **Pre-H1:** protect functions short-circuited when `current_setting('ant_marine.history_bypass') = 'on'`.
- **Any** PostgreSQL role can `SET` / `SET LOCAL` a custom GUC. Ordinary application runtime therefore could bypass frozen-revision / line-item / response protections without needing `DISABLE TRIGGER`.
- Disabling triggers alone was insufficient proof of safety.

## Correction

- Migration `db/migrate/20261126120000_f4_04b_h1_remove_history_bypass.rb`:
  - Rewrote `ant_marine_quote_revision_protect`, `ant_marine_quote_line_item_protect`, `ant_marine_quote_response_protect` with **no** bypass branch.
  - Parent revision locked `FOR UPDATE` during line-item mutations / freeze paths.
  - Dropped `ant_marine_history_bypass_enabled()`.
  - `REVOKE TRUNCATE … FROM PUBLIC` on protected history tables (owners retain TRUNCATE; production must use a non-owner runtime role).
- Test helper: `with_history_protection_admin` (test-only `DISABLE TRIGGER`) for fixture cleanup — never called from application code.
- `db/structure.sql` regenerated without bypass.

## Runtime privilege evidence

- Automated: `test/models/quote_history_triggers_test.rb` (direct SQL, GUC SET, PUBLIC TRUNCATE grant absence, concurrency).
- Disposable DB: `scripts/verify_history_protection_h1.sh` (fresh `structure.sql` load, non-owner role cannot DISABLE TRIGGER / DROP FUNCTION / TRUNCATE).
- **Production gate still OPEN:** deploy least-privilege runtime role that does not own protected tables.

## Mobile navigation root cause

Closed drawer / backdrop could still receive pointer events or remain interactive after Turbo navigation, intercepting Accept / Decline / Request changes on small viewports.

**Fix (shared client shell, not quotation-specific):**

- Closed drawer + backdrop: `pointer-events: none`.
- Stimulus `client_shell_controller`: `inert` + `aria-hidden` when closed on `<lg`; sync closed state on `turbo:before-visit` / `turbo:load`; Escape / backdrop dismiss; sidebar links call `close`.
- System coverage: `test/system/client_shell_navigation_test.rb` @390px.

## Browser acceptance evidence

Screens under `tmp/f404b_h1_screens/` (gitignored):

| Journey | Result |
|---|---|
| Accept @390 (visible controls, cancel/reopen) | Simulated accept on release 11 |
| Decline @390 | Simulated decline on release 12 with reason |
| Request changes @390 | Simulated changes on release 13; offer remains open |
| Invitation activate | Invitee activated via real `/invitations/:token` routes |
| Replay / invalid / expired / revoked | Correct denial pages |
| Layouts 1440 / 1280 / 768 / 390 | Screenshots captured |

## Commercial decision rules (simulated)

| Decision | Rule |
|---|---|
| Accept | One terminal decision per eligible offer version; content + evidence immutable |
| Decline | Closes that exact offer to later accept; history retained |
| Request changes | Records amendments; does **not** auto-withdraw; later terminal decision allowed; new commercial offer needs independently approved revision |

All decisions remain `mode: simulated`. Live / binding acceptance disabled.

## F4-05 conversion contract (documentation only)

See `docs/architecture/F4_04B_COMMERCIAL_DECISIONS.md` § F4-05. No Project models in this slice.

## Outcome docs

- [`docs/architecture/F4_04B_COMMERCIAL_DECISIONS.md`](../architecture/F4_04B_COMMERCIAL_DECISIONS.md)
- [`docs/architecture/F4_04A_CLIENT_ONBOARDING.md`](../architecture/F4_04A_CLIENT_ONBOARDING.md)
- [`docs/ui/SHARED_UI_COMPONENTS.md`](../ui/SHARED_UI_COMPONENTS.md)
- [`docs/DECISIONS.md`](../DECISIONS.md)
- [`docs/PHASE_PROGRESS.md`](../PHASE_PROGRESS.md)
