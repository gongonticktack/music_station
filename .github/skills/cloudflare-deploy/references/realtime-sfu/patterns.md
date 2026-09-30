# パターンとユースケース

## アーキテクチャ

```
Client (WebRTC) <---> CF Edge <---> Backend (HTTP)
                           |
                    CF Backbone (310+ DCs)
                           |
                    Other Edges <---> Other Clients
```

Anycast: 最終区間で 50 ms 未満（95%）、リージョン選択不要、NACK シールド、分散コンセンサス

カスケードツリーは数百万規模まで自動スケールします:
```
Publisher -> Edge A -> Edge B -> Sub1
                    \-> Edge C -> Sub2,3
```

## ユースケース

**1:1:** A がセッションを作成して公開し、B がセッションを作成して A を購読し、公開する。A は B を購読する
**N:N:** 全員がセッションを作成して公開し、バックエンドがトラック ID をブロードキャストし、全員が他の参加者を購読する
**1:N:** 配信者がセッションを作成して公開し、各視聴者がセッションを作成して購読する（ファンアウトの上限なし）
**ブレイクアウト:** 同じ PeerConnection を使用する。バックエンドがトラックを閉じたり追加したりし、再作成は不要

## PartyTracks（推奨）

デバイス／ネットワークを自動処理する Observable ベースのクライアント:

```typescript
import {PartyTracks} from 'partytracks';

// Create client
const pt = new PartyTracks({
  apiUrl: '/api/calls',
  sessionId: 'my-session',
  onTrack: (track, peer) => {
    const video = document.getElementById(`video-${peer.id}`) as HTMLVideoElement;
    video.srcObject = new MediaStream([track]);
  }
});

// Publish camera (push API)
const camera = await pt.getCamera(); // Auto-requests permissions, handles device changes
await pt.publishTrack(camera, {trackName: 'my-camera'});

// Subscribe to remote track (pull API)
await pt.subscribeToTrack({trackName: 'remote-camera', sessionId: 'other-session'});

// React hook example
import {useObservableAsValue} from 'observable-hooks';

function VideoCall() {
  const localTracks = useObservableAsValue(pt.localTracks$);
  const remoteTracks = useObservableAsValue(pt.remoteTracks$);
  
  return <div>{/* Render tracks */}</div>;
}

// Screenshare
const screen = await pt.getScreenshare();
await pt.publishTrack(screen, {trackName: 'my-screen'});

// Handle device changes (automatic)
// PartyTracks detects device changes (e.g., Bluetooth headset) and renegotiates
```

## バックエンド

Express:
```js
app.post('/api/new-session', async (req, res) => {
  const r = await fetch(`${CALLS_API}/apps/${process.env.CALLS_APP_ID}/sessions/new`,
    {method: 'POST', headers: {'Authorization': `Bearer ${process.env.CALLS_APP_SECRET}`}});
  res.json(await r.json());
});
```

Workers: 同じパターンを使用し、`env.CALLS_APP_ID` と `env.CALLS_APP_SECRET` を使う

DO Presence: 定型コードについては configuration.md を参照

## 音声レベルの検出

```typescript
// Attach analyzer to audio track
function attachAudioLevelDetector(track: MediaStreamTrack) {
  const ctx = new AudioContext();
  const analyzer = ctx.createAnalyser();
  const src = ctx.createMediaStreamSource(new MediaStream([track]));
  src.connect(analyzer);
  
  const data = new Uint8Array(analyzer.frequencyBinCount);
  const checkLevel = () => {
    analyzer.getByteFrequencyData(data);
    const level = data.reduce((a, b) => a + b) / data.length;
    if (level > 30) console.log('Speaking:', level); // Trigger UI update
    requestAnimationFrame(checkLevel);
  };
  checkLevel();
}
```

## 接続品質の監視

```typescript
pc.getStats().then(stats => {
  stats.forEach(report => {
    if (report.type === 'inbound-rtp' && report.kind === 'video') {
      const {packetsLost, packetsReceived, jitter} = report;
      const lossRate = packetsLost / (packetsLost + packetsReceived);
      if (lossRate > 0.05) console.warn('High packet loss:', lossRate);
      if (jitter > 100) console.warn('High jitter:', jitter);
    }
  });
});
```

## ステージ管理（表示する参加者数を制限）

```typescript
// Subscribe to top 6 active speakers only
let activeSubscriptions = new Set<string>();

function updateStage(topSpeakers: string[]) {
  const toAdd = topSpeakers.filter(id => !activeSubscriptions.has(id)).slice(0, 6);
  const toRemove = [...activeSubscriptions].filter(id => !topSpeakers.includes(id));
  
  toRemove.forEach(id => {
    pc.getSenders().find(s => s.track?.id === id)?.track?.stop();
    activeSubscriptions.delete(id);
  });
  
  toAdd.forEach(async id => {
    await fetch(`/api/subscribe`, {method: 'POST', body: JSON.stringify({trackId: id})});
    activeSubscriptions.add(id);
  });
}
```

## 応用

帯域幅の管理:
```ts
const s = pc.getSenders().find(s => s.track?.kind === 'video');
const p = s.getParameters();
if (!p.encodings) p.encodings = [{}];
p.encodings[0].maxBitrate = 1200000; p.encodings[0].maxFramerate = 24;
await s.setParameters(p);
```

Simulcast（CF が最適なレイヤーを自動転送）:
```ts
pc.addTransceiver('video', {direction: 'sendonly', sendEncodings: [
  {rid: 'high', maxBitrate: 1200000},
  {rid: 'med', maxBitrate: 600000, scaleResolutionDownBy: 2},
  {rid: 'low', maxBitrate: 200000, scaleResolutionDownBy: 4}
]});
```

DataChannel:
```ts
const dc = pc.createDataChannel('chat', {ordered: true, maxRetransmits: 3});
dc.onopen = () => dc.send(JSON.stringify({type: 'chat', text: 'Hi'}));
dc.onmessage = (e) => console.log('RX:', JSON.parse(e.data));
```

**WHIP/WHEP:** ストリーミング連携（OBS → SFU、SFU → ビデオプレーヤー）には、WHIP（入力）および WHEP（出力）プロトコルを使用します。Cloudflare Stream の連携ドキュメントを参照してください。

連携: 録画には R2 `env.R2_BUCKET.put(...)`、分析には Queues を使用

パフォーマンス: 接続時間 100～250 ms、レイテンシ約 50 ms（95%）、glass-to-glass で 200～400 ms、参加者数の上限なし（クライアント側: 10～50 トラック）