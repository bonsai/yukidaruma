# Yukidaruma growth plan — POC → MVP → MAX

## Product principle

Grow one product through three maturity levels. Do not build three separate systems or throw away the POC. The local Python job established in POC becomes the first allowlisted task in MVP.

## Stage map

| Stage | Question answered | User promise | Exit gate |
|---|---|---|---|
| POC | Does the analysis loop work? | CSV in, deterministic Python result, table + SVG out | Local CSV → Python → CSV → browser table/SVG is repeatable |
| MVP | Can a person use it repeatedly? | Authenticated workspace with queued Python jobs and durable results | Muse VM runs the POC task through Workers/D1 and D1/Drive results can be reopened |
| MAX | Can it scale in capability and operations? | Multi-runner personal compute workspace | Measured capacity, recovery, governance, and remote-runner operation meet explicit targets |

## POC — prove the smallest vertical slice

**Goal:** prove the core analysis experience before adding infrastructure.

### Include
- Local CSV fixture.
- Deterministic Python standard-library task in `poc/job.py`.
- CSV output and small JSON summary.
- Vanilla JavaScript HTML page that renders a table and SVG chart.
- Automated Python tests for deterministic output and error handling.
- Short local run guide.

### Explicitly defer
- API, queue, authentication, D1, Google Drive, job history, agent API, Kaggle/Colab automation, and polished workspace navigation.

### POC acceptance
- [ ] Sample CSV produces deterministic sorted aggregation.
- [ ] Test verifies row counts, token totals, cost totals, and missing-input failure.
- [ ] Browser loads output CSV and displays table + SVG chart.
- [ ] No external Python or browser dependency is required.

Issue: [#12 POC-01](https://github.com/bonsai/yukidaruma/issues/12).

## MVP — make it useful every day

**Goal:** wrap the proven POC task in a reliable control plane and durable storage.

### Include
- Cloudflare Workers API + D1 metadata and bounded small UTF-8 text.
- Private Google Drive storage for larger inputs and artifacts; OAuth stays server-side.
- Authentication and scoped user/agent/runner credentials.
- Dataset catalog, job submission, idempotency, claim, run history, events, logs, and artifact manifests.
- Muse Ubuntu VM Python polling worker; outbound HTTPS only, no inbound listener.
- Heartbeat, lease expiry, timeout, cancellation, retry as a new attempt, and restart recovery.
- Vanilla JavaScript + SVG UI for Overview, Datasets, Jobs, Runs, Artifacts, and Runners.
- Authenticated preview/download; large data is paginated or sampled.
- Automated schema, D1, API, storage, runner, and end-to-end tests.

### MVP non-goals
- Enterprise multi-tenancy, billing, distributed SQL, guaranteed free GPU, arbitrary untrusted code execution, and unattended notebook automation.
- Kaggle/Colab automatic dispatch is optional and best-effort, not an MVP promise.

### MVP acceptance
- [ ] A user can register a dataset and reopen its metadata.
- [ ] A user or agent can submit a versioned job without direct D1 access.
- [ ] Muse VM claims one attempt and executes the POC Python task.
- [ ] Small text results use D1; larger artifacts use private Google Drive.
- [ ] Run, logs, manifest, and artifacts remain accessible after refresh.
- [ ] Cancellation, timeout, stale lease, and restart behavior are tested.
- [ ] Documented test command passes in CI.

## MAX — expand capability without changing the core

**Goal:** increase throughput, reach, governance, and analytical usefulness while preserving the same contracts and storage rules.

Candidate capabilities:
1. **Compute federation:** verified Kaggle/Colab adapters, multiple Muse workers, capability-aware routing, queue priorities, and concurrency limits.
2. **Operational resilience:** bounded retries, dead-letter handling, lease reconciliation, backpressure, recovery drills.
3. **Data workspace:** DuckDB SQL worksheets, saved queries, query history, reusable Python environments, and larger result exploration.
4. **Governance:** workspace/project roles, token rotation, audit export, retention, and data classification.
5. **Observability:** queue latency, run metrics, cost/resource estimates, worker health, and provenance.
6. **Extensibility:** versioned task packages, Python-native adapters, import/export, and documented extension points.

### MAX acceptance is target-driven
Before implementing each capability, define a measurable SLO (queue wait, job success rate, recovery time, preview limit, concurrent workers, etc.). More integrations alone do not constitute MAX.

## Shared architecture invariants

- Storage is Cloudflare D1 or Google Drive only. No R2.
- D1 stores metadata and bounded small UTF-8 text; larger files and artifacts use private Google Drive.
- Every dataset/artifact has explicit `storage_backend` and `storage_ref`; canonical refs are `d1://` and `gdrive://`.
- All workloads execute in Python environments. No Go orchestrator and no Rust workload runtime.
- Muse VM uses outbound polling; no inbound public listener is required.
- UI is Vanilla JavaScript + SVG only.
- Kaggle/Colab availability is best-effort until verified by end-to-end tests.
- D1 is the control plane, not the analytical SQL engine.

## Existing issue mapping

| Existing issue | POC | MVP | MAX |
|---|---|---|---|
| #1 ADR / architecture | Baseline | Maintain | Revisit only through a new ADR |
| #2 Job/result schemas | Defer runtime use | Validate fixtures + compatibility | Version evolution |
| #3 D1 schema | Not used | Apply + constraint tests | Scale/retention tuning |
| #4 Storage policy/adapters | Not used | Prove D1 + Drive read/write | Quotas and lifecycle |
| #5 Workers API | Not used | Submit/claim/complete + auth | Routing, governance, rate limits |
| #6 Runner protocol | Not used | Lifecycle, lease, recovery | Multi-runner coordination |
| #7 Muse polling worker | Not used | One outbound-only worker | Fleet operations |
| #8 Python task runner | Local `poc/job.py` | Reuse as allowlisted task | Package/runtime extensions |
| #9 Vanilla JS + SVG UI | One-page POC | Core workspace UI | Richer exploration |
| #10 End-to-end tests | Local deterministic tests | Full integration matrix | Load, resilience, recovery tests |
| #12 POC-01 | Implement and verify | Keep as regression fixture | Keep compatibility |

## Delivery rule

Work in dependency order, but keep each stage vertically testable. A stage is complete only when its exit gate is demonstrated by a reproducible test or recorded evidence, not merely when its documentation or issue is closed.
