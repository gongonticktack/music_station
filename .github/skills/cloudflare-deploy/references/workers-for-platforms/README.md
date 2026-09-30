# Cloudflare Workers for Platforms

大規模環境で、顧客コードを分離して実行するマルチテナントプラットフォーム。

## ユースケース

- 顧客コードを実行するマルチテナントSaaS
- セキュアなサンドボックスでのAI生成コードの実行
- 分離されたコンピューティング環境を備えたプログラム可能なプラットフォーム
- エッジ関数／サーバーレスプラットフォーム
- 静的コンテンツと動的コンテンツを扱うウェブサイトビルダー
- 大規模環境での無制限のアプリデプロイ

**一般的なWorkers向けではありません** - Workers for Platformsアーキテクチャ専用です。

## クイックスタート

**ワンクリックデプロイ:** [Platform Starter Kit](https://github.com/cloudflare/workers-for-platforms-example)では、ディスパッチ名前空間、ディスパッチWorker、ユーザーWorkerのサンプルを含むWfPの完全なセットアップをデプロイできます。

[![Cloudflareにデプロイ](https://deploy.workers.cloudflare.com/button)](https://deploy.workers.cloudflare.com/?url=https://github.com/cloudflare/workers-for-platforms-example)

**手動セットアップ:** 名前空間の作成とディスパッチWorkerの設定については、[configuration.md](./configuration.md)を参照してください。

## 主な機能

- 名前空間ごとに無制限のWorkers（スクリプト数の上限なし）
- テナントの自動分離
- 顧客ごとのCPU／サブリクエスト制限のカスタマイズ
- ホスト名ルーティング（サブドメイン／バニティドメイン）
- エグレス／イングレス制御
- 静的アセットに対応
- 一括操作用のタグ

## アーキテクチャ

**4つのコンポーネント:**
1. **ディスパッチ名前空間** - 無制限の顧客Workerを格納し、自動的に分離（デフォルトは信頼しないモード - request.cfへのアクセスなし、共有キャッシュなし）
2. **動的ディスパッチWorker** - エントリーポイントとしてリクエストをルーティングし、プラットフォームのロジック（認証、制限、検証）を適用
3. **ユーザーWorker** - 分離されたサンドボックス内の顧客コード。API経由でデプロイし、任意のバインディング（KV/D1/R2/DO）を設定可能
4. **アウトバウンドWorker**（任意） - 外部へのfetchを横取りし、エグレスを制御してサブリクエストを記録（TCPソケットのconnect() APIをブロック）

**リクエストフロー:**
```
Request → Dispatch Worker → Determines user Worker → env.DISPATCHER.get("customer") 
→ User Worker executes (Outbound Worker for external fetch) → Response → Dispatch Worker → Client
```

## 判断フロー

### Workers for Platformsを使う場合
```
Need to run code?
├─ Your code only → Regular Workers
├─ Customer/AI code → Workers for Platforms
└─ Untrusted code in sandbox → Workers for Platforms OR Sandbox API
```

### ルーティング戦略の選択
```
Hostname routing needed?
├─ Subdomains only (*.saas.com) → `*.saas.com/*` route + subdomain extraction
├─ Custom domains → `*/*` wildcard + Cloudflare for SaaS + KV/metadata routing
└─ Path-based (/customer/app) → Any route + path parsing
```

### 分離モードの選択
```
Worker mode?
├─ Running customer code → Untrusted (default)
├─ Need request.cf geolocation → Trusted mode
├─ Internal platform, controlled code → Trusted mode with cache key prefixes
└─ Maximum isolation → Untrusted + unique resources per customer
```

## このリファレンスの内容

| ファイル | 目的 | 参照するタイミング |
|------|---------|--------------|
| [configuration.md](./configuration.md) | 名前空間のセットアップ、ディスパッチWorkerの設定 | 初回セットアップ、制限の変更時 |
| [api.md](./api.md) | ユーザーWorker API、ディスパッチAPI、アウトバウンドWorker | Workerのデプロイ、SDK統合時 |
| [patterns.md](./patterns.md) | マルチテナント、ルーティング、エグレス制御 | アーキテクチャの計画、スケーリング時 |
| [gotchas.md](./gotchas.md) | 制限、分離に関する問題、ベストプラクティス | デバッグ、本番環境の準備時 |

## 関連項目
- [workers](../workers/) - Workersランタイムの基本ドキュメント
- [durable-objects](../durable-objects/) - 状態を持つマルチテナントのパターン
- [sandbox](../sandbox/) - 信頼できないコードを実行する別の方法
- [リファレンスアーキテクチャ: プログラム可能なプラットフォーム](https://developers.cloudflare.com/reference-architecture/diagrams/serverless/programmable-platforms/)
- [リファレンスアーキテクチャ: AI Vibe Coding Platform](https://developers.cloudflare.com/reference-architecture/diagrams/ai/ai-vibe-coding-platform/)
