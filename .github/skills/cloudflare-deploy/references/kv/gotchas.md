# KV の注意点とトラブルシューティング

## よくあるエラー

### 「書き込み後に古い値が読み取られる」

**原因:** 結果整合性のため、書き込み内容が他のリージョンですぐに反映されないことがあります。  
**解決策:** 書き込み直後に読み取らず、読み取りを行わずに完了を返すか、直前に書き込んだローカルの値を使います。同じ場所では書き込みがすぐに反映され、グローバルには ≤60s で反映されます。

```typescript
// ❌ BAD: Read immediately after write
await env.KV.put("key", "value");
const value = await env.KV.get("key"); // May be null in other regions!

// ✅ GOOD: Use the value you just wrote
const newValue = "value";
await env.KV.put("key", newValue);
return new Response(newValue); // Don't re-read
```

### 「同時書き込みで 429 レート制限」

**原因:** 同じキーへの複数の同時書き込みが、1 秒あたり 1 回という上限を超えています。  
**解決策:** 書き込みを順番に行う、同時処理には一意なキーを使う、または指数バックオフによる再試行を実装します。

```typescript
async function putWithRetry(
  kv: KVNamespace,
  key: string,
  value: string,
  maxAttempts = 5
): Promise<void> {
  let delay = 1000;
  for (let i = 0; i < maxAttempts; i++) {
    try {
      await kv.put(key, value);
      return;
    } catch (err) {
      if (err instanceof Error && err.message.includes("429")) {
        if (i === maxAttempts - 1) throw err;
        await new Promise(r => setTimeout(r, delay));
        delay *= 2; // Exponential backoff
      } else {
        throw err;
      }
    }
  }
}
```

### 「複数回の get が非効率」

**原因:** 一括処理ではなく、個別の get() 呼び出しを複数回行っています。  
**解決策:** キーの配列を使って一括取得します。`env.USERS.get(["user:1", "user:2", "user:3"])` のように指定すると、操作を 1 回に減らせます。

### 「Null 参照エラー」

**原因:** キーが存在しない場合の null チェックをせずに値を使おうとしています。  
**解決策:** null の戻り値は必ず処理します。KV はキーが見つからない場合、undefined ではなく `null` を返します。

```typescript
// ❌ BAD: Assumes value exists
const config = await env.KV.get("config", "json");
return config.theme; // TypeError if null!

// ✅ GOOD: Null checks
const config = await env.KV.get("config", "json");
return config?.theme ?? "default";

// ✅ GOOD: Early return
const config = await env.KV.get("config", "json");
if (!config) return new Response("Not found", { status: 404 });
return new Response(config.theme);
```

### 「存在しないキーの検索キャッシュ」

**原因:** 存在しないキーは、最大 60s 間「見つからない」としてキャッシュされます。  
**解決策:** 確認後にキーを作成しても、キャッシュの期限が切れるまで反映されません。

```typescript
// Check → create pattern has race condition
const exists = await env.KV.get("key"); // null, cached as "not found"
if (!exists) {
  await env.KV.put("key", "value");
  // Next get() may still return null for ~60s due to negative cache
}

// Alternative: Always assume key may not exist, use defaults
const value = await env.KV.get("key") ?? "default-value";
```

## パフォーマンスのヒント

| シナリオ | 推奨事項 | 理由 |
|----------|----------------|-----|
| 大きな値（>1MB） | `stream` 型を使う | 値全体をメモリにバッファリングせずに済む |
| 小さなキーが多数ある | 1 つの JSON オブジェクトにまとめる | 操作数を減らし、キャッシュヒット率を高める |
| 書き込み量が多い | 複数のキーに分散する | キーごとの 1 秒あたり 1 回の上限を回避する |
| キャッシュのない読み取り | `cacheTtl` パラメーターを増やす | 頻繁に読み取るデータのレイテンシを下げる |
| 一括操作 | get() の配列形式を使う | 1 回の操作で済み、パフォーマンスが向上する |

## コストの例

**無料枠:**
- 1 日 100K 回の読み取り = 月 3M 回 ✅
- 1 日 1K 回の書き込み = 月 30K 回 ✅
- 1GB のストレージ ✅

**有料利用の例:**
- 月 10M 回の読み取り = $5.00
- 月 100K 回の書き込み = $0.50
- 1GB のストレージ = $0.50
- **合計: 約 $6/月**

## 制限

| 制限 | 値 | 備考 |
|-------|-------|-------|
| キーのサイズ | 512 bytes | キーの最大長 |
| 値のサイズ | 25 MiB | 値の最大サイズ。超過すると 413 エラー |
| メタデータのサイズ | 1024 bytes | キーごとのメタデータの最大サイズ |
| cacheTtl の最小値 | 60s | キャッシュ TTL の最小値 |
| キーごとの書き込みレート | 1 秒あたり 1 回 | すべてのプランが対象。超過すると 429 エラー |
| 伝播時間 | ≤60s | グローバルへの伝播時間 |
| 一括取得の最大数 | 100 キー | 1 回の一括操作で指定できるキーの最大数 |
| Worker あたりの操作数 | 1,000 | リクエストごと（一括操作も 1 回としてカウント） |
| 読み取り料金 | 10M 回あたり $0.50 | 読み取り 100 万回あたり |
| 書き込み料金 | 1M 回あたり $5.00 | 書き込み 100 万回あたり |
| 削除料金 | 1M 回あたり $5.00 | 削除 100 万回あたり |
| ストレージ料金 | GB-月あたり $0.50 | 1 か月、1GB あたり |
