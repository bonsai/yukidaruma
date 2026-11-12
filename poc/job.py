#!/usr/bin/env python3
"""Yukidaruma POC job — csv in, csv + summary json out. Stdlib only."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import defaultdict
from pathlib import Path


def aggregate(rows: list[dict[str, str]]) -> list[dict[str, object]]:
    totals: dict[str, dict[str, float]] = defaultdict(lambda: {"tokens": 0.0, "cost_usd": 0.0, "count": 0.0})
    for row in rows:
        model = (row.get("model") or "").strip() or "unknown"
        totals[model]["tokens"] += float(row.get("tokens") or 0)
        totals[model]["cost_usd"] += float(row.get("cost_usd") or 0)
        totals[model]["count"] += 1
    out = []
    for model in sorted(totals.keys()):
        t = totals[model]
        out.append(
            {
                "model": model,
                "count": int(t["count"]),
                "tokens": int(t["tokens"]),
                "cost_usd": round(t["cost_usd"], 6),
            }
        )
    return out


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    if not rows:
        path.write_text("model,count,tokens,cost_usd\n", encoding="utf-8")
        return
    fieldnames = list(rows[0].keys())
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(rows)


def main() -> int:
    p = argparse.ArgumentParser(description="Yukidaruma POC aggregator")
    p.add_argument("--input", "-i", type=Path, default=Path("sample.csv"))
    p.add_argument("--output", "-o", type=Path, default=Path("out.csv"))
    p.add_argument("--summary", "-s", type=Path, default=Path("summary.json"))
    args = p.parse_args()

    if not args.input.exists():
        print(f"input not found: {args.input}", file=sys.stderr)
        return 1

    rows = read_csv(args.input)
    result = aggregate(rows)
    write_csv(args.output, result)

    summary = {
        "schema_version": "1.0",
        "task": "aggregate_by_model",
        "input": str(args.input),
        "row_in": len(rows),
        "row_out": len(result),
        "models": result,
    }
    args.summary.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({"ok": True, "output": str(args.output), "summary": str(args.summary), "rows": len(result)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
