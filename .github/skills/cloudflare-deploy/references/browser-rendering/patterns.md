# Browser Rendering のパターン

## 基本的な Worker

```typescript
import puppeteer from "@cloudflare/puppeteer";

export default {
  async fetch(request, env) {
    const browser = await puppeteer.launch(env.MYBROWSER);
    try {
      const page = await browser.newPage();
      await page.goto("https://example.com");
      return new Response(await page.content());
    } finally {
      await browser.close(); // ALWAYS in finally
    }
  }
};
```

## セッションの再利用

パフォーマンス向上のためにセッションを維持します:
```typescript
let sessionId = await env.SESSION_KV.get("browser-session");
if (sessionId) {
  browser = await puppeteer.connect(env.MYBROWSER, sessionId);
} else {
  browser = await puppeteer.launch(env.MYBROWSER, { keep_alive: 600000 });
  await env.SESSION_KV.put("browser-session", browser.sessionId(), { expirationTtl: 600 });
}
// Don't close browser to keep session alive
```

## よく使う操作

| タスク | コード |
|------|------|
| スクリーンショット | `await page.screenshot({ type: "png", fullPage: true })` |
| PDF | `await page.pdf({ format: "A4", printBackground: true })` |
| データの抽出 | `await page.evaluate(() => document.querySelector('h1').textContent)` |
| フォーム入力 | `await page.type('#input', 'value'); await page.click('button')` |
| ナビゲーション待機 | `await Promise.all([page.waitForNavigation(), page.click('a')])` |

## 並列スクレイピング

```typescript
const pages = await Promise.all(urls.map(() => browser.newPage()));
await Promise.all(pages.map((p, i) => p.goto(urls[i])));
const titles = await Promise.all(pages.map(p => p.title()));
```

## Playwright セレクター

```typescript
import { launch } from "@cloudflare/playwright";
const browser = await launch(env.MYBROWSER);
await page.getByRole("button", { name: "Sign in" }).click();
await page.getByLabel("Email").fill("user@example.com");
await page.getByTestId("submit-button").click();
```

## シークレットコンテキスト

複数のブラウザーを使わずにセッションを分離します:
```typescript
const ctx1 = await browser.createIncognitoBrowserContext();
const ctx2 = await browser.createIncognitoBrowserContext();
// Each has isolated cookies/storage
```

## クォータの確認

```typescript
const limits = await puppeteer.limits(env.MYBROWSER);
if (limits.remaining < 60000) return new Response("Quota low", { status: 429 });
```

## エラー処理

```typescript
try {
  await page.goto(url, { timeout: 30000, waitUntil: "networkidle0" });
} catch (e) {
  if (e.message.includes("timeout")) return new Response("Timeout", { status: 504 });
  if (e.message.includes("Session limit")) return new Response("Too many sessions", { status: 429 });
} finally {
  if (browser) await browser.close();
}
```
