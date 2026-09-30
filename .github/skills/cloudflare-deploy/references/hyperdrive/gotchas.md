# 注意点

[README.md](./README.md)、[configuration.md](./configuration.md)、[api.md](./api.md)、[patterns.md](./patterns.md)を参照してください。

## よくあるエラー

### "Too many open connections" / "Connection limit exceeded"

**原因:** Worker の 1 回の呼び出しあたりの同時接続数は最大 **6** です。  
**解決策:** ドライバーの設定で `max: 5` を指定し、接続を再利用します。`client.end()` または `ctx.waitUntil(conn.end())` で適切にクリーンアップしてください。

### "Failed to acquire a connection (Pool exhausted)"

**原因:** 多くの場合、長時間実行されるトランザクションが原因で、プール内のすべての接続が使用中です。  
**解決策:** トランザクションの時間を短くし、60 秒を超えるクエリを避け、外部呼び出し中に接続を保持しないようにします。または、有料プランにアップグレードして接続数を増やします。

### "connection_refused"

**原因:** ファイアウォール、接続数の制限、またはサービス停止により、データベースが接続を拒否しています。  
**解決策:** ファイアウォールで Cloudflare の IP が許可されていること、DB がポートで待ち受けていること、サービスが稼働していることを確認し、認証情報を検証してください。

### "Query timeout (deadline exceeded)"

**原因:** クエリの実行時間が 60 秒のタイムアウト上限を超えています。  
**解決策:** インデックスを使って最適化し、LIMIT でデータセットを絞り、小さなクエリに分割するか、非同期処理を利用してください。

### "password authentication failed"

**原因:** Hyperdrive の設定に無効な認証情報が含まれています。  
**解決策:** Hyperdrive の設定にあるユーザー名とパスワードが、データベースの認証情報と一致することを確認してください。

### "SSL/TLS connection error"

**原因:** Hyperdrive とデータベースの SSL/TLS 設定が一致していません。  
**解決策:** `sslmode=require`（Postgres）または `sslMode=REQUIRED`（MySQL）を追加し、自己署名証明書の場合は CA 証明書をアップロードします。DB で SSL が有効になっていることを確認し、証明書の有効期限も確認してください。

### "Queries not being cached"

**原因:** クエリがデータを変更する（INSERT/UPDATE/DELETE）、揮発性関数（NOW()、RANDOM()）を含む、またはキャッシュが無効になっています。  
**解決策:** クエリがデータを変更しない SELECT であることを確認し、揮発性関数を避け、キャッシュが有効であることを確認します。`wrangler dev --remote` でテストし、postgres.js では `prepare=true` を設定してください。

### "Slow multi-query Workers despite Hyperdrive"

**原因:** Worker がエッジで実行され、クエリごとに DB のリージョンとの間でラウンドトリップが発生しています。  
**解決策:** Smart Placement（wrangler.jsonc で `"placement": {"mode": "smart"}`）を有効にして、Worker を DB の近くで実行します。[patterns.md](./patterns.md)の複数クエリパターンを参照してください。

### "Local database connection failed"

**原因:** `localConnectionString` が正しくないか、データベースが起動していません。  
**解決策:** `localConnectionString` が正しいことと DB が起動していることを確認し、環境変数名がバインディングと一致することを確かめてから、psql/mysql クライアントでテストしてください。

### "Environment variable not working"

**原因:** 環境変数の形式が正しくないか、エクスポートされていません。  
**解決策:** `CLOUDFLARE_HYPERDRIVE_LOCAL_CONNECTION_STRING_<BINDING>` の形式を使い、バインディングが wrangler.jsonc と一致することを確認します。シェルで変数をエクスポートし、wrangler dev を再起動してください。

## 制限

| 制限 | Free | 有料 | 説明 |
|-------|------|------|-------|
| 最大設定数 | 10 | 25 | アカウントごとの Hyperdrive 設定数 |
| Worker 接続数 | 6 | 6 | Worker の 1 回の呼び出しあたりの最大同時接続数 |
| ユーザー名/DB 名 | 63 bytes | 63 bytes | 最大長 |
| 接続タイムアウト | 15s | 15s | 接続確立までの時間 |
| アイドルタイムアウト | 10 min | 10 min | 接続のアイドルタイムアウト |
| オリジン接続の最大数 | ~20 | ~100 | オリジンデータベースへの接続数 |
| クエリの最大実行時間 | 60s | 60s | 60 秒を超えるクエリは終了されます |
| キャッシュ可能なレスポンスの最大サイズ | 50 MB | 50 MB | 50 MB を超えるレスポンスは返されますが、キャッシュされません |

## リソース

- [ドキュメント](https://developers.cloudflare.com/hyperdrive/)
- [入門ガイド](https://developers.cloudflare.com/hyperdrive/get-started/)
- [Wrangler リファレンス](https://developers.cloudflare.com/hyperdrive/reference/wrangler-commands/)
- [対応データベース](https://developers.cloudflare.com/hyperdrive/reference/supported-databases-and-features/)
- [Discord #hyperdrive](https://discord.cloudflare.com)
- [制限引き上げ申請フォーム](https://forms.gle/ukpeZVLWLnKeixDu7)
