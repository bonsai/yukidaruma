# YUKI-002 — Phase 1: Local vertical slice

- Priority: **P0**
- Status: open
- Labels: phase-1, mvp
- Depends on: YUKI-001

## Goal
One complete path: submit job → Muse VM claims → Python runs → artifact on R2 → visible in UI/API.

## Checklist
- [ ] Cloudflare Worker API + D1 metadata
- [ ] R2 artifact storage (or local FS for dev)
- [ ] Go VM poller / orchestrator
- [ ] Python local runner
- [ ] Minimal UI or CLI: submit, list, detail, logs, artifacts

## Exit criteria
- Submit a Python job
- VM claims and executes without duplicate ownership
- Artifact is visible
- Restart / failure handled; queued jobs survive VM restart

## Related
- PRD §8 FR-01 … FR-06
- PRD §14 Phase 1
- PRD §15 MVP acceptance checklist
