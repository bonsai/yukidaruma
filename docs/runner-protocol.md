# Runner protocol, state machine, threat model

Related: #6, ADR-001, `schemas/job.schema.json`, `schemas/result-manifest.schema.json`

## Roles

| Role | Responsibility |
|------|----------------|
| **API (Workers)** | Accept jobs, validate, persist to D1, issue claim tokens / signed URLs |
| **Orchestrator (Go on Muse VM)** | Poll, claim, start local runner, forward heartbeats, report terminal state |
| **Runner** | Execute one attempt, upload artifacts + manifest, report success/failure |

Remote adapters (Colab/Kaggle) implement the same logical steps behind an adapter interface.

## Job / run state machine

### Job states

```
queued → claimed → dispatched → running → succeeded
                                    ↘ failed
                                    ↘ timed_out
queued → cancel_requested → cancelled
running → cancel_requested → cancelled
```

Terminal: `succeeded`, `failed`, `cancelled`, `timed_out`.

### Run states (per attempt)

```
claimed → dispatched → running → succeeded | failed | cancelled | timed_out
```

Rules:

1. **Single owner**: exactly one `runner_id` per active attempt; claim is atomic in D1.
2. **No resurrection**: terminal → running is forbidden.
3. **Cancel**: `cancel_requested` is cooperative; runner should stop when observed; force `cancelled` after grace period.
4. **Stale heartbeat**: if `heartbeat_at` older than threshold (default 120s), orchestrator marks attempt `timed_out` or `failed` with code `stale_heartbeat` and may requeue a new attempt per policy.
5. **Idempotent complete**: `POST /v1/runs/{id}/complete` with the same manifest is safe to retry.

## Poll / claim flow (Muse VM)

```
loop:
  POST /v1/runners/heartbeat
  POST /v1/runners/claim  { capabilities, max_jobs }
  if job:
    transition → claimed/dispatched
    fetch inputs (presigned)
    execute
    upload artifacts + manifest.json
    POST /v1/runs/{id}/complete
  else:
    sleep(poll_interval)
```

## Heartbeat

- Interval: 30s recommended
- Stale threshold: 120s (configurable)
- Payload: `runner_id`, `status`, optional load metrics

## Error taxonomy (runner → API)

| code | retryable | meaning |
|------|-----------|--------|
| `validation_error` | no | bad inputs / unsupported task |
| `download_failed` | yes | could not fetch input |
| `exec_failed` | depends | process non-zero exit |
| `upload_failed` | yes | could not write artifacts |
| `timeout` | yes | exceeded resources.timeout_seconds |
| `cancelled` | no | cooperative cancel |
| `stale_heartbeat` | yes | orchestrator intervention |

## Threat model (MVP)

### Assets

- Dataset contents in R2
- Job parameters (may contain sensitive business data)
- API tokens / runner credentials
- Execution environment on Muse VM

### Threats and mitigations

| Threat | Mitigation |
|--------|------------|
| Stolen long-lived R2 keys | No static keys on runners; short-lived scoped creds |
| Job payload secrets | Forbidden in contract; reject if detected patterns (best-effort) |
| Untrusted code execution | MVP: trusted bundles / allowlisted tasks only |
| Log leakage of secrets | Redact known secret patterns; never log presigned query strings in full |
| Claim race / double run | Atomic claim in D1; unique (job_id, attempt) |
| Runner impersonation | Runner-scoped tokens distinct from user tokens |
| Supply-chain notebook from Colab | Remote path is P1; treat outputs as untrusted until reviewed |

### Explicit non-goals for MVP

- Multi-tenant hard isolation (gVisor/Firecracker)
- Formal compliance attestations
- Guaranteed free GPU

## Adapter interface (logical)

```
validate(job) -> ok | error
submit(job) -> platform_ref | manual_required
status(platform_ref) -> state
cancel(platform_ref) -> ok | unsupported
collect(platform_ref) -> manifest  # idempotent
```

Until an adapter passes E2E, UI must show `unavailable` or `manual`, never `ready`.
