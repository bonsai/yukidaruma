# Workers API specification (MVP)

Related: #5, PRD §11, `docs/runner-protocol.md`

Base path: `/v1`  
Auth: `Authorization: Bearer <token>`  
User tokens vs runner tokens are distinct scopes.

All timestamps UTC ISO-8601. IDs opaque strings.

## Conventions

- JSON request/response
- Errors: `{ "error": { "code": "...", "message": "...", "details": {} } }`
- Pagination: `?cursor=&limit=` (limit default 50, max 200)
- Idempotency: `Idempotency-Key` header or body `idempotency_key` on `POST /jobs`

## Datasets

| Method | Path | Scope | Description |
|--------|------|-------|-------------|
| POST | `/datasets` | user | Register dataset metadata |
| GET | `/datasets` | user | List (exclude archived by default) |
| GET | `/datasets/{id}` | user | Detail |
| PATCH | `/datasets/{id}` | user | Update metadata |
| POST | `/datasets/{id}/archive` | user | Soft-archive |

### POST /datasets body

```json
{
  "name": "usage_logs",
  "description": "optional",
  "uri": "r2://yukidaruma/datasets/ds_x/v1/data.parquet",
  "format": "parquet",
  "size_bytes": 12345,
  "checksum": "sha256:…",
  "schema_json": { },
  "tags": ["prod"]
}
```

## Jobs

| Method | Path | Scope | Description |
|--------|------|-------|-------------|
| POST | `/jobs` | user | Submit job (body = job.schema.json) |
| GET | `/jobs` | user | List |
| GET | `/jobs/{id}` | user | Detail + latest run summary |
| POST | `/jobs/{id}/cancel` | user | Request cancel |
| POST | `/jobs/{id}/retry` | user | New attempt from same payload |
| GET | `/jobs/{id}/events` | user | Event history |

### POST /jobs

- Validate against `schemas/job.schema.json`
- Persist **before** 201 response
- State starts as `queued`
- Reject secrets in payload (best-effort heuristics)

## Runs & artifacts

| Method | Path | Scope | Description |
|--------|------|-------|-------------|
| GET | `/runs/{id}` | user | Run detail |
| GET | `/runs/{id}/artifacts` | user | Artifact list |
| POST | `/runs/{id}/events` | runner | Progress / state | 
| POST | `/runs/{id}/complete` | runner | Terminal + manifest |

### POST /runs/{id}/complete body

Must validate against `schemas/result-manifest.schema.json` (or subset). Idempotent.

## Runners

| Method | Path | Scope | Description |
|--------|------|-------|-------------|
| POST | `/runners/register` | runner | Register/update capabilities |
| POST | `/runners/heartbeat` | runner | Liveness |
| POST | `/runners/claim` | runner | Atomically claim next eligible job |

### POST /runners/claim

Request:

```json
{
  "runner_id": "muse-vm-1",
  "max_jobs": 1,
  "capabilities": { "language": ["python"], "gpu": false }
}
```

Response 200 with job + attempt + temporary input/output access, or 204 if none.

Claim must be atomic: one runner wins; creates `runs` row with `attempt`.

## Auth scopes (MVP)

| Scope | Can |
|-------|-----|
| `user` | datasets, jobs (own/workspace), read runs |
| `runner` | register, heartbeat, claim, run events, complete |
| `admin` | (later) all runners, retention |

Revoked tokens must fail subsequent calls.

## Implementation notes

- Prefer D1 batch/transaction for claim + job state update
- Never return storage secrets in JSON
- Signed artifact URLs: short TTL query params only in dedicated download endpoints if needed
