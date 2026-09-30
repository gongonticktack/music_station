# 設定とデプロイ

## ダッシュボードの設定

1. https://dash.cloudflare.com/?to=/:account/calls に移動します
2. 「Create Application」をクリックします（または既存のアプリを使用します）
3. ダッシュボードから `CALLS_APP_ID` をコピーします
4. `CALLS_APP_SECRET` を生成してコピーします（機密性の高い認証情報として扱ってください）
5. 以下の Wrangler 設定または環境変数で認証情報を使用します

## 依存関係

**バックエンド（Workers）:** 組み込みの fetch API を使用するため、追加パッケージは不要です

**クライアント（PartyTracks）:**
```bash
npm install partytracks @cloudflare/calls
```

**クライアント（React + PartyTracks）:**
```bash
npm install partytracks @cloudflare/calls observable-hooks
# Observable hooks: useObservableAsValue, useValueAsObservable
```

**クライアント（Raw API）:** ブラウザー標準の WebRTC API のみ

## Wrangler の設定

```jsonc
{
  "name": "my-calls-app",
  "main": "src/index.ts",
  "compatibility_date": "2025-01-01", // Use current date for new projects
  "vars": {
    "CALLS_APP_ID": "your-app-id",
    "MAX_WEBCAM_BITRATE": "1200000",
    "MAX_WEBCAM_FRAMERATE": "24",
    "MAX_WEBCAM_QUALITY_LEVEL": "1080"
  },
  // Set secret: wrangler secret put CALLS_APP_SECRET
  "durable_objects": {
    "bindings": [
      {
        "name": "ROOM",
        "class_name": "Room"
      }
    ]
  }
}
```

## デプロイ

```bash
wrangler login
wrangler secret put CALLS_APP_SECRET
wrangler deploy
```

## 環境変数

**必須:**
- `CALLS_APP_ID`: ダッシュボードから取得
- `CALLS_APP_SECRET`: ダッシュボードから取得（シークレット）

**任意:**
- `MAX_WEBCAM_BITRATE`（デフォルト: 1200000）
- `MAX_WEBCAM_FRAMERATE`（デフォルト: 24）
- `MAX_WEBCAM_QUALITY_LEVEL`（デフォルト: 1080）
- `TURN_SERVICE_ID`: TURN サービス
- `TURN_SERVICE_TOKEN`: TURN 認証情報（シークレット）

## TURN の設定

```javascript
const pc = new RTCPeerConnection({
  iceServers: [
    { urls: 'stun:stun.cloudflare.com:3478' },
    {
      urls: [
        'turn:turn.cloudflare.com:3478?transport=udp',
        'turn:turn.cloudflare.com:3478?transport=tcp',
        'turns:turn.cloudflare.com:5349?transport=tcp'
      ],
      username: turnUsername,
      credential: turnCredential
    }
  ],
  bundlePolicy: 'max-bundle', // Recommended: reduces overhead
  iceTransportPolicy: 'all'    // Use 'relay' to force TURN (testing only)
});
```

**ポート:** 3478（UDP/TCP）、53（UDP）、80（TCP）、443（TLS）、5349（TLS）

**TURN を使用する場合:** UDP をブロックする制限の厳しい企業ファイアウォール／ネットワークでは必要です。接続の約 5～10% が TURN にフォールバックします。ほとんどのユーザーには STUN で対応できます。

**ICE 候補のフィルタリング:** Cloudflare が候補のフィルタリングを自動的に処理します。候補を手動でフィルタリングする必要はありません。

## Durable Object のボイラープレート

最小限のプレゼンスシステム:

```typescript
export class Room {
  private sessions = new Map<string, {userId: string, tracks: string[]}>();

  async fetch(req: Request) {
    const {pathname} = new URL(req.url);
    const body = await req.json();
    
    if (pathname === '/join') {
      this.sessions.set(body.sessionId, {userId: body.userId, tracks: []});
      return Response.json({participants: this.sessions.size});
    }
    
    if (pathname === '/publish') {
      this.sessions.get(body.sessionId)?.tracks.push(...body.tracks);
      // Broadcast to others via WebSocket (not shown)
      return new Response('OK');
    }
    
    return new Response('Not found', {status: 404});
  }
}
```

## 環境の検証

最初の API 呼び出しの前に認証情報を確認します:

```typescript
if (!env.CALLS_APP_ID || !env.CALLS_APP_SECRET) {
  throw new Error('CALLS_APP_ID and CALLS_APP_SECRET required');
}
```