# yukidaruma

Snowflake-inspired **personal compute workspace**: register data, submit Python jobs, track runs, and inspect results.

## Fixed design constraints

- Storage: Cloudflare D1 or Google Drive. No R2.
- Compute: Python environments on Kaggle, Colab, or the Muse Ubuntu VM.
- UI: Vanilla JavaScript + SVG only. No frontend framework.
- Control plane: Cloudflare Workers + D1.
- Muse VM: Python worker polls the API; no Go orchestrator and no inbound VM port.

D1 is suitable for metadata and small text datasets; Google Drive is the file store for larger datasets and artifacts. The selected storage backend is explicit in each dataset/artifact reference.

## Docs

| Doc | Purpose |
|-----|---------|
| [MRD](docs/MRD.md) | product context |
| [PRD](docs/PRD.md) | requirements and constraints |
| [ADR-001](docs/adr/001-mvp-architecture.md) | accepted MVP architecture |
| [Architecture diagrams](docs/architecture.puml) | PlantUML diagrams |
| [Storage model](docs/storage.md) | D1 / Google Drive storage rules |
| [Job schema](schemas/job.schema.json) | job contract |
| [Result manifest schema](schemas/result-manifest.schema.json) | result contract |
| [D1 schema](d1/schema.sql) / [D1 notes](d1/README.md) | metadata and small text payloads |
| [Workers API](docs/api.md) | control-plane API |
| [Python worker protocol](docs/runner-protocol.md) | claim, execute, heartbeat, result |

## Growth plan

The product grows as one system: **POC → MVP → MAX**. See [the staged roadmap](docs/roadmap-poc-mvp-max.md) for scope, exit gates, acceptance criteria, and the mapping to Issues #1–#10.

## Current status

Architecture and contracts are documented. The next milestone is the POC vertical slice: one deterministic Python job, one Muse VM worker, D1 metadata/small text, and a private Google Drive artifact. Kaggle/Colab remain best-effort until verified.
