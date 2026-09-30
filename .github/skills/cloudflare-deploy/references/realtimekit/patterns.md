# RealtimeKit のパターン

## UI キット（最小限のコード）

```tsx
// React
import { RtkMeeting } from '@cloudflare/realtimekit-react-ui';
<RtkMeeting authToken="<token>" onLeave={() => console.log('Left')} />

// Angular
@Component({ template: `<rtk-meeting [authToken]="authToken" (rtkLeave)="onLeave($event)"></rtk-meeting>` })
export class AppComponent { authToken = '<token>'; onLeave(event: unknown) {} }

// HTML/Web Components
<script type="module" src="https://cdn.jsdelivr.net/npm/@cloudflare/realtimekit-ui/dist/realtimekit-ui/realtimekit-ui.esm.js"></script>
<rtk-meeting id="meeting"></rtk-meeting>
<script>document.getElementById('meeting').authToken = '<token>';</script>
```

## UI コンポーネント

RealtimeKit は、フレームワーク用ラッパーを備えた 133 種類以上のビルド済み Stencil.js Web コンポーネントを提供します。

### レイアウトコンポーネント
- `<RtkMeeting>` - 会議 UI 全体（オールインワン）
- `<RtkHeader>`, `<RtkStage>`, `<RtkControlbar>` - レイアウトの各セクション
- `<RtkSidebar>` - チャット／参加者サイドバー
- `<RtkGrid>` - アダプティブなビデオグリッド

### 操作コンポーネント  
- `<RtkMicToggle>`, `<RtkCameraToggle>` - メディアコントロール
- `<RtkScreenShareToggle>` - 画面共有
- `<RtkLeaveButton>` - 会議から退出
- `<RtkSettingsModal>` - デバイス設定

### グリッドのバリエーション
- `<RtkSpotlightGrid>` - アクティブスピーカーにフォーカス
- `<RtkAudioGrid>` - 音声のみモード
- `<RtkPaginatedGrid>` - ページ分割レイアウト

**全カタログを参照**: https://docs.realtime.cloudflare.com/ui-kit

## コア SDK のパターン

### 基本設定
```typescript
import RealtimeKitClient from '@cloudflare/realtimekit';

const meeting = new RealtimeKitClient({ authToken, video: true, audio: true });
meeting.self.on('roomJoined', () => console.log('Joined:', meeting.meta.meetingTitle));
meeting.participants.joined.on('participantJoined', (p) => console.log(`${p.name} joined`));
await meeting.join();
```

### ビデオグリッドとデバイス選択
```typescript
// Video grid
function VideoGrid({ meeting }) {
  const [participants, setParticipants] = useState([]);
  useEffect(() => {
    const update = () => setParticipants(meeting.participants.joined.toArray());
    meeting.participants.joined.on('participantJoined', update);
    meeting.participants.joined.on('participantLeft', update);
    update();
    return () => { meeting.participants.joined.off('participantJoined', update); meeting.participants.joined.off('participantLeft', update); };
  }, [meeting]);
  return <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))' }}>
    {participants.map(p => <VideoTile key={p.id} participant={p} />)}
  </div>;
}

function VideoTile({ participant }) {
  const videoRef = useRef<HTMLVideoElement>(null);
  useEffect(() => {
    if (videoRef.current && participant.videoTrack) videoRef.current.srcObject = new MediaStream([participant.videoTrack]);
  }, [participant.videoTrack]);
  return <div><video ref={videoRef} autoPlay playsInline muted /><div>{participant.name}</div></div>;
}

// Device selection
const devices = await meeting.self.getAllDevices();
const switchCamera = (deviceId: string) => {
  const device = devices.find(d => d.deviceId === deviceId);
  if (device) await meeting.self.setDevice(device);
};
```

## React フック（公式）

```typescript
import { useRealtimeKitClient, useRealtimeKitSelector } from '@cloudflare/realtimekit-react-ui';

function MyComponent() {
  const [meeting, initMeeting] = useRealtimeKitClient();
  const audioEnabled = useRealtimeKitSelector(m => m.self.audioEnabled);
  const participantCount = useRealtimeKitSelector(m => m.participants.joined.size());
  
  useEffect(() => { initMeeting({ authToken: '<token>' }); }, []);
  
  return <div>
    <button onClick={() => meeting?.self.enableAudio()}>{audioEnabled ? 'Mute' : 'Unmute'}</button>
    <span>{participantCount} participants</span>
  </div>;
}
```

