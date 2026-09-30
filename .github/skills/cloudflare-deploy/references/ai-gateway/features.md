# 機能と対応範囲

## キャッシュ

ダッシュボード: Settings → Cache Responses → Enable

```typescript
// Custom TTL (1 hour)
headers: { 'cf-aig-cache-ttl': '3600' }

// Skip cache
headers: { 'cf-aig-skip-cache': 'true' }

// Custom cache key
headers: { 'cf-aig-cache-key': 'greeting-en' }
```

**制限:** TTL は 60 秒から 30 日まで。**ストリーミングでは機能しません。**

## レート制限

ダッシュボード: Settings → Rate-limiting → Enable

- **固定ウィンドウ:** 一定の間隔でリセットされます。
- **スライディングウィンドウ:** 移動する期間を基準にします（より正確）。
- 制限を超えると `429` を返します。

## ガードレール

ダッシュボード: Settings → Guardrails → Enable

プロンプトと応答に不適切な内容がないか確認します。アクションは Flag（ログに記録）または Block（拒否）です。

## データ損失防止（DLP）

ダッシュボード: Settings → DLP → Enable

個人情報（メールアドレス、米国の社会保障番号、クレジットカード情報）を検出します。アクションは Flag、Block、Redact（マスキング）です。

## 請求方法

| 方法 | 説明 | 設定 |
|------|-------------|-------|
| **統合請求** | プロバイダーのキーを使わず、Cloudflare 経由で支払う | `cf-aig-authorization` ヘッダーのみを使用 |
| **BYOK** | プロバイダーのキーをダッシュボードに保存する | Provider Keys セクションでキーを追加 |
| **パススルー** | リクエストごとにプロバイダーのキーを送信する | プロバイダーの認証ヘッダーを含める |

## データを保持しない設定

ダッシュボード: Settings → Privacy → Zero Data Retention

プロンプトと応答は保存されません。リクエスト数とコストは引き続き記録されます。

## ログ記録

ダッシュボード: Settings → Logs → Enable（最大 1,000 万件のログ）

各ログに記録される内容: プロンプト、応答、プロバイダー、モデル、トークン数、コスト、所要時間、キャッシュ状態、メタデータ。

```typescript
// Skip logging for request
headers: { 'cf-aig-collect-log': 'false' }
```

**エクスポート:** Logpush を使って S3、GCS、Datadog、Splunk などに送信します。

## 独自のコスト追跡

Cloudflare の価格データベースに登録されていないモデルの場合:

ダッシュボード: Gateway → Settings → Custom Costs

または API で `model`、`input_cost`、`output_cost` を設定します。

## 対応プロバイダー（22 以上）

| プロバイダー | 統合 API | 備考 |
|----------|-------------|-------|
| OpenAI | `openai/gpt-4o` | 全面的に対応 |
| Anthropic | `anthropic/claude-sonnet-4-5` | 全面的に対応 |
| Google AI | `google-ai-studio/gemini-2.0-flash` | 全面的に対応 |
| Workers AI | `workersai/@cf/meta/llama-3` | ネイティブ対応 |
| Azure OpenAI | `azure-openai/*` | デプロイ名を使用 |
| AWS Bedrock | プロバイダーのエンドポイントのみ | `/bedrock/*` |
| Groq | `groq/*` | 高速な推論 |
| Mistral, Cohere, Perplexity, xAI, DeepSeek, Cerebras | 全面的に対応 | - |

## ベストプラクティス

1. 結果が一定のプロンプトにはキャッシュを有効にする
2. 不正使用を防ぐためにレート制限を設定する
3. ユーザー向け AI にはガードレールを使用する
4. 機密データを扱う場合は DLP を有効にする
5. キーの管理を簡単にするため、統合請求または BYOK を使用する
6. デバッグのためにログ記録を有効にする
7. プライバシー保護が必要な場合は、データを保持しない設定を使用する
