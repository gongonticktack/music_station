# Bot Management API

## Workers: BotManagement インターフェース

```typescript
interface BotManagement {
  score: number;              // 1-99 (Enterprise), 0 if not computed
  verifiedBot: boolean;       // Is verified bot
  staticResource: boolean;    // Serves static resource
  ja3Hash: string;            // JA3 fingerprint (Enterprise, HTTPS only)
  ja4: string;                // JA4 fingerprint (Enterprise, HTTPS only)
  jsDetection?: {
    passed: boolean;          // Passed JS detection (if enabled)
  };
  detectionIds: number[];     // Heuristic detection IDs
  corporateProxy?: boolean;   // From corporate proxy (Enterprise)
}

// DEPRECATED: Use botManagement.score instead
// request.cf.clientTrustScore (legacy, duplicate of botManagement.score)

// Access via request.cf
import type { IncomingRequestCfProperties } from '@cloudflare/workers-types';

export default {
  async fetch(request: Request): Promise<Response> {
    const cf = request.cf as IncomingRequestCfProperties | undefined;
    const botMgmt = cf?.botManagement;
    
    if (!botMgmt) return fetch(request);
    if (botMgmt.verifiedBot) return fetch(request); // Allow verified bots
    if (botMgmt.score === 1) return new Response('Blocked', { status: 403 });
    if (botMgmt.score < 30) return new Response('Challenge required', { status: 429 });
    
    return fetch(request);
  }
};
```

## WAF フィールドのリファレンス

```txt
# Score fields
cf.bot_management.score                    # 0-99 (0 = not computed)
cf.bot_management.verified_bot             # boolean
cf.bot_management.static_resource          # boolean
cf.bot_management.ja3_hash                 # string (Enterprise)
cf.bot_management.ja4                      # string (Enterprise)
cf.bot_management.detection_ids            # array
cf.bot_management.js_detection.passed      # boolean
cf.bot_management.corporate_proxy          # boolean (Enterprise)
cf.verified_bot_category                   # string

# Workers equivalent
request.cf.botManagement.score
request.cf.botManagement.verifiedBot
request.cf.botManagement.ja3Hash
request.cf.botManagement.ja4
request.cf.botManagement.jsDetection.passed
request.cf.verifiedBotCategory
```

## JA4 シグナル（Enterprise）

```typescript
import type { IncomingRequestCfProperties } from '@cloudflare/workers-types';

interface JA4Signals {
  // Ratios (0.0-1.0)
  heuristic_ratio_1h?: number;  // Fraction flagged by heuristics
  browser_ratio_1h?: number;    // Fraction from real browsers  
  cache_ratio_1h?: number;      // Fraction hitting cache
  h2h3_ratio_1h?: number;       // Fraction using HTTP/2 or HTTP/3
  // Ranks (relative position in distribution)
  uas_rank_1h?: number;         // User-Agent diversity rank
  paths_rank_1h?: number;       // Path diversity rank
  reqs_rank_1h?: number;        // Request volume rank
  ips_rank_1h?: number;         // IP diversity rank
  // Quantiles (0.0-1.0, percentile in distribution)
  reqs_quantile_1h?: number;    // Request volume quantile
  ips_quantile_1h?: number;     // IP count quantile
}

export default {
  async fetch(request: Request): Promise<Response> {
    const cf = request.cf as IncomingRequestCfProperties | undefined;
    const ja4Signals = cf?.ja4Signals as JA4Signals | undefined;
    
    if (!ja4Signals) return fetch(request); // Not available for HTTP or Worker routing
    
    // Check for anomalous behavior
    // High heuristic_ratio or low browser_ratio = suspicious
    const heuristicRatio = ja4Signals.heuristic_ratio_1h ?? 0;
    const browserRatio = ja4Signals.browser_ratio_1h ?? 0;
    
    if (heuristicRatio > 0.5 || browserRatio < 0.3) {
      return new Response('Suspicious traffic', { status: 403 });
    }
    
    return fetch(request);
  }
};
```

## よく使われるパターン

Workers の例（モバイルアプリの許可リスト、企業プロキシの除外、データセンター検出、条件付き遅延など）は [patterns.md](./patterns.md) を参照してください。

## Bot Analytics

### アクセス先
- Dashboard: Security > Bots (old) または Security > Analytics > Bot analysis (new)
- プログラムからのアクセスには GraphQL API
- Security Events & Security Analytics
- Logpush/Logpull

### 利用可能なデータ
- **Enterprise BM**: Bot スコア（1-99）、スコアの判定元、分布
- **Pro/Business**: Bot の分類（自動化、ほぼ自動化、ほぼ人間）
- 上位の属性: IP、パス、ユーザーエージェント、国
- 検出元: ヒューリスティック、ML、AD、JSD
- 検証済み Bot のカテゴリ

### 期間
- **Enterprise BM**: 一度に最大 1 週間、履歴は 30 日分
- **Pro/Business**: 一度に最大 72 時間、履歴は 30 日分
- ほとんどの場合はリアルタイム。適応型サンプリング（ボリュームに応じて 1～10%）

## Logpush フィールド

```txt
BotScore              # 1-99 or 0 if not computed
BotScoreSrc           # Detection engine (ML, Heuristics, etc.)
BotTags               # Classification tags
BotDetectionIDs       # Heuristic detection IDs
```

**BotScoreSrc の値:**
- `"Heuristics"` - 既知のフィンガープリント
- `"Machine Learning"` - ML モデル
- `"Anomaly Detection"` - ベースラインからの異常
- `"JS Detection"` - JavaScript チェック
- `"Cloudflare Service"` - Zero Trust
- `"Not Computed"` - スコア = 0

Logpush（クラウドストレージ／SIEM へのストリーミング）、Logpull（ログ取得用 API）、または GraphQL API（分析データのクエリ）経由でアクセスします。

## Miniflare でのテスト

Miniflare はローカル開発用に botManagement のモックデータを提供します。

**既定値:**
- `score: 99`（人間）
- `verifiedBot: false`
- `corporateProxy: false`
- `ja3Hash: "25b4882c2bcb50cd6b469ff28c596742"`
- `staticResource: false`
- `detectionIds: []`

**テストでの上書き:**
```typescript
import { getPlatformProxy } from 'wrangler';

const { cf, dispose } = await getPlatformProxy();
// cf.botManagement is frozen mock object
expect(cf.botManagement.score).toBe(99);
```

独自のテストデータを使う場合は、テストのセットアップで request.cf をモックしてください。
