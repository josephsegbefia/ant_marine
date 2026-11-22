# ANT Marine W.A. — Master Product & Engineering Specification

**Specification ID:** ANT-MARINE-SPEC-001  
**Version:** 0.1 — pre-implementation baseline  
**Prepared:** 22 November 2026  
**Implementation:** Ruby on Rails + Hotwire + Stimulus (one Rails application)  
**Current gate:** Phase 1 prototype delivered; formal stakeholder design approval pending  
**Status convention:** `[REQUIRED]` = questionnaire or essential engineering requirement; `[PROPOSED]` = recommended decision to confirm; `[LATER]` = not an MVP prerequisite; `[OPEN]` = unresolved business decision.

## 0. How to use this specification

This is the working source of truth for Cursor AI agents. **Read this file, `AGENTS.md`, `design/PHASE_1_DESIGN_HANDOFF.md`, and the relevant screen in `design/ANT_Marine_Design_Studio_Phase_1.html` before modifying any related feature.** The HTML is an interactive visual blueprint, not an implemented product.

Source hierarchy:
1. Explicit, approved business decisions and acceptance criteria in this spec.
2. The original `design/ORIGINAL_QUESTIONNAIRE.docx` for the client's stated business objectives, audiences and service catalogue.
3. The reviewed/approved Phase 1 design studio and exported design reviews for layout, journeys and user-facing copy.
4. Engineering conventions in `AGENTS.md` and `.cursor/rules`.

If sources conflict, **do not silently guess**: document the discrepancy and propose a bounded decision. Illustrative sample names, dates, figures, photos and projects in the prototype are **not** authorised public claims.

### Product promise

An approachable maritime consultancy website and service-delivery platform serving prospective clients, corporate clients and ANT Marine staff: **discover → inquire → quote → confirm → perform work → review → release reports → bill/archive**.

### Product outcomes from questionnaire (6–12 months after launch)

- Increase monthly qualified inquiries by 30% versus email-only baseline.
- Process at least 50% of service bookings online.
- Reduce average time from client upload to final report by 25%.
- Aim for top-five search placement for selected West African maritime consulting terms (goal, not a guarantee).
- Publish 10 pieces of knowledge-centre content and achieve 200+ technical-resource downloads.

The operational dashboard must record baseline period, event timestamps, numerator/denominator, channel attribution, and trends; don't present hypothetical values as real.

## 1. Audiences and surfaces

| Surface | Who | Primary actions |
|---|---|---|
| Public website | Prospective clients, industry partners, training participants | Browse services/credentials, publications, approved case studies, contact ANT Marine, request a quotation or preferred booking date |
| Corporate client portal | Authorized people at client organizations | Follow inquiries, review quotations, view project progress, upload files, message team, obtain approved reports and invoices |
| Staff workspace | Surveyors, project coordinators, reviewers and finance team | Qualify inquiries, quote, schedule, assign work, inspect, review reports, send approved documents, bill |
| Administration | Authorized ANT Marine admins, content owners, security administrators | Publish reviewed content, manage users, access, document rules, audit records and business metrics |

**Client isolation:** The client company/organization is the security boundary. A member must not access records or files belonging to another client company without a separately authorized relationship. Some staff may be assigned to only a subset of client jobs.

### Geographic and service scope

Primary focus: Ghana and West Africa; clients include oil and gas operators, shipowners, terminals, EPC contractors, classification/certification bodies, and research/environmental organizations. Service content must cover Marine Warranty Surveys, incident and damage investigations, on-/off-hire and pre-purchase surveys, ship-in-service/drydock management, internal audits (ISM, MLC, ISPS), marine environmental assessments, naval design/modification and retrofit support, technical reporting, and training. Verify specialist standards, affiliations and client names before public display.

**Remote Monitoring & Data Analytics** is a service interest with no confirmed ingestion sources or dashboard requirements: show an informative service/inquiry page only until discovery approves a separate scope.

## 2. Product modules & key functional requirements

### 2.1 Public website [REQUIRED]

- Homepage, About, leadership and verified credentials, contact, services index and individual service detail pages.
- Target-industry pages, geographic reach, approved portfolio/case studies, training, news/insights, publications and downloadable resources.
- Plain-English service explanations and clear `Request a quote` / `Request a visit` actions; no account prerequisite for an initial inquiry.
- Server-rendered SEO metadata, canonical URLs, sitemap, accessible navigation, social preview metadata and structured data where warranted.
- Content approval/publish workflow; track public resource downloads without exposing confidential files.

