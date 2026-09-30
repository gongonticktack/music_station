# Cloudflare Workers KV

グローバルに分散され、結果整合性を持つキーバリューストアです。読み取り量が多く、レイテンシを低く抑える用途に最適化されています。

## 概要

KV の特長：
- 結果整合性（グローバルへの反映は 60 秒以内）
- 読み取りに最適化されたパフォーマンス
- 1 キーあたり 25 MiB の値サイズ上限
- Cloudflare のエッジへの自動レプリケーション
- メタデータをサポート（1024 bytes）

**ユースケース:** 設定の保存、ユーザーセッション、機能フラグ、キャッシュ、A/B テスト

## KV を使う場面

| 必要なもの | 推奨 |
|------|----------------|
| 強い整合性 | → [Durable Objects](../durable-objects/) |
| SQL クエリ | → [D1](../d1/) |
| オブジェクトストレージ（ファイル） | → [R2](../r2/) |
| 読み取り量が多く、書き込み量が少ない | → KV ✅ |
| グローバルで 10 ms 未満の読み取り | → KV ✅ |

**簡単な比較:**

| 機能 | KV | D1 | Durable Objects |
|---------|----|----|-----------------|
| 整合性 | 結果整合性 | 強い | 強い |
| 読み取りレイテンシ | <10ms | ~50ms | <1ms |
| 書き込み上限 | キーあたり 1/s | 無制限 | 無制限 |
| ユースケース | 設定、キャッシュ | リレーショナルデータ | 調整・連携 |

## クイックスタート

```bash
wrangler kv namespace create MY_NAMESPACE
# Add binding to wrangler.jsonc
```

```typescript
// Write
await env.MY_KV.put("key", "value", { expirationTtl: 300 });

// Read
const value = await env.MY_KV.get("key");
const json = await env.MY_KV.get<Config>("config", "json");
```

## 基本操作

| メソッド | 用途 | 戻り値 |
|--------|---------|---------|
| `get(key, type?)` | 単一読み取り | `string \| null` |
| `get(keys, type?)` | 一括読み取り（≤100） | `Map<string, T \| null>` |
| `put(key, value, options?)` | 書き込み | `Promise<void>` |
| `delete(key)` | 削除 | `Promise<void>` |
| `list(options?)` | キー一覧の取得 | `{ keys, list_complete, cursor? }` |
| `getWithMetadata(key)` | 値とメタデータの取得 | `{ value, metadata }` |

## 整合性モデル

- **書き込みの可視性:** 同じ場所では即時、グローバルでは 60 秒以内
- **読み取り経路:** 結果整合性
- **書き込みレート:** キーあたり 1 回/秒（超過すると 429）

## 読む順序

| 作業 | 読むファイル |
|------|---------------|
| クイックスタート | README → configuration.md |
| 機能の実装 | README → api.md → patterns.md |
| 問題のデバッグ | gotchas.md → api.md |
| 一括操作 | api.md（bulk セクション）→ patterns.md |
| パフォーマンス調整 | gotchas.md（performance）→ patterns.md（caching）|

## このリファレンスの内容

- [configuration.md](./configuration.md) - wrangler.jsonc の設定、namespace の作成、TypeScript の型
- [api.md](./api.md) - KV メソッド、一括操作、cacheTtl、コンテンツタイプ
- [patterns.md](./patterns.md) - キャッシュ、セッション、レート制限、A/B テスト
- [gotchas.md](./gotchas.md) - 結果整合性、同時書き込み、値のサイズ上限

## 関連項目

- [workers](../workers/) - KV にアクセスする Worker ランタイム
- [d1](../d1/) - 強い整合性が必要な場合は D1 を使用
- [durable-objects](../durable-objects/) - 強い整合性を持つ代替手段