# PRD — Yukidaruma

- Status: Draft
- Date: 2026-11-12
- Related: [MRD.md](MRD.md)
- Repository: https://github.com/bonsai/yukidaruma

## 1. Product definition

Yukidaruma is a Snowflake-inspired analytics workspace with a lightweight control plane and pluggable compute runners. Humans and AI agents can register datasets, submit jobs, monitor runs, inspect logs, and browse results from one UI.

The initial release uses one portable Python job contract across Kaggle, Colab, and the Muse Ubuntu VM. Each environment runs Python; platform-specific launch and availability are adapter concerns.

**Product promise:** one workspace for data, jobs, compute routing, and results — without requiring one monolithic execution engine.

## 2. Goals

1. Browser UI for datasets, jobs, runs, SQL worksheets, and artifacts.
2. Cloudflare D1 for metadata, job state, and small text-based dataset payloads.
3. Google Drive for larger dataset files and generated artifacts.
4. Python execution in Kaggle, Colab, and the Muse Ubuntu VM.
5. Versioned JSON job/result contracts shared across Python environments.
6. A Python worker on Muse VM polls the API; no Go orchestrator.
7. Human and AI-agent access through the same authenticated API.
8. Reproducibility through recorded provenance.

## 3. Non-goals

- Reimplement Snowflake, a distributed SQL engine, or a general-purpose data warehouse.
- Store large Parquet/CSV/JSONL datasets in D1.
- Guarantee free GPU capacity or uninterrupted Colab/Kaggle sessions.
- Execute arbitrary untrusted code without isolation and policy checks.
- Build enterprise IAM, billing, compliance, or multi-tenant features in the MVP.
- Add non-Python workload runtimes to the first usable release.
- Make remote notebook automation a prerequisite for MVP.
- Support every SQL dialect or notebook format initially.

## 4. Personas

### Human analyst
Browses datasets, runs SQL or analysis, inspects outputs, and reuses prior runs.

### AI agent
Submits a valid job, receives a job ID, polls status, and retrieves structured results without direct database access.

### Operator
Registers runners, configures credentials securely, inspects failures, cancels jobs, and monitors resource use.

## 5. Core user journeys

### A. First local analysis
1. User opens Yukidaruma.
2. User registers or uploads a dataset.
3. User creates a Python job or SQL worksheet.
4. User chooses automatic routing or Muse VM.
5. Yukidaruma persists the job as queued.
6. Muse VM polls for work and claims the job.
7. Runner fetches inputs, executes the task, and uploads artifacts.
8. Runner reports status and result manifest.
9. User opens the run and previews tables, logs, and charts.

### B. AI-agent delegation
1. Agent submits task, input references, parameters, and constraints.
2. API validates identity, schema, limits, and permissions.
3. API returns job_id.
4. Agent polls status or receives an event.
5. Agent reads a structured result summary and artifact references.

### C. Remote notebook execution
1. User selects Colab or Kaggle.
2. Yukidaruma checks adapter configuration and capabilities.
3. Adapter dispatches through a supported platform workflow.
4. Remote environment fetches inputs and uploads outputs.
5. Yukidaruma records results or a clear failure/manual-action state.

A remote adapter is not shown as available until it passes an end-to-end test. Manual handoff is an acceptable first implementation.

## 6. Information architecture

Primary navigation:
- Overview
- Databases / Datasets
- SQL Worksheets
- Jobs
- Runs / History
- Artifacts
- Runners
- Settings

### Overview
Queued/running/succeeded/failed counts, recent runs, runner availability and heartbeat, recent datasets and artifacts.

### Datasets
Name, description, format, size, schema, URI, version, checksum, provenance, tags, timestamps, and supported-format preview.

### SQL Worksheets
Editor, saved worksheets, dataset context, execution target, result grid, elapsed time, export, charts, and query history.

Initial analytical SQL target is local DuckDB. D1 queries are administrative only.

### Jobs and runs
Job identity, task, requested runtime, priority, submitter, state, runner assignment, attempt number, timestamps, duration, code revision, parameters, logs, metrics, and artifacts.

### Runners
Runner ID, type, capabilities, status, last heartbeat, labels, enable/disable, and configuration status. Secret values are never displayed.

## 7. System architecture

| Component | Responsibility | Initial technology |
|---|---|---|
| Web UI | Workspace, editor, tables, charts, job views | Vanilla JavaScript + SVG; no framework |
| Edge API | Authenticated requests, validation, metadata access | Cloudflare Workers |
| Metadata / small data store | Catalog, jobs, runs, runner registry, small text payloads | Cloudflare D1 |
| File store | Larger datasets, code bundles, logs, outputs, manifests | Google Drive |
| Muse worker | Polling, claim, heartbeat, launch and result reporting | Python on Ubuntu Muse VM |
| Compute environments | Python task execution | Kaggle / Colab / Muse VM Python |
| Analytics | Local tabular analysis where available | Python libraries; DuckDB optional |
| Observability | Execution traces of job runs and LLM calls | Langfuse Cloud (see [tracing.md](tracing.md)) |

