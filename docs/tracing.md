# Tracing Design — Langfuse

- Status: Draft (design only — no instrumentation code exists yet)
- Date: 2026-11-13
- Related: [PRD.md](PRD.md), [ADR-001](adr/001-mvp-architecture.md), [ADR-002](adr/002-storage-compute-ui.md), [architecture.puml](architecture.puml)
- Reference: Langfuse tracing best practices — https://langfuse.com/docs/observability/best-practices (re-fetch and re-check when implementing; this guidance changes over time)

## 1. Decision

Yukidaruma uses **Langfuse Cloud** as its observability plane for execution traces.

Roles stay separate:

| System | Role |
|---|---|
| D1 | Job state and control-plane records (catalog, jobs, runs, events, artifact references) plus bounded small text payloads. The authority for job lifecycle. |
| Google Drive | Larger datasets, code bundles, logs, notebooks, and generated artifacts. |
| Langfuse | Observability: traces of job executions and any LLM calls inside them. |

Langfuse is **not** a job-state store and **not** a dataset store. A missing or delayed trace never changes a job's state; D1 remains authoritative. Tracing is best-effort telemetry layered on top of the job protocol (PRD §12).

The same Langfuse project also receives the OpenRouter Traces destination: LLM calls that any client makes **through OpenRouter** appear in Langfuse via that integration. Yukidaruma-side traces cover the **job lifecycle** around those calls. Both views live in one project so an operator can move between "what did the job do" and "what did the model call cost" without switching tools.

## 2. Trace model

**One job execution = one trace.** A trace is one self-contained unit of work (one run attempt of one job). A retry is a new attempt and therefore a new trace; attempts are correlated through metadata (`job_id`, `attempt`), not by merging traces.

### Root observation

The root observation is created by the Python worker that executes the job, in the same process, at the moment its claim succeeds (see §5). Its name is derived from the task type, verb-first:

| Job `task` | Root span name |
|---|---|
| `python_script` | `run-python-script` |
| `sql_query` | `run-sql-query` |
| `notebook` | `run-notebook` |
| `analyze_dataset` | `analyze-dataset` |
| `transform` | `run-transform` |

A job may override the root name via `observability.trace_name` in the job contract (§6), subject to the naming rules in §3.

Trace-level input and output are taken from the root observation, so they are set deliberately:

- **Input**: a reviewer-readable summary of the job — task type, input dataset references (IDs and storage references, not contents), code revision, and parameters with secrets excluded.
- **Output**: the result summary — terminal state, artifact names/formats/sizes from the result manifest, row counts where the task produces them, and the error category on failure.

Raw payloads (full parameter objects, full logs) go in metadata or stay in the run's stored artifacts (D1 bounded payloads or Google Drive files); they are not the trace input/output.

### Child observations

Child spans follow the job's execution stages as named in PRD §5/§7 (poll → claim → fetch inputs → execute → store results → report). Each is a `span` unless a more specific observation type applies:

| Span name | Type | Content |
|---|---|---|
| `claim-job` | span | Atomic claim via the API: job and attempt assigned to this worker |
| `fetch-inputs` | span | Dataset IDs and storage references fetched (D1 or Google Drive), bytes, duration |
| `execute-task` | span | The Python task run itself; parent of any generations |
| `store-results` | span | Result artifacts written: bounded text persisted to D1, larger files uploaded to Google Drive (names, sizes, checksums) |
| `report-result` | span | Events and the completion manifest reported to the API; terminal state |

LLM calls made by the task's Python code (for example a summarisation or classification step inside a task) are **`generation`** observations, one per model invocation, nested under the step that requested them:

- model name set exactly as the provider names it (drives automatic cost calculation),
- input/output token usage recorded,
- input/output set to the messages the model saw and produced, subject to the data policy in §7,
- never collapse a loop of LLM calls into a single parent generation — each invocation is its own generation so per-step cost and decisions stay visible.

Dataset lookups that feed a model call are `retriever` observations where the framework supports the type; tool-style helper calls use the most specific type available rather than a generic span. Noisy internals (raw HTTP calls, DuckDB query internals, SDK retries) are **not** traced — filter them out; the trace tree should read as what the job did, not how the libraries work.

### Sessions

Jobs are independent by default and do not use sessions. When a higher-level workflow submits several jobs as one logical unit (for example a multi-step analysis pipeline), the submitter sets `observability.session_id` to the workflow's ID so the jobs' traces group into one session. Do not invent session IDs for single jobs.

## 3. Naming rules

Trace and observation names are an API: dashboards, saved views, and evaluators reference them, and renaming silently breaks those references. Therefore:

- Verb-first, lowercase, hyphenated (`fetch-inputs`, `generate-summary`).
- **Stable and low-cardinality.** A name identifies the operation, never one execution of it.
- **No dynamic values in names** — no job IDs, run IDs, dataset IDs, model names, or retry counts in names. Those belong in metadata, tags, or (for models) the generation's model attribute.
- Names do not change once shipped; add a new name for a genuinely new operation instead of renaming.

## 4. Metadata and tags

### Metadata (on the root observation; propagate key fields to children)

| Key | Value |
|---|---|
| `job_id` | Job ID assigned by the API |
| `run_id` | Run/attempt record ID |
| `attempt` | Attempt number for this job |
| `runner_id` | Executing runner (worker or remote environment identity) |
| `dataset_ids` | Input dataset IDs (list) |
| `code_revision` | Git SHA or version string of the executed code bundle |
| `idempotency_key` | Client idempotency key, when supplied |

Metadata is the place for run-specific context a reviewer or a filter needs. Anything needed to reproduce or debug the run that is not a name, tag, or the readable input/output belongs here.

