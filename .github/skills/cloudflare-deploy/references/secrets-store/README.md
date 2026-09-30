# Cloudflare Secrets Store

Workers と AI Gateway 向けのアカウントレベルの暗号化シークレット管理。

## 概要

**Secrets Store**: 一元管理されるアカウントレベルのシークレット。複数の Worker 間で再利用可能
**Worker Secrets**: Worker ごとのシークレット（`wrangler secret put`）

### アーキテクチャ

- **ストア**: コンテナ（ベータ版ではアカウントあたり 1 つ）
- **シークレット**: 文字列（最大 1024 bytes）
- **スコープ**: アクセスを制御する権限の境界
  - `workers`: Workers の実行時アクセス用
  - `ai-gateway`: AI Gateway のアクセス用
  - バインディングが機能するには、シークレットに正しいスコープが必要
- **バインディング**: `env` オブジェクト経由でシークレットを接続

**リージョン別の提供状況**: 中国ネットワークを除く全世界（中国ネットワークでは利用不可）

### アクセス制御

- **スーパー管理者**: フルアクセス
- **管理者**: シークレットの作成・編集・削除、メタデータの閲覧
- **デプロイヤー**: メタデータとバインディングの閲覧
- **レポーター**: メタデータのみ閲覧

API トークンの権限: `Account Secrets Store Edit/Read`

### 制限（ベータ版）

- アカウントあたり 100 件のシークレット
- アカウントあたり 1 つのストア
- シークレットあたり最大 1024 bytes
- 本番用シークレットは上限に算入

## 使用するケース

**次の場合は Secrets Store を使用:**
- 複数の Worker で同じ認証情報を共有する
- 一元管理が必要
- コンプライアンス上、監査証跡が必要
- チームでシークレットを共同管理する

**次の場合は Worker Secrets を使用:**
- シークレットが 1 つの Worker 専用
- 単純な単一 Worker のプロジェクト
- Worker 間で共有する必要がない

## このリファレンスについて

### タスク別の読む順序

| タスク | まず読む | 次に読む |
|------|------------|-----------|
| 概要をすばやく把握する | README.md | - |
| 初回セットアップ | README.md → configuration.md | api.md |
| Worker にシークレットを追加する | configuration.md | api.md |
| アクセスパターンを実装する | api.md | patterns.md |
| エラーをデバッグする | gotchas.md | api.md |
| シークレットをローテーションする | patterns.md | configuration.md |
| ベストプラクティス | gotchas.md | patterns.md |

### ファイル

- [configuration.md](./configuration.md) - Wrangler コマンド、バインディング設定
- [api.md](./api.md) - バインディング API、get/put/delete 操作
- [patterns.md](./patterns.md) - ローテーション、暗号化、アクセス制御
- [gotchas.md](./gotchas.md) - セキュリティ上の問題、制限、ベストプラクティス

## 関連項目
- [workers](../workers/) - Worker バインディングの統合
- [wrangler](../wrangler/) - CLI によるシークレット管理コマンド
