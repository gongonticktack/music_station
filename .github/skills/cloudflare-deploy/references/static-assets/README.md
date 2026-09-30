# Cloudflare Static Assets スキルリファレンス

Cloudflare Workersで静的アセットをデプロイおよび設定するための専門的なガイダンスです。このスキルでは、設定パターン、ルーティング構成、アセットバインディングの使用方法に加え、SPA、SSGサイト、フルスタックアプリケーションのベストプラクティスを扱います。

## クイックスタート

```jsonc
// wrangler.jsonc
{
  "name": "my-app",
  "main": "src/index.ts",
  "compatibility_date": "2025-01-01",
  "assets": {
    "directory": "./dist"
  }
}
```

```typescript
// src/index.ts
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    return env.ASSETS.fetch(request);
  }
};
```

デプロイ: `wrangler deploy`

## Workers Static AssetsとPagesの使い分け

| 要素 | Workers Static Assets | Cloudflare Pages |
|--------|----------------------|------------------|
| **用途** | ハイブリッドアプリ（静的コンテンツ + 動的API） | 静的サイト、SSG |
| **Workerの制御** | ルーティングを完全に制御可能 | 制限あり（Functions） |
| **設定** | コード中心で柔軟 | Gitベースで、方式が定められている |
| **動的ルーティング** | Worker優先のパターン | Functions (_functions/) |
| **最適な用途** | フルスタックアプリ、APIを備えたSPA | Jamstack、静的ドキュメント |

**選択の目安:**

- 独自のルーティングロジックが必要？ → Workers Static Assets
- 純粋な静的サイトまたはSSG？ → Pages
- APIルート + SPA？ → Workers Static Assets
- フレームワーク（Next、Nuxt、Remix）？ → Pages

## 読む順序

1. **configuration.md** - セットアップ、wrangler.jsoncのオプション、ルーティングパターン
2. **api.md** - ASSETSバインディングAPI、リクエストとレスポンスの処理
3. **patterns.md** - よく使われるパターン（SPA、APIルート、認証、A/Bテスト）
4. **gotchas.md** - 制限、エラー、パフォーマンスのヒント

## このリファレンスの内容

- **[configuration.md](configuration.md)** - セットアップ、デプロイ、設定
- **[api.md](api.md)** - APIエンドポイント、メソッド、インターフェース
- **[patterns.md](patterns.md)** - よく使われるパターン、用途、例
- **[gotchas.md](gotchas.md)** - トラブルシューティング、ベストプラクティス、制限事項

## 関連情報

- [Cloudflare Workers Docs](https://developers.cloudflare.com/workers/)
- [Static Assets Docs](https://developers.cloudflare.com/workers/static-assets/)
- [Cloudflare Pages](https://developers.cloudflare.com/pages/)
