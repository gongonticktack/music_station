# Cron トリガーの設定

## wrangler.jsonc

```jsonc
{
  "$schema": "./node_modules/wrangler/config-schema.json",
  "name": "my-cron-worker",
  "main": "src/index.ts",
  "compatibility_date": "2025-01-01", // Use current date for new projects
  
  "triggers": {
    "crons": [
      "*/5 * * * *",     // Every 5 minutes
      "0 */2 * * *",     // Every 2 hours
      "0 9 * * MON-FRI", // Weekdays at 9am UTC
      "0 2 1 * *"        // Monthly on 1st at 2am UTC
    ]
  }
}
```

## Green Compute（ベータ）

炭素排出量を考慮した実行のため、炭素排出量の少ない時間帯にcronをスケジュールします。

```jsonc
{
  "name": "eco-cron-worker",
  "triggers": {
    "crons": ["0 2 * * *"]
  },
  "placement": {
    "mode": "smart"  // Runs during low-carbon periods
  }
}
```

**モード:**
- `"smart"` - 炭素排出量を考慮したスケジューリング（最適な時間帯に合わせて最大24時間遅延する場合があります）
- デフォルト（placement設定なし） - 標準のスケジューリング（遅延なし）

**仕組み:**
- Cloudflareは、電力網の炭素強度が下がるまで実行を遅らせます
- 最大遅延：スケジュール時刻から24時間
- 実行時刻に柔軟性があるバッチジョブに最適です

**ユースケース:** 
- 夜間のデータ処理とETLパイプライン
- 週次・月次レポートの生成
- データベースのバックアップとメンテナンス
- 分析データの集計
- MLモデルのトレーニング

**適していない用途:** 
- 時間に厳密な処理（SLA要件があるもの）
- 即時実行が必要なユーザー向け機能
- リアルタイムの監視とアラート
- 厳密な時間枠が定められたコンプライアンス関連タスク

## 環境ごとのスケジュール

```jsonc
{
  "name": "my-cron-worker",
  "triggers": {
    "crons": ["0 */6 * * *"]  // Prod: every 6 hours
  },
  "env": {
    "staging": {
      "triggers": {
        "crons": ["*/15 * * * *"]  // Staging: every 15min
      }
    },
    "dev": {
      "triggers": {
        "crons": ["*/5 * * * *"]  // Dev: every 5min
      }
    }
  }
}
```

## スケジュール形式

**構造:** `minute hour day-of-month month day-of-week`

**特殊文字:** `*`（任意）、`,`（リスト）、`-`（範囲）、`/`（間隔）、`L`（最終）、`W`（平日）、`#`（第n曜日）

## トリガーの管理

**すべて削除:** `"triggers": { "crons": [] }`  
**既存設定を保持:** `"triggers"` フィールドを丸ごと省略

## デプロイ

```bash
# Deploy with config crons
npx wrangler deploy

# Deploy specific environment
npx wrangler deploy --env production

# View deployments
npx wrangler deployments list
```

**⚠️ 変更が全世界に反映されるまで最大15分かかります**

## APIによる管理

**トリガーの取得:**
```bash
curl "https://api.cloudflare.com/client/v4/accounts/{account_id}/workers/scripts/{script_name}/schedules" \
  -H "Authorization: Bearer {api_token}"
```

**トリガーの更新:**
```bash
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/{account_id}/workers/scripts/{script_name}/schedules" \
  -H "Authorization: Bearer {api_token}" \
  -H "Content-Type: application/json" \
  -d '{"crons": ["*/5 * * * *", "0 2 * * *"]}'
```

**すべて削除:**
```bash
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/{account_id}/workers/scripts/{script_name}/schedules" \
  -H "Authorization: Bearer {api_token}" \
  -H "Content-Type: application/json" \
  -d '{"crons": []}'
```

## 複数のWorkerの組み合わせ

複雑なスケジュールには、複数のWorkerを使用します。

```jsonc
// worker-frequent.jsonc
{
  "name": "data-sync-frequent",
  "triggers": { "crons": ["*/5 * * * *"] }
}

// worker-daily.jsonc
{
  "name": "reports-daily",
  "triggers": { "crons": ["0 2 * * *"] },
  "placement": { "mode": "smart" }
}

// worker-weekly.jsonc
{
  "name": "cleanup-weekly",
  "triggers": { "crons": ["0 3 * * SUN"] }
}
```

**利点:**
- WorkerごとにCPU制限を分けられる
- エラーの影響範囲を個別に隔離できる
- Green Computeのポリシーを個別に設定できる
- 保守やデバッグが容易になる

## 検証

**cron構文のテスト:**
- [crontab.guru](https://crontab.guru/) - 対話型バリデーター
- Wranglerはデプロイ時に検証しますが、ロジック上の誤りは検出できません

**よくある間違い:**
- `0 0 * * *` は現地時間ではなく、毎日UTC午前0時に実行されます
- `*/60 * * * *` は無効です（毎時実行するには `0 * * * *` を使用します）
- `0 2 31 * *` は、31日まである月にのみ実行されます

## 関連項目

- [README.md](./README.md) - 概要、クイックスタート
- [api.md](./api.md) - ハンドラーの実装
- [patterns.md](./patterns.md) - 複数cronのルーティング例