### Connectivity
Prefer outbound polling:
- Muse VM initiates HTTPS requests to the Cloudflare API.
- No inbound public port is required for MVP.
- Worker API persists jobs before the VM claims them.
- Runner heartbeats renew liveness.
- Optional webhook/tunnel connectivity can be added later.

### Data flow
1. Browser/agent submits job to Worker API.
2. Worker validates and writes metadata to D1.
3. Muse VM polls and claims an eligible job.
4. Runner retrieves inputs using scoped access.
5. Runner executes workload.
6. Runner stores small text payloads in D1 or uploads larger files to Google Drive.
7. Runner reports state transitions and storage-qualified artifact references.
8. UI reads metadata from D1 and previews/downloads from D1 or Google Drive.

### SQL boundary
D1 is not the analytical SQL engine. D1 stores control-plane records. DuckDB is the initial local analytical engine and can read Parquet, CSV, and JSONL from local or downloaded object-store files. A future remote SQL engine can be added behind an adapter.

### Observability boundary
Langfuse Cloud is the observability plane for execution traces (see §12 and [tracing.md](tracing.md)). Like D1, it stores neither datasets nor artifacts: job state and control-plane records live in D1, dataset content and outputs live in D1 (bounded text payloads) or Google Drive, and traces live in Langfuse. No one of the three replaces another, and D1 remains the authority for job state.

## 8. Functional requirements

Priority: P0 required for first usable MVP; P1 next; P2 later.

### FR-01 Authentication and workspace — P0
- Authenticate UI and API requests.
- Support revocable, scoped agent/API tokens.
- Never expose worker or storage credentials in UI responses.
- Audit actor and action.

Acceptance:
- Unauthenticated requests are rejected.
- Revoked tokens cannot submit or read jobs.
- Secrets are never returned in API responses.

### FR-02 Dataset catalog — P0
- Create, read, update, and archive dataset metadata.
- Store storage_backend (d1 or google_drive), storage_ref, format, size, checksum, schema summary, and provenance.
- Initially support CSV, JSONL, JSON, and Parquet.
- D1 may hold small text payloads within documented limits; larger files use Google Drive.

Acceptance:
- Dataset can be registered by URI.
- Catalog displays format, URI, and registration time.
- Checksum or explicit unknown value is retained.

### FR-03 Job submission — P0
- Accept a versioned JSON job specification.
- Validate required fields, runtime, input references, and resource limits.
- Return stable job_id.
- Support idempotency keys.

Acceptance:
- Valid jobs persist and return queued.
- Invalid jobs return structured validation errors.
- Same idempotency key does not create a duplicate.

### FR-04 Job lifecycle — P0
States: queued, claimed, dispatched, running, succeeded, failed, cancel_requested, cancelled, timed_out.

- Record state transitions with timestamps and actor/runner.
- Prevent two runners from owning the same attempt.
- Detect stale heartbeats and reconcile abandoned runs.
- Terminal states cannot silently return to running.

Acceptance:
- Each attempt has one runner owner.
- State transitions are validated.
- Stale runs become visibly lost or timed_out according to a documented rule.

### FR-05 Muse VM runner — P0
- VM polls for jobs using runner-scoped authentication.
- VM advertises capabilities and heartbeat.
- Runner downloads inputs, executes an allowed task, and uploads artifacts.
- Runner reports logs and final status.

Acceptance:
- A Python job completes end-to-end on Ubuntu.
- VM restart does not erase queued jobs.
- Failed process produces a failure record and accessible logs.

### FR-06 Run history and artifacts — P0
- Store attempt, timestamps, duration, runner, code revision, parameters, environment summary, and output manifest.
- Artifacts have stable IDs and storage-qualified references (D1 row or Google Drive file ID).
- UI previews text and basic CSV/JSONL from either supported backend.

Acceptance:
- Completed run can be reopened after refresh.
- Manifest lists artifact names, formats, sizes, checksums, and URIs.

### FR-07 SQL worksheet — P1
- Execute SQL against local DuckDB datasets.
- Display tabular results and elapsed time.
- Save worksheets and query history.
- Export results to D1 for small text results or Google Drive for larger files.
- Separate D1 administrative queries from analytical queries.

Acceptance:
- User queries registered Parquet/CSV data with DuckDB.
- Results can be exported and reopened.