### 2.2 Inquiry, quotation and booking [REQUIRED]

- Step-by-step inquiry form: service, company, contact, email/phone, location, need, preferred date, optional files, review, confirmation/reference.
- Service-specific questions shown progressively; support validation, saved form progress where feasible and failure/retry copy.
- Staff queue: assign owner, request clarification, distinguish unqualified/qualified, decide next action.
- Quotation: scope, deliverables, exclusions, proposed fee/currency, validity, revisions, send/withdraw, accept/decline with time and authorized actor.
- Booking: requested date is **not** a confirmed appointment; staff explicitly confirms availability, project scope and assignment.
- Accepted quotes turn into projects **only** after configured approvals and verification; prevent duplicates from retries or repeated button clicks.
- [OPEN] Payment/deposit policy, cancellation/rescheduling rules. **Proposed defaults (pending approval):** ADR-014 public inquiry without account; ADR-005 invitation-based portal; ADR-006 quote acceptance by owner or authorised member (`quotes.accept`).

### 2.3 Client portal [REQUIRED]

- Invitation-led initial access [PROPOSED default — ADR-005; pending approval]; authentication, account recovery, secure sessions and extra verification for sensitive actions.
- Dashboard showing requests, projects, action-needed items, reports and helpful notifications.
- Readable project status timeline: `Received → Planning → Site work → Review → Report ready`; internal stages may be more precise, but public labels remain simple.
- Secure upload requests with requested file type and reason; file lists and previews; project messages; outstanding actions.
- Approved report visibility only **after explicit release**, with version, timestamp, downloads and release history; invoices and archive.
- Optional high-value: client vessel registry and reusable authorized vessel records [PROPOSED].

### 2.4 Staff operations [REQUIRED]

- Staff overview and work queue; request triage; quote preparation/approval; confirmation and scheduling; projects, assignments and task deadlines.
- Inspection checklists, report drafts and revisions, internal notes, client messages and document requests.
- Report approval separated from report release: surveyor drafts; authorized reviewer approves; authorized releaser confirms recipient and exact approved version.
- Invoice creation and payment-status records (do not assume live collection); finance permissions; audit history.
- Prevent unauthorized actions, stale updates, duplicate release and cross-organization access.

### 2.5 Administration and content [REQUIRED]

- Services, website sections, articles, project stories, training catalogue; draft → review → publish with editable SEO metadata.
- User invitations, roles and project access; notifications; company settings; archive/retention and audit history.
- Analytics for questionnaire metrics, monthly inquiry qualification, bookings, turnaround and resource downloads.

### 2.6 Document management [REQUIRED]

Treat **document records** as distinct from **stored blobs**.
- Organize by company, project, vessel, document category and access classification.
- Preserve immutable file revision history: filename, uploader, checksum, type, size, uploaded/approved/released timestamps and review decision.
- State machine: `pending_upload → scanning → available` or `rejected`; business workflow `working_draft → submitted → changes_requested → approved → released → archived`.
- Permission evaluation **before** preview, download, list, upload, release or share; no publicly accessible client bucket.
- Malware scan/quarantine; accepted file types and size limits; preview only safe formats; audit access and release.
- Storage: Rails Active Storage with private S3-compatible Hetzner Object Storage [PROPOSED]; secrets not committed; HTTPS enforced.
- **Security caveat:** Hetzner Object Storage objects are not encrypted at rest by default. Before real confidential uploads, design and test supported client-side/SSE-C encryption and key custody; ensure browser upload strategy works with the selected encryption approach. Never claim encrypted storage until verified.
- Backups must include database **and object copies** in separate recovery locations; object versioning is not a substitute for backup. Test restoration.
- [OPEN] Legal/contractual retention rules, file-size policy, client download expiry, residency, encryption strategy, RPO/RTO, offsite backup vendor.

### 2.7 Cross-cutting requirements [REQUIRED]

