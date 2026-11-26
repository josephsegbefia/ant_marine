# F4-06-H1 — Document security, final verification & acceptance

**Checkpoint:** F4-06-H1  
**Baseline:** `1f00cc6` (F4-06)  
**Branch:** local `main`  
**Hard stops:** no push, no deploy, no F4-07/F4-08, no live document/commercial ops, no external storage activation, no quarantine bypass, no Design Studio edits, no DB reset.

Full requirements are in the approved H1 brief. Evidence: [`docs/architecture/F4_06_H1_ACCEPTANCE.md`](../architecture/F4_06_H1_ACCEPTANCE.md).

## Focus

Correct genuine deficiencies in F4-06: fail-closed scanning, scan-digest binding, storage asset immutability after verification, access grant / client visibility hardening, exact-version review/release races, missing high-risk tests, authenticated browser acceptance.