### FR-08 Charts — P1
- Render bar, line, and scatter charts from tabular results.
- Save chart configuration with worksheet or run.
- Do not imply causality or statistical significance automatically.

Acceptance:
- User selects x/y fields and renders a chart.
- Chart configuration can be reopened.

### FR-09 Remote runner adapters — P1
- Adapter interface: validate, submit, status, cancel where supported, collect.
- Implement Colab/Kaggle only to the extent supported by current interfaces and policies.
- Support manual handoff where automatic dispatch is unavailable.
- Expose quotas, availability, and interruption risk as best-effort.

Acceptance:
- Each operation reports supported, manual, or unavailable.
- A remote job is not marked dispatched before platform acceptance.
- Result collection is idempotent.

### FR-10 Python environment extensions — P2
- Add Python packages or optional Python-native analytics tools only when a measured workload requires them.
- Keep the public job contract and supported Python targets stable.

## 9. Job contract

Illustrative version 1.0 payload:

    {
      "schema_version": "1.0",
      "idempotency_key": "client-generated-key",
      "task": "python_script",
      "runtime": {
        "target": "auto",
        "language": "python",
        "version": "3.11"
      },
      "input": [
        {
          "dataset_id": "ds_example",
          "uri": "gdrive://example-file-id",
          "format": "parquet",
          "version": "v1"
        }
      ],
      "code": {
        "source_uri": "gdrive://file-id-or-d1://code-row-id",
        "revision": "git-sha-or-version"
      },
      "parameters": {},
      "resources": {
        "gpu": "optional",
        "memory_mb": 8192,
        "timeout_seconds": 1800
      },
      "output": {
        "backend": "google_drive",
        "prefix": "gdrive://folder-id"
      }
    }

For D1-backed input, uri may instead be d1://dataset-row-id. Server-owned fields such as job_id, timestamps, state, and runner assignment must not be trusted from clients. Credentials must never be embedded in job payloads.

## 10. Core data entities

### datasets
id, name, description, storage_backend, storage_ref, format, size_bytes, checksum, schema_json, tags_json, source_json, created_at, updated_at, archived_at.

### jobs
id, task, requested_runtime, language, payload_json, state, priority, submitted_by, idempotency_key, created_at, updated_at, cancel_requested_at.

### runs
id, job_id, attempt, runner_id, state, started_at, finished_at, heartbeat_at, duration_ms, code_revision, environment_json, error_code, error_message.

### artifacts
id, run_id, name, storage_backend, storage_ref, format, size_bytes, checksum, content_type, created_at.

### runners
id, type, status, capabilities_json, labels_json, last_heartbeat_at, registered_at, disabled_at.

### job_events
id, job_id, run_id, event_type, from_state, to_state, message, metadata_json, created_at.

Use UTC ISO-8601 timestamps and opaque IDs. Keep large JSON documents and binary payloads out of D1 where practical.

## 11. API surface

| Method | Path | Purpose |
|---|---|---|
| POST | /v1/datasets | Register dataset |
| GET | /v1/datasets | List datasets |
| GET | /v1/datasets/{id} | Dataset detail |
| POST | /v1/jobs | Submit job |
| GET | /v1/jobs | List jobs |
| GET | /v1/jobs/{id} | Job detail |
| POST | /v1/jobs/{id}/cancel | Request cancellation |
| POST | /v1/jobs/{id}/retry | Create new attempt |
| GET | /v1/jobs/{id}/events | Event history |
| GET | /v1/runs/{id} | Run detail |
| GET | /v1/runs/{id}/artifacts | Artifact list |
| POST | /v1/runners/register | Register runner |
| POST | /v1/runners/heartbeat | Runner heartbeat |
| POST | /v1/runners/claim | Claim eligible job |
| POST | /v1/runs/{id}/events | Report progress/state |
| POST | /v1/runs/{id}/complete | Complete run and manifest |

All endpoints require authentication and validation. Runner endpoints require runner-scoped credentials.

## 12. Non-functional requirements

### Reliability
- Persist a job before acknowledging submission.
- Make state reporting and artifact collection idempotent.
- Resume queued work after restart/reconnect.
- Distinguish retryable and non-retryable failures.

### Security
- Never commit API keys, tokens, signed URLs, or passwords.
- Store server secrets in Cloudflare secrets or VM secret storage.
- Use least-privilege Google Drive OAuth scopes and never expose refresh/access tokens to browser code.
- Keep D1 payloads bounded; store large files in Google Drive.
- Restrict task types and resource limits.
- Treat datasets, notebooks, and parameters as untrusted input.
- Redact secrets from logs and errors.

