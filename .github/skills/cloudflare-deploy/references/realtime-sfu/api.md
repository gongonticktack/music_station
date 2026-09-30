# API リファレンス

## 認証

```bash
curl -X POST 'https://rtc.live/v1/apps/${CALLS_APP_ID}/sessions/new' \
  -H "Authorization: Bearer ${CALLS_APP_SECRET}"
```

## 基本概念

**セッション:** Cloudflare エッジへの PeerConnection  
**トラック:** メディア／データチャネル（音声／動画／datachannel）  
**ルームなし:** トラック共有を使ってプレゼンスを構築

## クライアントライブラリ

**PartyTracks（推奨）:** 本番環境向けの Observable ベースのクライアントライブラリ。デバイスの変更、ネットワークの切り替え、ICE の再起動を自動的に処理します。React フックを備えた push/pull API です。完全な例は patterns.md を参照してください。

```bash
npm install partytracks @cloudflare/calls
```

**Raw API:** 独自要件向けの HTTP + WebRTC 直接利用（以下に説明）。

## エンドポイント

### セッションの作成
```http
POST /v1/apps/{appId}/sessions/new
→ {sessionId, sessionDescription}
```

### トラックの追加（公開）
```http
POST /v1/apps/{appId}/sessions/{sessionId}/tracks/new
Body: {
  sessionDescription: {sdp, type: "offer"},
  tracks: [{location: "local", trackName: "my-video"}]
}
→ {sessionDescription, tracks: [{trackName}]}
```

### トラックの追加（購読）
```http
POST /v1/apps/{appId}/sessions/{sessionId}/tracks/new
Body: {
  tracks: [{
    location: "remote",
    trackName: "remote-track-id",
    sessionId: "other-session-id"
  }]
}
→ {sessionDescription} (server offer)
```

### 再ネゴシエーション
```http
PUT /v1/apps/{appId}/sessions/{sessionId}/renegotiate
Body: {sessionDescription: {sdp, type: "answer"}}
```

### トラックを閉じる
```http
PUT /v1/apps/{appId}/sessions/{sessionId}/tracks/close
Body: {tracks: [{trackName}]}
→ {requiresImmediateRenegotiation: boolean}
```

### セッションの取得
```http
GET /v1/apps/{appId}/sessions/{sessionId}
→ {sessionId, tracks: TrackMetadata[]}
```

## TypeScript 型

```typescript
interface TrackMetadata {
  trackName: string;
  location: "local" | "remote";
  sessionId?: string; // For remote tracks
  mid?: string; // WebRTC mid
}
```

## WebRTC のフロー

```typescript
// 1. Create PeerConnection
const pc = new RTCPeerConnection({
  iceServers: [{urls: 'stun:stun.cloudflare.com:3478'}]
});

// 2. Add tracks
const stream = await navigator.mediaDevices.getUserMedia({video: true, audio: true});
stream.getTracks().forEach(track => pc.addTrack(track, stream));

// 3. Create offer
const offer = await pc.createOffer();
await pc.setLocalDescription(offer);

// 4. Send to backend → Cloudflare API
const response = await fetch('/api/new-session', {
  method: 'POST',
  body: JSON.stringify({sdp: offer.sdp})
});

// 5. Set remote answer
const {sessionDescription} = await response.json();
await pc.setRemoteDescription(sessionDescription);
```

## 公開

```typescript
const offer = await pc.createOffer();
await pc.setLocalDescription(offer);

const res = await fetch(`/api/sessions/${sessionId}/tracks`, {
  method: 'POST',
  body: JSON.stringify({
    sdp: offer.sdp,
    tracks: [{location: 'local', trackName: 'my-video'}]
  })
});

const {sessionDescription, tracks} = await res.json();
await pc.setRemoteDescription(sessionDescription);
const publishedTrackId = tracks[0].trackName; // Share with others
```

## 購読

```typescript
const res = await fetch(`/api/sessions/${sessionId}/tracks`, {
  method: 'POST',
  body: JSON.stringify({
    tracks: [{location: 'remote', trackName: remoteTrackId, sessionId: remoteSessionId}]
  })
});

const {sessionDescription} = await res.json();
await pc.setRemoteDescription(sessionDescription);

const answer = await pc.createAnswer();
await pc.setLocalDescription(answer);

await fetch(`/api/sessions/${sessionId}/renegotiate`, {
  method: 'PUT',
  body: JSON.stringify({sdp: answer.sdp})
});

pc.ontrack = (event) => {
  const [remoteStream] = event.streams;
  videoElement.srcObject = remoteStream;
};
```