# Browser Rendering の注意点

## プランごとの制限

| 制限 | Free | Paid |
|-------|------|------|
| 1 日あたりのブラウザー使用時間 | 10 分 | 無制限* |
| 同時セッション数 | 3 | 30 |
| 1 分あたりのリクエスト数 | 6 | 180 |
| セッションの keep-alive | 最大 10 分 | 最大 10 分 |

*公正利用ポリシーが適用されます。

**クォータの確認:**
```typescript
const limits = await puppeteer.limits(env.MYBROWSER);
// { remaining: 540000, total: 600000, concurrent: 2 }
```

## ブラウザーは必ず閉じる

```typescript
const browser = await puppeteer.launch(env.MYBROWSER);
try {
  const page = await browser.newPage();
  await page.goto("https://example.com");
  return new Response(await page.content());
} finally {
  await browser.close(); // ALWAYS in finally
}
```

**Workers と REST の違い:** REST ではタイムアウト後に自動的に閉じられます。Workers では `close()` を呼び出す必要があります。呼び出さないと、`keep_alive` の期限が切れるまでセッションが開いたままになります。

## 同時実行数を最適化する

```typescript
// ❌ 3 sessions (hits free tier limit)
const browser1 = await puppeteer.launch(env.MYBROWSER);
const browser2 = await puppeteer.launch(env.MYBROWSER);

// ✅ 1 session, multiple pages
const browser = await puppeteer.launch(env.MYBROWSER);
const page1 = await browser.newPage();
const page2 = await browser.newPage();
```

## よくあるエラー

| エラー | 原因 | 対処法 |
|-------|-------|-----|
| セッション上限を超過 | 同時実行数が多すぎる | 使用していないブラウザーを閉じ、ブラウザーではなくページを使う |
| ページのナビゲーションがタイムアウト | ページの読み込みが遅い、またはアクセスの多いページでの `networkidle` | タイムアウトを延長し、`waitUntil: "load"` を使用 |
| セッションが見つからない | セッションの期限切れ | エラーを捕捉し、新しいセッションを起動 |
| 評価に失敗 | DOM 要素が見つからない | `?.` のオプショナルチェーンを使用 |
| Protocol error: Target closed | 処理中にページが閉じられた | 閉じる前にすべての処理を await する |

## page.evaluate() の注意点

```typescript
// ❌ Outer scope not available
const selector = "h1";
await page.evaluate(() => document.querySelector(selector));

// ✅ Pass as argument
await page.evaluate((sel) => document.querySelector(sel)?.textContent, selector);
```

## パフォーマンス

**waitUntil のオプション（速い順）:**
1. `domcontentloaded` - DOM の準備完了
2. `load` - load イベント（デフォルト）
3. `networkidle0` - 500 ミリ秒間ネットワーク通信なし

**不要なリソースをブロックする:**
```typescript
await page.setRequestInterception(true);
page.on("request", (req) => {
  if (["image", "stylesheet", "font"].includes(req.resourceType())) {
    req.abort();
  } else {
    req.continue();
  }
});
```

**セッションの再利用:** コールドスタートは約 1〜2 秒、ウォーム接続は約 100〜200 ミリ秒です。再利用するには sessionId を KV に保存してください。
