# Cloudflare RealtimeKit

**Cloudflare RealtimeKit** を使用してリアルタイムのビデオ／音声アプリケーションを構築するための専門的なガイダンスです。Web またはモバイルアプリケーションに、カスタマイズ可能なライブビデオや音声を追加するための包括的な SDK スイートです。

## 概要

RealtimeKit は、Realtime SFU を基盤とする Cloudflare の SDK スイートです。WebRTC の複雑さを抽象化し、迅速な統合、ビルド済み UI コンポーネント、グローバルなパフォーマンス（300 以上の都市）、本番環境向け機能（録画、文字起こし、チャット、投票）を提供します。

**ユースケース**: チーム会議、ウェビナー、ソーシャルビデオ、音声通話、インタラクティブなプラグイン

## 主要な概念

- **App**: 会議、参加者、プリセット、録画をまとめるワークスペース。ステージング環境と本番環境では App を分ける
- **Meeting**: 再利用可能な仮想ルーム。参加するたびに新しい **Session** が作成される
- **Session**: ライブ会議のインスタンス。初回の参加時に作成され、最後の参加者が退出すると終了する
- **Participant**: REST API 経由で追加されるユーザー。クライアント SDK 用の `authToken` が返される。**トークンを再利用しないこと**
- **Preset**: 再利用可能な権限／UI テンプレート（権限、会議タイプ、テーマ）。参加者の作成時に適用される
- **Peer ID** (`id`): セッションごとに固有で、再参加時に変わる
- **Participant ID** (`userId`): セッションをまたいで保持される

## クイックスタート

### 1. App と Meeting を作成する（バックエンド）

```bash
# Create app
curl -X POST 'https://api.cloudflare.com/client/v4/accounts/<account_id>/realtime/kit/apps' \
  -H 'Authorization: Bearer <api_token>' \
  -d '{"name": "My RealtimeKit App"}'

# Create meeting
curl -X POST 'https://api.cloudflare.com/client/v4/accounts/<account_id>/realtime/kit/<app_id>/meetings' \
  -H 'Authorization: Bearer <api_token>' \
  -d '{"title": "Team Standup"}'

# Add participant
curl -X POST 'https://api.cloudflare.com/client/v4/accounts/<account_id>/realtime/kit/<app_id>/meetings/<meeting_id>/participants' \
  -H 'Authorization: Bearer <api_token>' \
  -d '{"name": "Alice", "preset_name": "host"}'
# Returns: { authToken }
```

### 2. クライアントを統合する

**React**:
```tsx
import { RtkMeeting } from '@cloudflare/realtimekit-react-ui';

function App() {
  return <RtkMeeting authToken="<participant_auth_token>" onLeave={() => {}} />;
}
```

**コア SDK**:
```typescript
import RealtimeKitClient from '@cloudflare/realtimekit';

const meeting = new RealtimeKitClient({ authToken: '<token>', video: true, audio: true });
await meeting.join();
```

## 読む順序

| タスク | ファイル |
|------|-------|
| クイック統合 | README のみ |
| カスタム UI | README → patterns → api |
| バックエンドのセットアップ | README → configuration |
| 問題のデバッグ | gotchas |
| 高度な機能 | patterns → api |

## RealtimeKit と Realtime SFU の比較

| 選択肢 | 適した用途 |
|--------|------|
| **RealtimeKit** | ビルド済み UI、迅速な統合、React／Angular／HTML が必要な場合 |
| **Realtime SFU** | ゼロからの構築、カスタム WebRTC、完全な制御が必要な場合 |

RealtimeKit は Realtime SFU を基盤とし、UI コンポーネントと SDK によって WebRTC の複雑さを抽象化します。

## どのパッケージを使うか

ビルド済みの会議 UI が必要ですか？
- React → `@cloudflare/realtimekit-react-ui` (`<RtkMeeting>`)
- Angular → `@cloudflare/realtimekit-angular-ui`
- HTML／Vanilla → `@cloudflare/realtimekit-ui`

カスタム UI が必要ですか？
- コア SDK → `@cloudflare/realtimekit` (RealtimeKitClient) - 完全な制御

WebRTC を直接制御する必要がありますか？
- `realtime-sfu/` のリファレンスを参照

## このリファレンスの内容

- [Configuration](./configuration.md) - セットアップ、インストール、wrangler の設定
- [API](./api.md) - Meeting オブジェクト、REST API、SDK メソッド
- [Patterns](./patterns.md) - 一般的なワークフロー、コード例
- [Gotchas](./gotchas.md) - よくある問題、トラブルシューティング

## 関連項目

- [Workers](../workers/) - バックエンドとの統合
- [D1](../d1/) - 会議メタデータの保存
- [R2](../r2/) - 録画の保存
- [KV](../kv/) - セッション管理

## リファレンスリンク

- **公式ドキュメント**: https://developers.cloudflare.com/realtime/realtimekit/
- **API リファレンス**: https://developers.cloudflare.com/api/resources/realtime_kit/
- **サンプル**: https://github.com/cloudflare/realtimekit-web-examples
- **ダッシュボード**: https://dash.cloudflare.com/?to=/:account/realtime/kit