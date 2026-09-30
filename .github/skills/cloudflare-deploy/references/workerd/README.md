# Workerd ランタイム

Cloudflare Workers を支える、V8 ベースの JS/Wasm ランタイムです。アプリケーションサーバー、開発ツール、または HTTP プロキシとして使用できます。

## ⚠️ 重要なセキュリティに関する注意
**workerd は強化されたサンドボックスではありません。** 信頼できないコードを実行しないでください。workerd は、複数テナント型 SaaS 向けではなく、ローカルまたはセルフホスト環境で**自身のコードを**デプロイするために設計されています。Cloudflare の本番環境には、オープンソース版 workerd にはないセキュリティ層が追加されています。

## 判断フロー：何を使うべきか

**ユーザーの 95%:** Wrangler を使用する
- ローカル開発: `wrangler dev`（内部で workerd を使用）
- デプロイ: `wrangler deploy`（Cloudflare にデプロイ）
- 型定義: `wrangler types`（TypeScript 型を生成）

**生の workerd を直接使うのは、次の場合に限ります:**
- Workers ランタイムを本番環境でセルフホストする
- C++ アプリケーションにランタイムを組み込む
- カスタムのツールやテスト基盤を構築する
- workerd 固有の挙動をデバッグする

**workerd を決して使ってはいけない用途:**
- 信頼できないコードやユーザーが投稿したコードの実行
- マルチテナントの分離（十分に強化されていません）
- 追加のセキュリティ層を設けない本番環境での使用

## 主な機能
- **標準ベース**: Fetch API、Web Crypto、Streams、WebSocket
- **ナノサービス**: ローカル呼び出しと同等のパフォーマンスを持つサービスバインディング
- **ケイパビリティセキュリティ**: 明示的なバインディングにより SSRF を防止
- **後方互換性**: バージョンはサポートされる最大の互換性日付に対応

## アーキテクチャ
```
Config (workerd.capnp)
├── Services (workers/endpoints)
├── Sockets (HTTP/HTTPS listeners)
└── Extensions (global capabilities)
```

## クイックスタート
```bash
workerd serve config.capnp
workerd compile config.capnp myConfig -o binary
workerd test config.capnp
```

## プラットフォームのサポートとベータ版の状況

| プラットフォーム | 状況 | 備考 |
|----------|--------|-------|
| Linux (x64) | 安定版 | 主なプラットフォーム |
| macOS (x64/ARM) | 安定版 | フルサポート |
| Windows | ベータ版 | 最良の結果を得るには WSL2 を使用 |
| Linux (ARM64) | 実験的 | テストは限定的 |

workerd は**活発に開発中**です。破壊的変更が生じる可能性があります。本番環境ではバージョンを固定してください。

## 基本概念
- **サービス**: 名前付きエンドポイント（worker/network/disk/external）
- **バインディング**: ケイパビリティベースのリソースアクセス（KV/DO/R2/services）
- **互換性日付**: 機能の有効化を制御する日付（必ず設定してください！）
- **モジュール**: ES モジュール（推奨）またはサービスワーカー構文

## 読む順序（段階的に情報を開示）

**まずはこちら:**
1. この README（概要、判断フロー）
2. [patterns.md](./patterns.md) - 一般的なワークフロー、フレームワークの例

**詳細が必要な場合:**
3. [configuration.md](./configuration.md) - 設定形式、サービス、バインディング
4. [api.md](./api.md) - ランタイム API、TypeScript 型
5. [gotchas.md](./gotchas.md) - よくあるエラー、デバッグ

## 関連資料
- [workers](../workers/) - Workers ランタイム API のドキュメント
- [miniflare](../miniflare/) - workerd を基盤とするテストツール
- [wrangler](../wrangler/) - ローカル開発で workerd を使用する CLI
