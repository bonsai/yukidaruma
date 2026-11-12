# Storage layout — D1 + Google Drive

Related: #4, ADR-001 (revised)

## Constraints

- **Allowed:** Cloudflare D1, Google Drive
- **Not required for MVP:** R2, S3, local-only disk as system of record
- D1 = control plane + small structured data
- Drive = datasets, code bundles, run logs, artifacts

## D1 (metadata)

See `d1/schema.sql`.

Store:

- dataset catalog (name, Drive file id / URL, format, checksum, schema summary)
- jobs, runs, events, runners
- artifact **references** (Drive file id, name, size, checksum)
- optional tiny previews (e.g. ≤ 50 rows JSON) if needed

Do **not** store Parquet/CSV bodies or large logs in D1.

## Google Drive (bytes)

Logical layout (folder names; implement via Drive folder IDs):

```
Yukidaruma/
  datasets/
    {dataset_id}/
      v{version}/
        data.parquet | data.csv | data.jsonl
        schema.json
  code/
    {bundle_id}/
      {revision}/
        bundle.tar.gz | main.py
  runs/
    {job_id}/
      {run_id}/
        manifest.json
        logs/
          stdout.log
          stderr.log
        artifacts/
          …
```

D1 columns should store `drive_file_id` (and optional webViewLink) rather than assuming `r2://` URIs.

### URI convention (job contract)

Prefer one of:

- `drive://file/{fileId}`
- `https://drive.google.com/file/d/{fileId}/…` (normalized to file id server-side)

Legacy `r2://` may appear in older drafts; treat as non-MVP.

## Access control

| Actor | Access |
|-------|--------|
| Workers API | Service account or OAuth for Drive metadata ops |
| Muse VM runner | Scoped access to job input files + run output folder |
| Colab | User/runtime already in Google ecosystem; pass file ids |
| Kaggle | Download via API/exported links; upload results back to Drive when possible |
| Browser | No raw service credentials; open Drive links or short-lived app proxy |

Secrets never go in job JSON or manifests.

## Size policy

| Kind | Where |
|------|--------|
| Catalog, state, events | D1 |
| Full datasets / artifacts | Drive |
| Result preview (small) | manifest / D1 JSON |

## Anti-patterns

- Large analytical tables only in D1
- Embedding OAuth refresh tokens in run artifacts
- Assuming free Drive quota is unlimited
