# Cloudflare Realtime SFU リファレンス

Cloudflare Realtime SFU（Selective Forwarding Unit）を使用してリアルタイムの音声・動画・データアプリケーションを構築するための専門的なガイダンス。

## 読む順序

| タスク | ファイル | 約トークン数 |
|------|-------|---------|
| 新規プロジェクト | README → configuration | 約1200 |
| パブリッシュ／サブスクライブの実装 | README → api | 約1600 |
| PartyTracks の追加 | patterns（PartyTracks セクション） | 約800 |
| プレゼンスシステムの構築 | patterns（DO セクション） | 約800 |
| 接続の問題のデバッグ | gotchas | 約700 |
| 数百万規模へのスケール | patterns（Cascading セクション） | 約600 |
| シムルキャストの追加 | patterns（Advanced セクション） | 約500 |
| TURN の設定 | configuration（TURN セクション） | 約400 |

## このリファレンスの内容

- **[configuration.md](configuration.md)** - セットアップ、デプロイ、環境変数、Wrangler の設定
- **[api.md](api.md)** - セッション、トラック、エンドポイント、リクエスト／レスポンスのパターン
- **[patterns.md](patterns.md)** - アーキテクチャパターン、ユースケース、統合例
- **[gotchas.md](gotchas.md)** - よくある問題、デバッグ、パフォーマンス、セキュリティ

## クイックスタート

Cloudflare Realtime SFU：グローバルネットワーク（310 以上の都市）上の WebRTC インフラストラクチャ。エニーキャストルーティングを採用し、リージョンの制約がなく、パブリッシュ／サブスクライブモデルを使用します。

**基本概念:**
- **セッション:** Cloudflare エッジへの WebRTC PeerConnection
- **トラック:** パブリッシュまたはサブスクライブする音声／動画／データチャネル
- **ルームなし:** トラック共有を使ってプレゼンスレイヤーを自分で構築します（patterns.md を参照）

**基本的な考え方:** クライアントは WebRTC セッションを1つ確立し、トラック（音声／動画）をパブリッシュします。バックエンド経由でトラック ID を共有すると、他のユーザーはトラック ID とセッション ID を使ってそのトラックをサブスクライブできます。

## アプローチを選ぶ

| アプローチ | 使用する場面 | 複雑さ |
|----------|-------------|------------|
| **PartyTracks** | デバイス切り替えや React を使う本番アプリ | 低 - Observable ベースで、再接続に対応 |
| **Raw API** | 独自要件、ブラウザー以外の環境、学習 | 中 - 完全な制御が可能で、WebRTC のライフサイクルを手動管理 |
| **RealtimeKit** | UI コンポーネント付きのエンドツーエンド SDK | 最低 - 状態管理と React フックを提供 |

**推奨:** ほとんどの本番アプリケーションでは PartyTracks から始めてください。PartyTracks の例は patterns.md を参照してください。

## SFU と RealtimeKit の比較

- **Realtime SFU:** WebRTC インフラストラクチャ（このリファレンスの対象）。シグナリング、プレゼンス、UI は自分で構築します。
- **RealtimeKit:** SFU 上の SDK レイヤー。React フック、状態管理、UI コンポーネントが含まれます。Cloudflare AI プラットフォームの一部です。

独自のシグナリングが必要な場合や React 以外のフレームワークを使う場合は、SFU を直接使用します。React で迅速に開発する場合は RealtimeKit を使用します。

## セットアップ

ダッシュボード: https://dash.cloudflare.com/?to=/:account/calls

ダッシュボードから `CALLS_APP_ID` と `CALLS_APP_SECRET` を取得し、デプロイについては configuration.md を参照してください。

## 関連項目

- [Orange Meets Demo](https://demo.orange.cloudflare.dev/)
- [Orange Source](https://github.com/cloudflare/orange)
- [Calls Examples](https://github.com/cloudflare/calls-examples)
- [API Reference](https://developers.cloudflare.com/api/resources/calls/)
- [RealtimeKit Docs](https://developers.cloudflare.com/workers-ai/realtimekit/)