- Keyboard-accessible, responsive (desktop/tablet/phone) interface; visibly labeled inputs; reduced-motion support; 44px minimum practical touch targets.
- Simple everyday English for interface copy, including validation, emails and alerts; maritime specialist terminology only when the service requires it.
- Status and email notifications idempotent and deliverable; don't promise instantaneous delivery from an external email provider.
- Effective authorization and CSRF protection; secure cookies; login throttles; signed expiring file-access actions; audit significant writes.
- Sensitive personal/project information excluded from analytics and application logs. Never embed secrets or sample client personal data in Git.
- Structured errors, resilient background tasks, retry policy for external delivery, alerts and monitoring.
- Tests for all user-facing journeys and denial scenarios. No AI agent may mark work done without evidence of its tests and a review of changed files.

## 3. Rails architecture (architectural decisions)

**One modular Rails monolith.** Do not build separate React/Next.js frontend, Express backend, GraphQL gateway, microservices or parallel auth system unless the spec is formally revised.

- Rails 8.1 stable patch, Ruby 3.4.x supported release (pin installed patch in repo), Rails ERB templates/partials and optional ViewComponent only when helpful.
- Hotwire Turbo Drive, Frames, Streams and Stimulus controllers. Favor server-side form objects, validation and readable controller actions. Avoid hand-built JS app-state framework.
- Tailwind CSS via `tailwindcss-rails` v4, Propshaft, Importmap (no mandatory Node build chain). Icons: consistent inline SVG helper/icon library with accessible labels.
- PostgreSQL for primary operational data. Models: `Organization`, `Membership`, `User`, `ClientContact`, `Vessel`, `Service`, `ServiceRequest`, `Quote`, `QuoteRevision`, `Booking`, `Project`, `Assignment`, `Task`, `Inspection`, `InspectionChecklist`, `Document`, `DocumentVersion`, `Report`, `ReportReview`, `ReportRelease`, `Invoice`, `PaymentRecord`, `Notification`, `Conversation`, `Message`, `ContentPage`, `Article`, `CaseStudy`, `TrainingOffering`, `AuditEvent`. These are **proposed domain concepts**, not a mandate to generate every model at once.
- Rails-native auth generator [preferred for evaluation], account invitations, session security; Pundit policy gem [proposed]. Never assume authentication equals authorization.
- Action Mailer with configured transactional delivery, Active Job/Solid Queue, Solid Cache and Solid Cable as appropriate. Worker process must be defined and monitored separately in production.
- Active Storage private object store. Avoid storing production files on ephemeral application disks or exposed public web directories.
- Architecture boundaries: public site, client area, operations, admin; share domain models but isolate controllers, policies and views by context. Complex domain transitions should occur through narrow service operations and database transactions.
- Database migrations must be reversible where feasible, reviewed and safe with existing data. Use DB constraints/indexes to enforce uniqueness and consistency.
- Developer test stack: Minitest, Rails integration/system tests, fixtures/factories as project decides, RuboCop, Brakeman, dependency audit. CI must test from clean installation.

### 3.1 Configurable role & permission system [REQUIRED]

ANT Marine **must** ship a **configurable RBAC** system with two strictly separated domains:

- **ANT Marine staff** (`Organization.kind = ant_marine`)
- **Client organisations** (`Organization.kind = client`)

**Staff default roles:** Super Administrator, Operations Manager, Project Coordinator, Surveyor / Consultant, Technical Reviewer, Finance Officer, Content Manager, General Staff.

**Client default roles:** Organisation Owner, Organisation Administrator, Client Manager, Client Member, Client Finance.

A Client Organisation Owner is **never** equivalent to a Super Administrator. Client users **cannot** acquire staff permissions through roles or custom grants.

**Authoritative architecture documents:**

- [`docs/architecture/ROLE_PERMISSION_SPEC.md`](architecture/ROLE_PERMISSION_SPEC.md) — domains, resolution hierarchy, admin authority, project-level rules, sensitive operations, audit, Rails approach.
- [`docs/architecture/PERMISSION_CATALOGUE.md`](architecture/PERMISSION_CATALOGUE.md) — stable internal keys, plain-English labels, categories, override rules.
- [`docs/architecture/DEFAULT_ROLE_MATRIX.md`](architecture/DEFAULT_ROLE_MATRIX.md) — default grants per role.

**Permission resolution (summary):** protected restrictions → organisation/resource boundaries → explicit user deny → explicit user grant → role defaults → deny. Permission changes take effect on the next request without requiring logout.

