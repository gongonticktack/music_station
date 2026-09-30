# 注意点とトラブルシューティング

## よくあるエラー

### 「初回接続が遅い（約1.8秒）」

**原因:** コンセンサス形成中に最初の STUN が遅延する（通常の動作）
**解決策:** 以降の接続はより速くなります。CF は DTLS ClientHello を早期に検出して補います。

### 「メディアが流れない」

**原因:** SDP の交換が完了していない、接続が確立されていない、offer の作成前にトラックが追加されていない、ブラウザーの権限が不足している
**解決策:** 
1. SDP の交換が完了していることを確認する
2. `pc.connectionState === 'connected'` を確認する
3. offer を作成する前にトラックが追加されていることを確認する
4. ブラウザーの権限が許可されていることを確認する
5. デバッグには `chrome://webrtc-internals` を使用する

### 「トラックを受信できない」

**原因:** トラックが公開されていない、トラック ID が共有されていない、セッション ID が一致しない、`pc.ontrack` が設定されていない、再ネゴシエーションが必要
**解決策:** 
1. トラックが正常に公開されたことを確認する
2. ピア間でトラック ID が共有されていることを確認する
3. セッション ID が一致していることを確認する
4. answer の前に `pc.ontrack` ハンドラーを設定する
5. 必要に応じて再ネゴシエーションを開始する

### 「ICE 接続に失敗する」

**原因:** ネットワークが変わった、ファイアウォールが UDP をブロックしている、TURN が必要、一時的なネットワークの問題
**解決策:**
```typescript
pc.oniceconnectionstatechange = async () => {
  if (pc.iceConnectionState === 'failed') {
    console.warn('ICE failed, attempting restart');
    await pc.restartIce(); // Triggers new ICE gathering
    
    // Create new offer with ICE restart flag
    const offer = await pc.createOffer({iceRestart: true});
    await pc.setLocalDescription(offer);
    
    // Send to backend → Cloudflare API
    await fetch(`/api/sessions/${sessionId}/renegotiate`, {
      method: 'PUT',
      body: JSON.stringify({sdp: offer.sdp})
    });
  }
};
```

### 「トラックが停止／フリーズする」

**原因:** 送信側がトラックを一時停止した、ネットワークが混雑している、コーデックが一致しない、モバイルブラウザーがバックグラウンドに移行した
**解決策:**
1. `track.enabled` と `track.readyState === 'live'` を確認する
2. 送信側がアクティブであることを確認する: `pc.getSenders().find(s => s.track === track)`
3. パケット損失／ジッターの統計情報を確認する（patterns.md を参照）
4. モバイルの場合: アプリがフォアグラウンドに戻ったときにトラックを再取得する
5. 問題が続く場合は、別のコーデックでテストする

### 「ネットワーク変更で通話が切断される」

**原因:** モバイル端末が Wi-Fi と携帯回線を切り替える、ノート PC がネットワークを切り替える
**解決策:**
```typescript
// Listen for network changes
if ('connection' in navigator) {
  (navigator as any).connection.addEventListener('change', async () => {
    console.log('Network changed');
    await pc.restartIce(); // Use ICE restart pattern above
  });
}

// Or use PartyTracks (handles automatically)
```

## 指数バックオフによる再試行

```typescript
async function fetchWithRetry(url: string, options: RequestInit, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      const res = await fetch(url, options);
      if (res.ok) return res;
      if (res.status >= 500) throw new Error('Server error');
      return res; // Client error, don't retry
    } catch (err) {
      if (i === maxRetries - 1) throw err;
      const delay = Math.min(1000 * 2 ** i, 10000); // Cap at 10s
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
}
```

## chrome://webrtc-internals によるデバッグ

1. Chrome／Edge で `chrome://webrtc-internals` を開く
2. 一覧から対象の PeerConnection を探す
3. **Stats graphs** でパケット損失、ジッター、帯域幅を確認する
4. **ICE candidate pairs** を確認する: `succeeded` 状態、および relay 候補と host 候補を確認する
5. **getStats** を確認する: 受信／送信 RTP の生のメトリクス
6. **Event log** でエラーを探す: `iceConnectionState`、`connectionState` の変更
7. 「Download the PeerConnection updates and stats data」ボタンでデータをエクスポートする
8. ここで確認できる一般的な問題: ICE の失敗、高いパケット損失、ビットレートの低下

## 制限

| リソース／制限 | 値 | 備考 |
|----------------|-------|-------|
| エグレス（無料） | 1TB/月 | アカウントごと |
| エグレス（有料） | $0.05/GB | 無料枠を超過した分 |
| インバウンド通信 | 無料 | すべてのプラン |
| TURN サービス | 無料 | SFU に含まれる |
| 参加者数 | 明確な上限なし | クライアントの帯域幅／CPU に依存（通常 10～50 トラック） |
| セッションあたりのトラック数 | 明確な上限なし | クライアントのリソースに制限される |
| セッション時間 | 明確な上限なし | 本番環境の通話は数時間続く |
| WebRTC ポート | UDP 1024-65535 | アウトバウンドのみ。メディアに必要 |
| API レート制限 | 600 req/min | アプリごと。バースト可 |

## セキュリティチェックリスト

- ✅ `CALLS_APP_SECRET` をクライアントに**絶対に公開しない**
- ✅ セッション作成前にバックエンドで**ユーザー ID を検証する**
- ✅ セッションアクセス用の**認証トークンを実装する**（カスタムヘッダー内の JWT）
- ✅ セッション作成エンドポイントに**レート制限を設定する**
- ✅ 非アクティブ状態が続いたらサーバー側で**セッションを期限切れにする**
- ✅ 購読前に**トラック ID を検証する**（不正アクセスを防止）
- ✅ すべてのシグナリング（API 呼び出し）に**HTTPS を使用する**
- ✅ **DTLS-SRTP を有効にする**（Cloudflare で自動設定され、メディアを暗号化）
- ⚠️ 機密性の高いコンテンツでは**E2EE を検討する**（Insertable Streams API を使ってクライアント側で実装）