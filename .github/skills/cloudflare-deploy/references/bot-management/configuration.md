# Bot Management の設定

## 製品プラン

**注:** ダッシュボードのパスは新旧の UI で異なります:
- **新:** Security > Settings > 「Bot traffic」でフィルター
- **旧:** Security > Bots

どちらの UI からも同じ設定にアクセスできます。

### ボットスコアの分類（Pro/Business）

Pro/Business のユーザーには、1～99 の詳細なスコアではなく、ボットスコアの分類が表示されます:

| スコア | 分類 | 意味 |
|-------|---------|---------|
| 0 | 未計算 | Bot Management が実行されていない |
| 1 | 自動化 | 確実にボット（ヒューリスティックに一致） |
| 2-29 | 自動化の可能性が高い | おそらくボット（ML による検出） |
| 30-99 | 人間の可能性が高い | おそらく人間 |
| N/A | 検証済みボット | 許可リストに登録された良好なボット |

Enterprise プランでは、カスタムしきい値用に1～99の詳細なスコアを利用できます。

### Bot Fight Mode（Free）
- 確実なボット（score=1）を自動的にブロックし、デフォルトで検証済みボットを除外
- JavaScript Detections は常に有効で、設定オプションはありません

### Super Bot Fight Mode（Pro/Business）
```txt
Dashboard: Security > Bots > Configure
- Definitely automated: Block/Challenge
- Likely automated: Challenge/Allow  
- Verified bots: Allow (recommended)
- Static resource protection: ON (may block mail clients)
- JavaScript Detections: Optional
```

### Bot Management（Enterprise）
```txt
Dashboard: Security > Bots > Configure > Auto-updates: ON (recommended)

# Template 1: Block definite bots
(cf.bot_management.score eq 1 and not cf.bot_management.verified_bot and not cf.bot_management.static_resource)
Action: Block

# Template 2: Challenge likely bots
(cf.bot_management.score ge 2 and cf.bot_management.score le 29 and not cf.bot_management.verified_bot and not cf.bot_management.static_resource)
Action: Managed Challenge
```

## JavaScript Detections の設定

### ダッシュボードから有効化
```txt
Security > Bots > Configure Bot Management > JS Detections: ON

Update CSP: script-src 'self' /cdn-cgi/challenge-platform/;
```

### JS の手動挿入（API）
```html
<script>
function jsdOnload() {
  window.cloudflare.jsd.executeOnce({ callback: function(result) { console.log('JSD:', result); } });
}
</script>
<script src="/cdn-cgi/challenge-platform/scripts/jsd/api.js?onload=jsdOnload" async></script>
```

**API を使う場合**: 特定のページに限定して導入できます  
**併用しないでください**: ゾーン全体の切り替え + 手動挿入

### JSD 用 WAF ルール
```txt
# NEVER use on first page visit (needs HTML page first)
(not cf.bot_management.js_detection.passed and http.request.uri.path eq "/api/user/create" and http.request.method eq "POST" and not cf.bot_management.verified_bot)
Action: Managed Challenge (always use Managed Challenge, not Block)
```

### 制限事項
- 最初のリクエストには JSD データがありません（先に HTML ページが必要）
- HTML レスポンスから ETag を削除します
- `<meta>` タグによる CSP には対応していません
- WebSocket エンドポイントには対応していません
- ネイティブモバイルアプリでは検証を通過できません
- cf_clearance cookie: 有効期間は15分、最大4096バイト

## __cf_bm Cookie

Cloudflare は `__cf_bm` cookie を設定し、ユーザーセッション間のボットスコアを平滑化します:

- **目的:** スコアの変動による誤検知を減らす
- **適用範囲:** ドメイン単位、HTTP 専用
- **有効期間:** セッション中
- **プライバシー:** 個人を特定できる情報は含まず、セッションの分類情報のみ
- **自動:** 設定不要

再訪問者のボットスコアは、この cookie を通じてセッション履歴を考慮します。

## 静的リソース保護

**ファイル拡張子**: ico, jpg, png, jpeg, gif, css, js, tif, tiff, bmp, pict, webp, svg, svgz, class, jar, txt, csv, doc, docx, xls, xlsx, pdf, ps, pls, ppt, pptx, ttf, otf, woff, woff2, eot, eps, ejs, swf, torrent, midi, mid, m3u8, m4a, mp3, ogg, ts  
**および**: `/.well-known/` パス（すべてのファイル）

```txt
# Exclude static resources from bot rules
(cf.bot_management.score lt 30 and not cf.bot_management.static_resource)
```

**警告**: 静的画像を取得するメールクライアントがブロックされる場合があります

## JA3/JA4 フィンガープリント（Enterprise）

```txt
# Block specific attack fingerprint
(cf.bot_management.ja3_hash eq "8b8e3d5e3e8b3d5e")

# Allow mobile app by fingerprint
(cf.bot_management.ja4 eq "your_mobile_app_fingerprint")
```

HTTPS/TLS トラフィックでのみ利用できます。Worker 経由のトラフィックや HTTP リクエストでは取得できません。

## 検証済みボットのカテゴリ

```txt
# Allow search engines only
(cf.verified_bot_category eq "Search Engine Crawler")

# Block AI crawlers
(cf.verified_bot_category eq "AI Crawler")
Action: Block

# Or use dashboard: Security > Settings > Bot Management > Block AI Bots
```

| カテゴリ | 文字列値 | 例 |
|----------|--------------|---------|
| AI クローラー | `AI Crawler` | GPTBot, Claude-Web |
| AI アシスタント | `AI Assistant` | Perplexity-User, DuckAssistBot |
| AI 検索 | `AI Search` | OAI-SearchBot |
| アクセシビリティ | `Accessibility` | Accessible Web Bot |
| 学術研究 | `Academic Research` | Library of Congress |
| 広告・マーケティング | `Advertising & Marketing` | Google Adsbot |
| アグリゲーター | `Aggregator` | Pinterest, Indeed |
| アーカイバー | `Archiver` | Internet Archive, CommonCrawl |
| フィード取得 | `Feed Fetcher` | RSS/Podcast updaters |
| 監視・分析 | `Monitoring & Analytics` | Uptime monitors |
| ページプレビュー | `Page Preview` | Facebook/Slack link preview |
| SEO | `Search Engine Optimization` | Google Lighthouse |
| セキュリティ | `Security` | Vulnerability scanners |
| ソーシャルメディアマーケティング | `Social Media Marketing` | Brandwatch |
| Webhook | `Webhooks` | Payment processors |
| その他 | `Other` | Uncategorized bots |

## ベストプラクティス

- **ML の自動更新**: 最新モデルを利用できるよう、Enterprise で有効にする
- **まず Managed Challenge を使用**: ブロックする前にテストする
- **検証済みボットは必ず除外**: `not cf.bot_management.verified_bot` を使用する
- **企業プロキシを除外**: `cf.bot_management.corporate_proxy` を使った B2B トラフィック向け
- **静的リソースの例外を使用**: パフォーマンスを高め、オーバーヘッドを減らす