**UI [REQUIRED]:** Dedicated **Team & Permissions** pages in staff and client portals (Phase 4); Phase 1 design change request in [`docs/design/PHASE_1_DESIGN_CHANGE_REQUEST_TEAM_PERMISSIONS.md`](design/PHASE_1_DESIGN_CHANGE_REQUEST_TEAM_PERMISSIONS.md) — **do not** alter the approved HTML studio until that request is signed off.

**Enforcement:** Server-side on every action. **Two layers:** feature permission (catalogue key) **and** resource scope (org-wide staff oversight, project `Assignment`, client org boundary, confidential classification, report release). See [`ROLE_PERMISSION_SPEC.md`](architecture/ROLE_PERMISSION_SPEC.md) §5. Denial tests are required for cross-organisation access, direct URLs, report approve/release separation, and permission revocation on the next request.

**Public visitors** have no membership; they may only access published content and anonymous inquiry endpoints.

### 3.2 Data & event design principles

- UTC timestamps in persistence, display Ghana time (and client local zone if configured); no inferred project dates.
- Human-readable reference numbers generated server-side with database uniqueness.
- Separate status/history events from an editable `current_status`; record actor, prior/new state, time, business reason.
- All major transitions idempotent, authorization checked inside operation, and background email enqueued after durable commit.
- File and report release uses a controlled association to **approved exact version**, not a mutable document pointer.
- Prefer explicit active/inactive statuses and soft archive over destructive deletes when retention is required.

## 4. Five phases, execution responsibilities and exit gates

### PHASE 1 — UX/UI Design & Prototyping
**Status:** Delivered for review; sign-off pending. **Owner:** design reviewer / product owner.

Responsibilities: interactive design system, public/client/staff/admin screens, responsive previews, full service journeys, states, accessible copy, review notes and exportable approval record. Includes 104 screen entries in the HTML studio.

**Exit:** Stakeholders approve essential journeys and language; reconcile screen changes; save approved HTML snapshot and review JSON. Reference `design/PHASE_1_DESIGN_HANDOFF.md`.

### PHASE 2 — Domain, Database, Workflow & Authorization Architecture
**Status:** In progress — P2.1 domain + RBAC **reconciled**; stakeholder approval pending on ADR proposed defaults and Team & Permissions DCR. **Owner:** Rails architecture agent; product owner approves decisions.

Deliverables:
- Entity relationship map, primary/foreign keys, tenancy strategy, unique constraints, soft delete/retention rules and PostgreSQL migration sequence.
- State machines and guards: inquiry, quote, booking, job, task, document, report, invoice.
- **Permission architecture:** staff and client role inventories, full permission catalogue, default role matrix, resolution hierarchy, project-level access rules, sensitive-operation safeguards, audit fields ([`docs/architecture/ROLE_PERMISSION_SPEC.md`](architecture/ROLE_PERMISSION_SPEC.md) and companions).
- **Authentication & authorization (P2.2):** [`P2_2_AUTHENTICATION_ARCHITECTURE.md`](architecture/P2_2_AUTHENTICATION_ARCHITECTURE.md), [`P2_2_AUTHORIZATION_ARCHITECTURE.md`](architecture/P2_2_AUTHORIZATION_ARCHITECTURE.md), [`P2_2_SECURITY_THREAT_MODEL.md`](architecture/P2_2_SECURITY_THREAT_MODEL.md), [`P2_2_DATABASE_HANDOFF.md`](architecture/P2_2_DATABASE_HANDOFF.md).
- **Database architecture (P2.3):** [`P2_3_DATABASE_ARCHITECTURE.md`](architecture/P2_3_DATABASE_ARCHITECTURE.md), [`P2_3_SCHEMA_CATALOGUE.md`](architecture/P2_3_SCHEMA_CATALOGUE.md), [`P2_3_RELATIONSHIP_DIAGRAMS.md`](architecture/P2_3_RELATIONSHIP_DIAGRAMS.md), [`P2_3_MIGRATION_PLAN.md`](architecture/P2_3_MIGRATION_PLAN.md), [`P2_3_DATA_INTEGRITY_SECURITY.md`](architecture/P2_3_DATA_INTEGRITY_SECURITY.md).
- **Workflow architecture (P2.4):** [`P2_4_WORKFLOW_ARCHITECTURE.md`](architecture/P2_4_WORKFLOW_ARCHITECTURE.md), [`P2_4_STATE_TRANSITIONS.md`](architecture/P2_4_STATE_TRANSITIONS.md), [`P2_4_AUTHORIZATION_WORKFLOW_MATRIX.md`](architecture/P2_4_AUTHORIZATION_WORKFLOW_MATRIX.md), [`P2_4_EVENTS_AND_CONCURRENCY.md`](architecture/P2_4_EVENTS_AND_CONCURRENCY.md), [`P2_4_OPEN_DECISIONS.md`](architecture/P2_4_OPEN_DECISIONS.md).
- Threat model for privilege escalation and cross-organisation leakage.
- Project structure, modules, navigation routes, view patterns, notification/event catalogue and job requirements.
- Document storage security architecture, encryption feasibility proof-of-concept, backups and disaster-recovery assumptions.
- Slice-by-slice acceptance tests traced to actual design screens and permission keys.

