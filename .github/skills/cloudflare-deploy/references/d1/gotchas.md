# D1 の注意点とトラブルシューティング

## よくあるエラー

### "SQL Injection Vulnerability"

**原因:** bind() を使ったプリペアドステートメントではなく、文字列補間を使用している  
**解決策:** 必ずプリペアドステートメントを使用してください: 攻撃者が悪意のある SQL を注入できる文字列補間ではなく、`env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId).all()` を使用します。

### "no such table"

**原因:** マイグレーションが実行されていない、または誤ったデータベースバインディングを使用しているため、テーブルが存在しない  
**解決策:** `wrangler d1 migrations apply <db-name> --remote` でマイグレーションを実行し、wrangler.jsonc のバインディング名がコードと一致していることを確認します。

### "UNIQUE constraint failed"

**原因:** UNIQUE 制約のある列に重複した値を挿入しようとしている  
**解決策:** エラーを捕捉し、409 Conflict ステータスコードを返します。

### "Query Timeout (30s exceeded)"

**原因:** クエリの実行が 30 秒のタイムアウト上限を超えている  
**解決策:** クエリを小さく分割する、インデックスを追加してクエリを高速化する、またはデータセットのサイズを減らします。

### "N+1 Query Problem"

**原因:** 最適化された単一のクエリではなく、ループ内で個別のクエリを複数回実行している  
**解決策:** JOIN を使って関連データを単一のクエリで取得するか、複数のクエリには `batch()` メソッドを使用します。

### "Missing Indexes"

**原因:** インデックスなしでクエリがテーブル全体をスキャンしている  
**解決策:** `EXPLAIN QUERY PLAN` を使ってインデックスが使用されているか確認し、その後 `CREATE INDEX idx_users_email ON users(email)` でインデックスを作成します。

### "Boolean Type Issues"

**原因:** SQLite はネイティブの boolean 型ではなく INTEGER（0/1）を使用する  
**解決策:** boolean 値を扱うときは true/false ではなく 1 または 0 をバインドします。

### "Date/Time Type Issues"

**原因:** SQLite にはネイティブの DATE/TIME 型がない  
**解決策:** 日時の値には TEXT（ISO 8601 形式）または INTEGER（Unix タイムスタンプ）を使用します。

## プランの階層ごとの上限

| 上限 | Free Tier | Paid Plans | 備考 |
|-------|-----------|------------|-------|
| データベースサイズ | 500 MB | 10 GB | 有料プランではテナントごとに複数 DB を使う設計にする |
| 行サイズ | 1 MB | 1 MB | 大きなファイルは D1 ではなく R2 に保存 |
| クエリのタイムアウト | 30s | 30s（sessions 使用時は 900s） | マイグレーションには sessions API を使用 |
| バッチサイズ | 1,000 ステートメント | 10,000 ステートメント | 大きなバッチは適宜分割 |
| Time Travel | 7 日 | 30 日 | ポイントインタイムリカバリの期間 |
| 読み取りレプリカ | ❌ 利用不可 | ✅ 利用可能 | 低レイテンシーのための有料アドオン |
| Sessions API | ❌ 利用不可 | ✅ 最大 15 分 | マイグレーションや負荷の高い処理向け |
| 同時リクエスト数 | 10,000/分 | それ以上 | 独自の上限についてはサポートに問い合わせ |

## 本番環境での注意点

### "Batch size exceeded"

**原因:** Free tier で 1,000 を超えるステートメント、または有料プランで 10,000 を超えるステートメントを送信しようとしている  
**解決策:** バッチを分割します: `for (let i = 0; i < stmts.length; i += MAX_BATCH) await env.DB.batch(stmts.slice(i, i + MAX_BATCH))`

### "Session not closed / resource leak"

**原因:** sessions API の使用後に `session.close()` を呼び忘れている  
**解決策:** 必ず try/finally ブロックを使用します: `try { await session.prepare(...) } finally { session.close() }`

### "Replication lag causing stale reads"

**原因:** 書き込み直後にレプリカから読み取っているため、100ms〜2s のレプリケーション遅延が発生する可能性がある  
**解決策:** 書き込み直後の読み取りにはプライマリを使用します: `await env.DB.prepare(...)` ではなく `env.DB_REPLICA` を使用します。

### "Migration applied to local but not remote"

**原因:** マイグレーションの適用時に `--remote` フラグを付け忘れている  
**解決策:** 本番環境では必ず `wrangler d1 migrations apply <db-name> --remote` を実行します。

### "Foreign key constraint failed"

**原因:** 存在しない親を参照する FK 付きの行を挿入している、または子より先に親を削除している  
**解決策:** `PRAGMA foreign_keys = ON;` で FK の検証を有効にし、スキーマで ON DELETE CASCADE を使用します。

### "BLOB data corrupted on export"

**原因:** D1 のエクスポートでは BLOB が正しく処理されない場合がある  
**解決策:** バイナリファイルは R2 に保存し、D1 には R2 の URL/キーだけを保存します。

### "Database size approaching limit"

**原因:** 1 つのデータベースにデータを保存しすぎている  
**解決策:** 水平スケールアウトとして、テナントまたはユーザーごとにデータベースを作成する、古いデータをアーカイブする、または有料プランにアップグレードします。

### "Local dev vs production behavior differs"

**原因:** ローカルでは SQLite ファイルを使用し、本番では分散型の D1 を使用するため、性能や上限が異なる  
**解決策:** 本番リリース前に、必ず `--remote` フラグを付けてリモート環境でマイグレーションをテストします。
