# よくある落とし穴とトラブルシューティング

## 実行順序

**問題:** ルールが予期しない順序で実行される
**原因:** フェーズの実行順序についての誤解
**解決策:**

フェーズは順番に実行されます（変更できません）。
1. `http_request_firewall_custom` - カスタムルール
2. `http_request_firewall_managed` - マネージドルールセット
3. `http_ratelimit` - レート制限

各フェーズ内では上から順に評価され、最初に一致したルールが適用されます（`skip` の場合を除く）。

```typescript
// WRONG: Can't mix phase-specific actions
await client.rulesets.create({
  phase: 'http_request_firewall_custom',
  rules: [
    { action: 'block', expression: 'cf.waf.score gt 50' },
    { action: 'execute', action_parameters: { id: 'managed_id' } }, // WRONG
  ],
});

// CORRECT: Separate rulesets per phase
await client.rulesets.create({ phase: 'http_request_firewall_custom', rules: [...] });
await client.rulesets.create({ phase: 'http_request_firewall_managed', rules: [...] });
```

## 式のエラー

**問題:** 構文エラーによってデプロイに失敗する
**原因:** フィールド、演算子、または構文が無効
**解決策:**

```typescript
// Common mistakes
'http.request.path' → 'http.request.uri.path' // Correct field
'ip.geoip.country eq US' → 'ip.geoip.country eq "US"' // Quote strings
'http.user_agent eq "Mozilla"' → 'lower(http.user_agent) contains "mozilla"' // Case sensitivity
'matches ".*[.jpg"' → 'matches ".*\\.jpg$"' // Valid regex
```

デプロイ前に Security Events で式をテストしてください。

## Skip ルールの落とし穴

**問題:** Skip ルールが想定どおりに機能しない
**原因:** Skip の適用範囲についての誤解
**解決策:**

Skip の種類:
- `ruleset: 'current'` - 現在のルールセット内の残りのルールのみをスキップ
- `phases: ['phase_name']` - フェーズ全体をスキップ

```typescript
// WRONG: Trying to skip managed rules from custom phase
// In http_request_firewall_custom:
{
  action: 'skip',
  action_parameters: { ruleset: 'current' },
  expression: 'ip.src in {192.0.2.0/24}',
}
// This only skips remaining custom rules, not managed rules

// CORRECT: Skip specific phases
{
  action: 'skip',
  action_parameters: {
    phases: ['http_request_firewall_managed', 'http_ratelimit'],
  },
  expression: 'ip.src in {192.0.2.0/24}',
}
```

## 更新ですべてのルールが置き換わる

**問題:** ルールセットを更新すると、他のルールが削除される
**原因:** `update()` はルールリスト全体を置き換える
**解決策:**

```typescript
// WRONG: This deletes all existing rules!
await client.rulesets.update({
  zone_id: 'zone_id',
  ruleset_id: 'ruleset_id',
  rules: [{ action: 'block', expression: 'cf.waf.score gt 50' }],
});

// CORRECT: Get existing rules first
const ruleset = await client.rulesets.get({ zone_id: 'zone_id', ruleset_id: 'ruleset_id' });
await client.rulesets.update({
  zone_id: 'zone_id',
  ruleset_id: 'ruleset_id',
  rules: [...ruleset.rules, { action: 'block', expression: 'cf.waf.score gt 50' }],
});
```

## オーバーライドの競合

**問題:** マネージドルールセットのオーバーライドが適用されない
**原因:** ルール ID が存在しないか、カテゴリ名が正しくない
**解決策:**

```typescript
// List managed ruleset rules to find IDs
const ruleset = await client.rulesets.get({
  zone_id: 'zone_id',
  ruleset_id: 'efb7b8c949ac4650a09736fc376e9aee',
});
console.log(ruleset.rules.map(r => ({ id: r.id, description: r.description })));

// Use correct IDs in overrides
{ action: 'execute', action_parameters: { id: 'efb7b8c949ac4650a09736fc376e9aee', 
  overrides: { rules: [{ id: '5de7edfa648c4d6891dc3e7f84534ffa', action: 'log' }] } } }
```

## 誤検知

**問題:** 正当なトラフィックがブロックされる
**原因:** ルールまたはしきい値の設定が厳しすぎる
**解決策:**

1. ログモードから開始します: `overrides: { action: 'log' }`
2. Security Events を確認して誤検知を特定します
3. 特定のルールをオーバーライドします: `overrides: { rules: [{ id: 'rule_id', action: 'log' }] }`

## レート制限における NAT の問題

**問題:** NAT 配下のユーザーがすぐにレート制限に達する
**原因:** 複数のユーザーが単一の IP アドレスを共有している
**解決策:**

User-Agent、セッション Cookie、認証ヘッダーなどの特性を追加します。
```typescript
{
  action: 'block',
  expression: 'http.request.uri.path starts_with "/api"',
  action_parameters: {
    ratelimit: {
      characteristics: ['cf.colo.id', 'ip.src', 'http.request.cookies["session"][0]'],
      period: 60,
      requests_per_period: 100,
    },
  },
}
```

## パフォーマンスの問題

**問題:** レイテンシの増加
**原因:** 複雑な式、過剰なルール
**解決策:**

1. 静的アセットを早い段階でスキップします: `action: 'skip'` を `\\.(jpg|css|js)$` に対して使用
2. パスベースでデプロイします: `/api` または `/admin` に対してのみマネージドルールを実行
3. 未使用のカテゴリを無効にします: `{ category: 'wordpress', enabled: false }`
4. 正規表現より文字列演算子を優先します: `starts_with` と `matches` の比較

## 制限とクォータ

| リソース | Free | Pro | Business | Enterprise |
|----------|------|-----|----------|------------|
| カスタムルール | 5 | 20 | 100 | 1000 |
| レート制限ルール | 1 | 10 | 25 | 100 |
| ルール式の長さ | 4096 文字 | 4096 文字 | 4096 文字 | 4096 文字 |
| ルールセットあたりのルール数 | 75 | 75 | 400 | 1000 |
| マネージドルールセット | はい | はい | はい | はい |
| レート制限の特性数 | 2 | 3 | 5 | 5 |

**重要な注意事項:**
- ルールは順番に実行され、最初に一致したルールが適用されます（Skip ルールを除く）
- AND チェーンでは、最初の `false` で式の評価が停止します
- `matches` 正規表現演算子は文字列演算子より低速です
- レート制限のカウントは緩和措置の前に行われます

## API エラー

**問題:** API 呼び出しが分かりにくいエラーで失敗する
**原因:** パラメーターが無効、または権限が不足している
**解決策:**

```typescript
// Error: "Invalid phase" → Use exact phase name
phase: 'http_request_firewall_custom'

// Error: "Ruleset already exists" → Use update() or list first
const rulesets = await client.rulesets.list({ zone_id, phase: 'http_request_firewall_custom' });
if (rulesets.result.length > 0) {
  await client.rulesets.update({ zone_id, ruleset_id: rulesets.result[0].id, rules: [...] });
}

// Error: "Action not supported" → Check phase/action compatibility
// 'execute' only in http_request_firewall_managed
// Rate limit config only in http_ratelimit phase

// Error: "Expression parse error" → Common fixes:
'ip.geoip.country eq "US"'   // Quote strings
'cf.waf.score gt 40'         // Use 'gt' not '>'
'http.request.uri.path'      // Not 'http.request.path'
```

**ヒント**: デプロイ前にダッシュボードの Security Events で式をテストしてください。
