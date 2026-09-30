# RealtimeKit の注意点とトラブルシューティング

## よくあるエラー

### 「ミーティングに接続できません」

**原因:** 認証トークンが無効または期限切れ、API 認証情報に必要な権限がない、またはネットワークで WebRTC がブロックされている
**解決方法:**
トークンの有効性を確認し、API トークンに **Realtime / Realtime Admin** 権限があることを確認します。制限の厳しいネットワークでは TURN サービスを有効にします。

### 「ビデオ／音声トラックがありません」

**原因:** ブラウザーの権限が許可されていない、ビデオ／音声が有効になっていない、デバイスが使用中、またはデバイスが利用できない
**解決方法:**
ブラウザーの権限を明示的に要求し、初期化設定を確認し、`meeting.self.getAllDevices()` を使ってデバッグし、デバイスを使用しているほかのアプリを閉じます。

### 「参加者数が一致しません」

**原因:** `meeting.participants` には `meeting.self` が含まれない
**解決方法:** 合計数 = `meeting.participants.joined.size() + 1`

### 「イベントが発火しません」

**原因:** アクションの実行後にリスナーを登録している、イベント名が正しくない、または名前空間が間違っている
**解決方法:**
`meeting.join()` を呼び出す前にリスナーを登録し、イベント名をドキュメントと照合して、正しい名前空間であることを確認します。

### 「API 呼び出しで CORS エラーが発生します」

**原因:** クライアント側から REST API を呼び出している
**解決方法:** REST API の呼び出しはすべてサーバー側（Workers、バックエンド）で行う**必要があります**。API トークンをクライアントに公開しないでください。

### 「プリセットが適用されません」

**原因:** プリセットが存在しない、名前が一致しない（大文字と小文字を区別）、またはプリセットより先に参加者を作成している
**解決方法:**
Dashboard または API でプリセットの存在を確認し、正確な綴りと大文字・小文字を確認してから、参加者を追加する前にプリセットを作成します。

### 「トークン再利用エラー」

**原因:** セッション間で参加者トークンを再利用している
**解決方法:** セッションごとに新しいトークンを生成します。セッション中にトークンの期限が切れた場合は、更新エンドポイントを使用します。

### 「ビデオ品質が低い」

**原因:** 帯域幅が不足している、解像度／ビットレートが高すぎる、または CPU に過負荷がかかっている
**解決方法:**
`mediaConfiguration.video` の解像度／frameRate を下げ、ネットワーク状況を監視し、参加者数またはグリッドサイズを減らします。

### 「エコーまたは音声のフィードバック」

**原因:** 複数のデバイスが同じ音源を拾っている
**解決方法:**
- `mediaConfiguration.video` の解像度／frameRate を下げる
- ネットワーク状況を監視する
- 参加者数またはグリッドサイズを減らす

### 問題: エコーまたは音声のフィードバック
**原因**: 複数のデバイスが同じ音源を拾っている

**解決策**:
`echoCancellation: true` を `mediaConfiguration.audio` で有効にし、ヘッドホンを使用し、発言していないときはミュートにします。

### 「画面共有が機能しません」

**原因:** ブラウザーが画面共有 API に対応していない、権限が拒否された、または `displaySurface` の設定が間違っている
**解決方法:**
Chrome／Edge／Firefox を使用します（Safari の対応は限定的です）。ブラウザーの権限を確認し、`displaySurface` に別の値（'window'、'monitor'、'browser'）を試します。

### 「ミーティングをスケジュールするにはどうすればよいですか？」

**原因:** RealtimeKit には組み込みのスケジュール管理システムがない
**解決方法:**
ミーティング ID をタイムスタンプとともにデータベースに保存します。ユーザーが参加するタイミングでのみ参加者トークンを生成します。例:
```typescript
// Store in DB
{ meetingId: 'abc123', scheduledFor: '2026-02-15T10:00:00Z', userId: 'user456' }

// Generate token when user clicks "Join" near scheduled time
const response = await fetch('/api/join-meeting', {
  method: 'POST',
  body: JSON.stringify({ meetingId: 'abc123' })
});
const { authToken } = await response.json();
```

### 「録画が開始されません」

**原因:** プリセットに録画権限がない、アクティブなセッションがない、またはクライアントから API を呼び出している
**解決方法:**
プリセットに `canRecord: true` と `canStartStopRecording: true` があることを確認し、セッションがアクティブ（参加者が少なくとも 1 人）であることを確認して、録画 API の呼び出しはサーバー側のみで行います。

