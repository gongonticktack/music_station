# Cloudflare Stream

1つのAPIでライブ動画とオンデマンド動画を配信できるサーバーレスプラットフォーム。

## 概要

Cloudflare Streamを使うと、インフラを管理せずに動画のアップロード、保存、エンコード、配信ができます。Cloudflareのグローバルネットワーク上で動作します。

### 主な機能
- **オンデマンド動画**: アップロード、エンコード、保存、配信
- **ライブ配信**: ABR対応のRTMPS/SRT取り込み
- **Direct Creator Uploads**: エンドユーザーがAPIキーなしでアップロード
- **署名付きURL**: トークンベースのアクセス制御
- **分析**: GraphQL経由のサーバー側メトリクス
- **Webhook**: 処理完了の通知
- **字幕**: 字幕のアップロードまたはAI生成
- **ウォーターマーク**: 動画にブランド表示を適用
- **ダウンロード**: オフライン視聴用のMP4を有効化

## 基本概念

### 動画のアップロード方法
1. **APIアップロード（TUSプロトコル）**: サーバーから直接アップロード
2. **URLからアップロード**: 外部ソースからインポート
3. **Direct Creator Uploads**: ユーザー生成コンテンツ（推奨）

### 再生方法
1. **Stream Player（iframe）**: 最適化された組み込みプレーヤー
2. **カスタムプレーヤー（HLS/DASH）**: Video.js、HLS.jsとの連携
3. **サムネイル**: 静止画またはアニメーションのプレビュー

### アクセス制御
- **公開**: 制限なし
- **requireSignedURLs**: トークンベースのアクセス
- **allowedOrigins**: ドメイン制限
- **アクセスルール**: トークン内での地域/IP制限

### ライブ配信
- OBS、FFmpegからRTMPS/SRTで取り込み
- オンデマンド動画に自動録画
- YouTube、Twitchなどへ同時配信
- ブラウザー配信向けWebRTCサポート

## クイックスタート

**API経由で動画をアップロード**
```bash
curl -X POST \
  "https://api.cloudflare.com/client/v4/accounts/{account_id}/stream/copy" \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com/video.mp4"}'
```

**プレーヤーを埋め込む**
```html
<iframe
  src="https://customer-<CODE>.cloudflarestream.com/<VIDEO_ID>/iframe"
  style="border: none;"
  height="720" width="1280"
  allow="accelerometer; gyroscope; autoplay; encrypted-media; picture-in-picture;"
  allowfullscreen="true"
></iframe>
```

**ライブ入力を作成する**
```bash
curl -X POST \
  "https://api.cloudflare.com/client/v4/accounts/{account_id}/stream/live_inputs" \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"recording": {"mode": "automatic"}}'
```

## 制限

- 最大ファイルサイズ: 30 GB
- 最大フレームレート: 60 fps（推奨）
- 対応フォーマット: MP4、MKV、MOV、AVI、FLV、MPEG-2 TS/PS、MXF、LXF、GXF、3GP、WebM、MPG、QuickTime

## 料金

- 保存時間1000分あたり$5
- 配信時間1000分あたり$1

## リソース

- ダッシュボード: https://dash.cloudflare.com/?to=/:account/stream
- APIドキュメント: https://developers.cloudflare.com/api/resources/stream/
- Streamドキュメント: https://developers.cloudflare.com/stream/

## 読む順序

| 順序 | ファイル | 目的 | 使用する場面 |
|-------|------|---------|-------------|
| 1 | [configuration.md](./configuration.md) | SDK、環境変数、署名キーのセットアップ | 新規プロジェクトの開始時 |
| 2 | [api.md](./api.md) | オンデマンド動画API | アップロードや再生の実装時 |
| 3 | [api-live.md](./api-live.md) | ライブ配信API | ライブ配信の構築時 |
| 4 | [patterns.md](./patterns.md) | フルスタックの処理フロー、TUS、JWT署名 | ワークフローの実装時 |
| 5 | [gotchas.md](./gotchas.md) | エラー、制限、トラブルシューティング | 問題のデバッグ時 |

## このリファレンスの内容

- [configuration.md](./configuration.md) - セットアップ、環境変数、wranglerの設定
- [api.md](./api.md) - オンデマンド動画のアップロード、再生、管理API
- [api-live.md](./api-live.md) - ライブ配信（RTMPS/SRT/WebRTC）、同時配信
- [patterns.md](./patterns.md) - フルスタックの処理フロー、状態管理、ベストプラクティス
- [gotchas.md](./gotchas.md) - エラーコード、トラブルシューティング、制限

## 関連項目

- [workers](../workers/) - WorkersでStream APIをデプロイする
- [pages](../pages/) - StreamをPagesと統合する
- [workers-ai](../workers-ai/) - AIで字幕を生成する
