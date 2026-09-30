# Cloudflare Images スキルリファレンス

**Cloudflare Images** は、Cloudflare のグローバルネットワークを通じて、大規模な画像の保存、変換、最適化、配信を提供するエンドツーエンドの画像管理ソリューションです。

## クイック判断ツリー

**必要な操作:**
- **Worker 内で変換する？** → [api.md](api.md#workers-binding-api-2026-primary-method)（Workers Binding API）
- **Worker からアップロードする？** → [api.md](api.md#upload-from-worker)（REST API）
- **クライアントからアップロードする？** → [patterns.md](patterns.md#upload-from-client-direct-creator-upload)（Direct Creator Upload）
- **バリアントを設定する？** → [configuration.md](configuration.md#variants-configuration)
- **レスポンシブ画像を配信する？** → [patterns.md](patterns.md#responsive-images)
- **ウォーターマークを追加する？** → [patterns.md](patterns.md#watermarking)
- **エラーを解決する？** → [gotchas.md](gotchas.md#common-errors)

## 読む順序

**画像のアップロード／変換機能を構築する場合:**
1. [configuration.md](configuration.md) - Workers バインディングを設定
2. [api.md](api.md#workers-binding-api-2026-primary-method) - 変換 API を確認
3. [patterns.md](patterns.md#upload-from-client-direct-creator-upload) - 直接アップロードのパターン
4. [gotchas.md](gotchas.md) - 制限とエラーを確認

**URL ベースの変換を行う場合:**
1. [configuration.md](configuration.md#variants-configuration) - バリアントを作成
2. [api.md](api.md#url-transform-api) - URL の構文
3. [patterns.md](patterns.md#responsive-images) - レスポンシブ画像のパターン

**トラブルシューティングの場合:**
1. [gotchas.md](gotchas.md#common-errors) - エラーメッセージ
2. [gotchas.md](gotchas.md#limits) - サイズ／形式の制限

## 主な方法

| 方法 | 用途 | 場所 |
|--------|----------|----------|
| `env.IMAGES.input().transform()` | Worker 内で変換 | [api.md:11](api.md) |
| REST API `/images/v1` | 画像をアップロード | [api.md:57](api.md) |
| Direct Creator Upload | クライアント側からアップロード | [api.md:127](api.md) |
| URL transforms | 静的画像の配信 | [api.md:112](api.md) |

## このリファレンスの内容

- **[api.md](api.md)** - API 全般：Workers バインディング、REST エンドポイント、URL 変換
- **[configuration.md](configuration.md)** - セットアップ：wrangler.toml、バリアント、認証、署名付き URL
- **[patterns.md](patterns.md)** - パターン：レスポンシブ画像、ウォーターマーク、形式ネゴシエーション、キャッシュ
- **[gotchas.md](gotchas.md)** - トラブルシューティング：制限、エラー、ベストプラクティス

## 主な機能

- **自動最適化** - AVIF/WebP 形式のネゴシエーション
- **オンザフライ変換** - URL または API を使ったリサイズ、クロップ、ぼかし、シャープ化
- **Workers バインディング** - Workers で画像を変換（2026 年時点の主な方法）
- **直接アップロード** - バックエンドのプロキシを介さない安全なクライアント側アップロード
- **グローバル配信** - Cloudflare の 300 以上のデータセンターでキャッシュ
- **ウォーターマーク** - プログラムによる画像の重ね合わせ

## 関連項目

- [公式ドキュメント](https://developers.cloudflare.com/images/)
- [Workers の例](https://developers.cloudflare.com/images/tutorials/)
