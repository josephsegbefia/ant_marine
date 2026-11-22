# ANT Marine W.A. — Architecture Decision Register

| ID | Area | Decision | Status | Rationale / owner / date |
|---|---|---|---|---|
| ADR-001 | App shape | One Rails modular monolith; ERB/Hotwire/Stimulus | Proposed direction agreed in conversation | Less integration overhead; shared business models |
| ADR-002 | Database | PostgreSQL | Proposed direction agreed | Mature relational integrity; Rails integration |
| ADR-003 | Hosting | Hetzner + Coolify + Cloudflare | Proposed direction agreed | Deployment control; separation from other apps |
| ADR-004 | Storage | Private S3-compatible object storage, Hetzner first candidate | Proposed, pending security PoC | Requires verified encryption at rest and independent backup |
| ADR-005 | Client signup | Invite after qualified/confirmed service | OPEN | Ease of public inquiry versus tenant security |
| ADR-006 | Quote/booking approval | Client acceptance and staff confirmation guards | OPEN | Contractual and payment implications |
| ADR-007 | Report roles | Technical approval and explicit release are distinct | Proposed, confirm roles | Prevent accidental publication |
| ADR-008 | Payment | Billing records initially; live collection separately decided | OPEN | Commercial/provider obligations |
| ADR-009 | Email | Action Mailer plus an external delivery service | OPEN (provider) | Deliverability |
| ADR-010 | Storage protection | Encryption method, keys, location, retention, backups | OPEN / launch blocker | Confidential documents |

Only mark a decision `APPROVED` when the user or authorized stakeholder clearly confirms it. Keep history when decisions change.
