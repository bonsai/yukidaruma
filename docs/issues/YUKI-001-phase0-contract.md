# YUKI-001 — Phase 0: Contract and foundation

- Priority: **P0**
- Status: open
- Labels: phase-0, foundation

## Goal
Lock the job protocol, D1 schema, R2 layout, and runner rules before application code.

## Checklist
- [x] Job schema (`schemas/job.schema.json`)
- [x] D1 schema (`d1/schema.sql`)
- [ ] Result manifest schema
- [ ] R2 key layout document
- [ ] Runner protocol + threat model
- [ ] State machine rules (ownership, heartbeat, stale runs)

## Exit criteria
- Example job validates against schema
- Ownership / state transition rules documented
- No secrets in fixtures

## Related
- PRD §8 FR-03, FR-04
- PRD §9 Job contract
- PRD §10 Core data entities
- PRD §14 Phase 0
