# Browser Rendering API

## REST API

**ベース:** `https://api.cloudflare.com/client/v4/accounts/{accountId}/browser-rendering`  
**認証:** `Authorization: Bearer <token>`（Browser Rendering - Edit権限）

### エンドポイント

| エンドポイント | 説明 | 主なオプション |
|----------|-------------|-------------|
| `/content` | レンダリング済みHTMLを取得 | `url`, `waitUntil` |
| `/screenshot` | 画像を撮影 | `screenshotOptions: {type, fullPage, clip}` |
| `/pdf` | PDFを生成 | `pdfOptions: {format, landscape, margin}` |
| `/snapshot` | HTMLとインライン化されたリソース | `url` |
| `/scrape` | セレクターで抽出 | `selectors: ["h1", ".price"]` |
| `/json` | AIによる構造化抽出 | `schema: {name: "string", price: "number"}` |
| `/links` | すべてのリンクを取得 | `url` |
| `/markdown` | Markdownに変換 | `url` |

```bash
curl -X POST '.../browser-rendering/screenshot' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"url":"https://example.com","screenshotOptions":{"fullPage":true}}'
```

## Workersバインディング

```jsonc
// wrangler.jsonc
{ "browser": { "binding": "MYBROWSER" } }
```

## Puppeteer

```typescript
import puppeteer from "@cloudflare/puppeteer";

const browser = await puppeteer.launch(env.MYBROWSER, { keep_alive: 600000 });
const page = await browser.newPage();
await page.goto('https://example.com', { waitUntil: 'networkidle0' });

// Content
const html = await page.content();
const title = await page.title();

// Screenshot/PDF
await page.screenshot({ fullPage: true, type: 'png' });
await page.pdf({ format: 'A4', printBackground: true });

// Interaction
await page.click('#button');
await page.type('#input', 'text');
await page.evaluate(() => document.querySelector('h1')?.textContent);

// Session management
const sessions = await puppeteer.sessions(env.MYBROWSER);
const limits = await puppeteer.limits(env.MYBROWSER);

await browser.close();
```

## Playwright

```typescript
import { launch, connect } from "@cloudflare/playwright";

const browser = await launch(env.MYBROWSER, { keep_alive: 600000 });
const page = await browser.newPage();

await page.goto('https://example.com', { waitUntil: 'networkidle' });

// Modern selectors
await page.locator('.button').click();
await page.getByText('Submit').click();
await page.getByTestId('search').fill('query');

// Context for isolation
const context = await browser.newContext({
  viewport: { width: 1920, height: 1080 },
  userAgent: 'custom'
});

await browser.close();
```

## セッション管理

```typescript
// List sessions
await puppeteer.sessions(env.MYBROWSER);

// Connect to existing
await puppeteer.connect(env.MYBROWSER, sessionId);

// Check limits
await puppeteer.limits(env.MYBROWSER);
// { remaining: ms, total: ms, concurrent: n }
```

## 主なオプション

| オプション | 値 |
|--------|--------|
| `waitUntil` | `load`, `domcontentloaded`, `networkidle0`, `networkidle2` |
| `keep_alive` | 最大600000ms（10分） |
| `screenshot.type` | `png`, `jpeg` |
| `pdf.format` | `A4`, `Letter`, `Legal` |