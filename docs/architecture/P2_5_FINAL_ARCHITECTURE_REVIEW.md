# P2.5 — Final Architecture Review

**Date:** 22 November 2026  
**Status:** Architecture package complete — **Phase 2 exit NOT approved** until stakeholder sign-off and technical gates  
**Reviewed:** P2.1–P2.4, master spec, ADRs, Phase 1 design studio (HTML unchanged)

---

## 1. Executive summary

| Verdict | Detail |
|---|---|
| **Architecture consistency** | **Largely consistent** — minor wording fixes applied (quote→project 1:1 is **PROPOSED**, not approved) |
| **Requirements coverage** | **Broad coverage** with explicit gaps (live payments, encryption PoC, remote monitoring product, some CMS analytics) |
| **Security posture (design)** | **Sound on paper** — implementation and tests required in Phase 3–5 |
| **Phase 3 readiness** | **CONDITIONAL GO** — see [`P2_5_PHASE_3_READINESS.md`](P2_5_PHASE_3_READINESS.md) |

**Design rule:** Production UI implements [`design/ANT_Marine_Design_Studio_Phase_1.html`](../../design/ANT_Marine_Design_Studio_Phase_1.html) identity — no substitution with external templates.

---

## 2. Consistency findings

| Area | Finding | Severity |
|---|---|---|
| Quote → project 1:1 | P2.4 had mixed “confirmed” vs “proposed” — **corrected** to PROPOSED (P2-OD-043/004) | Medium (process) |
| P2-OD-004 vs P2-OD-043 | Aligned as same decision thread | Low |
| P2.1 `ContactMessage` vs P2-OD-002 | Proposal: merge into `ServiceInquiry`; schema catalogue still optional — consistent as PROPOSED | Low |
| Role matrix vs catalogue | 71 keys incl. `billing.view_all`; finance without project assignment | None |
| Workflows vs P2.3 schema | `suspended` project, `acknowledged_at` assignment — documented, not migrated | Low |
| ADR-007 | “Proposed, confirm roles” — consistent with SoD in P2.4 | Info |

No contradictions requiring P2.1 mandatory requirement rollback.

---

## 3. Unnecessary complexity (watch list)

| Item | Note |
|---|---|
| Separate CMS tables (P2-OD-007) | More tables but clearer than STI — acceptable |
| Dual document state machines | Required by master spec |
| audit_events STI | Proposed; alternative typed tables documented |

---

## 4. Risky assumptions

| Assumption | Mitigation |
|---|---|
| Cookie sessions sufficient | P2-OD-040; revisit for compliance |
| Hetzner SSE not default encrypted | ADR-010 PoC mandatory before confidential production files |
| Signed URL revocation | Short TTL + accept limitation |
| Stakeholder will approve 1:1 quote-project | Explicit approval item in stakeholder pack |

---

## 5. Phase 2 exit criteria (master spec)

| Criterion | Status |
|---|---|
| Domain map & data dictionary | Done (P2.1, P2.3) |
| Permission catalogue & matrix | Done — **stakeholder approval pending** |
| Threat model | Done (P2.2, P2.4) |
| Workflow state machines | Done (P2.4) |
| Decisions in DECISIONS.md | Many **PROPOSED/OPEN** |
| Storage encryption PoC | **Not done** — gate documented P2.5 |
| Do not generate all models before approval | **Honoured** |

---

## 6. Document index

| P2.5 deliverable | Purpose |
|---|---|
| [`P2_5_REQUIREMENTS_TRACEABILITY.md`](P2_5_REQUIREMENTS_TRACEABILITY.md) | Questionnaire / spec → architecture → Phase 3/4 slice |
| [`P2_5_SECURITY_AND_STORAGE_GATES.md`](P2_5_SECURITY_AND_STORAGE_GATES.md) | Invariants + ADR-010 PoC plan |
| [`P2_5_PHASE_3_READINESS.md`](P2_5_PHASE_3_READINESS.md) | Implementation backlog |
| [`P2_5_STAKEHOLDER_APPROVAL_PACK.md`](P2_5_STAKEHOLDER_APPROVAL_PACK.md) | Decisions for product owner |

---

## 7. GO recommendation

**CONDITIONAL GO** to Phase 3 **foundation slices** that do not depend on unresolved ADRs (e.g. org/users skeleton, permission seeds in dev, layout shells) **only after** product owner acknowledges stakeholder pack and accepts CONDITIONAL scope.

**NO-GO** for confidential production files, live client onboarding policy, or Team & Permissions UI until respective ADRs/DCR approved.

**NO-GO** to mark Phase 2 **fully approved** in `PHASE_PROGRESS` until sign-off recorded.