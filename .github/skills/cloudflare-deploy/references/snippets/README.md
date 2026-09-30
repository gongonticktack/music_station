# Cloudflare Snippets スキルリファレンス

## 説明
**Cloudflare Snippets 専用**の専門的なガイダンスです。HTTP リクエストとレスポンスを変更する、軽量な JavaScript ベースのエッジロジックプラットフォームです。Snippets は Ruleset Engine の一部として実行され、有料プラン（Pro、Business、Enterprise）では追加料金なしで利用できます。

## Snippets とは？
Snippets は、Cloudflare の Ruleset Engine の一部としてエッジで実行される JavaScript 関数です。主な特徴：
- **実行時間**：リクエストあたり CPU 時間 5ms の上限
- **サイズ上限**：スニペットあたり 32KB
- **ランタイム**：V8 isolate（Workers API の一部）
- **サブリクエスト**：プランに応じて fetch 呼び出し 2～5 回
- **料金**：Pro/Business/Enterprise プランに含まれます

## Snippets と Workers の選択マトリクス

| 要素 | Snippets を選ぶ場合... | Workers を選ぶ場合... |
|--------|----------------------|---------------------|
| **複雑さ** | シンプルなリクエスト／レスポンスの変更 | 複雑なビジネスロジック、ルーティング、ミドルウェア |
| **実行時間** | 5ms 未満で十分 | 5ms 超、または変動する実行時間が必要 |
| **サブリクエスト** | fetch 呼び出し 2～5 回で十分 | 5 回を超えるサブリクエスト、または複雑なオーケストレーションが必要 |
| **コードサイズ** | 32KB 未満で十分 | 32KB 超、または npm 依存関係が必要 |
| **料金** | 追加料金なしで利用したい | 月額 5 ドル＋使用量を負担できる |
| **API** | 基本的な fetch、ヘッダー、URL が必要 | KV、D1、R2、Durable Objects、cron トリガーが必要 |
| **デプロイ** | ルールベースのトリガーが必要 | カスタムのルーティングロジックが必要 |

**目安**：変更には Snippets、アプリケーションには Workers を使用します。

## 実行モデル
1. リクエストが Cloudflare エッジに到着
2. Ruleset Engine がスニペットルール（フィルター式）を評価
3. ルールに一致すると、スニペットが 5ms の制限内で実行
4. 変更されたリクエスト／レスポンスがパイプラインを続行
5. レスポンスがクライアントに返される

Snippets はリクエスト処理経路で同期的に実行されるため、パフォーマンスが重要です。

## 読む順序
1. **[configuration.md](configuration.md)** - まずはこちら：セットアップ、デプロイ方法（Dashboard/API/Terraform）
2. **[api.md](api.md)** - コア API：Request、Response、ヘッダー、`request.cf` プロパティ
3. **[patterns.md](patterns.md)** - 実例：地域別ルーティング、A/B テスト、セキュリティヘッダー
4. **[gotchas.md](gotchas.md)** - トラブルシューティング：よくあるエラー、パフォーマンスのヒント、API の制限

## このリファレンスの内容

- **[configuration.md](configuration.md)** - セットアップ、デプロイ、設定
- **[api.md](api.md)** - API エンドポイント、メソッド、インターフェース
- **[patterns.md](patterns.md)** - よく使われるパターン、ユースケース、例
- **[gotchas.md](gotchas.md)** - トラブルシューティング、ベストプラクティス、制限事項

## クイックスタート
```javascript
// Snippet: Add security headers
export default {
  async fetch(request) {
    const response = await fetch(request);
    const newResponse = new Response(response.body, response);
    newResponse.headers.set("X-Frame-Options", "DENY");
    newResponse.headers.set("X-Content-Type-Options", "nosniff");
    return newResponse;
  }
}
```

Dashboard（Rules → Snippets）または API/Terraform 経由でデプロイします。詳しくは configuration.md を参照してください。

## 関連項目

- [Cloudflare Docs](https://developers.cloudflare.com/rules/snippets/)