## 制限

| リソース | 制限 |
|----------|-------|
| セッションあたりの最大参加者数 | 100 |
| App あたりの最大同時セッション数 | 1000 |
| 録画の最大時間 | 6 時間 |
| ミーティングの最大時間 | 24 時間 |
| チャットメッセージの最大文字数 | 4000 文字 |
| プリセット名の最大文字数 | 64 文字 |
| ミーティングタイトルの最大文字数 | 256 文字 |
| 参加者名の最大文字数 | 256 文字 |
| トークンの有効期限 | 24 時間（デフォルト） |
| 必要な WebRTC ポート | UDP 1024-65535 |

## ネットワーク要件

### ファイアウォールルール
次への送信 UDP／TCP を許可します:
- `*.cloudflare.com` ポート 443、80
- UDP ポート 1024-65535（WebRTC メディア）

### TURN サービス
ファイアウォール／プロキシの制限が厳しい環境のユーザー向けに有効にします:
```jsonc
// wrangler.jsonc
{
  "vars": {
    "TURN_SERVICE_ID": "your_turn_service_id"
  }
  // Set secret: wrangler secret put TURN_SERVICE_TOKEN
}
```

アカウントで有効にすると、SDK で TURN が自動的に設定されます。

## デバッグのヒント

```typescript
// Check devices
const devices = await meeting.self.getAllDevices();
meeting.self.on('deviceListUpdate', ({ added, removed, devices }) => console.log('Devices:', { added, removed, devices }));

// Monitor participants
meeting.participants.joined.on('participantJoined', (p) => console.log(`${p.name} joined:`, { id: p.id, userId: p.userId, audioEnabled: p.audioEnabled, videoEnabled: p.videoEnabled }));

// Check room state
meeting.self.on('roomJoined', () => console.log('Room:', { meetingId: meeting.meta.meetingId, meetingTitle: meeting.meta.meetingTitle, participantCount: meeting.participants.joined.size() + 1, audioEnabled: meeting.self.audioEnabled, videoEnabled: meeting.self.videoEnabled }));

// Log all events
['roomJoined', 'audioUpdate', 'videoUpdate', 'screenShareUpdate', 'deviceUpdate', 'deviceListUpdate'].forEach(event => meeting.self.on(event, (data) => console.log(`[self] ${event}:`, data)));
['participantJoined', 'participantLeft'].forEach(event => meeting.participants.joined.on(event, (data) => console.log(`[participants] ${event}:`, data)));
meeting.chat.on('chatUpdate', (data) => console.log('[chat] chatUpdate:', data));
```

## セキュリティとパフォーマンス

### セキュリティ: してはいけないこと
- クライアントコードで `CLOUDFLARE_API_TOKEN` を公開したり、フロントエンドに認証情報をハードコードしたりしない
- 参加者トークンを再利用しない。暗号化せずにトークンを localStorage に保存しない
- クライアント側でミーティングを作成できるようにしない

### セキュリティ: すること
- トークンはサーバー側でのみ生成し、HTTPS を使用し、レート制限を実装する
- トークンを生成する前にユーザー認証を検証し、`custom_participant_id` を使って独自のユーザーシステムに対応付ける
- ユーザーのロールごとに適切なプリセット権限を設定し、API トークンを定期的にローテーションする

### パフォーマンス
- **CPU**: ビデオの解像度／frameRate を下げ、音声のみの場合はビデオを無効にし、大規模なミーティングでは `meeting.participants.active` を使用し、仮想スクロールを実装する
- **帯域幅**: `mediaConfiguration` で最大解像度を設定し、不要であれば画面共有の音声を無効にし、音声のみのモードを使用し、適応型ビットレートを実装する
- **メモリ**: アンマウント時にイベントリスナーをクリーンアップし、完了したら `meeting.leave()` を呼び出し、大きな参加者配列を保存しない

## このリファレンスについて
- [README.md](README.md) - 概要、主要な概念、クイックスタート
- [configuration.md](configuration.md) - SDK 設定、プリセット、wrangler のセットアップ
- [api.md](api.md) - クライアント SDK API、REST エンドポイント
- [patterns.md](patterns.md) - 一般的なパターン、React フック、バックエンド統合