# Yukidaruma growth stages（出世魚）

同じプロダクトを、核を変えずに育てる。POC を捨てて MVP を作り直すのではなく、POC の Python 処理を MVP の標準タスクとして包み、MAX で実行先と運用能力を増やす。

```
POC ──稚魚──  動く
 │
MVP ──成魚──  使える
 │
MAX ──巨魚──  任せられる
```

## 共通の設計の芯

- データ処理: Python
- 表示: HTML table + SVG
- UI: Vanilla JavaScript（フレームワークなし）
- ストレージ: Cloudflare D1 または Google Drive。R2 は使わない
- D1: メタデータと上限付き小さな UTF-8 テキストのみ
- 大きなファイル: private Google Drive
- Muse VM: Python worker が外向き HTTPS で Workers API を poll
- Go オーケストレーター、Rust workload runtime は作らない

## POC — 稚魚「動く」

**目的:** CSV → Python → CSV → HTML/SVG の分析ループを、最小依存で実証する。

| 項目 | 内容 |
|---|---|
| 入力 | ローカル CSV |
| 計算 | Python 標準ライブラリの `poc/job.py` |
| 出力 | 集計 CSV + JSON summary |
| 表示 | `poc/index.html` で表 + SVG |
| 状態管理 | なし |
| API / Queue / Auth | なし |
| D1 / Drive | 使わない |

**実装済みの入口**
- `poc/sample.csv`
- `poc/job.py`
- `poc/index.html`
- `tests/test_poc_job.py`
- `poc/README.md`

**完了条件**
1. サンプル CSV から決定的な集計結果が出る
2. HTML が集計 CSV を表と SVG で表示する
3. Python の標準ライブラリだけでテストできる

Issue: [#12 POC-01](https://github.com/bonsai/yukidaruma/issues/12)

## MVP — 成魚「使える」

**目的:** POC の Python 処理を捨てずに、受付・台帳・実行履歴・成果物管理を外側に足す。

| 項目 | 内容 |
|---|---|
| 入力 | ローカル upload / Google Drive dataset |
| 計算 | Muse Ubuntu VM の Python worker |
| 制御 | Cloudflare Workers API + D1 |
| 出力 | 小さなテキストは D1、大きな成果物は Google Drive |
| UI | Overview / Datasets / Jobs / Runs / Artifacts |
| 契約 | versioned Job schema + Result Manifest |
| 接続 | VM から外向き poll。VM の inbound port 不要 |

**POC から足すもの**
- 認証と user / agent / runner token
- Workers API、D1 schema、job submit / claim / complete
- Muse VM Python poller と lease / heartbeat
- Google Drive storage adapter と認証付き read/write
- run history、logs、artifact manifest
- Vanilla JS + SVG の最小 workspace UI
- API / D1 / storage / worker の E2E tests

**完了条件**
1. 認証付きで job を登録できる
2. Muse worker が排他 claim して POC の Python task を実行できる
3. run と成果物を D1 / Drive に保存し、再取得できる
4. VM 再起動後も queued job が残り、失敗が可視化される
5. shell や D1 直接操作なしで日常利用できる

Kaggle / Colab は MVP の必須条件にしない。自動実行が E2E 検証されるまでは manual / unavailable と明示する。

## MAX — 巨魚「任せられる」

**目的:** 複数の Python 実行環境・データ量・運用負荷に対応する。

候補機能:
- Muse VM worker の複数台運用、capability-aware routing、queue priority / concurrency
- Kaggle / Colab の検証済み adapter。未対応操作は manual と明示
- DuckDB を Python 経由で使う SQL Worksheet、query history、saved charts
- dataset versioning、checksum、provenance、再実行
- retry / dead-letter / retention / audit / quota
- queue latency、job success rate、worker health、resource metrics
- workspace / project 単位の権限管理

**完了条件:** 機能の数ではなく、queue wait、成功率、復旧時間、同時実行数などの測定可能な SLO を満たす。

## 出世ルール

1. **POC を壊さない:** `poc/job.py` を MVP の最初の allowlisted task として再利用する
2. **契約を守る:** Job / Manifest / storage reference は versioned contract として進化させる
3. **台帳と計算を分離:** D1 は control plane。分析 SQL engine や大容量 blob store にしない
4. **下位ステージを先食いしない:** POC に queue、auth、remote compute を持ち込まない
5. **実測して拡張:** MAX の機能は実 workload の bottleneck と SLO から選ぶ
