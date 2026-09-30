# 注意点とトラブルシューティング

Cloudflare Workers の TCP ソケットでよくある落とし穴、制限、解決策。

## プラットフォームの制限

### 接続数の上限

| 上限 | 値 |
|-------|-------|
| リクエストあたりの同時ソケット最大数 | 6（厳格な上限） |
| ソケットの存続期間 | リクエストの処理時間 |
| 接続タイムアウト | プラットフォームに依存。設定項目なし |

**問題:** 接続数が 6 を超えるとエラーが発生する

**解決策:** 6 件ずつバッチ処理する

```typescript
for (let i = 0; i < hosts.length; i += 6) {
  const batch = hosts.slice(i, i + 6).map(h => connect({ hostname: h, port: 443 }));
  await Promise.all(batch.map(async s => { /* use */ await s.close(); }));
}
```

### ブロックされる接続先

Cloudflare の IP アドレス（1.1.1.1）、localhost（127.0.0.1）、ポート 25（SMTP）、Worker 自身の URL はセキュリティ上ブロックされます。

**解決策:** 公開 IP アドレスまたは Tunnel のホスト名を使用します: `connect({ hostname: "db.internal.company.net", port: 5432 })`

### スコープ要件

**問題:** グローバルスコープで作成したソケットは失敗する

**原因:** ソケットはリクエストのライフサイクルに紐づいている

**解決策:** ハンドラー内で作成します: `export default { async fetch() { const socket = connect(...); } }`

## よくあるエラー

### エラー: "proxy request failed"

**原因:** 接続先がブロックされている（Cloudflare の IP アドレス、localhost、ポート 25）、DNS エラー、ネットワークに到達できない

**解決策:** 接続先を検証し、Tunnel のホスト名を使用して、try/catch でエラーを捕捉します

### エラー: "TCP Loop detected"

**原因:** Worker が自分自身に接続している

**解決策:** Worker 自身のホスト名ではなく、外部サービスに接続します

### エラー: "Port 25 prohibited"

**原因:** SMTP ポートがブロックされている

**解決策:** メールには Email Workers API を使用します

### エラー: "socket is not open"

**原因:** ソケットを閉じた後に読み取りまたは書き込みを行っている

**解決策:** 正しい順序で確実にクローズするため、常に try/finally を使用します

### エラー: 接続タイムアウト

**原因:** 組み込みのタイムアウト機能がない

**解決策:** `Promise.race()` を使用します:

```typescript
const socket = connect(addr, opts);
const timeout = new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout')), 5000));
await Promise.race([socket.opened, timeout]);
```

## TLS/SSL の問題

### StartTLS のタイミング

**問題:** `startTls()` の呼び出しが早すぎる

**解決策:** プロトコル固有の STARTTLS コマンドを送信し、サーバーからの OK を待ってから `socket.startTls()` を呼び出します

### 証明書の検証

**問題:** 自己署名証明書では失敗する

**解決策:** 正規の証明書または Tunnel を使用します（TLS 終端を処理します）

## パフォーマンスの問題

### 接続プーリングを使用していない

**問題:** リクエストごとに新しい接続を確立するオーバーヘッドが発生する

**解決策:** データベースには[Hyperdrive](../hyperdrive/)を使用します（接続プーリングを内蔵）

### Smart Placement を使用していない

**問題:** バックエンドへのレイテンシが大きい

**解決策:** wrangler.jsonc で `{ "placement": { "mode": "smart" } }` を有効にします

### ソケットを閉じ忘れる

**問題:** リソースリークが発生する

**解決策:** 常に try/finally を使用します:

```typescript
const socket = connect({ hostname: "api.internal", port: 443 });
try {
  // Use socket
} finally {
  await socket.close();
}
```

## データ処理の問題

### 1 回の読み取りですべてのデータを取得できると思い込む

**問題:** 1 回しか読み取らないと、チャンク化されたデータを取りこぼす場合がある

**解決策:** `done === true` になるまで `reader.read()` をループします（patterns.md を参照）

### テキストエンコーディングの問題

**問題:** 誤ったエンコーディングを使用している

**解決策:** エンコーディングを指定します: `new TextDecoder('iso-8859-1').decode(data)`

## セキュリティの問題

### SSRF の脆弱性

**問題:** ユーザーが制御する接続先によって、内部サービスへのアクセスが可能になる

**解決策:** 厳格な許可リストと照合して検証します:

```typescript
const ALLOWED = ['api1.internal.net', 'api2.internal.net'];
const host = new URL(req.url).searchParams.get('host');
if (!host || !ALLOWED.includes(host)) return new Response('Forbidden', { status: 403 });
```

## 代替手段を使うケース

| 用途 | 代替手段 | 理由 |
|----------|-------------|--------|
| PostgreSQL/MySQL | [Hyperdrive](../hyperdrive/) | 接続プーリング、キャッシュ |
| HTTP/HTTPS | `fetch()` | よりシンプルで、組み込み |
| SSRF 保護が必要な HTTP | VPC Services（ベータ版、2025 年以降） | 宣言的なバインディング |

## デバッグのヒント

1. **接続の詳細をログに記録します:** `const info = await socket.opened; console.log(info.remoteAddress);`
2. **まず公開サービスでテストします:** tcpbin.com:4242 のエコーサーバーを使用します
3. **Tunnel を確認します:** `cloudflared tunnel info <name>` および `cloudflared tunnel route ip list`

## 関連情報

- [Hyperdrive](../hyperdrive/) - データベース接続
- [Smart Placement](../smart-placement/) - レイテンシの最適化
- [Tunnel のトラブルシューティング](../tunnel/gotchas.md)
