# Python worker protocol, state machine, and threat model

Related: #6, ADR-001, schemas/job.schema.json, schemas/result-manifest.schema.json

## Roles

| Role | Responsibility |
|---|---|
| Workers API | Authenticate, validate, persist jobs in D1, issue job-scoped storage access |
| Python worker (Muse VM) | Poll, claim, heartbeat, launch Python task, report events and completion |
| Python execution environment | Execute one attempt on Muse VM, Kaggle, or Colab |
| Storage adapter | Read/write bounded D1 text or Google Drive files |

There is no Go orchestrator. All user workloads run in Python environments.

## Job and run state machine

    queued -> claimed -> dispatched -> running -> succeeded
                                         |-> failed
                                         |-> timed_out
    queued -> cancelled
    claimed/dispatched/running -> cancel_requested -> cancelled

Terminal states are succeeded, failed, cancelled, and timed_out. A retry creates a new attempt; it does not reopen a terminal run.

Rules:
1. Exactly one runner owns an active attempt; claim is atomic in D1.
2. Terminal -> running is forbidden.
3. Cancellation is cooperative; force a terminal cancellation after the configured grace period.
4. Stale heartbeat is reconciled by the API/worker lease policy, not by a separate Go service.
5. Completion with the same manifest is idempotent.

## Muse VM polling loop

    while true:
        POST /v1/runners/heartbeat
        POST /v1/runners/claim
        if a job is returned:
            validate job contract and Python target
            resolve D1 or Google Drive inputs
            execute the allowlisted Python task
            store small text results in D1 or larger files in Google Drive
            POST /v1/runs/{id}/events
            POST /v1/runs/{id}/complete
        else:
            sleep(poll_interval)

The Muse worker uses outbound HTTPS only. No public inbound listener is required.

## Remote Python environments

Kaggle and Colab use the same logical contract:
- validate target and environment capability;
- hand off or dispatch only through a currently supported platform mechanism;
- report manual/unavailable rather than pretending a job was dispatched;
- collect outputs into Google Drive or bounded D1 text storage;
- report the result manifest idempotently.

Remote sessions and free compute are best-effort and may be interrupted.

## Heartbeat

- Recommended interval: 30 seconds.
- Initial stale threshold: 120 seconds, configurable.
- Payload: runner_id, status, Python version, supported targets, optional load metrics.

## Error taxonomy

| Code | Retryable | Meaning |
|---|---|---|
| validation_error | no | invalid contract or unsupported task |
| storage_read_failed | yes | D1/Drive input could not be read |
| exec_failed | depends | Python process returned non-zero |
| storage_write_failed | yes | result could not be persisted |
| timeout | yes | resources.timeout_seconds exceeded |
| cancelled | no | cooperative cancellation |
| stale_heartbeat | yes | worker lease expired |

## Threat model

Assets:
- D1 metadata and bounded text payloads
- Google Drive files and OAuth credentials
- job parameters and execution environments
- user and runner API tokens

| Threat | Mitigation |
|---|---|
| Google Drive token theft | OAuth tokens server-side, narrow scopes, rotation |
| Publicly exposed data | Use private Drive files; file IDs are not authorization |
| D1 oversized payload | API byte limit and format allowlist |
| Job payload secrets | Forbid credentials in schemas and redact logs |
| Untrusted Python code | Allowlisted task types/trusted bundles; isolate process and enforce limits |
| Claim race | Atomic D1 claim and unique (job_id, attempt) |
| Runner impersonation | Distinct runner-scoped tokens |
| Remote notebook supply chain | Treat remote outputs as untrusted until validated |

## Adapter interface

    validate(job) -> ok | error
    submit(job) -> platform_ref | manual_required
    status(platform_ref) -> state
    cancel(platform_ref) -> ok | unsupported
    collect(platform_ref) -> manifest

Until an adapter passes end-to-end tests, the UI shows manual or unavailable, never ready.