**Exit:** Reviewed domain diagram and data dictionary, **approved permission catalogue and default matrix**, threat model, approved decisions in `docs/DECISIONS.md`, migration/implementation backlog. **Do not generate all models before approval.**

### PHASE 3 — Rails Foundation & Development Infrastructure
**Status:** Not started. **Owner:** Rails foundation agent + infrastructure reviewer.

Deliverables:
- Rails 8.1/PostgreSQL/Hotwire/Tailwind/Stimulus baseline, Solid Queue/Cable/Cache configured to fit chosen topology, secure Rails authentication, invitations and **permission infrastructure**.
- **Authorization foundation (before business feature slices):** seeded permission catalogue, role-permission joins, membership overrides, `EffectivePermissions` resolution, Pundit (or equivalent) policies with deny-by-default, permission-change audit, cache/version invalidation on grant/revoke.
- Design tokens, layout shells for public/client/staff/admin, shared components, icon helper and consistent messages.
- Local Docker PostgreSQL, `.env` templates with no secrets, CI, unit/integration/system test harness, lint/security checks, seed demo and health checks.
- Active Storage private bucket integration proof-of-concept, protected previews, quarantine pathway and sample backup restore verification.
- Production-ready Dockerfile with separate web/worker commands, configuration contracts for Coolify/Hetzner/Cloudflare; staging isolated from production.

**Exit:** Fresh clone passes boot, migrations, tests, audit, assets, responsive shell smoke tests, **permission enforcement and cross-org denial tests**, role-isolation checks and encrypted-storage acceptance gate. **No real private files until storage gate passes.**

### PHASE 4 — Functional Implementation (vertical slices)
**Status:** Not started. **Owner:** feature agents; reviewer validates each merged slice.

Recommended sequence:
- `F4-01` Public site and content management; verified services, about, contact, cases, resources, training.
- `F4-02` Anonymous quote/visit request, validation, attachments, confirmation and anti-abuse controls.
- `F4-03` Staff intake queue, client records, qualification and quotation/version/acceptance workflow.
- `F4-04` Organization invitations, client home, requests, project creation and staff assignment; **permission UI not required until `F4-04b` or dedicated slice below**.
- `F4-04b` **Team & Permissions** (staff M07a–j and client C15a–j per design change request): invite, role change, grouped permission edits, effective access, history, sensitive confirmations.
- `F4-05` Project milestones, task lists, status notifications, messages and schedules.
- `F4-06` Secure document repository, requested uploads, version history, previews, access history.
- `F4-07` Inspection checklists, report draft/review/approval, separate final release and client download.
- `F4-08` Billing records, invoices, organization history, analytics, reporting and admin controls.
- `F4-09` Mobile responsiveness, empty/error/loading states, accessibility and holistic polish for all flows.

For each slice: implement routes/models/views/jobs/policies, domain/integration/system tests, failure/denial tests, migrations, UI screenshots or browser acceptance, and a short completion report. No fake-success buttons are allowed in production.

**Exit:** Essential end-to-end flow works for public, client, surveyor, reviewer, finance and admin, with an independently tested denied-access flow; **Team & Permissions** management verified for staff and client owners; success metrics are instrumented.

### PHASE 5 — Deployment, Hardening, Acceptance & Launch
**Status:** Not started. **Owner:** infrastructure/operations agent; product owner authorizes release.

