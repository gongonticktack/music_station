# TURN の注意点とトラブルシューティング

Cloudflare TURN でよくある間違い、セキュリティのベストプラクティス、トラブルシューティングを説明します。

## クイックリファレンス

| 問題 | 解決策 | 詳細 |
|-------|----------|---------|
| 認証情報が機能しない | TTL が 48 時間以下か確認 | [トラブルシューティングを参照](#issue-turn-credentials-not-working) |
| 約 48 時間後に接続が切れる | 認証情報の更新を実装 | [接続切断を参照](#issue-connection-drops-after-48-hours) |
| ブラウザーでポート 53 が失敗する | サーバー側でフィルタリング | [ポート 53 を参照](#using-port-53-in-browsers) |
| パケット損失が多い | レート制限を確認 | [レート制限を参照](#limits-per-turn-allocation) |
| メンテナンス後に接続できない | ICE 再起動を実装 | [ICE 再起動を参照](#ice-restart-required-scenarios) |

## 重要な制約

| 制約 | 値 | 違反した場合の影響 |
|------------|-------|-------------------------|
| 認証情報の最大 TTL | 48 時間（172800 秒） | API がリクエストを拒否 |
| 認証情報の失効反映時間 | 約数秒 | 課金は即時停止し、接続はまもなく切断 |
| IP 許可リストの更新期間 | 14 日（IP が変更された場合） | IP が変更されると接続に失敗 |
| パケットレート | 割り当てごとに 5～10k pps | パケットがドロップ |
| データレート | 割り当てごとに 50～100 Mbps | パケットがドロップ |
| 一意な IP のレート | 毎秒 5 個超の新しい IP | パケットがドロップ |

<a id="limits-per-turn-allocation"></a>
## TURN 割り当てごとの制限

**ユーザーごと**（アカウント全体ではありません）:

- **IP アドレス**: 毎秒 5 個超の新しい一意な IP
- **パケットレート**: 毎秒 5～10k パケット（受信／送信）
- **データレート**: 50～100 Mbps（受信／送信）
- **MTU**: 特定の制限なし
- **バーストレート**: 公開されている値より高い

制限を超えると、**パケットがドロップ**します。

## よくある間違い

### TTL を 48 時間より長く設定する

```typescript
// ❌ BAD: API will reject
const creds = await generate({ ttl: 604800 });  // 7 days

// ✅ GOOD:
const creds = await generate({ ttl: 86400 });   // 24 hours
```

### 監視せずに IP をハードコードする

```typescript
// ❌ BAD: IPs can change with 14-day notice
const iceServers = [{ urls: 'turn:141.101.90.1:3478' }];

// ✅ GOOD: Use DNS
const iceServers = [{ urls: 'turn:turn.cloudflare.com:3478' }];
```

<a id="using-port-53-in-browsers"></a>
### ブラウザーでポート 53 を使用する

```typescript
// ❌ BAD: Blocked by Chrome/Firefox
urls: ['turn:turn.cloudflare.com:53']

// ✅ GOOD: Filter port 53
urls: urls.filter(url => !url.includes(':53'))
```

### 認証情報の有効期限切れに対処しない

```typescript
// ❌ BAD: Credentials expire but call continues → connection drops
const creds = await fetchCreds();
const pc = new RTCPeerConnection({ iceServers: creds });

// ✅ GOOD: Refresh before expiry
setInterval(() => refreshCredentials(pc), 3000000);  // 50 min
```

### ICE 再起動への対応がない

```typescript
// ❌ BAD: No recovery from TURN maintenance
pc.addEventListener('iceconnectionstatechange', () => {
  console.log('State changed:', pc.iceConnectionState);
});

// ✅ GOOD: Implement ICE restart
pc.addEventListener('iceconnectionstatechange', async () => {
  if (pc.iceConnectionState === 'failed') {
    await refreshCredentials(pc);
    pc.restartIce();
  }
});
```

### TURN キーのシークレットをクライアント側に公開する

```typescript
// ❌ BAD: Secret exposed to client
const secret = 'your-turn-key-secret';
const response = await fetch(`https://rtc.live.cloudflare.com/v1/turn/...`, {
  headers: { 'Authorization': `Bearer ${secret}` }
});

// ✅ GOOD: Generate credentials server-side
const response = await fetch('/api/turn-credentials');
```

<a id="ice-restart-required-scenarios"></a>
## ICE 再起動が必要な状況

次のイベントでは ICE の再起動が必要です（[patterns.md](./patterns.md#ice-restart-pattern) を参照）:

1. **TURN サーバーのメンテナンス**（Cloudflare のネットワークで時折発生）
2. **ネットワークトポロジーの変更**（エニーキャストのルーティング変更）
3. **長時間セッション（1 時間超）中の認証情報の更新**
4. **接続障害**（iceConnectionState === 'failed'）

本番アプリではすべて実装してください:

```typescript
pc.addEventListener('iceconnectionstatechange', async () => {
  if (pc.iceConnectionState === 'failed' || 
      pc.iceConnectionState === 'disconnected') {
    await refreshTURNCredentials(pc);
    pc.restartIce();
    const offer = await pc.createOffer({ iceRestart: true });
    await pc.setLocalDescription(offer);
    // Send offer to peer via signaling...
  }
});
```

参照: [RFC 8445 Section 2.4](https://datatracker.ietf.org/doc/html/rfc8445#section-2.4)

## セキュリティチェックリスト

- [ ] 認証情報はサーバー側のみで生成する（クライアント側では生成しない）
- [ ] TURN_KEY_SECRET は vars ではなく wrangler secrets に設定する
- [ ] TTL は想定セッション時間以下にする（かつ 48 時間以下）
- [ ] 認証情報生成エンドポイントにレート制限を設定する
- [ ] 認証情報を発行する前にクライアントを認証する
- [ ] セッション侵害に備えて認証情報の失効 API を用意する
- [ ] IP をハードコードしない（または DNS 監視を行う）
- [ ] ブラウザークライアント向けにポート 53 をフィルタリングする

## トラブルシューティング

<a id="issue-turn-credentials-not-working"></a>
### 問題: TURN 認証情報が機能しない

**確認項目:**
- キー ID とシークレットが正しい
- 認証情報の有効期限が切れていない（TTL を確認）
- TTL が 172800 秒（48 時間）を超えていない
- サーバーから rtc.live.cloudflare.com に接続できる
- ネットワークで HTTPS の送信が許可されている

**解決策:**
```typescript
// Validate before using
if (ttl > 172800) {
  throw new Error('TTL cannot exceed 48 hours');
}
```

### 問題: 接続の確立が遅い

**解決策:**
- ICE 候補が適切に収集されることを確認する
- Cloudflare エッジまでのネットワーク遅延を確認する
- ファイアウォールで WebRTC ポート（3478、5349、443）が許可されていることを確認する
- 社内ネットワークでは TURN over TLS（ポート 443）の使用を検討する

### 問題: パケット損失が多い

**確認項目:**
- レート制限（5～10k pps）を超えていない
- 帯域幅制限（50～100 Mbps）を超えていない
- 接続先の一意な IP が多すぎない（毎秒 5 個超）
- クライアントのネットワーク品質

<a id="issue-connection-drops-after-48-hours"></a>
### 問題: 約 48 時間後に接続が切れる

**原因**: 認証情報の有効期限切れ（最大 48 時間）

**解決策**: 
- TTL を想定セッション時間に設定する
- setConfiguration() で認証情報を更新する
- 接続に失敗した場合は ICE を再起動する

```typescript
// Refresh credentials before expiry
const refreshInterval = ttl * 1000 - 60000; // 1 min early
setInterval(async () => {
  await refreshTURNCredentials(pc);
}, refreshInterval);
```

### 問題: ブラウザーでポート 53 の URL が失敗しても通知されない

**原因**: Chrome／Firefox がポート 53 をブロックする

**解決策**: サーバー側でポート 53 の URL をフィルタリングします:

```typescript
const filtered = urls.filter(url => !url.includes(':53'));
```

### 問題: ハードコードした IP が機能しなくなる

**原因**: Cloudflare が IP アドレスを変更した（14 日前に通知）

**解決策**: 
- DNS ホスト名（`turn.cloudflare.com`）を使用する
- 自動アラートで DNS の変更を監視する
- IP 許可リストを使用している場合は 14 日以内に更新する

## コストの最適化

1. 適切な TTL を使用する（過剰に設定しない）
2. 認証情報のキャッシュを実装する
3. まず直接接続を試すように `iceTransportPolicy: 'all'` を設定する（必要な場合にのみ `'relay'` を使用）
4. 帯域幅の使用量を監視する
5. Cloudflare Calls SFU と併用する場合は無料

## 関連項目

- [api.md](./api.md) - 認証情報生成 API、失効
- [configuration.md](./configuration.md) - IP 許可リスト、監視
- [patterns.md](./patterns.md) - ICE 再起動、認証情報の更新パターン
