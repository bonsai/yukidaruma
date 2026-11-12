# Workers API specification (MVP)

Related: #5, PRD §11, docs/runner-protocol.md, docs/storage.md

Base path: /v1  
Auth: Authorization: Bearer <token>  
User tokens and runner tokens have distinct scopes.

All timestamps are UTC ISO-8601. IDs are opaque strings.

## Storage contract

Only two storage backends are supported:
- d1: small UTF-8 text payloads stored in dataset_contents; API enforces a configurable byte limit.
- google_drive: larger files stored in Google Drive; D1 stores the file ID and metadata.

Canonical references are d1://{dataset_or_artifact_id} and gdrive://{drive_file_id}. Do not use R2, public share URLs, or browser-visible OAuth credentials.

## Conventions

- JSON request/response.
- Structured errors: error.code, error.message, error.details.
- Pagination: ?cursor=&limit= (default 50, maximum 200).
- Idempotency: Idempotency-Key header or body idempotency_key on POST /jobs.

## Datasets

| Method | Path | Scope | Description |
|---|---|---|---|
| POST | /datasets | user | Register dataset metadata and storage reference |
| GET | /datasets | user | List datasets |
| GET | /datasets/{id} | user | Detail |
| PATCH | /datasets/{id} | user | Update metadata |
| POST | /datasets/{id}/archive | user | Soft archive |
| GET | /datasets/{id}/content | user | Read bounded D1 text content or stream/download Drive file |

Example metadata:

    {
      "name": "usage_logs",
      "storage_backend": "google_drive",
      "storage_ref": "gdrive://1abc...",
      "format": "parquet",
      "size_bytes": 12345,
      "checksum": "sha256:..."
    }

For D1 inline text, register storage_backend=d1 and write UTF-8 content through the content endpoint. The API must reject payloads above the configured limit.

## Jobs

| Method | Path | Scope | Description |
|---|---|---|---|
| POST | /jobs | user | Submit job (job.schema.json) |
| GET | /jobs | user | List |
| GET | /jobs/{id} | user | Detail + latest run |
| POST | /jobs/{id}/cancel | user | Request cancellation |
| POST | /jobs/{id}/retry | user | Create a new attempt |
| GET | /jobs/{id}/events | user | Event history |

POST /jobs validates schemas/job.schema.json and persists before returning 202. State starts as queued. Secrets are forbidden in payloads. runtime.target is auto, muse_vm, colab, or kaggle; runtime.language is python only.

## Runs and artifacts

| Method | Path | Scope | Description |
|---|---|---|---|
| GET | /runs/{id} | user | Run detail |
| GET | /runs/{id}/artifacts | user | Artifact metadata |
| GET | /artifacts/{id}/content | user | Read small D1 artifact or download Drive file |
| POST | /runs/{id}/events | runner | Progress / state |
| POST | /runs/{id}/complete | runner | Terminal state + result manifest |

Completion validates schemas/result-manifest.schema.json and is idempotent. Each artifact declares storage_backend and storage_ref.

## Runners

| Method | Path | Scope | Description |
|---|---|---|---|
| POST | /runners/register | runner | Register/update Python environment capabilities |
| POST | /runners/heartbeat | runner | Liveness |
| POST | /runners/claim | runner | Atomically claim next eligible job |

Claim request:

    {
      "runner_id": "muse-vm-1",
      "max_jobs": 1,
      "capabilities": {"language": ["python"], "targets": ["muse_vm"]}
    }

Response contains job, attempt, and only the storage references/permissions needed for that job; 204 means no work. Claim is atomic and creates one runs row per attempt.

## Auth scopes

| Scope | Can |
|---|---|
| user | datasets, jobs, read runs and artifacts |
| runner | register, heartbeat, claim, run events, complete |
| admin | later operational controls |

Revoked tokens fail subsequent calls. Google Drive tokens remain server-side. Browser receives application-scoped download responses, not OAuth refresh/access tokens.

## UI constraint

The browser UI is implemented using Vanilla JavaScript and SVG only. No frontend framework or charting dependency is assumed.
