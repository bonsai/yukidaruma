# Yukidaruma POC — csv → py → svg

台帳なし。ブラウザ + Python 標準ライブラリだけで一周する。

## 3 行手順

```bash
cd poc
python job.py -i sample.csv -o out.csv -s summary.json
# ブラウザで index.html を開き、out.csv を選択（または「sample 相当を試す」）
```

## ファイル

| ファイル | 役割 |
|----------|------|
| `sample.csv` | 入力例（model / tokens / cost_usd） |
| `job.py` | モデル別に集計 → `out.csv` + `summary.json` |
| `index.html` | CSV を table + SVG バーチャートで表示 |

## 依存

- Python 3（stdlib のみ: `csv`, `json`, `argparse`, `pathlib`）
- ブラウザ（Vanilla JS + SVG。フレームワークなし）

## 完了条件（出世魚 POC）

1. 同じ `sample.csv` で `job.py` が同じ結果を再出力できる
2. その結果を `index.html` が表と SVG で表示できる
3. D1 / Drive / Workers は使わない

次の段（MVP）でこの `job.py` をデフォルトタスクとして残し、外側にキューと Drive を被せる。
