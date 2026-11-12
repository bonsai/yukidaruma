from __future__ import annotations

import csv
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JOB = ROOT / "poc" / "job.py"
SAMPLE = ROOT / "poc" / "sample.csv"


class PocJobTests(unittest.TestCase):
    def test_aggregate_is_sorted_and_totals_are_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "out.csv"
            summary = Path(tmp) / "summary.json"
            result = subprocess.run(
                [
                    sys.executable, str(JOB),
                    "--input", str(SAMPLE),
                    "--output", str(output),
                    "--summary", str(summary),
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)

            with output.open(newline="", encoding="utf-8") as handle:
                rows = list(csv.DictReader(handle))
            self.assertEqual([row["model"] for row in rows], ["Claude", "GPT", "Gemini"])
            self.assertEqual(
                rows,
                [
                    {"model": "Claude", "count": "2", "tokens": "118", "cost_usd": "0.11"},
                    {"model": "GPT", "count": "3", "tokens": "183", "cost_usd": "0.17"},
                    {"model": "Gemini", "count": "2", "tokens": "104", "cost_usd": "0.07"},
                ],
            )

            data = json.loads(summary.read_text(encoding="utf-8"))
            self.assertEqual(data["row_in"], 7)
            self.assertEqual(data["row_out"], 3)
            self.assertEqual(data["task"], "aggregate_by_model")

    def test_missing_input_returns_nonzero(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            missing = Path(tmp) / "missing.csv"
            result = subprocess.run(
                [sys.executable, str(JOB), "--input", str(missing)],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("input not found", result.stderr)


if __name__ == "__main__":
    unittest.main()
