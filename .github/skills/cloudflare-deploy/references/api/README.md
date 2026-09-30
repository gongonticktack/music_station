# Cloudflare API の統合

Cloudflare の REST API を利用するためのガイド。認証、SDK の使い方、よく使うパターン、トラブルシューティングを扱う。

## クイック判断フロー

```
How are you calling the Cloudflare API?
├─ From Workers runtime → Use bindings, not REST API (see ../bindings/)
├─ Server-side (Node/Python/Go) → Official SDK (see api.md)
├─ CLI/scripts → Wrangler or curl (see configuration.md)
├─ Infrastructure-as-code → See ../pulumi/ or ../terraform/
└─ One-off requests → curl examples (see api.md)
```

## SDK の選択

| 言語 | パッケージ | 適した用途 | デフォルトの再試行回数 |
|----------|---------|----------|-----------------|
| TypeScript | `cloudflare` | Node.js、Bun、Next.js、Workers | 2 |
| Python | `cloudflare` | FastAPI、Django、スクリプト | 2 |
| Go | `cloudflare-go/v4` | CLI ツール、マイクロサービス | 10 |

すべての SDK は OpenAPI 仕様から Stainless によって生成されており、API の一貫性が保たれている。

## 認証方法

| 方法 | セキュリティ | 用途 | 権限の範囲 |
|--------|----------|----------|-------|
| **API トークン** ✓ | 権限範囲を限定でき、ローテーション可能 | 本番環境 | ゾーン単位またはアカウント単位 |
| API キー + メールアドレス | アカウント全体にアクセス可能 | 既存システムのみ | すべて |
| ユーザーサービスキー | 制限あり | Origin CA 証明書のみ | Origin CA |

新規プロジェクトでは**必ず API トークンを使用する**。

## レート制限

| 制限 | 値 |
|-------|-------|
| ユーザー／トークンあたり | 5 分間に 1200 リクエスト |
| IP あたり | 1 秒間に 200 リクエスト |
| GraphQL | 5 分間に 320（コストに基づく） |

## 読む順序

| 作業 | 参照するファイル |
|------|---------------|
| SDK クライアントを初期化する | api.md |
| 認証／タイムアウト／再試行を設定する | configuration.md |
| 使用パターンを調べる | patterns.md |
| エラー／レート制限を調査する | gotchas.md |
| 製品固有の API を調べる | ../workers/, ../r2/, ../kv/ など |

## このリファレンスの内容

- **[api.md](api.md)** - SDK クライアントの初期化、ページネーション、エラー処理、使用例
- **[configuration.md](configuration.md)** - 環境変数、SDK の設定、Wrangler のセットアップ
- **[patterns.md](patterns.md)** - 実践的なパターン、一括操作、ワークフロー
- **[gotchas.md](gotchas.md)** - レート制限、SDK 固有の問題、トラブルシューティング

## 関連資料

- [Cloudflare API ドキュメント](https://developers.cloudflare.com/api/)
- [バインディングのリファレンス](../bindings/) - Workers ランタイムのバインディング（REST API より優先）
- [Wrangler のリファレンス](../wrangler/) - Cloudflare 開発用の CLI ツール
