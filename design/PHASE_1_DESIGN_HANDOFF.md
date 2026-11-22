# ANT Marine W.A. — Phase 1 Design Handoff

**Status:** Interactive concept prototype; ready for stakeholder review, not final sign-off.

## What this blueprint contains

- **104 designed screen entries** across public website, access, client portal, staff operations, company settings, mobile layouts, and shared states.
- A self-contained, offline HTML design studio with searchable pages, single and gallery views, full-size previews, simulated journeys, screen specifications, approval statuses, notes, and JSON review import/export.
- Desktop frame: 1440 × 900. Phone frame: 390 × 844.
- Example data only. No real account access, bookings, uploads, messages, payments or report releases.

## Design direction

- Deep navy `#102C43`, muted teal `#25877F`, blue `#4A7F9A`, sky `#EAF4F7`, warm sand `#F8F4ED`, pale canvas `#F6F8F8`.
- Serif-like editorial headings, clear system sans-serif body, generous spacing, rounded cards, subtle borders and shadows.
- Soft hover movement, loading shimmer and short screen transitions; respect reduced-motion preference.
- User-facing labels in everyday English; retain recognised maritime service terms only where necessary.
- 44px touch targets, keyboard focus indicators, field labels, understandable error/empty states.

## Core journeys and their screen IDs

1. Public inquiry: `P01` → `P02` → appropriate service detail (`P03`–`P08`) → `P19` → `P20` → `P21` → `P22`.
2. Client quotation: `C01` → `C02` → `C03` → `C04`; accepting a quote should require clear consent and create a confirmed job only after the real business checks.
3. Client project: `C05` → `C06` → `C07`/`C08` → `C09` or `C10`; final report `C11` → `C12`.
4. Staff intake: `S01` → `S02` → `S03` → `S04` → `S05`; scheduling in `S06` and `S21`.
5. Staff delivery: `S07` → `S08` → `S09` → `S10`/`S11` → `S12` → `S13` → `S14`.
6. Administration: `M01`–`M14` include content, users, document rules, notices, analytics and record history.

## Implementation mapping

- **Rails full stack:** Rails views + Hotwire Turbo + Stimulus. Avoid inventing separate frontend services without compelling requirements.
- **Database:** PostgreSQL for businesses, memberships, enquiries, quotations, projects, assignments, vessels, reports, invoices, notifications and audited actions.
- **Jobs and messaging:** Solid Queue and Action Mailer. Status changes should be clear and reliable; do not imply GPS tracking.
- **Files:** Active Storage with private S3-compatible object storage. Design document records and revisions independently from raw attachments.
- **Authorization:** every file and project access must be checked server-side against company, membership, role and project assignment.
- **Report workflow:** draft → review → approval → separate release confirmation; record versions, reviewer, decision, recipient and time.
- **Operations:** deploy independently on Hetzner/Coolify with Cloudflare, backups, secure file handling and monitored jobs.

## Business decisions requiring confirmation

- Whether clients join only by invitation after confirmed work; authentication choices and which client roles can invite colleagues.
- Booking confirmations versus preferred-date requests, quotation approvals, invoice/payment expectations and allowed staff permissions.
- Report creation method, file limits and types, storage region, encryption, retention duration, recovery objectives and exact publication permissions.
- Approved company details, real project evidence, training dates, contact channels, exact service catalogue and claims of accreditation or partnerships.
- Remote Monitoring & Data Analytics is listed as a possible service but does not have enough detail for an interactive monitoring product.

## Screen inventory

### Design guide (4 screens)

- **G01 — Welcome & product map:** See the full ANT Marine experience and choose where to start. Main action: Explore website.
- **G02 — Colors, type & components:** Keep every screen visually consistent and easy to use. Main action: Browse screens.
- **G03 — End-to-end service journey:** Understand the steps from the first inquiry to final report delivery. Main action: Start with quote.
- **G04 — Navigation & writing rules:** Explain how visitors and staff move through the experience. Main action: Browse public pages.

### Public website (24 screens)

