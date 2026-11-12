# Storage model — D1 and Google Drive

Related: ADR-001, issues #3 and #4.

## Supported backends

Yukidaruma supports exactly two storage backends.

| Backend | Use | Canonical reference |
|---|---|---|
| D1 | Metadata and small UTF-8 text payloads (CSV/JSON/JSONL/text) | d1://{record_id} |
| Google Drive | Larger files, Parquet, notebooks, archives, code bundles, logs, and artifacts | gdrive://{file_id} |

R2 and other object stores are out of scope.

## Selection rule

1. Dataset and artifact metadata always live in D1.
2. Use D1 content storage only when the payload is text and below a configurable byte threshold.
3. Use Google Drive for binary formats, Parquet, archives, notebooks, large logs, and any payload above that threshold.
4. Store backend and reference separately; never infer the backend from a display name.
5. Do not use public Drive share URLs as canonical IDs.

The exact D1 inline threshold is a Phase 0 implementation decision: validate current Cloudflare D1 row/database limits and enforce a lower application-level limit. Do not claim unlimited or arbitrary binary storage in D1.

## Google Drive access

- Keep OAuth refresh/access tokens on the server side.
- Prefer the narrowest practical OAuth scope and private files.
- Use file IDs for references.
- The browser calls the authenticated Workers API; it does not receive Drive credentials.
- Handle missing, trashed, inaccessible, and quota-limited files as explicit errors.

## D1 content table

dataset_contents stores only small UTF-8 text payloads with byte_length and checksum. API validation must enforce the configured byte limit before insert/update. Binary payloads are not stored there.

## Artifact lifecycle

- Store artifact metadata in D1.
- Small text artifacts may store content in D1.
- Larger artifacts are created in Drive and referenced by file ID.
- Result manifest records storage_backend and storage_ref for every artifact.
- Repeated completion must not create duplicate artifact records.
