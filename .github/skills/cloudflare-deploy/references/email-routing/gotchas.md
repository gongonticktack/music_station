# 注意点とトラブルシューティング

## 重大な落とし穴

### ストリームの消費（最もよくある問題）

**問題:** 「stream already consumed」エラーが出る、または Worker がハングする

**原因:** `message.raw` は `ReadableStream` で、一度だけ読み取れます

**解決策:**
```typescript
// ❌ WRONG
const email1 = await parser.parse(await message.raw.arrayBuffer());
const email2 = await parser.parse(await message.raw.arrayBuffer()); // FAILS

// ✅ CORRECT
const raw = await message.raw.arrayBuffer();
const email = await parser.parse(raw);
```

非同期処理を行う前に、すぐに `message.raw` を読み取ってください。

### 宛先の検証

**問題:** メールが転送されない

**原因:** 宛先が検証されていない

**解決策:** 宛先を追加し、受信トレイで検証メールを確認してリンクをクリックします。検証状態は `GET /zones/{id}/email/routing/addresses` で確認できます。

### メール認証

**問題:** 正当なメールが拒否される

**原因:** 送信元ドメインに SPF/DKIM/DMARC が設定されていない

**解決策:** 送信元の DNS を設定します:
```dns
example.com. IN TXT "v=spf1 include:_spf.example.com ~all"
selector._domainkey.example.com. IN TXT "v=DKIM1; k=rsa; p=..."
_dmarc.example.com. IN TXT "v=DMARC1; p=quarantine"
```

### エンベロープとヘッダー

**問題:** 誤ったアドレスでフィルタリングしている

**解決策:**
```typescript
// Routing/auth: envelope
if (message.from === "trusted@example.com") { }

// Display: headers
const display = message.headers.get("from");
```

### SendEmail の制限

| 問題 | 制限 | 解決策 |
|-------|-------|----------|
| From ドメイン | 所有している必要がある | Email Routing のドメインを使用する |
| 送信量 | 無料プランでは約100通/分 | アップグレードするか、送信を抑制する |
| 添付ファイル | サポート対象外 | R2 へのリンクを使用する |
| 種類 | トランザクションメール | 一括送信は不可 |

## よくあるエラー

### CPU 時間の超過

**原因:** 重い解析、大きなメール

**解決策:**
```typescript
const size = parseInt(message.headers.get("content-length") || "0") / 1024 / 1024;
if (size > 20) {
  message.setReject("Too large");
  return;
}

ctx.waitUntil(expensiveWork());
await message.forward("dest@example.com");
```

### ルールが実行されない

**原因:** 優先順位の競合、マッチャーのエラー、キャッチオールによる上書き

**解決策:** 優先順位（数値が小さいほど先）を確認し、完全一致を検証して、宛先が検証済みであることを確認します

### 未定義のプロパティ

**原因:** ヘッダーがない

**解決策:**
```typescript
// ❌ WRONG
const subj = message.headers.get("subject").toLowerCase();

// ✅ CORRECT
const subj = message.headers.get("subject")?.toLowerCase() || "";
```

## 制限

| リソース | 無料 | 有料 |
|----------|------|------|
| メールサイズ | 25 MB | 25 MB |
| ルール | 200 | 200 |
| 宛先 | 200 | 200 |
| CPU 時間 | 10ms | 50ms |
| SendEmail | 約100通/分 | より多い |

## デバッグ

### ローカル

```bash
npx wrangler dev

curl -X POST 'http://localhost:8787/__email' \
  --header 'content-type: message/rfc822' \
  --data 'From: test@example.com
To: you@yourdomain.com
Subject: Test

Body'
```

### 本番環境

```bash
npx wrangler tail
```

### パターン

```typescript
export default {
  async email(message, env, ctx) {
    try {
      console.log("From:", message.from);
      await process(message, env);
    } catch (err) {
      console.error(err);
      message.setReject(err.message);
    }
  }
} satisfies ExportedHandler;
```

## 認証のトラブルシューティング

### ステータスの確認

```typescript
const auth = message.headers.get("authentication-results") || "";
console.log({
  spf: auth.includes("spf=pass"),
  dkim: auth.includes("dkim=pass"),
  dmarc: auth.includes("dmarc=pass")
});

if (!auth.includes("pass")) {
  message.setReject("Failed auth");
  return;
}
```

### SPF の問題

**原因:** 転送による SPF の破損、参照回数の超過（10回超）、include の不足

**解決策:**
```dns
; ✅ Good
example.com. IN TXT "v=spf1 include:_spf.google.com ~all"

; ❌ Bad - too many
example.com. IN TXT "v=spf1 include:a.com include:b.com ... ~all"
```

### DMARC のアライメント

**原因:** From ドメインは SPF/DKIM ドメインと一致している必要がある

## ベストプラクティス

1. `message.raw` をすぐに読み取る
2. 宛先を検証する
3. 欠落しているヘッダーを処理する（`?.`）
4. ルーティングにはエンベロープを使用する
5. スパムスコアを確認する
6. まずローカルでテストする
7. バックグラウンド処理には `ctx.waitUntil` を使用する
8. 早い段階でサイズを確認する
