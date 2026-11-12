# ADR-002 — Storage, compute and UI constraints (user decision)

- Status: Accepted
- Date: 2026-11-13
- Decided by: user
- Amends ADR-001 (object store); resolves ADR-001's deferred frontend decision

## Context

The user set hard constraints for Yukidaruma (2026-11-13):

- Data lives in **Cloudflare D1 or Google Drive** — no new object store as the primary dataset location
- Compute runs on **Kaggle, Colab, or a Python environment on the Muse VM**
- The UI is **vanilla JavaScript + SVG only**

## Decision

| Question | Choice |
|---|---|
| Storage | D1 for control plane. Datasets / manifests on **Google Drive** (the .metadata flow already lives there). R2 is optional (edge artifact cache), not the primary dataset location |
| Compute | **Kaggle / Colab / Python env on Muse VM** — all three are first-class runner targets (Kaggle and Colab promoted from P1 adapters) |
| UI | **Vanilla JavaScript + SVG only.** No frameworks, no bundler, no chart libraries — charts are hand-built SVG |

## Consequences

**Positive**
- Datasets stay in the ecosystem where the metadata ML line already works (.metadata on Drive)
- No build step and no dependency churn for the UI; hand-built SVG charts double as exportable artifacts
- Kaggle/Colab promoted: the job contract must be runnable there from day one

**Negative / constraints**
- No framework conveniences (state management, charting) — more hand-rolled code
- Google Drive is not addressable from Workers at runtime without an API layer — datasets on Drive are fetched by runners (VM / Kaggle / Colab), not by the edge API
- R2's role shrinks to optional artifact caching

## Relation to ADR-001

- Object store row amended: R2 → optional; Google Drive primary for datasets
- Frontend framework non-decision resolved: vanilla JS + SVG
- Compute unchanged in principle, but Kaggle/Colab are promoted from "P1 best-effort adapters" to first-class targets
