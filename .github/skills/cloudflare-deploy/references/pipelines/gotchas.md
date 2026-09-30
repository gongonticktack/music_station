# Pipelines の注意点

## 重大な問題

### イベントが通知なく破棄される

**最もよくある問題です。** イベントは受け付けられる（HTTP 200）が、sink に現れません。

**原因:**
1. スキーマ検証の失敗 - 構造化ストリームは無効なイベントを通知なく破棄します
2. ロール間隔（10～300 秒）の待機中 - 想定された動作です

**解決策:** Zod でクライアント側の検証を行います:
```typescript
const EventSchema = z.object({ user_id: z.string(), amount: z.number() });
try {
  const validated = EventSchema.parse(rawEvent);
  await env.STREAM.send([validated]);
} catch (e) { /* get immediate feedback */ }
```

### Pipelines は不変

作成後に SQL を変更できません。削除して再作成する必要があります。

```bash
npx wrangler pipelines delete old-pipeline
npx wrangler pipelines create new-pipeline --sql "..."
```

**ヒント:** バージョン名（`events-pipeline-v1`）を使用し、SQL をバージョン管理に保存してください。

### Worker バインディングが見つからない

**`env.STREAM is undefined`**

1. `wrangler.jsonc` では pipeline ID ではなく **stream ID** を使用します
2. バインディングを追加した後、再デプロイします

```bash
npx wrangler pipelines streams list  # Get stream ID
npx wrangler deploy
```

## よくあるエラー

| エラー | 原因 | 対処 |
|-------|-------|-----|
| R2 にイベントがない | ロール間隔が経過していない | 10～300 秒待ち、`roll_interval` を確認 |
| スキーマ検証の失敗 | 型の不一致、必須フィールドの欠落 | クライアント側で検証 |
| レート制限（429） | ストリームあたり 5 MB/s 超過 | イベントをまとめて送信し、上限引き上げを申請 |
| ペイロードが大きすぎる（413） | リクエストが 1 MB 超過 | 小さなバッチに分割 |
| ストリームを削除できない | Pipeline が参照している | 先に Pipelines を削除 |
| Sink の認証情報エラー | トークンの期限切れ | 新しい認証情報で sink を再作成 |

## 制限（オープンベータ）

| リソース | 制限 |
|----------|-------|
| アカウントあたりの Streams/Sinks/Pipelines | 各 20 |
| ペイロードサイズ | 1 MB |
| ストリームあたりの取り込み速度 | 5 MB/s |
| イベントの保持期間 | 24 時間 |
| 推奨バッチサイズ | 100 イベント |

## SQL の制限事項

- **JOIN は不可** - 1 つの pipeline で使用できるストリームは 1 つだけです
- **ウィンドウ関数は不可** - 基本的な SQL のみ使用できます
- **サブクエリは不可** - `INSERT INTO ... SELECT ... FROM` を使用する必要があります
- **スキーマの進化は不可** - 作成後に変更できません

## デバッグ用チェックリスト

- [ ] ストリームが存在する: `npx wrangler pipelines streams list`
- [ ] Pipeline が正常: `npx wrangler pipelines get <ID>`
- [ ] SQL 構文がスキーマと一致している
- [ ] バインディング追加後に Worker を再デプロイした
- [ ] ロール間隔が経過するまで待った
- [ ] 受け付けた件数と処理済み件数が一致する（検証時の破棄がない）
