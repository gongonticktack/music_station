# 動的ルーティング

コードを変更せずに、ダッシュボードで複雑なルーティングを設定できます。モデル名の代わりにルート名を使用します。

## 使い方

```typescript
const response = await client.chat.completions.create({
  model: 'dynamic/smart-chat', // Route name from dashboard
  messages: [{ role: 'user', content: 'Hello!' }]
});
```

## ノードの種類

| ノード | 目的 | ユースケース |
|------|---------|----------|
| **条件分岐** | メタデータに基づいて分岐 | 有料ユーザーと無料ユーザーの振り分け、地域別ルーティング |
| **割合** | トラフィックを A/B 分割 | モデルのテスト、段階的な展開 |
| **レート制限** | 割り当てを適用 | ユーザーまたはチームごとの制限 |
| **予算制限** | コストの割り当て | ユーザーごとの支出上限 |
| **モデル** | プロバイダーを呼び出す | 最終的な送信先 |

## メタデータ

ヘッダーで渡します（最大 5 項目、入れ子構造は不可）。
```typescript
headers: {
  'cf-aig-metadata': JSON.stringify({
    userId: 'user-123',
    tier: 'pro',
    region: 'us-east'
  })
}
```

## 一般的なパターン

**複数モデル間のフォールバック:**
```
Start → GPT-4 → On error: Claude → On error: Llama
```

**利用区分ごとのアクセス制御:**
```
Conditional: tier == 'enterprise' → GPT-4 (no limit)
Conditional: tier == 'pro' → Rate Limit 1000/hr → GPT-4o
Conditional: tier == 'free' → Rate Limit 10/hr → GPT-4o-mini
```

**段階的な展開:**
```
Percentage: 10% → New model, 90% → Old model
```

**コストに応じたフォールバック:**
```
Budget Limit: $100/day per teamId
  < 80%: GPT-4
  >= 80%: GPT-4o-mini
  >= 100%: Error
```

## バージョン管理

- 変更を新しいバージョンとして保存する
- `model: 'dynamic/route@v2'` でテストする
- 以前のバージョンをデプロイしてロールバックする

## モニタリング

Dashboard → Gateway → Dynamic Routes:
- 経路ごとのリクエスト数
- 成功率とエラー率
- 経路ごとのレイテンシーとコスト

## 制限事項

- メタデータは最大 5 項目
- 値は文字列、数値、真偽値、null のみ
- 入れ子になったオブジェクトは不可
- ルート名には英数字とハイフンを使用