### Tags (set at creation; tags are immutable afterwards)

| Tag source | Example |
|---|---|
| Task type | `task:python_script` |
| Requested runtime target (`runtime.target` in the job contract) | `runtime_target:muse_vm` |
| Adapter used, when a remote adapter executed the job | `adapter:colab` |

Tags answer breakdown questions ("cost/latency by task type", "failures by runtime target"). Job-level `tags` and `observability.tags` from the job contract are merged into the trace tags in addition to the derived ones above.

### Environment

Every trace sets the environment attribute (`production`, `staging`, `development`) from the deployment's configuration, so development and test runs never pollute production dashboards.

## 5. Ownership — the Python worker, in one process

Yukidaruma's fixed constraints (PRD §17, ADR-001) put a **Python polling worker** on the Muse VM — there is no Go orchestrator and no second workload runtime. The tracing design follows from that: a trace never spans processes or languages.

- The Muse VM worker **owns the trace end-to-end in one process**. It creates the root observation when its atomic claim of a job succeeds, emits the stage spans of §2 around the work it performs (claim, fetch, store, report), and closes the trace after it reports the completion manifest.
- The Python task process is launched by the worker on the same VM; any generations for LLM calls made by the task belong to the same trace, nested under `execute-task`. Trace context is the worker's own in-process context (handed to the task launcher locally), so **no cross-service trace-context propagation (W3C `traceparent`, OTLP bridges, or similar) is part of this design**. If a future component in another language ever needs to join a trace, that requires an explicit constraint change first (PRD §17/§18).
- Instrumentation uses the official **Langfuse Python SDK v3** (OpenTelemetry-based) with `@observe` decorators, or the SDK's context managers where decorators do not fit. **Prefer framework integrations** (OpenAI, LangChain, LlamaIndex, etc.) over manual instrumentation when the task code uses such a framework — integrations capture model, usage, and observation types automatically. Pin the exact SDK version in the worker's dependency manifest when implementing; use the latest v3 release at that time.

### Remote environments (Kaggle / Colab)

All targets run the same versioned Python job contract, so the same instrumented worker code produces the same trace shape (root + stages) when a job executes inside Kaggle or Colab and Langfuse credentials are present in that environment; the `runner_id` metadata and the `runtime_target`/`adapter` tags record where it ran. A manual-handoff run records in metadata that tracing was `unavailable` rather than silently producing a partial trace.

### Edge API (Workers)

The Workers API does not emit Langfuse traces in the MVP. It records `job_id` (and, once the worker reports it, the run's trace ID — see §6) in D1 so the UI can deep-link from a run to its Langfuse trace. Revisit only if API-side latency tracing becomes a stated need.

## 6. Configuration and contract

### Environment variables (every environment that emits traces)

```
LANGFUSE_PUBLIC_KEY   pk-lf-...
LANGFUSE_SECRET_KEY   sk-lf-...
LANGFUSE_HOST         https://cloud.langfuse.com   (EU cloud; US cloud differs)
```

- Keys are per-environment secrets, stored in the platform secret store (Cloudflare secrets / VM secret storage / the remote platform's secret mechanism), never in the repository, never in fixtures, and **never in job payloads** (the job contract already forbids credentials in payloads — PRD §9).
- If the variables are absent, tracing is silently disabled and the job still runs. Tracing must never block or fail a job.

### Job contract (`schemas/job.schema.json`)

The optional `observability` object carries submitter intent only:

| Field | Meaning |
|---|---|
| `session_id` | Group this job's trace into a workflow session (§2) |
| `tags` | Extra trace tags, merged with the job's own `tags` and the derived tags (§4) |
| `trace_name` | Override of the default root span name (§2); must follow the naming rules (§3) |

The worker reports the resulting Langfuse trace ID back with its completion report so the API can store it on the run record and the UI can link to the trace. (Extending `schemas/result-manifest.schema.json` with a `trace_id` field is part of implementing this design; the manifest schema is intentionally not changed by the design itself.)

## 7. Data policy

Metadata-only by default, consistent with PRD §12 ("Avoid storing prompts or sensitive dataset rows in operational logs by default"):

- **Never** trace raw dataset rows, file contents, or credentials.
- Trace input/output are the summaries defined in §2 — dataset references and parameters (secrets excluded), result/manifest summaries.
- Generation input/output (prompt and response bodies) are recorded **only** when the task's owner has explicitly enabled content capture for that task type; the default is usage/model metadata without bodies. This mirrors the standing decision to keep prompt/response logging off unless deliberately turned on.
- Full payloads needed for debugging go in metadata only when they contain no dataset content and no secrets; otherwise they stay with the run's stored artifacts (D1 bounded payloads or Google Drive) under the platform's access control.

## 8. Acceptance — the audit loop (once worker code exists)

Instrumentation is not done when it compiles. For the first instrumented worker:

1. Run a representative job end-to-end so a real trace is sent.
2. Fetch that trace from Langfuse (`langfuse-cli`, REST API, or SDK) and open it in the Langfuse UI.
3. Audit it against the current best-practices page (re-fetch it; do not audit from memory):
   - root name follows §3; input/output are the readable summaries from §2;
   - every stage is present with the right observation type;
   - every LLM call is its own `generation` with model and token usage (cost calculates);
   - metadata keys from §4 are present; tags and environment are set;
   - no dataset rows, secrets, or noisy internal spans appear.
4. Fix every gap found, re-run, and re-fetch to confirm.
5. Record the final trace ID in the run record and link it in the implementation PR or issue.

Repeat the loop for each new task type's first trace.
