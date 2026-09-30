# Stream ライブストリーミング API

ライブ入力の作成、ステータス確認、同時配信、WebRTC ストリーミング。

## ライブ入力の作成

### Cloudflare SDK を使用

```typescript
import Cloudflare from 'cloudflare';

const client = new Cloudflare({ apiToken: env.CF_API_TOKEN });

const liveInput = await client.stream.liveInputs.create({
  account_id: env.CF_ACCOUNT_ID,
  recording: { mode: 'automatic', timeoutSeconds: 30 },
  deleteRecordingAfterDays: 30
});

// Returns: { uid, rtmps, srt, webRTC }
```

### Raw fetch API

```typescript
async function createLiveInput(accountId: string, apiToken: string) {
  const response = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${accountId}/stream/live_inputs`,
    {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${apiToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        recording: { mode: 'automatic', timeoutSeconds: 30 },
        deleteRecordingAfterDays: 30
      })
    }
  );
  const { result } = await response.json();
  return {
    uid: result.uid,
    rtmps: { url: result.rtmps.url, streamKey: result.rtmps.streamKey },
    srt: { url: result.srt.url, streamId: result.srt.streamId, passphrase: result.srt.passphrase },
    webRTC: result.webRTC
  };
}
```

## ライブステータスの確認

```typescript
async function getLiveStatus(accountId: string, liveInputId: string, apiToken: string) {
  const response = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${accountId}/stream/live_inputs/${liveInputId}`,
    { headers: { 'Authorization': `Bearer ${apiToken}` } }
  );
  const { result } = await response.json();
  return {
    isLive: result.status?.current?.state === 'connected',
    recording: result.recording,
    status: result.status
  };
}
```

## 同時配信（ライブ出力）

### 出力の作成

```typescript
async function createLiveOutput(
  accountId: string, liveInputId: string, apiToken: string,
  outputUrl: string, streamKey: string
) {
  return fetch(
    `https://api.cloudflare.com/client/v4/accounts/${accountId}/stream/live_inputs/${liveInputId}/outputs`,
    {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${apiToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        url: `${outputUrl}/${streamKey}`,
        enabled: true,
        streamKey // For platforms like YouTube, Twitch
      })
    }
  ).then(r => r.json());
}
```

### 例: YouTube と Twitch への同時配信

```typescript
const liveInput = await createLiveInput(accountId, apiToken);

// Add YouTube output
await createLiveOutput(
  accountId, liveInput.uid, apiToken,
  'rtmp://a.rtmp.youtube.com/live2',
  'your-youtube-stream-key'
);

// Add Twitch output
await createLiveOutput(
  accountId, liveInput.uid, apiToken,
  'rtmp://live.twitch.tv/app',
  'your-twitch-stream-key'
);
```

## WebRTC ストリーミング（WHIP/WHEP）

### ブラウザーから Stream への配信（WHIP）

```typescript
async function startWebRTCBroadcast(liveInputId: string) {
  const pc = new RTCPeerConnection();
  
  // Add local media tracks
  const stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
  stream.getTracks().forEach(track => pc.addTrack(track, stream));
  
  // Create offer
  const offer = await pc.createOffer();
  await pc.setLocalDescription(offer);
  
  // Send to Stream via WHIP
  const response = await fetch(
    `https://customer-<CODE>.cloudflarestream.com/${liveInputId}/webRTC/publish`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/sdp' },
      body: offer.sdp
    }
  );
  
  const answer = await response.text();
  await pc.setRemoteDescription({ type: 'answer', sdp: answer });
}
```

### Stream からブラウザーへの配信（WHEP）

```typescript
async function playWebRTCStream(videoId: string) {
  const pc = new RTCPeerConnection();
  
  pc.addTransceiver('video', { direction: 'recvonly' });
  pc.addTransceiver('audio', { direction: 'recvonly' });
  
  const offer = await pc.createOffer();
  await pc.setLocalDescription(offer);
  
  const response = await fetch(
    `https://customer-<CODE>.cloudflarestream.com/${videoId}/webRTC/play`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/sdp' },
      body: offer.sdp
    }
  );
  
  const answer = await response.text();
  await pc.setRemoteDescription({ type: 'answer', sdp: answer });
  
  return pc;
}
```

## 録画設定

| モード | 動作 |
|------|----------|
| `automatic` | すべてのライブストリームを録画 |
| `off` | 録画しない |
| `timeoutSeconds` | 非アクティブ状態が N 秒続くと録画を停止 |

```typescript
const recordingConfig = {
  mode: 'automatic',
  timeoutSeconds: 30, // Auto-stop 30s after stream ends
  requireSignedURLs: true, // Require token for VOD playback
  allowedOrigins: ['https://yourdomain.com']
};
```

## このリファレンスについて

- [README.md](./README.md) - 概要とクイックスタート
- [api.md](./api.md) - オンデマンド動画 API
- [configuration.md](./configuration.md) - セットアップと設定
- [patterns.md](./patterns.md) - フルスタックのフローとベストプラクティス
- [gotchas.md](./gotchas.md) - エラーコードとトラブルシューティング

## 関連項目

- [workers](../workers/) - Workers でライブ API をデプロイ