# Cloudflare Pulumi プロバイダー

Cloudflare Pulumi プロバイダー（@pulumi/cloudflare）に関する専門的なガイダンス。

## 概要

Cloudflare リソース（Workers、Pages、D1、KV、R2、DNS、Queues など）をプログラムから管理します。

**パッケージ:**
- TypeScript/JS: `@pulumi/cloudflare`
- Python: `pulumi-cloudflare`
- Go: `github.com/pulumi/pulumi-cloudflare/sdk/v6/go/cloudflare`
- .NET: `Pulumi.Cloudflare`

**バージョン:** v6.x

## 基本原則

1. API トークンを使用します（従来の API キーは使用しません）
2. accountId をスタック設定に保存します
3. コードと設定の間でバインディング名を一致させます
4. ES モジュールには `module: true` を使用します
5. 動作を固定するため `compatibilityDate` を設定します

## 認証

```typescript
import * as cloudflare from "@pulumi/cloudflare";

// API Token (recommended): CLOUDFLARE_API_TOKEN env
const provider = new cloudflare.Provider("cf", { apiToken: process.env.CLOUDFLARE_API_TOKEN });

// API Key (legacy): CLOUDFLARE_API_KEY + CLOUDFLARE_EMAIL env
const provider = new cloudflare.Provider("cf", { apiKey: process.env.CLOUDFLARE_API_KEY, email: process.env.CLOUDFLARE_EMAIL });

// API User Service Key: CLOUDFLARE_API_USER_SERVICE_KEY env
const provider = new cloudflare.Provider("cf", { apiUserServiceKey: process.env.CLOUDFLARE_API_USER_SERVICE_KEY });
```

## セットアップ

**Pulumi.yaml:**
```yaml
name: my-cloudflare-app
runtime: nodejs
config:
  cloudflare:apiToken:
    value: ${CLOUDFLARE_API_TOKEN}
```

**Pulumi.<stack>.yaml:**
```yaml
config:
  cloudflare:accountId: "abc123..."
```

**index.ts:**
```typescript
import * as pulumi from "@pulumi/pulumi";
import * as cloudflare from "@pulumi/cloudflare";
const accountId = new pulumi.Config("cloudflare").require("accountId");
```

## よく使うリソースタイプ
- `Provider` - プロバイダー設定
- `WorkerScript` - Worker
- `WorkersKvNamespace` - KV
- `R2Bucket` - R2
- `D1Database` - D1
- `Queue` - Queue
- `PagesProject` - Pages
- `DnsRecord` - DNS
- `WorkerRoute` - Worker ルート
- `WorkersDomain` - カスタムドメイン

## 主なプロパティ
- `accountId` - ほとんどのリソースで必須
- `zoneId` - DNS/ドメインで必須
- `name`/`title` - リソース識別子
- `*Bindings` - リソースを Workers に接続

## 推奨される閲覧順

| 順序 | ファイル | 内容 | 読むタイミング |
|-------|------|------|--------------|
| 1 | [configuration.md](./configuration.md) | Workers/KV/D1/R2/Queues/Pages のリソース設定 | 初回セットアップ、リソースの参照 |
| 2 | [patterns.md](./patterns.md) | アーキテクチャパターン、複数環境、コンポーネントリソース | 複雑なアプリの構築、ベストプラクティス |
| 3 | [api.md](./api.md) | 出力、依存関係、インポート、動的プロバイダー | 高度な機能、統合 |
| 4 | [gotchas.md](./gotchas.md) | よくあるエラー、トラブルシューティング、制限事項 | デバッグ、デプロイの問題 |

## このリファレンスの内容
- [configuration.md](./configuration.md) - プロバイダー設定、スタック設定、Workers/バインディング
- [api.md](./api.md) - リソースタイプ、Workers スクリプト、KV/D1/R2/Queues/Pages
- [patterns.md](./patterns.md) - 複数環境、シークレット、CI/CD、スタック管理
- [gotchas.md](./gotchas.md) - 状態の問題、デプロイの失敗、制限事項

## 関連項目
- [terraform](../terraform/) - Cloudflare 向けの代替 IaC
- [wrangler](../wrangler/) - CLI によるデプロイの代替手段
- [workers](../workers/) - Worker ランタイムのドキュメント