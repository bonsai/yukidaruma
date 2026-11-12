# Hard constraints

Revised: 2026-11-13

These override earlier R2 / SPA assumptions in drafts.

| Area | Allowed | Not required / out of MVP |
|------|---------|---------------------------|
| **Storage** | Cloudflare **D1** (metadata), **Google Drive** (files) | R2, S3 as system of record |
| **Compute** | **Muse VM**, **Colab**, **Kaggle** Python envs | Extra clusters, mandatory Rust runtime |
| **UI** | **Vanilla JS + SVG** | React / Vue / Svelte requirement |

See also: [ADR-001](adr/001-mvp-architecture.md), [storage-layout.md](storage-layout.md).
