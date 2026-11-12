# D1 metadata and small-payload store

Related: #3, d1/schema.sql, ADR-001

## Role

D1 stores:
- dataset catalog and storage references
- jobs, runs, events, and runner registry
- artifact metadata and references
- deliberately small text payloads when storage_backend is d1

D1 is not an unlimited file store or an analytical warehouse. Larger datasets, Parquet files, notebooks, archives, and large logs belong in Google Drive. Python environments perform analytical scans.

## Apply schema

```bash
wrangler d1 execute yukidaruma --file=./d1/schema.sql
wrangler d1 execute yukidaruma --local --file=./d1/schema.sql
```

## Storage policy

- Dataset metadata always lives in D1.
- Small UTF-8 text payloads may be stored in dataset_contents with an explicit byte limit enforced by the API.
- Google Drive stores larger files. Save the Drive file ID and metadata in D1; do not store public share links as canonical references.
- The initial payload threshold is intentionally configurable and must be validated against current D1 limits before implementation.

## Migration policy

1. schema.sql is the greenfield source of truth.
2. Additive changes preferred.
3. Breaking changes require numbered migration files under d1/migrations/.
4. Do not add R2 bindings, bucket names, or R2 credentials.

## Operational checks

- [ ] API enforces the configured D1 inline payload byte limit.
- [ ] Google Drive OAuth tokens remain server-side.
- [ ] D1 claim operation is atomic and creates one run per attempt.
- [ ] All timestamps are UTC ISO-8601.
