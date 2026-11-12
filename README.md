# yukidaruma

Snowflake-inspired **personal compute warehouse**: browse datasets, submit jobs, track runs, fetch artifacts.

- **Control plane:** Cloudflare Workers + D1 + R2
- **Orchestrator:** Go on Ubuntu Muse VM (poll / claim / heartbeat)
- **Compute:** Python (+ DuckDB) first; Colab/Kaggle later (best-effort)

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
| [R2 layout & ACL](docs/r2-layout.md) | #4 |
| [Workers API](docs/api.md) | #5 |
| [Runner protocol & threat model](docs/runner-protocol.md) | #6 |

## Implementation order

```
#1 ADR → #2 Schema → #3 D1 → #4 R2 → #6 Protocol → #5 Workers API
    → #7 Go Orchestrator → #8 Python Runner → #9 UI → #10 E2E
```

## Status

Phase 0 design artifacts are in-repo. Runtime code not started.
