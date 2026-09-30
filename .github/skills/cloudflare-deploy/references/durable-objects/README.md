# Cloudflare Durable Objects

Cloudflare Durable Objects を使ってステートフルなアプリケーションを構築するための専門的なガイダンス。

## 読む順序

1. **初めてですか？** この概要とクイックスタートを読む
2. **セットアップ中ですか？** [設定](./configuration.md)を参照
3. **機能を構築中ですか？** 以下の判断ツリーを使う → [パターン](./patterns.md)
4. **問題をデバッグ中ですか？** [注意点](./gotchas.md)を確認
5. **詳しく調べますか？** [API](./api.md)と[DO Storage](../do-storage/README.md)

## 概要

Durable Objects はコンピューティングとストレージを組み合わせ、グローバルに一意で強整合性を備えたパッケージとして提供します。
- **グローバルに一意なインスタンス**: 各 DO は一意の ID を持ち、複数クライアント間の調整に使えます
- **ストレージの併置**: コンピューティングと併せて、高速で強整合性のあるストレージを利用できます
- **自動配置**: オブジェクトは最初のリクエスト元の近くで起動します
- **ステートフルなサーバーレス**: メモリ内状態と永続ストレージを利用します
- **シングルスレッド**: リクエストを順番に処理します（競合状態は発生しません）

## Durable Objects のルール

本番環境での問題の大半を防ぐための重要なルールです。

1. **DO ごとにアラームは 1 つ** - 複数のイベントはキューパターンでスケジュールする
2. **DO ごとの上限は約 1K req/s** - さらに高いスループットが必要ならシャーディングする
3. **起動のたびにコンストラクターが実行される** - 初期化を軽く保ち、遅延読み込みを使う
4. **ハイバネーションでメモリが消去される** - メモリ内の状態は失われるため、重要なデータは永続化する
5. **クリーンアップには `ctx.waitUntil()` を使う** - レスポンス送信後も処理の完了を保証する
6. **永続化に setTimeout を使わない** - 確実なスケジューリングには `setAlarm()` を使う

## 基本概念

### クラス構造
すべての DO は `DurableObject` 基底クラスを継承します。コンストラクターは `DurableObjectState`（ストレージ、WebSocket、アラームを含む）と `Env`（バインディング）を受け取ります。

### ライフサイクルの状態

```
[Not Created] → [Active] ⇄ [Hibernated] → [Evicted]
                   ↓
              [Destroyed]
```

- **Not Created**: DO ID は存在しますが、インスタンスはまだ起動していません
- **Active**: リクエストを処理中で、メモリ内の状態は有効です。GB 時間単位で課金されます
- **Hibernated**: WebSocket 接続は開いたままですが、コンピューティングはゼロで、コストも発生しません
- **Evicted**: メモリから削除された状態です。次のリクエストでコールドスタートが発生します
- **Destroyed**: マイグレーションまたは手動削除によってデータが削除された状態です

### Workers からのアクセス
Workers はバインディングを使ってスタブを取得し、RPC メソッドを直接呼び出す方法（推奨）か、fetch ハンドラーを使う方法（旧方式）でアクセスします。

**RPC と fetch() の選択:**
```
├─ New project + compat ≥2024-04-03 → RPC (type-safe, simpler)
├─ Need HTTP semantics (headers, status) → fetch()
├─ Proxying requests to DO → fetch()
└─ Legacy compatibility → fetch()
```

例は[パターン: RPC と fetch()](./patterns.md)を参照してください。

### ID の生成
- `idFromName()`: 決定論的な名前付き調整（レート制限、ロック）に使用
- `newUniqueId()`: 高スループットのワークロードをシャーディングするためのランダム ID
- `idFromString()`: 既存の ID から生成
- Jurisdiction オプション: データのローカリティ要件への準拠

### ストレージの選択肢

**どのストレージ API を使いますか？**
```
├─ Structured data, relations, transactions → SQLite (recommended)
├─ Simple KV on SQLite DO → ctx.storage.kv (sync KV)
└─ Legacy KV-only DO → ctx.storage (async KV)
```