- **P01 — Homepage:** Introduce the company and help visitors find the right service. Main action: Request a quote.
- **P02 — All services:** Let visitors browse the full range of marine support. Main action: Explore a service.
- **P03 — Marine surveys:** Explain inspections, marine warranty surveys and vessel checks. Main action: Request this service.
- **P04 — Project support:** Explain drydock, marine project and technical management services. Main action: Request this service.
- **P05 — Environmental & safety checks:** Explain environmental reviews, internal audits and compliance support. Main action: Request this service.
- **P06 — Naval design & modifications:** Explain naval design, retrofits and modifications. Main action: Request this service.
- **P07 — Technical reports:** Explain documentation and technical reporting services. Main action: Request this service.
- **P08 — Training:** Introduce professional marine training services. Main action: See training options.
- **P09 — Industries we serve:** Make it easy for industry-specific visitors to recognise relevant expertise. Main action: Request a quote.
- **P10 — Projects & experience:** Show permission-cleared project examples and capabilities. Main action: View a project.
- **P11 — Project story:** Explain the work, challenges and outcome for one approved example. Main action: Discuss a similar project.
- **P12 — About ANT Marine:** Present the company, leadership, credentials and geographic reach. Main action: Get in touch.
- **P13 — Insights & updates:** Share useful maritime news, advice and company perspectives. Main action: Read an article.
- **P14 — Insight article:** Let readers explore one publication and related services. Main action: Ask a question.
- **P15 — Resources & downloads:** Offer approved technical guides and downloadable resources. Main action: View resource.
- **P16 — Training sessions:** Show available sessions and group training options. Main action: View training.
- **P17 — Training details:** Explain course content, intended audience and registration. Main action: Ask about training.
- **P18 — Contact:** Give visitors an easy way to reach ANT Marine. Main action: Send message.
- **P19 — Quote — your details:** Collect a prospective client’s contact details without forcing account creation. Main action: Continue.
- **P20 — Quote — project details:** Collect relevant project needs and optional supporting files. Main action: Review request.
- **P21 — Quote — review & send:** Help visitors check and correct their request. Main action: Send request.
- **P22 — Request received:** Confirm safe receipt, reference number and expected next step. Main action: Back to home.
- **P23 — Book a visit:** Let visitors request a preferred date, subject to confirmation. Main action: Send booking request.
- **P24 — Privacy & information:** Explain how contact details and uploaded files will be handled. Main action: Go to contact.

### Access (6 screens)

- **A01 — Sign in:** Give existing clients and staff a secure route to their account. Main action: Sign in.
- **A02 — Accept invitation:** Help a new member join the correct company account. Main action: Continue.
- **A03 — Set up account:** Collect a name and password during invitation acceptance. Main action: Continue.
- **A04 — Confirm it’s you:** Enter a one-time code for additional account protection. Main action: Confirm.
- **A05 — Reset password:** Let users regain account access without contacting staff. Main action: Send reset link.
- **A06 — Choose workspace:** Help a person with multiple permitted memberships choose the right account. Main action: Open workspace.

### Client portal (20 screens)

- **C01 — Client home:** Give clients a simple overview of current work and actions. Main action: Request a service.
- **C02 — My requests:** View past and current service requests. Main action: New request.
- **C03 — Request details:** See what ANT Marine has received and any follow-up questions. Main action: Review quote.
- **C04 — Review a quotation:** Read a service quote, ask questions and accept it. Main action: Accept quote.
- **C05 — My projects:** Browse confirmed and completed jobs. Main action: Open a project.
- **C06 — Project overview:** See the current stage, important dates and next steps. Main action: See files needed.
- **C07 — Files we need:** Upload missing information requested by the assigned team. Main action: Upload files.
- **C08 — Documents & files:** Find shared documents and upload project materials. Main action: Upload file.
- **C09 — Document preview:** Preview allowed documents and view version history. Main action: Download.
- **C10 — Project messages:** Keep project questions and replies together. Main action: Send message.
- **C11 — My reports:** Find approved final reports for completed or ongoing work. Main action: Open report.
- **C12 — Final report:** Preview the approved report and related downloads. Main action: Download report.
- **C13 — Bills & payments:** Show invoices and amounts due without assuming online payments are live. Main action: View bill.
- **C14 — Bill details:** Show a readable invoice with an option to download it. Main action: Download bill.
- **C15 — My company & team:** View permitted colleagues and request team changes. Main action: Invite a colleague.
- **C16 — My account:** Update profile details, password and alerts. Main action: Save changes.
- **C17 — Updates & reminders:** Show recent project changes and action requests. Main action: Open update.
- **C18 — My vessels:** Reuse vessel information across repeat jobs. Main action: Add vessel.
- **C19 — Vessel details:** Show a vessel profile, associated files and previous jobs. Main action: Request inspection.
- **C20 — Help & support:** Help clients find answers or contact the ANT Marine team. Main action: Send question.

### Staff workspace (23 screens)

