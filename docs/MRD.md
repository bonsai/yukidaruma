# MRD — Yukidaruma

- Status: Draft
- Date: 2026-11-12
- Repository: https://github.com/bonsai/yukidaruma

## 1. Executive summary

Yukidaruma is a lightweight, Snowflake-inspired analytics workbench for personal and small-team use. It provides one place to register datasets, submit analytical jobs, inspect execution history, and explore results while delegating compute to the most suitable available runtime.

Yukidaruma is not a cloud data warehouse and does not attempt to reproduce Snowflake's storage engine, SQL engine, governance suite, or enterprise workload management. It separates the control plane from compute:

- Cloudflare D1 stores catalog metadata, job definitions, state transitions, and references.
- Cloudflare D1 stores metadata, job state, and deliberately small text-based data payloads.
- Google Drive stores larger datasets, code bundles, logs, and result artifacts.
- Kaggle, Colab, and the Muse Ubuntu VM provide Python execution environments.
- A Python worker on Muse VM polls the control-plane API; there is no Go orchestration service.
- The UI is restricted to Vanilla JavaScript + SVG.

**Promise:** submit work once, run it where it makes sense, and keep its data, status, and results discoverable in one workspace.

## 2. Problem and opportunity

Analytical work is commonly spread across notebooks, scripts, cloud notebooks, local machines, object storage, and ad-hoc logs. Users struggle to discover datasets, reproduce jobs, compare runs, and collect results. AI agents can generate analysis but often lack a consistent interface for requesting compute and receiving structured results.

Yukidaruma offers a small, composable control plane that makes heterogeneous compute feel like one workspace without owning every compute engine.

## 3. Target users

### Primary
- Individual developers and technical creators running analytics, ETL, experiments, and ML jobs.
- AI-agent builders who need a stable interface to delegate work to local or hosted compute.
- Small teams that want reproducible jobs without adopting a full enterprise warehouse.

### Secondary
- Researchers and educators using public datasets and notebook workflows.
- Operators combining local CPU work with occasional hosted GPU sessions.

### Not initial targets
- Enterprises requiring formal compliance certifications, enterprise SSO, contractual SLAs, or large-scale warehouse concurrency.
- Users expecting guaranteed always-on free GPU capacity.
- Workloads requiring a managed distributed SQL engine in the first release.

## 4. Jobs to be done

1. Register a dataset with its location, format, schema, version, and provenance.
2. Submit an analysis using a portable job specification.
3. Run lightweight work on the Muse VM.
4. Route suitable work to Colab or Kaggle when available.
5. Inspect status, logs, metrics, and output artifacts in one place.
6. Let an AI agent request work through the same auditable API as a human.
7. Revisit a run and identify its exact inputs, code revision, parameters, and runtime.

## 5. Market positioning

| Alternative | Strength | Yukidaruma opportunity |
|---|---|---|
| Snowflake / BigQuery | Managed warehouse, SQL, governance, scale | Less operational and commercial weight for personal workflows |
| Jupyter / Colab / Kaggle | Notebook and experiment environments | Unified catalog, orchestration, and cross-runtime history |
| DuckDB / Polars | Fast local analytical execution | Add job management, multi-runtime dispatch, and discoverability |
| Airflow / Prefect / Dagster | Workflow orchestration | Smaller surface area for personal analytics |
| GitHub Actions | Reproducible automation and CI | Interactive analytics workspace and result browsing |

Yukidaruma should integrate with these tools rather than replace them.

## 6. Value proposition

- One control plane for catalog, jobs, runs, and artifacts.
- Pluggable compute across VM, Colab, Kaggle, and future runners.
- Portable contracts that isolate runtime-specific details.
- Inspectable execution with provenance and outputs.
- Agent-ready API shared by humans and automation.
- Cost-aware routing while clearly communicating that free compute is best-effort.

## 7. Product principles

1. Metadata is not bulk data: D1 is the control-plane database, not the analytical warehouse.
2. Storage is limited to D1 or Google Drive: D1 for metadata/small text payloads, Google Drive for larger files.
3. Compute is replaceable across Kaggle, Colab, and Muse VM Python environments using one job contract.
4. UI remains framework-free: Vanilla JavaScript + SVG only.
4. Prefer pull-based connectivity: the Muse VM polls for work; inbound VM ports are not required.
5. Colab and Kaggle are best-effort adapters, not guaranteed compute services.
6. Build one dependable local runner before remote notebook automation.
7. Preserve provenance: inputs, code revision, parameters, runtime, and timestamps.
8. Secure by default: no secrets in Git, job payloads, logs, or artifacts.

## 8. Business and sustainability model

Initial use is personal and experimental. Minimize fixed infrastructure cost by using Cloudflare services where practical and existing compute resources where available.

Potential future directions, not MVP commitments:
- hosted multi-user workspaces,
- managed runner integrations,
- team collaboration and access controls,
- usage and cost reporting,
- self-hosted distribution.

No revenue target or pricing commitment is set for the MVP.

## 9. Success metrics

- Time from deployment to first successful local job.
- Percentage of users who register a dataset and complete a job.
- Successful completion rate by runner type.
- Percentage of runs with complete provenance and retrievable artifacts.
- Time to find a prior run and its outputs.
- Local versus remote execution distribution.
- Cost per completed job where measurable.

MVP outcome: a user can register one dataset, submit a local Python job, inspect its run, and retrieve its output without manually editing D1 or accessing the VM shell.

## 10. Risks and constraints

| Risk | Impact | Mitigation |
|---|---|---|
| Colab/Kaggle quota or API changes | Remote jobs may not start or may be interrupted | Best-effort adapters, timeout, retry policy, manual handoff |
| Muse VM unavailable | Dispatch pauses | Persist queued jobs in D1 and resume polling after reconnect |
| D1 unsuitable for large payloads or analytical scans | Size/performance limits | Keep D1 payloads small; use Google Drive for larger files and Python libraries for analysis |
| Storage permissions misconfigured | Data exposure or failed runs | Scoped credentials, short-lived access, least privilege |
| Runtime mismatch | Non-reproducible outputs | Capture environment, dependency lock, code revision, parameters |
| Too many implementation languages | Maintenance burden | Keep user workloads in Python; Workers is the control-plane runtime |
| Free compute is not guaranteed | Unpredictable completion time | Show availability and fallback/manual states |

## 11. Scope boundary

This MRD establishes the market opportunity, target users, and product requirements. Detailed behavior, APIs, entities, acceptance criteria, and delivery phases are defined in PRD.md.

## 12. Fixed technical constraints

- Storage: Cloudflare D1 or Google Drive only; no R2.
- Compute: Python environments on Kaggle, Colab, or Muse VM.
- UI: Vanilla JavaScript + SVG only.
- Muse VM orchestration is a Python polling worker, not a Go service.
