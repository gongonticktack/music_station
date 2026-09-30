# Cloudflare Observability スキルリファレンス

**目的**: Cloudflare Workers でトレース、ログ、メトリクス、分析を扱う可観測性を実装するための包括的なガイダンスです。

**対象範囲**: Cloudflare Observability の機能のみ — Workers Logs、Traces、Analytics Engine、Logpush、Metrics & Analytics、OpenTelemetry エクスポート。

---

## 判断ツリー: 読み込むファイルの選択

すべての内容を読み込まず、適切なファイルを選ぶ際に使用してください:

```
├─ "How do I enable/configure X?"           → configuration.md
├─ "What's the API/method/binding for X?"   → api.md
├─ "How do I implement X pattern?"          → patterns.md
│   ├─ Usage tracking/billing               → patterns.md
│   ├─ Error tracking                       → patterns.md
│   ├─ Performance monitoring               → patterns.md
│   ├─ Multi-tenant tracking                → patterns.md
│   ├─ Tail Worker filtering                → patterns.md
│   └─ OpenTelemetry export                 → patterns.md
└─ "Why isn't X working?" / "Limits?"       → gotchas.md
```

## 読み込み順

タスクに応じて、次の順序でファイルを読み込みます:

| タスクの種類 | 読み込み順 | 理由 |
|-----------|------------|--------|
| **初期設定** | configuration.md → gotchas.md | まず設定し、落とし穴を避ける |
| **機能の実装** | patterns.md → api.md → gotchas.md | パターン → API の詳細 → エッジケース |
| **問題のデバッグ** | gotchas.md → configuration.md | まずよくある問題を確認 |
| **データのクエリ** | api.md → patterns.md | API の構文 → クエリ例 |

## 製品概要

### Workers Logs
- **内容:** Workers からのコンソール出力 (console.log/warn/error)
- **アクセス:** ダッシュボード (リアルタイムログ)、Logpush、Tail Workers
- **料金:** 無料 (すべての Workers に含まれる)
- **保持期間:** リアルタイムのみ (ダッシュボードに履歴は保存されません)

### Workers Traces
- **内容:** 実行時間、CPU 使用量、結果を含む実行トレース
- **アクセス:** ダッシュボード (Workers Analytics → Traces)、Logpush
- **料金:** 100 万スパンあたり $0.10 (GA 料金は 2026 年 3 月 1 日開始)、月 1,000 万件まで無料
- **保持期間:** 14 日間を含む

### Analytics Engine
- **内容:** カーディナリティの高いイベントの保存と SQL クエリ
- **アクセス:** SQL API、ダッシュボード (Analytics → Analytics Engine)
- **料金:** 月 1,000 万回の無料枠を超える書き込み 100 万回あたり $0.25
- **保持期間:** 90 日間 (最長 1 年まで設定可能)

### Tail Workers
- **内容:** 他の Workers からログ/トレースを受け取る Workers
- **用途:** ログのフィルタリング、変換、外部へのエクスポート
- **料金:** 通常の Workers 料金

### Logpush
- **内容:** ログを外部ストレージ (S3、R2、Datadog など) にストリーミング
- **アクセス:** ダッシュボード、API
- **料金:** Business/Enterprise プランが必要

## 料金の概要 (2026)

| 機能 | 無料枠 | 無料枠を超えた場合の料金 | 必要なプラン |
|---------|-----------|----------------------|------------------|
| Workers Logs | 無制限 | 無料 | すべて |
| Workers Traces | 月 1,000 万スパン | 100 万スパンあたり $0.10 | Paid Workers (GA: 2026 年 3 月 1 日) |
| Analytics Engine | 月 1,000 万回の書き込み | 100 万回の書き込みあたり $0.25 | Paid Workers |
| Logpush | 該当なし | プランに含まれる | Business/Enterprise |

## このリファレンスの内容

- **[configuration.md](configuration.md)** - セットアップ、デプロイ、設定 (Logs、Traces、Analytics Engine、Tail Workers、Logpush)
- **[api.md](api.md)** - API エンドポイント、メソッド、インターフェース (GraphQL、SQL、バインディング、型)
- **[patterns.md](patterns.md)** - よくあるパターン、用途、例 (課金、監視、エラー追跡、エクスポート)
- **[gotchas.md](gotchas.md)** - トラブルシューティング、ベストプラクティス、制限事項 (よくあるエラー、パフォーマンス上の注意点、料金)

## 関連情報

- [Cloudflare Workers Docs](https://developers.cloudflare.com/workers/)
- [Analytics Engine Docs](https://developers.cloudflare.com/analytics/analytics-engine/)
- [Workers Traces Docs](https://developers.cloudflare.com/workers/observability/traces/)