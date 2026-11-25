# F4-04A — Implementation specification (anchor)

**Checkpoint:** Client onboarding, organization management & client portal  
**Baseline HEAD at start:** `bf25897`  
**Prior accepted:** F4-03 `fe4cf5d` (preserve later UI commits)  
**Branch:** `main` (local commits only — **do not push**)

## Authorisation

Product owner authorised the complete F4-04A scope as an implementation task (not architecture-only).

## Hard stops

- Do not push or deploy
- Do not start F4-04B or F4-05
- Do not enable live email or real commercial acceptance
- Do not automatically create projects
- Do not reset databases or modify Design Studio HTML
- Do not weaken security or change production DB privileges
- Do not switch schema format without separate approval

## Outcome document

Implementation architecture, Design Studio mapping, release semantics, history-protection proposal, and acceptance evidence:

→ [`docs/architecture/F4_04A_CLIENT_ONBOARDING.md`](../architecture/F4_04A_CLIENT_ONBOARDING.md)

## Scope summary

Qualified enquiry → create/select client organisation → invite representative → activate → client portal (requests + eligible quotations + PDF). Commercial decisions deferred.
