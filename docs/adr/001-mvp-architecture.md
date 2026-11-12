# ADR-001 — MVP Architecture

- Status: Accepted (revised 2026-11-13)
- Date: 2026-11-12
- Revised: 2026-11-13
- Related issues: #1, #2, #3, #4, #5, #6, #9

## Context

Yukidaruma needs a Snowflake-inspired analytics workspace without reimplementing a warehouse engine. Humans and AI agents must submit jobs, track runs, and retrieve artifacts. Compute is limited to existing Python environments the operator already uses.

## Hard constraints (product)

| Area | Constraint |
|------|------------|
| **Storage** | **Cloudflare D1** (metadata / small structured state) and/or **Google Drive** (datasets, artifacts, logs). No R2 requirement for MVP. |
| **Compute** | **Muse VM / Colab / Kaggle** Python environments only. No mandatory extra cluster. |
| **UI** | **Vanilla JS + SVG only** (no React/Vue/Svelte requirement). |

## Decision

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Edge API | Cloudflare Workers | Low ops, native D1 binding, auth at edge |
| Metadata | Cloudflare D1 | Job/run/catalog control plane |
| Blob / files | Google Drive (primary for large objects) | Fits constraint; shareable with Colab |
| Small blobs / previews | D1 only when tiny (rows, JSON summaries) | Avoid D1 as warehouse |
| Orchestrator | Muse VM (Python or thin Go/Python hybrid later) | Poll / claim / run local py env |
| Compute runners | Muse VM py · Colab · Kaggle | Same job contract; best-effort remote |
| Analytics in-process | DuckDB / Polars inside Python | Local SQL feel without a warehouse |
| UI | Vanilla JS + SVG | Lightweight Snowsight-like sheets/charts |
| Connectivity | Outbound poll from Muse VM | No inbound public port required |

## Consequences

**Positive**
- Matches real operator tooling (Drive + Colab/Kaggle/VM)
- UI stack stays trivial to host (static files + Workers)
- Control plane stays on D1; files stay off-SQLite

**Negative / constraints**
- Drive API auth, quotas, and latency replace R2 presign simplicity
- D1 size limits still forbid large analytical tables
- Colab/Kaggle session limits remain best-effort
- Vanilla JS means no heavy UI framework productivity for complex state

## Non-decisions (deferred)

- R2 as optional later backend behind the same URI scheme
- Go orchestrator vs Python-first orchestrator on Muse VM
- Auth IdP details beyond bearer tokens
- Multi-tenant IAM, billing, compliance

## Alternatives considered

1. **R2 as primary object store** — deferred; conflicts with current storage constraint (D1 or Google Drive).
2. **D1 as analytical store** — rejected; wrong scale and query model.
3. **SPA framework for UI** — rejected for MVP; vanilla JS + SVG only.
4. **Inbound webhook to Muse VM** — deferred; poll is simpler and safer.
