# ADR-001 — MVP Architecture

- Status: Accepted
- Date: 2026-11-13
- Related issues: #1, #2, #3, #4, #5, #6

## Context

Yukidaruma is a Snowflake-inspired personal compute workspace. It must expose one catalog/job/run/result experience while executing Python workloads across Kaggle, Colab, and the Muse Ubuntu VM.

Hard constraints:
1. Storage is Cloudflare D1 or Google Drive. R2 is not used.
2. Compute runs only in Python environments on Kaggle, Colab, or Muse VM.
3. UI is Vanilla JavaScript + SVG only.
4. Muse VM uses a Python polling worker, not a separate Go orchestrator.

## Decision

| Layer | Choice | Responsibility |
|---|---|---|
| UI | Vanilla JavaScript + SVG | Workspace, forms, tables, charts, status and previews; no frontend framework |
| Control-plane API | Cloudflare Workers | Authentication, validation, job lifecycle, storage coordination |
| Metadata DB | Cloudflare D1 | Datasets, jobs, runs, runners, events, artifact references |
| Small text data | D1 bounded text payloads | Small CSV/JSON/JSONL/text values only, subject to D1 limits |
| File storage | Google Drive | Larger datasets, code bundles, logs, notebooks, and result artifacts |
| Muse execution | Python worker on Ubuntu VM | Outbound poll, claim, heartbeat, execute, report |
| Remote execution | Kaggle / Colab Python | Best-effort Python execution adapters |
| Analytics | Python environment | pandas / Polars / DuckDB where installed and suitable |

## Storage policy

- Every dataset and artifact declares storage_backend: d1 or google_drive.
- D1 is for metadata and small text payloads, not an unlimited binary store or analytical warehouse.
- Google Drive is used for files that exceed the configured D1 payload threshold or require file-oriented formats such as Parquet, notebooks, archives, and large logs.
- Google Drive references use stable file IDs, not public sharing links.
- OAuth tokens remain server-side; use the narrowest practical Drive scope.
- No R2 bucket, R2 URI, presigned URL, or R2 credential is part of the architecture.

## Compute policy

- A job requests Python and a target of auto, muse_vm, colab, or kaggle.
- Every target runs the same versioned Python job contract.
- Muse VM polls Workers over outbound HTTPS; no inbound listener is required.
- Kaggle and Colab availability is best-effort and must be shown as manual, available, or unavailable based on verified adapter capability.
- No Go or Rust workload runtime is included in MVP.

## Consequences

**Positive**
- One language and job contract for all user workloads.
- No additional object-storage product to operate.
- Frontend remains small, inspectable, and dependency-light.
- Muse VM does not need a public inbound endpoint.

**Trade-offs**
- D1 payload size and query limits require a clear threshold and Drive fallback.
- Google Drive API quotas, OAuth consent, and ownership/sharing rules become operational constraints.
- Kaggle/Colab execution can be interrupted or require manual handoff.
- Vanilla JS + SVG means UI components, routing, and chart primitives are maintained in-repo.

## Alternatives rejected

- Cloudflare R2: explicitly outside the storage constraint.
- Go orchestrator: unnecessary second runtime; Muse polling is handled by Python.
- React/Vue/Svelte: outside the UI constraint.
- D1 as unlimited bulk storage: unsuitable for large files and analytical scans.

## Deferred

- Exact D1 inline-payload threshold, to be set from current Cloudflare limits and tested behavior.
- Google Drive OAuth model and shared-drive support.
- Which Kaggle/Colab automation mechanism is supported by current platform interfaces.
- UI component conventions and SVG chart primitives.
