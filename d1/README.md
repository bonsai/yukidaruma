# D1 control plane

Related: #3, `d1/schema.sql`, ADR-001

## Role

D1 stores **metadata only**:

- datasets catalog
- jobs / runs / events
- runners registry
- artifact **references** (URI, size, checksum)

Analytical scans run on DuckDB (local) or future engines — **not** on D1.

## Apply schema

```bash
# Example — adjust to your wrangler project layout
wrangler d1 execute yukidaruma --file=./d1/schema.sql
```

For local:

```bash
wrangler d1 execute yukidaruma --local --file=./d1/schema.sql
```

## Migration policy (MVP)

1. `schema.sql` is the source of truth for greenfield.
2. Additive changes preferred (new columns / tables).
3. Breaking changes require a numbered migration file under `d1/migrations/` (to be added when first needed).
4. Never store Parquet/CSV bodies or large logs in D1.

## Indexes

Defined in `schema.sql` for:

- job state / created_at / submitted_by
- unique idempotency_key (when present)
- runs by job_id and runner_id
- artifacts by run_id

## Operational checks

- [ ] `PRAGMA foreign_keys = ON` effective for connection
- [ ] Claim path uses a single transaction (update job + insert run)
- [ ] Stale heartbeat query uses `runs.heartbeat_at`