- **S01 — Team overview:** Show today’s requests, assignments and urgent tasks. Main action: View requests.
- **S02 — Incoming requests:** Review, filter and follow up on new inquiries. Main action: Open request.
- **S03 — Request details:** Qualify the inquiry and decide what happens next. Main action: Prepare quote.
- **S04 — Prepare quotation:** Create a clear service quote and scope of work. Main action: Review quotation.
- **S05 — Quotes & decisions:** Track draft, sent, accepted and declined quotes. Main action: View quote.
- **S06 — Booking calendar:** Coordinate preferred dates, bookings and survey schedules. Main action: New booking.
- **S07 — All jobs:** See active, upcoming and completed projects. Main action: Open job.
- **S08 — Job overview:** Manage the assignment and communicate progress. Main action: Assign team.
- **S09 — Assign team:** Choose responsible staff and deadlines. Main action: Save assignment.
- **S10 — Inspection checklist:** Record structured field observations and task completion. Main action: Save checklist.
- **S11 — Job documents:** Organise received files and staff-only working documents. Main action: Upload document.
- **S12 — Reports to review:** Find drafts awaiting technical review and final release. Main action: Review report.
- **S13 — Review report:** Check report versions, add comments and approve or request edits. Main action: Approve report.
- **S14 — Release final report:** Confirm the right report and recipient before client release. Main action: Release to client.
- **S15 — My tasks:** Organise daily work, deadlines and responsibilities. Main action: Open task.
- **S16 — Client directory:** View client organisations and their active engagements. Main action: Open client.
- **S17 — Client profile:** See company contacts, vessels, requests and project history. Main action: View projects.
- **S18 — Vessel register:** Find vessel records for assignments and repeat inspections. Main action: View vessel.
- **S19 — Bills & balances:** Track invoices and outstanding amounts. Main action: Create bill.
- **S20 — Prepare bill:** Create an invoice linked to approved work and a client. Main action: Review bill.
- **S21 — Team calendar:** See surveyor assignments and important dates. Main action: Open job.
- **S22 — Activity history:** Review important events and document actions. Main action: Open record.
- **S23 — Client conversations:** Keep service conversations connected to relevant jobs. Main action: Open conversation.

### Company settings (14 screens)

- **M01 — Company overview:** See activity, site performance and important warnings. Main action: View insights.
- **M02 — Service pages:** Edit published descriptions and service categories. Main action: Edit service.
- **M03 — Website content:** Update public page sections, buttons and contact information. Main action: Edit page.
- **M04 — Insights & articles:** Draft, review and publish approved articles. Main action: New article.
- **M05 — Project stories:** Manage approved case studies and project permissions. Main action: New project story.
- **M06 — Training catalogue:** Manage available courses and session information. Main action: New training.
- **M07 — Team access:** Manage staff accounts and access levels. Main action: Invite staff member.
- **M08 — Invitations:** View pending and accepted staff/client invitations. Main action: New invitation.
- **M09 — Document rules:** Control categories, who may see files and retention needs. Main action: Edit rules.
- **M10 — Email messages:** Preview notices sent to clients and staff. Main action: Edit message.
- **M11 — Company settings:** Update contact details, office locations and public information. Main action: Save details.
- **M12 — Business insights:** See qualified inquiries, bookings, turnaround and resource downloads. Main action: Export summary.
- **M13 — Security history:** View significant account and document activity. Main action: Review event.
- **M14 — Archive & retention:** Review archived jobs and planned retention actions. Main action: Review archive.

### Mobile previews (8 screens)

- **R01 — Mobile home:** Phone layout for visitors exploring the website. Main action: Request a quote.
- **R02 — Mobile quote request:** Phone-friendly version of the inquiry form. Main action: Continue.
- **R03 — Mobile client home:** Show client updates and useful shortcuts on a phone. Main action: Open project.
- **R04 — Mobile project details:** Make project progress readable on small screens. Main action: Files we need.
- **R05 — Mobile file upload:** Allow clients to choose or photograph supporting materials. Main action: Choose files.
- **R06 — Mobile team home:** Provide a compact overview for working staff. Main action: Open job.
- **R07 — Mobile job details:** Show job tasks and field notes on site. Main action: Open checklist.
- **R08 — Mobile inspection checklist:** Preview a simple field inspection experience. Main action: Save notes.

### Special states (5 screens)

- **X01 — New client — no projects:** Show helpful next steps before a client has requested a service. Main action: Request a service.
- **X02 — Unable to load information:** Explain temporary problems clearly without losing user work. Main action: Try again.
- **X03 — Upload needs attention:** Explain supported files, size limits and how to retry. Main action: Try upload again.
- **X04 — Access not allowed:** Explain that the current account cannot view a particular project. Main action: Go to my projects.
- **X05 — Nothing matched the search:** Show a friendly empty search result with a way to clear filters. Main action: Clear filters.

## Phase 1 acceptance checklist

- Every anticipated screen is reviewed; critical business journeys can be followed without broken navigation.
- Public and client wording is readable, friendly and approved by ANT Marine.
- Desktop and phone layouts, empty/loading/error/no-access states and accessible controls are verified.
- Any illustrative content is replaced with verified project/company information before publication.
- Role permissions and document release boundaries have written approval.
- Reviewers export the studio JSON record and store the agreed version with the implementation plan.

**Important:** This HTML is an interactive UX prototype, not a functioning production application. Build the agreed screens and transitions in Rails; do not treat demo buttons as evidence that backend processes exist.