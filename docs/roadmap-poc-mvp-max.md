# Yukidaruma growth plan — POC → MVP → MAX

## Product principle

Grow one product through three maturity levels. Do not build three separate systems or throw away the POC.

The contracts established in POC (job schema, result manifest, storage references, API resource model, and runner protocol) remain the compatibility boundary for MVP and MAX. Add capabilities behind those contracts; version a contract only when compatibility requires it.

## Stage map

| Stage | Question answered | User promise | Exit gate |
|---|---|---|---|
| POC | Can the complete path work? | Submit one Python job and retrieve its result | One deterministic job completes end-to-end through Workers + D1 + Python worker + storage |
| MVP | Can a person use it repeatedly? | A small, authenticated analytics workspace | A user can register data, submit jobs, inspect runs and artifacts, and reopen results reliably |
| MAX | Can it scale in capability and operations? | A durable multi-runner data/compute workspace | Measured capacity, recovery, governance, and remote-runner operation meet explicit service targets |

## POC — prove the vertical slice

**Goal:** retire the highest-risk integration questions with the smallest runnable system.

### Include
- One authenticated path through Cloudflare Workers and D1.
- Minimal D1 schema for datasets, jobs, runs, runner registration/heartbeat, and events.
- One Muse Ubuntu VM Python polling worker; outbound HTTPS only.
- One allowlisted deterministic Python task (for example, read a small input and emit a summary).
- Exercise both storage paths: bounded UTF-8 text in D1 and one larger artifact in private Google Drive.
- Versioned job and result-manifest schemas with fixtures.
- Minimal API/client or CLI-driven submission and status inspection; a polished UI is not required.
- Request/job/run/runner IDs and enough logs to diagnose the path.

### Explicitly defer
- Full workspace navigation, SQL editor, charts, notebook automation, Kaggle/Colab auto-dispatch, multi-user administration, advanced retries, quotas, and performance tuning.
- Do not claim Kaggle or Colab automation until each adapter has a passing end-to-end test. Manual handoff is acceptable.

### POC acceptance
- [ ] A valid job is persisted before acknowledgement.
- [ ] The Muse worker claims exactly one attempt and executes the deterministic Python task.
- [ ] The run reaches a terminal state and survives page refresh / API re-read.
- [ ] A small text result is written/read through D1.
- [ ] A larger private Drive artifact is uploaded and read back through the authenticated path.
- [ ] The manifest validates and includes storage_backend + storage_ref.
- [ ] VM restart leaves queued work intact; interrupted work is visible and recoverable.
- [ ] Secrets are absent from Git, payloads, browser responses, and logs.

**POC exit decision:** proceed only when the full vertical slice is repeatable and its failure modes are observable. If a platform dependency blocks the path, record it and keep that adapter manual/unavailable.

## MVP — make it useful every day

**Goal:** turn the proven vertical slice into the smallest dependable product for one operator / small trusted workspace.

### Include
- Authentication, scoped user/agent/runner credentials, revocation, and audit trail.
- Dataset catalog with metadata, provenance, format, checksum, and D1/Drive references.
- Job submit/list/detail, cancellation, retry as a new attempt, event history, and run detail.
- Reliable Muse VM Python worker with heartbeat, lease expiry, timeout, cancellation, and restart recovery.
- Result manifest, artifact catalog, authenticated preview/download, and bounded/paginated data views.
- Vanilla JavaScript + SVG UI for Overview, Datasets, Jobs, Runs, Artifacts, and Runners.
- Local Python analytics with DuckDB as the first SQL execution target; D1 remains control-plane storage, not the analytics engine.
- Automated tests for schemas, D1 constraints, API auth/idempotency/state transitions, storage adapters, worker lifecycle, and the happy path.
- Clear runtime capability labels: verified, manual, or unavailable.