**利点:** 自動再レンダリング、メモ化されたセレクター、型安全

## ウェイトリストの処理

```typescript
// Monitor waitlist
meeting.participants.waitlisted.on('participantJoined', (participant) => {
  console.log(`${participant.name} is waiting`);
  // Show admin UI to approve/reject
});

// Approve from waitlist (backend only)
await fetch(
  `https://api.cloudflare.com/client/v4/accounts/${accountId}/realtime/kit/${appId}/meetings/${meetingId}/active-session/waitlist/approve`,
  {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${apiToken}` },
    body: JSON.stringify({ user_ids: [participant.userId] })
  }
);

// Client receives automatic transition when approved
meeting.self.on('roomJoined', () => console.log('Approved and joined'));
```

## 音声のみモード

```typescript
const meeting = new RealtimeKitClient({
  authToken: '<token>',
  video: false,  // Disable video
  audio: true,
  mediaConfiguration: {
    audio: {
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true
    }
  }
});

// Use audio grid component
import { RtkAudioGrid } from '@cloudflare/realtimekit-react-ui';
<RtkAudioGrid meeting={meeting} />
```

## アドオンシステム

```typescript
// List available addons
meeting.plugins.all.forEach(plugin => {
  console.log(plugin.id, plugin.name, plugin.active);
});

// Activate collaborative app
await meeting.plugins.activate('whiteboard-addon-id');

// Listen for activations
meeting.plugins.on('pluginActivated', ({ plugin }) => {
  console.log(`${plugin.name} activated`);
});

// Deactivate
await meeting.plugins.deactivate();
```

## バックエンドとの統合

### トークン生成（Workers）
```typescript
export interface Env { CLOUDFLARE_API_TOKEN: string; CLOUDFLARE_ACCOUNT_ID: string; REALTIMEKIT_APP_ID: string; }

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    
    if (url.pathname === '/api/join-meeting') {
      const { meetingId, userName, presetName } = await request.json();
      const response = await fetch(
        `https://api.cloudflare.com/client/v4/accounts/${env.CLOUDFLARE_ACCOUNT_ID}/realtime/kit/${env.REALTIMEKIT_APP_ID}/meetings/${meetingId}/participants`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${env.CLOUDFLARE_API_TOKEN}` },
          body: JSON.stringify({ name: userName, preset_name: presetName })
        }
      );
      const data = await response.json();
      return Response.json({ authToken: data.result.authToken });
    }
    
    return new Response('Not found', { status: 404 });
  }
};
```

## ベストプラクティス

### セキュリティ
1. **API トークンをクライアント側に絶対に公開しない** - 参加者トークンはサーバー側でのみ生成する
2. **参加者トークンを再利用しない** - セッションごとに新しいトークンを生成し、期限切れの場合は更新エンドポイントを使用する
3. **カスタム参加者 ID を使用する** - セッションをまたいだ追跡のため、独自のユーザーシステムに対応付ける

### パフォーマンス
1. **イベント駆動の更新** - イベントをリッスンし、ポーリングはしない。必要な場合にのみ `toArray()` を使用する
2. **メディア品質の制約** - ネットワーク状況に応じて適切な解像度／ビットレートの上限を設定する
3. **デバイス管理** - UX 向上のため `autoSwitchAudioDevice` を有効にし、デバイス一覧の更新を処理する

### アーキテクチャ
1. **環境ごとに App を分ける** - データの混在を防ぐため、ステージング用と本番用を分ける
2. **プリセット戦略** - App レベルでプリセットを作成し、複数の会議で再利用する
3. **トークン管理** - バックエンドでトークンを生成し、認証済みエンドポイント経由でフロントエンドに渡す

## このリファレンスの内容
- [README.md](README.md) - 概要、主要な概念、クイックスタート
- [configuration.md](configuration.md) - SDK の設定、プリセット、wrangler のセットアップ
- [api.md](api.md) - クライアント SDK API、REST エンドポイント
- [gotchas.md](gotchas.md) - よくある問題、トラブルシューティング、制限事項