### Performance
- Paginate job, run, and dataset lists.
- Index D1 for common metadata filters.
- Sample or paginate large previews.
- Never load entire datasets into browser memory.

### Portability
- Version job and result contracts.
- Isolate runner-specific metadata in adapter fields.
- Use JSON/JSONL for interchange and Parquet for analytical data where suitable.

### Observability
Record request IDs, job IDs, run IDs, runner IDs, state changes, durations, and failure categories. Avoid storing prompts or sensitive dataset rows in operational logs by default.

Execution tracing is provided by **Langfuse Cloud**: one job execution produces one trace covering its lifecycle stages and any LLM calls made inside the Python worker, in the same Langfuse project that receives the OpenRouter Traces destination. The full design — trace model, naming rules, metadata and tags, worker-owned instrumentation with the Langfuse Python SDK, configuration, data policy, and the acceptance audit loop — is specified in [tracing.md](tracing.md). Tracing is best-effort and metadata-only by default: it never stores dataset rows or prompt/response bodies unless explicitly enabled per task type, missing credentials disable it silently, and a tracing failure must never fail or block a job. D1 remains the authority for job state regardless of trace availability.

## 13. UX requirements

- Snowflake-inspired layout: left navigation, central worksheet/workspace, result panel.
- Distinguish job definition, individual run, and artifact.
- Show whether runtime is automatic, confirmed, manual, or unavailable.
- Show state and timestamps clearly.
- Keep logs and results accessible from run detail.
- Provide useful empty states and first actions.
- Never imply a remote runtime is available merely because it is configured.

## 14. Delivery plan — POC → MVP → MAX

The product is delivered as one evolving system, not three separate implementations. See [roadmap-poc-mvp-max.md](roadmap-poc-mvp-max.md) for detailed scope and exit gates.

### POC — prove the vertical slice
- One authenticated Workers/D1 path.
- One Muse VM Python polling worker and one allowlisted deterministic task.
- Prove bounded text read/write in D1 and larger private-file read/write in Google Drive.
- Validate job/result contracts and one complete run lifecycle.
- Use API/CLI or a diagnostic view; a polished UI is not required.

Exit: a repeatable job submission → claim → Python execution → artifact persistence → result retrieval path, including restart/failure evidence.

### MVP — dependable daily-use workspace
- Full authenticated dataset/job/run/artifact API and minimal Vanilla JS + SVG workspace.
- Reliable Muse VM runner with heartbeat, timeout, cancellation, retry-as-new-attempt, and restart recovery.
- Dataset catalog, logs, artifact preview/download, and provenance.
- Local DuckDB worksheet for CSV/JSONL/Parquet.
- Automated CI tests across schema, D1, API, storage, runner, and UI.

Exit: a small trusted team can run and inspect real work without shell access or direct database edits.

### MAX — capability and operations expansion
- Verified Kaggle/Colab adapters and multiple Python workers with capability-aware routing.
- Operational resilience, concurrency/quotas, audit/retention, and observability.
- Richer analytics and reusable Python task packages.
- Multi-user governance and performance targets defined from measured workloads.

Exit: each added capability meets an explicit SLO or acceptance target. More integrations alone do not constitute MAX.

## 16. Open decisions

1. Which Vanilla JavaScript module and SVG component conventions should the UI standardize on?
2. Should the first SQL worksheet run only DuckDB locally, or support remote DuckDB jobs too?
3. What authentication source should browser users and agents use?
4. Which datasets/results fit D1's bounded text-payload path, and which must use Google Drive?
5. Which Colab/Kaggle workflow is acceptable: API-driven dispatch, notebook template/manual handoff, or both?
6. Which task types are allowed first: predefined tasks only, or trusted Python bundles?

## 17. Fixed implementation constraints

- Storage choices are D1 or Google Drive only. R2 is out of scope.
- Compute choices are Python environments on Kaggle, Colab, or Muse VM only.
- UI implementation is Vanilla JavaScript + SVG only; no React, Vue, Svelte, or other frontend framework.
- Muse VM runs a Python polling worker; do not introduce a Go orchestrator.
- The API/control plane may use Cloudflare Workers, but all user workloads execute in the selected Python environment.

## 18. Implementation guardrails

- Inspect the existing repository before selecting or replacing its stack.
- Treat this PRD as product behavior authority; record architecture decisions separately in ADRs.
- Do not use D1 as an unlimited bulk-file store; use Google Drive for larger files.
- Do not promise unattended Colab/Kaggle execution before an end-to-end test.
- Never add R2, a non-Python workload runtime, or a UI framework without an explicit change to these constraints.
- Build one complete local execution path before adding languages or remote runners.
- Add schema migrations and contract tests before expanding the UI.
