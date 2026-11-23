# ANT Marine phase progress

| Gate | Status | Evidence required |
|---|---|---|
| Phase 1 — UI/UX | Delivered; final approval pending | Approved studio review export, corrected design HTML and signed-off wording |
| Preflight B0 — toolchain | **B0.0–B0.3 passed** | See B0 checkpoint log |
| Phase 2 — architecture | **Exit preparation complete — approval pending P2.5B trio** | `P2_5B_PHASE_2_EXIT_DECISIONS.md`; P2.5A in `08a5423` |
| Phase 3 — foundation | **P3-A3 local on `main`** | RBAC catalogue + EffectivePermissions + Pundit + granter; 124 tests; **not pushed** |
| Phase 4 — features | **F4-01A local on `main`** | Public routes + staff Website CMS; see F4-01A checkpoint; **not pushed** |
| Phase 5 — deployment | Not started | Staging checks, backup restoration, security/performance/SEO acceptance, launch approval |

## B0 checkpoint log

| Checkpoint | Date | Result | Notes |
|---|---|---|---|
| B0.0 Environment audit | — | **Passed** | Toolchain and workspace audit |
| B0.1A Prerequisites | — | **Passed** | mise Ruby 3.4.13, Rails 8.1.4.1 |
| B0.1B Rails application | 2026-11-22 | **Passed** | Commit `c448c4c`, module `AntMarine` |
| B0.2 Local PostgreSQL | 2026-11-22 | **Passed** | Commit `70a44f4`; PostgreSQL 17, `ant_marine_development` / `ant_marine_test`, `db:prepare`, HTTP 200, read/write verification |
| B0.3 Development quality | 2026-11-22 | **Passed** | Commit `28a1b2b`; smoke tests (4), `scripts/verify_foundation.sh`, `.env.example`, README, `.github/workflows/ci.yml` |

## P2 checkpoint log

