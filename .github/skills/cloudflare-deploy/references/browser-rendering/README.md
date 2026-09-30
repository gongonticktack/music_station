# Cloudflare Browser Rendering スキル リファレンス

**説明**: Cloudflare Browser Rendering に関する専門知識。Cloudflare のグローバルネットワーク上でヘッドレス Chrome を操作し、ブラウザー自動化、スクリーンショット、PDF、ウェブスクレイピング、テスト、コンテンツ生成を行います。

**使用する場面**: スクリーンショットの撮影、PDF の生成、ウェブスクレイピング、ブラウザー自動化、ウェブアプリケーションのテスト、構造化データの抽出、ページ指標の取得、ブラウザー操作の自動化など、Cloudflare Browser Rendering に関するあらゆるタスク。

## 選択ガイド

### REST API と Workers Bindings の使い分け

**REST API を使用する場合:**
- 単発のステートレスなタスク（スクリーンショット、PDF、コンテンツ取得）
- Workers のインフラストラクチャがまだない
- 外部サービスとのシンプルな連携
- デプロイせずにすばやく試作したい

**Workers Bindings を使用する場合:**
- 複雑なブラウザー自動化ワークフロー
- パフォーマンス向上のためにセッションを再利用する必要がある
- 1 回のリクエストで複数ページを操作する
- カスタムスクリプトやロジックが必要
- 本番アプリケーションを構築する

### Puppeteer と Playwright の比較

| 機能 | Puppeteer | Playwright |
|---------|-----------|------------|
| API スタイル | Chrome DevTools Protocol | 高水準の抽象化 |
| セレクター | CSS、XPath | CSS、テキスト、ロール、test-id |
| 適した用途 | 高度な制御、CDP アクセス | 手軽な自動化、テスト |
| 学習コスト | 高め | 低め |

**Puppeteer を使用する場合:** CDP プロトコルへのアクセスが必要、Chrome 固有の機能が必要、既存の Puppeteer コードから移行する
**Playwright を使用する場合:** 最新のセレクター API を使う、クロスブラウザーのパターンが必要、より速く開発する

## プランごとの制限の概要

| 制限 | Free プラン | Paid プラン |
|-------|-----------|-----------|
| 1 日あたりのブラウザー使用時間 | 10 分 | 無制限* |
| 同時セッション数 | 3 | 30 |
| 1 分あたりのリクエスト数 | 6 | 180 |

*公正利用ポリシーが適用されます。詳細は [gotchas.md](gotchas.md) を参照してください。

## 読む順序

**Browser Rendering を初めて使う場合:**
1. [configuration.md](configuration.md) - セットアップとデプロイ
2. [patterns.md](patterns.md) - 例を交えた一般的なユースケース
3. [api.md](api.md) - API リファレンス
4. [gotchas.md](gotchas.md) - よくある落とし穴を回避

**特定のタスクの場合:**
- **セットアップ/デプロイ** → [configuration.md](configuration.md)
- **API リファレンス/エンドポイント** → [api.md](api.md)
- **コード例/パターン** → [patterns.md](patterns.md)
- **デバッグ/トラブルシューティング** → [gotchas.md](gotchas.md)

**REST API を使う場合:**
- [api.md](api.md) の REST API セクションから始める
- レート制限については [gotchas.md](gotchas.md) を確認する

**Workers を使う場合:**
- [configuration.md](configuration.md) から始める
- セッション管理については [patterns.md](patterns.md) を確認する
- Workers Bindings については [api.md](api.md) を参照する

## このリファレンスの内容

- **[configuration.md](configuration.md)** - セットアップ、デプロイ、wrangler の設定、互換性
- **[api.md](api.md)** - REST API エンドポイント + Workers Bindings（Puppeteer/Playwright）
- **[patterns.md](patterns.md)** - 一般的なパターン、ユースケース、実例
- **[gotchas.md](gotchas.md)** - トラブルシューティング、ベストプラクティス、プランごとの制限、よくあるエラー

## 関連項目

- [Cloudflare Docs](https://developers.cloudflare.com/browser-rendering/)
