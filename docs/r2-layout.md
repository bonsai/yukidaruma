# R2 object layout and access control

Related: #4, ADR-001

## Principles

- R2 holds **bytes**; D1 holds **references**.
- No long-lived credentials in job payloads or Git.
- Prefer short-lived signed URLs or scoped temporary credentials issued by Workers.
- Large previews stay in R2; API returns URIs + small samples only.

## Key layout

```
r2://yukidaruma/
  datasets/
    {dataset_id}/
      v{version}/
        data.{parquet|csv|jsonl}
        schema.json          # optional sidecar
  code/
    {bundle_id}/
      {revision}/
        bundle.tar.gz
  runs/
    {job_id}/
      {run_id}/
        manifest.json        # result-manifest.schema.json
        logs/
          stdout.log
          stderr.log
        artifacts/
          {name}
  worksheets/                # optional P1
    {worksheet_id}/
      latest.sql
      exports/
        {export_id}.parquet
```

## Naming rules

| Segment | Rule |
|---------|------|
| IDs | Opaque, URL-safe (`[a-z0-9_-]+` or ULID) |
| Versions | Explicit `v1`, `v2`, … or content hash |
| Checksums | SHA-256 hex when known; else omit / `unknown` in D1 |

## Access control

| Actor | Access |
|-------|--------|
| Workers API | Full bucket via server secret |
| Muse VM runner | Temporary read on inputs; temporary write on `runs/{job_id}/{run_id}/` |
| Browser / agent | No direct R2 credentials; get signed GET for specific URIs |
| Colab/Kaggle | Same as runner: short-lived scoped access only |

### Temporary access flow

1. Runner claims job.
2. Workers issue time-limited credentials or presigned URLs for listed input URIs + output prefix.
3. Runner fetches / uploads.
4. Credentials expire (default target: ≤ 2 hours; align with job timeout).

## Retention (MVP defaults)

| Object class | Retention |
|--------------|-----------|
| datasets | Until archived + optional grace period |
| run logs / artifacts | 90 days (configurable later) |
| manifests | Same as run artifacts |

## Anti-patterns

- Putting Parquet bodies in D1
- Embedding API keys in `manifest.json`
- Letting runners list the entire bucket