| Checkpoint | Date | Result | Notes |
|---|---|---|---|
| P2.1 Domain architecture | 2026-11-22 | **Reconciled — awaiting stakeholder approval** | Tiered RBAC access, ADR proposed defaults, DCR awaiting approval |
| P2.2 Auth & permissions architecture | 2026-11-22 | **Designed** | `docs/architecture/P2_2_*`; finance/confidential matrix refinements |
| P2.3 Database architecture | 2026-11-22 | **Designed** | `docs/architecture/P2_3_*`; P2-OD-040–042 proposed |
| P2.4 Workflow architecture | 2026-11-22 | **Designed** | `docs/architecture/P2_4_*`; P2-OD-043–048 proposed |
| P2.5 Final architecture review | 2026-11-22 | **Complete — partial approval** | `docs/architecture/P2_5_*` |
| P2.5A Stakeholder decisions | 2026-11-22 | **Enumerated ADRs approved** | Commit `08a5423`; `P2_5A_STAKEHOLDER_DECISION_RECORD.md` |
| P2.5B Phase 2 exit prep | 2026-11-22 | **P2-OD-040–042 approved** | Product owner 2026-11-22; Phase 1 sign-off checklist still open |
| P3-A1 Auth & organisations | 2026-11-22 | **Accepted — merged to `main`** | Super Admin sign-in + staff workspace verified by PO; 46 tests; invitations/RBAC deferred |
| P3-A1 Browser acceptance | 2026-11-22 | **Partial** | **PO verified:** sign-in, staff workspace. **Not agent-verified:** full reset mailbox flow, mobile screenshots, dual-org switch, client portal in browser |
| P3-A1 Gates unchanged | — | **Open** | Phase 1 final design sign-off; ADR-010 confidential storage PoC; A02–A04 invitation UI |
| P3-A1 GitHub push & CI | 2026-11-22 | **Passed** | `main` → `origin/main` at `6328294`; [CI run 45010728775](https://github.com/josephsegbefia/ant_marine/actions/runs/45010728775) (`verify` + `scan_js` success) |
| P3-A2 Invitations & verification | 2026-11-22 | **Accepted — local `main` only** | Staff/client invite, mailer, A02/A03, audit_events, interim `Invitations::Policy`; 70 tests / 258 assertions; **not pushed** |
| P3-A2 Browser acceptance | 2026-11-22 | **Partial — agent verified** | Browser: A02/A03 staff+client @390px; acceptance+replay screens; staff sign-in attempted. PO: full staff UI send flow + client owner portal invite |
| P3-A2 Design Studio A02/A03 | 2026-11-22 | **Substantially aligned** | Shared access layout, navy/teal panel, icon circle, notice, locked email, headings match studio intent; minor copy/CTA differences vs static HTML |
| P3-A2 Security acceptance | 2026-11-22 | **Passed (automated + samples)** | Digest-only storage; GET non-consuming; resend revokes prior token (dev runner); policy matrix tests; `::Invitations` autoload fix for invitation controllers |
| P3-A2 GitHub push & CI | 2026-11-22 | **Passed** | `main` @ `8123f21`; [CI 45018069479](https://github.com/josephsegbefia/ant_marine/actions/runs/45018069479); PO consolidated browser acceptance |
| P3-A2-UX-D Staff sidebar refinement | 2026-11-22 | **Accepted — on GitHub main** | Removed org card; 272px / softer navy; studio SVG icons; mobile drawer/backdrop; published with P3-A2 follow-up |
| P3-A3 Authorization engine | 2026-11-22 | **Complete — local `main` only** | 71 permissions, 13 roles seeded; `EffectivePermissions`, `PermissionGranter`, Pundit, epoch freshness, audit; invitations unchanged or stricter; 124 tests / 507 assertions; docs `P3_A3_AUTHORIZATION.md`; **not pushed** |
| P3-A3 Security & DB acceptance | 2026-11-22 | **GO — on GitHub main** | `eacc00a`; CI [45021921542](https://github.com/josephsegbefia/ant_marine/actions/runs/45021921542) |
| P3-A4 Public / client / admin UI foundations | 2026-11-22 | **On GitHub main** | `b74363c`; CI [45023470217](https://github.com/josephsegbefia/ant_marine/actions/runs/45023470217); 137 tests / 556 assertions. Signed-in C01 desktop/mobile, client drawer, and staff browser regression remain **open**. |
| P3-A5 Jobs, email and notifications | 2026-11-22 | **On GitHub main** | `a980458`; CI [45029141335](https://github.com/josephsegbefia/ant_marine/actions/runs/45029141335); 160 tests / 635 assertions; AES-GCM envelope; fail-closed mail; Puma/Solid Queue isolation fix |
| P3-A5 Final security acceptance | 2026-11-22 | **Published** | 4 commits above `b74363c`; permanent SMTP discard via logs + error reporter (not `failed_executions`); **local `bin/jobs` stable run not verified** in agent session (pg segfault) |
| P3-A6 Secure storage PoC | 2026-11-22 | **Complete — local `main` only** | Active Storage + `EncryptedDisk`; app-side AES-GCM; quarantine scan job; staff proof upload/download; recovery test; `docs/architecture/P3_A6_SECURE_STORAGE.md`; **not pushed** |
| P3-A6 Final security acceptance | 2026-11-22 | **GO — local automated** | Production gate blocks plain `private_s3`/disk; extra storage security tests; **193 tests / 721 assertions**; live ClamAV + live `bin/jobs` **NOT VERIFIED**; ADR-010 production **BLOCKED**; GitHub **NO-GO** until PO |
| P3-A7 Phase 3 exit (local) | 2026-11-22 | **CONDITIONAL GO** | Fork+pg worker mitigations; `/ready`; `EncryptedS3Service` + PoC compose; **3/3 runtime smoke jobs** (`scripts/verify_solid_queue_runtime.sh`); **200 tests / 730 assertions**; MinIO/ClamAV pulls **blocked** on host; authenticated browser matrix **NOT VERIFIED**; **not pushed** |
| P3 final acceptance (local) | 2026-11-23 | **ACCEPTED** | Engineering foundation closed; SeaweedFS + ClamAV PoC verified; **203 / 741** with PoC env; **production deployment NOT AUTHORISED** |
| F4-01A Public content foundation | 2026-11-23 | **Complete — local `main` only** | `services` + `public_site_pages`, staff Website (M02/M03), public routes/SEO/sitemap, draft catalogue seeder; `verify_foundation.sh` pass; docs `F4_01A_PUBLIC_CONTENT.md`; **content publish still PO-blocked**; **not pushed** |
| F4-01A Service draft-save correction | 2026-11-23 | **Code complete — PO browser gate open** | Auto slug, list normalization, snapshot protection, draft vs `:editorial` validation; tests extended; **not pushed** |
| F4-01A Website list UX (M02/M03) | 2026-11-23 | **Code complete — PO browser gate open** | Shared list hub components, single breadcrumb, record cards; integration tests; **not pushed** |
| F4-01B Public marketing content | 2026-11-23 | **Foundation local — PO content gate open** | Articles, case studies, training, resources + staff hub tabs; resource files disabled; **not pushed** |
| F4-01B WYSIWYG editor | 2026-11-23 | **Code complete — PO browser gate open** | Action Text/Trix, draft preview, snapshot HTML, attachments disabled; **not pushed** |
| F4-01B Action Text save + toolbar | 2026-11-23 | **Code complete — PO browser retest** | `ignored_columns` + dev schema refresh; custom toolbar/canvas; create-article regression tests; **not pushed** |
| F4-01B Expanded WYSIWYG toolbar | 2026-11-23 | **Code complete — PO browser retest** | Underline/strike/code/More menu; Trix 2.1.19 extensions; format sanitizer tests; **not pushed** |
| F4-01A Service editor UX | 2026-11-23 | **Delivered — PO visual sign-off pending** | Guided four-step editor + list builders + staff draft preview; Pundit fix `32503c1`; automated suite green; **not pushed** |
| P3 browser acceptance (PO) | 2026-11-23 | **Accepted — PO manual** | All six checks: staff sign-in + **S01**, **M08**, responsive staff nav, dev client invite, **C01**, staff/client separation; authority: Product Owner |
| Phase 3 local engineering | 2026-11-23 | **ACCEPTED** | Ready for controlled `origin/main` publication; **Phase 1 formal sign-off still open** |
| P3-A4 Browser acceptance | 2026-11-23 | **Closed (PO)** | Superseded by P3 browser acceptance row above |
| P3-A2-UX-C Staff workspace shell | 2026-11-22 | **Accepted — on GitHub main** | Studio **S01** `staff_portal` layout; honest team-access card; workspace back/switch rule |
| P3-A2-UX-B Back navigation | 2026-11-22 | **Ready for PO sign-off — local only** | `ant_back_link`; studio A05/P19–P21 outline+left; staff/client invitations + A05 password flows; see UI guide |
| P3-A2-UX Shared UI & notifications | 2026-11-22 | **Accepted (local)** | `AntUiHelper`, `custom-select`, `toast-stack`, `form-submit`; studios A01/M08; **83 tests / 351 assertions**; see [`docs/ui/SHARED_UI_COMPONENTS.md`](ui/SHARED_UI_COMPONENTS.md) |
| P3-A2 UI & data integrity correction | 2026-11-22 | **Accepted (local)** | Design Studio **M08** split layout (recent list + invite form), **M07** admin nav pattern; portal layout for staff/client; `RoleLabels` for roles/statuses; dev cleanup of acceptance rows (4 invitations, 1 user, 1 org, 7 audit events); **77 tests / 299 assertions** |
| P3-A2 Synthetic data finding | 2026-11-22 | **Resolved (dev)** | Test-looking rows were **development DB records** from P3-A2 `rails runner`/browser acceptance—not hardcoded views. Removed by ID after inventory. **Retained:** `elsegbefia@gmail.com`, `browser-test@example.com`, `you@example.com` super admins (not removed without PO direction). |
| P3-A2 Browser acceptance (correction) | 2026-11-22 | **Partial** | Integration tests cover HTML labels/empty state; live browser @1440/390 requires PO/super-admin sign-in (credentials not in repo). Restart `bin/dev` after pull for new Tailwind. |
| P3-A2 Gates unchanged | — | **Open** | Phase 1 sign-off; ADR-010 storage; MFA A04; full M08 app shell/sidebar (deferred); production SMTP |

## Local development quick reference

Paths assume project root containing `Gemfile` (e.g. `~/Desktop/elorm/appsentrix/ant_marine`). Credentials: copy `.env.example` → `.env.local` (gitignored).

### Start PostgreSQL

```bash
docker compose --env-file .env.local -f compose.dev.yml up -d db
docker inspect -f 'health={{.State.Health.Status}}' ant_marine_postgres_dev
```

### Stop PostgreSQL (keep data)

```bash
docker compose --env-file .env.local -f compose.dev.yml stop db
```

Do **not** use `docker compose down -v` (deletes volume `ant_marine_local_pg`).

### Load environment

```bash
set -a && source .env.local && set +a
```

### Foundation verification

```bash
bash scripts/verify_foundation.sh
```

See `README.md` for Rails server and full setup links.

### Troubleshooting database connections

| Symptom | Likely cause | Fix |
|---|---|---|
| `connection refused` | DB container stopped | `docker compose --env-file .env.local -f compose.dev.yml up -d db` |
| `password authentication failed` | `.env.local` out of sync with container | Align `ANT_MARINE_DB_PASSWORD`; avoid recreating volume unless intended |
| `KeyError: ANT_MARINE_DB_PASSWORD` | Env not loaded | `source .env.local` before Rails |
| Wrong Ruby | System Ruby used | `mise exec --` or `verify_foundation.sh` |

Update dates and links as gates complete.