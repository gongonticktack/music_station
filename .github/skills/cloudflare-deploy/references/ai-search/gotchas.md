# AI Search の注意点

## 型に関する注意

**タイムスタンプの精度:** ミリ秒ではなく秒（10 桁）を使用します。
```typescript
const nowInSeconds = Math.floor(Date.now() / 1000); // Correct
```

**フォルダーのプレフィックス照合:** パスの「～で始まる」という条件には `gte` を使用します。
```typescript
filters: { column: "folder", operator: "gte", value: "docs/api/" } // Matches nested
```

## フィルターの制限

| 制限項目 | 値 |
|-------|-------|
| ネストの最大深さ | 2 階層 |
| 複合フィルターあたりのフィルター数 | 10 |
| `or` 演算子 | 同じ列に対する `eq` のみ |

**OR の制約の例:**
```typescript
// ✅ Valid: same column, eq only
{ operator: "or", filters: [
  { column: "folder", operator: "eq", value: "docs/" },
  { column: "folder", operator: "eq", value: "guides/" }
]}
```

## インデックス化の問題

| 問題 | 原因 | 対処方法 |
|---------|-------|----------|
| ファイルがインデックス化されない | 非対応の形式、または 4 MB 超 | 形式を確認する（.md/.txt/.html/.pdf/.doc/.csv/.json） |
| インデックスが同期されていない | 6 時間ごとのインデックス化サイクル | 待つか、「Force Sync」を使用する（30 秒のレート制限あり） |
| 結果が空 | インデックス化が未完了 | ダッシュボードでインデックス化の状態を確認する |

## 認証エラー

| エラー | 原因 | 対処方法 |
|-------|-------|-----|
| `AutoRAGUnauthorizedError` | トークンが無効、または指定されていない | AI Search の権限を持つ Service API トークンを作成する |
| `AutoRAGNotFoundError` | インスタンス名が間違っている | ダッシュボードで正確な名前を確認する |

## パフォーマンス

**応答が遅い場合（3 秒超）:**
```typescript
// Add score threshold + limit results
ranking_options: { score_threshold: 0.5 },
max_num_results: 10
```

**結果が空の場合の調査手順:**
1. フィルターを外し、基本的なクエリを試す
2. `score_threshold` を 0.1 に下げる
3. インデックスにデータが入っているか確認する

## 上限

| リソース | 上限 |
|----------|-------|
| アカウントあたりのインスタンス数 | 10 |
| インスタンスあたりのファイル数 | 100,000 |
| ファイルの最大サイズ | 4 MB |
| インデックス化の間隔 | 6 時間 |

## 避けるべきパターン

**インスタンス名には環境変数を使用する:**
```typescript
const answer = await env.AI.autorag(env.AI_SEARCH_INSTANCE).aiSearch({...});
```

**エラーの種類ごとに処理する:**
```typescript
if (error instanceof AutoRAGNotFoundError) { /* 404 */ }
if (error instanceof AutoRAGUnauthorizedError) { /* 401 */ }
```
