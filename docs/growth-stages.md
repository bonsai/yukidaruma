# Yukidaruma growth stages（出世魚）

同じ魚が成長につれて名前を変えるように、**核は変えず**に段階で能力だけ増やす。

核（全ステージ共通）:

- データ: **CSV**（後から Parquet 可）
- 計算: **Python**（Muse VM / Colab / Kaggle）
- 表示: **SVG**（+ 表は HTML）
- 糊: **Vanilla JS**（フレームワーク禁止のまま拡張）
- ストレージ制約: **D1 and/or Google Drive**

```
  POC ──稚魚──  「動く」
   │
  MVP ──成魚──  「使える」
   │
  MAX ──巨魚──  「任せられる」
```

---

## POC — 稚魚（Proof of Concept）

**別名:** `csv-py-svg`  
**目的:** 分析ループが一周することを目で確認する。台帳なしでよい。

| 項目 | 内容 |
|------|------|
| 入力 | ローカル CSV |
| 計算 | 手元 or Muse VM の `python job.py` |
| 出力 | CSV / 小さな JSON 要約 |
| UI | 単一 HTML。CSV 読込 → table → SVG チャート |
| 状態 | なし（実行のたびに完結） |
| API | なし |
| Drive / D1 | 使わない |

**入るもの**

- [ ] `poc/index.html` — file input, table, SVG bar/line
- [ ] `poc/job.py` — 決定的な集計（例: group-by count）
- [ ] `poc/sample.csv`
- [ ] README に「py → 出力 → HTML で開く」の 3 行手順

**入らないもの**

- ジョブキュー、認証、履歴、エージェント API、Kaggle/Colab 自動投入

**完了条件**

1. サンプル CSV で Python が同じ結果を再出力できる  
2. その結果を HTML が表と SVG で表示できる  
3. 依存は「ブラウザ + Python 標準 + 必要なら csv モジュール」程度

---

## MVP — 成魚（Minimum Viable Product）

**別名:** `drive-queued-workspace`  
**目的:** 人が繰り返し使え、エージェントが同じ口から投げられる。

POC の csv-py-svg を**捨てず**、外側に台帳と受付を被せる。

| 項目 | 内容 |
|------|------|
| 入力 | Drive 上の CSV（+ ローカル upload → Drive） |
| 計算 | Muse VM Python を本線。Colab/Kaggle は手動 or 粗アダプタ可 |
| 出力 | Drive に成果物。要約は D1 / manifest |
| UI | Vanilla JS の簡易 Snowsight 風（Overview / Datasets / Jobs / Run） |
| 状態 | D1: jobs / runs / artifacts 参照 |
| API | Workers `/v1`（job submit, claim, complete） |
| 契約 | `job.schema.json` + `result-manifest.schema.json` |

**POC から足すもの**

- [ ] Workers + D1 スキーマ適用
- [ ] Drive フォルダ規約（`docs/storage-layout.md`）
- [ ] Muse VM: poll → claim → `job.py` → upload → complete
- [ ] UI: ジョブ一覧・状態・ログ・簡易プレビュー（SVG 維持）
- [ ] ユーザー / runner トークン

**まだ本気でやらないもの**

- 高度な SQL IDE、権限の多テナント、保証付き GPU、Rust 必須パス

**完了条件（PRD MVP checklist と整合）**

1. 認証付きで job を投げられる  
2. Muse VM が排他 claim して Python を走らせる  
3. 成果が Drive に残り、UI から状態とプレビューが見える  
4. VM 再起動後も queued が消えない  

---

## MAX — 巨魚（Full vision）

**別名:** `personal-compute-warehouse`  
**目的:** 人・エージェント・複数ランナーが日常の分析基盤として使う。

| 項目 | 内容 |
|------|------|
| 入力 | CSV / Parquet / JSONL、データセット版管理 |
| 計算 | Muse VM + Colab + Kaggle を capability で自動ルーティング |
| 出力 | manifest 完備、再現用 code revision、メトリクス |
| UI | Worksheet、履歴、チャート保存、ランナー健康状態 |
| 状態 | リトライ方針、stale heartbeat、保持期間、監査ログ |
| API | 安定版契約、エージェント第一級 |
| 分析 | DuckDB を Python 経由で SQL Worksheet に |

**MVP から足すもの**

- [ ] リモートアダプタ本実装（失敗時は manual 明示）
- [ ] SQL Worksheet（DuckDB）
- [ ] チャート設定の保存
- [ ] データセット版と provenance
- [ ] 配额・リトライ・retention
- [ ] （任意）R2 など Drive 以外の blob バックエンドを URI で差替え
- [ ] （任意）Rust はボトルネック計測後のみ

**完了条件**

1. 同一ジョブ契約で VM/Colab/Kaggle のいずれかに載る  
2. 過去 run を入力・revision・成果から再現できる  
3. エージェントが人と同じ API だけで回せる  

---

## 出世ルール（設計規律）

1. **下位を壊さない** — POC の `job.py` 入出力は MVP ランナーのデフォルトタスクとして残す  
2. **表示の核は SVG** — チャートライブラリ必須にしない（MAX でも可、ただし必須化しない）  
3. **台帳と計算を混ぜない** — D1 に大表を載せ始めたら退化  
4. **名前が変わっても契約は版で増やす** — `schema_version` を壊さず拡張  
5. **MAX の機能を POC に先食いしない** — キューも認証も POC 禁止

## マップ（Issue との対応）

| Stage | 主な Issue |
|-------|------------|
| POC | リポジトリに `poc/` を追加（Issue 外でも可） |
| MVP | #1–#8, #10 の最小セット / Phase 1 |
| MAX | #9 高度化, Phase 2–4, リモートアダプタ本線 |

## 一言で

| Stage | 一言 |
|-------|------|
| **POC** | csv → py → svg が動く |
| **MVP** | それに順番待ちと Drive と履歴が付く |
| **MAX** | それに選択・再現・エージェント運用が付く |
