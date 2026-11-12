# yukidaruma

Snowflake-inspired **personal compute warehouse**: browse datasets, submit jobs, track runs, fetch artifacts.

## Constraints

| Area | Rule |
|------|------|
| Storage | **D1** (metadata) and/or **Google Drive** (files) |
| Compute | **Muse VM / Colab / Kaggle** Python environments |
| UI | **Vanilla JS + SVG only** |

## Architecture (MVP)

- **Control plane:** Cloudflare Workers + D1
- **Files:** Google Drive
- **Orchestrator / local run:** Muse VM Python env
- **Remote run:** Colab, Kaggle (best-effort)
- **UI:** static vanilla JS + SVG

Not a Snowflake clone. D1 is not the analytical engine.

## Docs

| Doc | Issue |
|-----|-------|
| [MRD](docs/MRD.md) | product context |
| [PRD](docs/PRD.md) | requirements |
| [ADR-001 MVP architecture](docs/adr/001-mvp-architecture.md) | #1 |
| [Job schema](schemas/job.schema.json) | #2 |
| [Result manifest schema](schemas/result-manifest.schema.json) | #2 |
| [D1 schema](d1/schema.sql) / [D1 notes](d1/README.md) | #3 |
| [Storage layout (D1 + Drive)](docs/storage-layout.md) | #4 |
| [Workers API](docs/api.md) | #5 |
| [Runner protocol & threat model](docs/runner-protocol.md) | #6 |

## Implementation order

```
#1 ADR → #2 Schema → #3 D1 → #4 Storage → #6 Protocol → #5 Workers API
    → #7 Orchestrator (Muse VM) → #8 Python Runner → #9 UI (vanilla JS) → #10 E2E
```

## Status

Phase 0 design artifacts in-repo (constraints revised 2026-11-13). Runtime code not started.