### MVP non-goals
- Enterprise multi-tenancy, billing, distributed query execution, guaranteed free GPU, arbitrary untrusted code execution, and unattended notebook automation.
- Kaggle/Colab are optional best-effort execution targets, not MVP availability promises.

### MVP acceptance
- [ ] A user can register a dataset and reopen its metadata.
- [ ] A user or agent can submit a versioned job without direct D1 access.
- [ ] A Muse VM worker executes and reports reproducible runs.
- [ ] Cancellation, timeout, retry, stale lease, and restart behavior are tested.
- [ ] Logs and artifacts remain accessible after refresh and worker restart.
- [ ] DuckDB can query registered local/downloaded CSV, JSONL, and Parquet data.
- [ ] UI is framework-free Vanilla JS + SVG and does not load entire datasets into browser memory.
- [ ] Documented test command passes in CI.

**MVP exit decision:** a small team can use it for real work repeatedly without shell access or manual database edits.

## MAX — expand capability without changing the core

**Goal:** increase throughput, reach, governance, and analytical usefulness while preserving the same contracts and storage rules.

### Candidate capabilities (prioritize from measured demand)
1. **Compute federation:** verified Kaggle and Colab adapters, additional Muse workers, capability-aware routing, queue priorities, and concurrency limits.
2. **Operational resilience:** bounded retries, dead-letter handling, lease reconciliation, backpressure, maintenance windows, and recovery drills.
3. **Data workspace:** richer DuckDB workflows, saved worksheets, query history, reusable Python environments, and larger result exploration.
4. **Governance:** multi-user roles, project/workspace boundaries, token rotation, audit export, retention policies, and data classification.
5. **Observability:** run-level metrics, cost/resource estimates, queue latency, worker health, traceable provenance, and operational dashboards.
6. **Extensibility:** versioned task packages, Python-native adapters, import/export, and documented extension points.

### MAX acceptance is target-driven
Before implementing each capability, define a measurable SLO or acceptance target (for example queue wait, job success rate, recovery time, maximum preview size, or concurrent workers). Do not label the product MAX merely because more integrations have been added.

## Shared architecture invariants

- Storage is Cloudflare D1 or Google Drive only. No R2.
- D1 stores metadata and bounded small UTF-8 text; larger files and artifacts use private Google Drive.
- Every dataset/artifact has an explicit storage_backend and storage_ref; canonical refs are d1:// and gdrive://.
- All workloads execute in Python environments. No Go orchestrator and no Rust workload runtime.
- Muse VM uses outbound polling; no inbound public listener is required.
- UI is Vanilla JavaScript + SVG only.
- Kaggle/Colab availability is best-effort until verified by end-to-end tests.
- D1 is the control plane, not the analytical SQL engine.

## Existing issue mapping

| Existing issue | POC | MVP | MAX |
|---|---|---|---|
| #1 ADR / architecture | Baseline | Maintain | Revisit only through a new ADR |
| #2 Job/result schemas | Required fixtures | Compatibility tests | Version evolution |
| #3 D1 schema | Minimal tables | Full constraints/indexes | Scale/retention tuning |
| #4 Storage policy/adapters | Prove D1 + Drive read/write | Harden limits, auth, errors | Quotas and lifecycle |
| #5 Workers API | Minimal submit/claim/complete | Full authenticated API | Routing, governance, rate limits |
| #6 Runner protocol | Minimal lifecycle | Recovery/cancel/retry | Multi-runner coordination |
| #7 Muse polling worker | One worker | Reliable service | Fleet operations |
| #8 Python task runner | One allowlisted task | Reusable task execution | Package/runtime extensions |
| #9 Vanilla JS + SVG UI | Optional diagnostic view | Core workspace UI | Richer exploration |
| #10 End-to-end tests | One vertical-slice test | Full CI matrix | Load, resilience, recovery tests |

## Delivery rule

Work in dependency order, but keep each stage vertically testable. A stage is complete only when its exit gate is demonstrated by a reproducible test or recorded evidence, not merely when its documentation or issue is closed.
