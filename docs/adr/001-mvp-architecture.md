# ADR-001 — MVP Architecture

- Status: Accepted
- Date: 2026-11-12
- Related issues: #1, #2, #3, #4, #5, #6

## Context

Yukidaruma needs a Snowflake-inspired analytics workspace without reimplementing a warehouse engine. Humans and AI agents must submit jobs, track runs, and retrieve artifacts. Compute must be pluggable (Muse VM first; Colab/Kaggle later).

## Decision

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Edge API | Cloudflare Workers | Low ops, close to D1/R2, auth at edge |
| Metadata DB | Cloudflare D1 | Control-plane only; SQLite-compatible |
| Object store | Cloudflare R2 | Datasets + artifacts; no egress fee to Workers |
| Orchestrator | Go on Ubuntu Muse VM | Long-running poller, claim, heartbeat |
| Local runner | Python + DuckDB/Polars | Analysis standard; notebooks later |
| Remote runners | Colab / Kaggle adapters (P1) | Best-effort only after local path works |
| Optional accel | Rust CLI (P2) | Only for measured bottlenecks |
| Connectivity | Outbound poll from VM | No inbound public port on Muse VM |

## Consequences

**Positive**
- Clear control plane vs compute plane
- VM restart does not lose queued jobs (state in D1)
- Same job contract for humans and agents

**Negative / constraints**
- D1 is not an analytical engine (size + single-thread limits)
- Free Colab/Kaggle are unreliable; must not block MVP
- Two languages (Go + Python) to maintain for MVP

## Non-decisions (deferred)

- Frontend framework (inspect repo when UI starts)
- Auth provider details (token shape fixed in API spec; IdP later)
- Multi-tenant IAM, billing, compliance

## Alternatives considered

1. **All-in on one language** — rejected; Python is required for analysis UX, Go fits long-running orchestrator.
2. **D1 as analytical store** — rejected; wrong scale and query model.
3. **Inbound webhook to Muse VM** — deferred; poll is simpler and safer for MVP.