Deliverables:
- Separate Hetzner production environment, Coolify deployments of web/worker/PostgreSQL, Cloudflare DNS/TLS/WAF with correct origin restrictions.
- Private object storage, documented encryption/key management, staged backups, restoration tests, secrets rotation, monitored workers/queues, health/error/log alerts.
- Staging acceptance across roles, **privilege-escalation and organisation-isolation acceptance tests**, load tests for large uploads/reports, accessibility checks, SEO checks, security review, incident/runbook and rollback.
- Content approval: business registration claims, certifications/partnerships, portfolio permissions, contact details and policy pages; training copy and live email templates.
- Launch checklist, baseline analytics, operation owner and post-launch monitoring.

**Exit:** Demonstrated recovery from a backup; no high-risk permission/security issues; signed acceptance checklist; production launch decision recorded.

### Preflight B0 — Setup before Phase 2 (not a sixth phase)

Set up the local development toolchain and create a **minimal bootable Rails shell only**. Keep database/domain modeling inside Phase 2. Use `docs/SETUP_AND_BOOTSTRAP.md` and `scripts/bootstrap_macos.sh` as the safe starting point.

## 5. Cursor AI working agreement

1. Agent starts by restating target phase/slice, screens, expected changes and acceptance tests.
2. Inspect existing repository and the blueprint before changes. Never replace user work or rewrite all pages without agreement.
3. Implement **one vertical slice** at a time, grouping only tightly coupled tasks. Keep sensitive/report/payment boundaries as separate review gates.
4. Prefer Rails defaults; no axios, no SPA, no external state manager, no speculative integrations.
5. Do not run production database migrations, modify live Cloudflare/Coolify settings, pay for services or send real email/SMS without explicit instruction.
6. Show commands and actual pass/fail outcomes. If unrun, clearly say `not run`.
7. Produce a completion note: files changed, design screens matched, migrations, security review, checks passed, remaining risks, next slice.
8. Track uncertainties and decisions; don't disguise inferred behavior as a questionnaire requirement.

## 6. Scope exclusions for initial release

No live ship telemetry/remote monitoring dashboard, automatic professional engineering conclusions, AI-generated unattended inspections, native iOS/Android app, live client payments without approved commercial requirements, or separate multi-service architecture. These require discovery/explicit authorization.

## 7. Open decisions to resolve in Phase 2

- Client accounts invitation-only or self-signup; which roles may accept quotes and add colleagues — **see ADR-005, ADR-006, ADR-014, ADR-016 (proposed defaults, not approved)**.
- Roles for technical approval versus report release; escalation/delegation and audit expectations.
- Official service catalogue/detail wording; publication rights for names, images and accreditation claims.
- Preferred-date booking policy, quotation validity/currency, deposits, payments, cancellation/refunds.
- File size/type ceilings, malware scanner, document preview rules, encryption mechanics, storage region, retention, separate backups and RPO/RTO.
- Notification channels and exact Action Mailer delivery provider.
- Whether vessel registry is MVP or follow-on; whether technical report templates are needed in first release.

## 8. Traceability / source and design references

- Original questionnaire: `design/ORIGINAL_QUESTIONNAIRE.docx`.
- Phase 1 interactive HTML: `design/ANT_Marine_Design_Studio_Phase_1.html`.
- Screen inventory and journeys: `design/PHASE_1_DESIGN_HANDOFF.md`.
- Setup instructions: `docs/SETUP_AND_BOOTSTRAP.md`.
- Architecture decision register: `docs/DECISIONS.md` (starter ADRs present; mark `APPROVED` during Phase 2).
- Role & permission architecture: `docs/architecture/ROLE_PERMISSION_SPEC.md`, `PERMISSION_CATALOGUE.md`, `DEFAULT_ROLE_MATRIX.md`.
- Phase 1 Team & Permissions UI change request: `docs/design/PHASE_1_DESIGN_CHANGE_REQUEST_TEAM_PERMISSIONS.md`.

External technology references (re-check before implementation):
- Rails guides: https://guides.rubyonrails.org/
- Cursor project rules: https://cursor.com/docs/rules
- Tailwind Rails integration: https://github.com/rails/tailwindcss-rails
- Hetzner object storage docs: https://docs.hetzner.com/storage/object-storage/
- Coolify docs: https://coolify.io/docs
