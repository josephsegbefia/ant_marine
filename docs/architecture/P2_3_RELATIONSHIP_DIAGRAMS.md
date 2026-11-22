# P2.3 — Relationship Diagrams

**Version:** 1.0 — 22 November 2026  
**Notation:** `||--o{` one-to-many; cardinalities match [`P2_1_DOMAIN_RELATIONSHIPS.md`](P2_1_DOMAIN_RELATIONSHIPS.md) unless noted.

---

## Platform — identity & RBAC

```mermaid
erDiagram
  Organization ||--o{ Membership : has
  User ||--o{ Membership : has
  Organization ||--o{ Invitation : issues
  Membership ||--o{ PermissionOverride : overrides
  Permission ||--o{ RolePermission : granted_to
  Membership ||--o{ AuditEvent : actor
  Invitation }o--|| User : accepted_by
  PermissionOverride }o--|| Permission : on
  RolePermission }o--|| Permission : includes
```

---

## Commercial funnel

```mermaid
erDiagram
  Service ||--o{ ServiceInquiry : attracts
  Organization ||--o{ ServiceInquiry : linked_client
  ServiceInquiry ||--o| Quote : may_spawn
  Organization ||--o{ Quote : owns
  Quote ||--|{ QuoteRevision : versions
  QuoteRevision ||--o{ QuoteResponse : client_answers
  QuoteRevision ||--o| Project : creates_one
  ServiceInquiry ||--o{ BookingRequest : may_have
  BookingRequest ||--o| BookingConfirmation : confirms
```

---

## Delivery

```mermaid
erDiagram
  Organization ||--o{ Project : client_owns
  Project ||--|{ Assignment : staffed
  User ||--o{ Assignment : assigned
  Project ||--o{ ProjectVessel : uses
  Vessel ||--o{ ProjectVessel : linked
  Organization ||--o{ Vessel : registers
  Project ||--o{ Inspection : conducts
  Inspection ||--o{ InspectionFinding : records
  Project ||--o{ Task : includes
  Project ||--o{ ProjectStatusEvent : history
```

---

## Documents

```mermaid
erDiagram
  Organization ||--o{ Document : owns
  Project ||--o{ Document : contains
  Document ||--|{ DocumentVersion : versions
  Document ||--o{ DocumentAccessGrant : explicit
  User ||--o{ DocumentAccessGrant : recipient
  Project ||--o{ UploadRequest : requests
```

---

## Reports

```mermaid
erDiagram
  Project ||--o{ Report : delivers
  Report ||--|{ ReportVersion : versions
  ReportVersion ||--o{ ReportReview : reviewed
  ReportVersion ||--o{ ReportRelease : released_to_client
  Organization ||--o{ ReportRelease : recipient_org
```

---

## Billing

```mermaid
erDiagram
  Organization ||--o{ Invoice : billed
  Project ||--o{ Invoice : optional_link
  Invoice ||--|{ InvoiceLine : lines
  Invoice ||--o{ PaymentRecord : payments
```

---

## Collaboration

```mermaid
erDiagram
  Project ||--|| Conversation : primary_thread
  Conversation ||--|{ Message : posts
  User ||--o{ Notification : receives
  Organization ||--o{ Notification : scoped
```

---

## Public CMS (simplified)

```mermaid
erDiagram
  Service ||--o{ CaseStudy : optional_link
  PublicResource ||--o{ ResourceDownload : metrics
```

---

## Cross-context tenancy (logical)

```mermaid
flowchart LR
  subgraph client_tenant [ClientOrganization]
    P[Project]
    D[Document]
    I[Invoice]
    V[Vessel]
  end
  subgraph staff_ctx [StaffMembership]
    U[User]
    A[Assignment]
  end
  U --> A
  A --> P
  P --> D
  client_tenant --> I
```

Staff **never** store `client_organization_id` on `users`; access paths traverse `assignments` or policy-scoped queries.