- **SQLite**（推奨）: 構造化データ、トランザクション、DO あたり 10GB
- **同期 KV API**: SQLite オブジェクト上で使えるシンプルなキーと値のストレージ
- **非同期 KV API**: 旧方式または高度なユースケース向け

詳しくは[DO Storage](../do-storage/README.md)を参照してください。

### 特別な機能
- **アラーム**: DO ごとに将来の実行をスケジュールします（DO ごとに 1 つ。複数必要な場合はキューパターンを使用）
- **WebSocket ハイバネーション**: アイドル中の接続はコストゼロです（ハイバネーション時にメモリは消去されます）
- **ポイントインタイムリカバリー**: 過去 30 日間の任意の時点に復元できます（SQLite のみ）

## クイックスタート

```typescript
import { DurableObject } from "cloudflare:workers";

export class Counter extends DurableObject<Env> {
  async increment(): Promise<number> {
    const result = this.ctx.storage.sql.exec(
      `INSERT INTO counters (id, value) VALUES (1, 1)
       ON CONFLICT(id) DO UPDATE SET value = value + 1
       RETURNING value`
    ).one();
    return result.value;
  }
}

// Worker access
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const id = env.COUNTER.idFromName("global");
    const stub = env.COUNTER.get(id);
    const count = await stub.increment();
    return new Response(`Count: ${count}`);
  }
};
```

## 判断ツリー

### 何が必要ですか？

```
├─ Coordinate requests (rate limit, lock, session)
│   → idFromName(identifier) → [Patterns: Rate Limiting/Locks](./patterns.md)
│
├─ High throughput (>1K req/s)
│   → Sharding with newUniqueId() or hash → [Patterns: Sharding](./patterns.md)
│
├─ Real-time updates (WebSocket, chat, collab)
│   → WebSocket hibernation + room pattern → [Patterns: Real-time](./patterns.md)
│
├─ Background work (cleanup, notifications, scheduled tasks)
│   → Alarms + queue pattern (1 alarm/DO) → [Patterns: Multiple Events](./patterns.md)
│
└─ User sessions with expiration
    → Session pattern + alarm cleanup → [Patterns: Session Management](./patterns.md)
```

### どのアクセスパターンを使いますか？

```
├─ New project + typed methods → RPC (compat ≥2024-04-03)
├─ Need HTTP semantics → fetch()
├─ Proxying to DO → fetch()
└─ Legacy compat → fetch()
```

例は[パターン: RPC と fetch()](./patterns.md)を参照してください。

### どのストレージを使いますか？

```
├─ Structured data, SQL queries, transactions → SQLite (recommended)
├─ Simple KV on SQLite DO → ctx.storage.kv (sync API)
└─ Legacy KV-only DO → ctx.storage (async API)
```

完全なガイドは[DO Storage](../do-storage/README.md)を参照してください。

## 必須コマンド

```bash
npx wrangler dev              # Local dev with DOs
npx wrangler dev --remote     # Test against prod DOs
npx wrangler deploy           # Deploy + auto-apply migrations
```

## リソース

**ドキュメント**: https://developers.cloudflare.com/durable-objects/  
**API リファレンス**: https://developers.cloudflare.com/durable-objects/api/  
**サンプル**: https://developers.cloudflare.com/durable-objects/examples/

## このリファレンスの内容

- **[設定](./configuration.md)** - wrangler.jsonc のセットアップ、マイグレーション、バインディング、環境
- **[API](./api.md)** - クラス構造、ctx メソッド、アラーム、WebSocket ハイバネーション
- **[パターン](./patterns.md)** - シャーディング、レート制限、ロック、リアルタイム、セッション
- **[注意点](./gotchas.md)** - 制限、ハイバネーション時の注意事項、よくあるエラー

## 関連項目

- **[DO Storage](../do-storage/README.md)** - SQLite、KV、トランザクション（ストレージの詳細ガイド）
- **[Workers](../workers/README.md)** - Workers ランタイムの主な機能
- **[WebSockets](../websockets/README.md)** - WebSocket API とパターン
