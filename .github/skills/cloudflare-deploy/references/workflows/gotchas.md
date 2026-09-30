# 落とし穴とデバッグ

## よくあるエラー

### 「Step Timeout」

**原因:** ステップの実行時間がデフォルトの10分、または設定されたタイムアウトを超過している  
**解決策:** `step.do('long operation', {timeout: '30 minutes'}, async () => {...})` を使ってカスタムタイムアウトを設定するか、wrangler.jsonc で CPU 制限を引き上げる（CPU 時間は最大5分）

### 「waitForEvent Timeout」

**原因:** タイムアウト期間内にイベントを受信できない（デフォルト24時間、最大365日）  
**解決策:** try-catch で囲み、タイムアウトを適切に処理してデフォルトの動作を続行する

### 「Non-Deterministic Step Names」

**原因:** ステップ名に `Date.now()` のような動的な値を使うと、リプレイ時に問題が発生する  
**解決策:** ステップ名には `event.instanceId` のような決定論的な値を使う

### 「State Lost in Variables」

**原因:** ハイバネーション時に失われるモジュールレベルまたはローカル変数に状態を保存している  
**解決策:** 自動的に永続化される `step.do()` から値を返す: `const total = await step.do('step 1', async () => 10)`

### 「Non-Deterministic Conditionals」

**原因:** 条件分岐のステップ外で、`Date.now()` のような非決定論的なロジックを使っている  
**解決策:** 非決定論的な処理をステップ内に移す: `const isLate = await step.do('check', async () => Date.now() > deadline)`

### 「Large Step Returns Exceeding Limit」

**原因:** ステップから1 MiBを超えるデータを返している  
**解決策:** 大きなデータは R2 に保存し、参照のみを返す: `{ key: 'r2-object-key' }`

### 「Step Exceeded CPU Limit But Ran for < 30s」

**原因:** CPU 時間（実際の計算時間）と実時間（I/O 待機を含む）の混同  
**解決策:** ネットワークリクエスト、データベースクエリ、スリープは CPU 時間に含まれない。30秒の制限は、実際に処理している時間が30秒という意味

### 「Idempotency Violation」

**原因:** ステップの処理が冪等でないため、リトライ時に二重請求や処理の重複が発生する  
**解決策:** 実行前に処理が完了済みか確認する（例: 顧客への請求がすでに済んでいるか確認する）

### 「Instance ID Collision」

**原因:** インスタンス ID の再利用によって競合が発生する  
**解決策:** タイムスタンプを含む一意の ID を使う: `await env.MY_WORKFLOW.create({ id: \`${userId}-${Date.now()}\`, params: {} })`

### 「Instance Data Disappeared After Completion」

**原因:** 完了またはエラーになったインスタンスは、保持期間（無料プランでは3日間、有料プランでは30日間）の経過後に自動削除される  
**解決策:** ワークフローの完了前に、重要なデータを KV/R2/D1 にエクスポートする

### 「Missing await on step.do」

**原因:** step.do() の await を忘れると、完了を待たずに実行される  
**解決策:** ステップの処理には必ず await を付ける: `await step.do('task', ...)`

## 制限

| 制限 | 無料 | 有料 | 備考 |
|-------|------|------|-------|
| ステップあたりの CPU | 10ms | 30秒（デフォルト）、5分（最大） | wrangler.jsonc の `limits.cpu_ms` で設定 |
| ステップの状態 | 1 MiB | 1 MiB | ステップごとの戻り値 |
| インスタンスの状態 | 100 MB | 1 GB | ワークフローインスタンスごとの状態合計 |
| ワークフローあたりのステップ数 | 1,024 | 1,024 | `step.sleep()` は含まれない |
| 1日あたりの実行回数 | 100k | 無制限 | 1日の実行上限 |
| 同時実行インスタンス数 | 25 | 10k | 同時実行できるワークフローの最大数。待機状態は除く |
| キュー内のインスタンス数 | 100k | 1M | キューに入れられるワークフローインスタンスの最大数 |
| ステップあたりのサブリクエスト数 | 50 | 1,000 | ステップごとの送信リクエストの最大数 |
| 状態の保持期間 | 3日 | 30日 | 完了したインスタンスの保持期間 |
| ステップのデフォルトタイムアウト | 10分 | 10分 | 試行ごと |
| waitForEvent のデフォルトタイムアウト | 24時間 | 24時間 | 最大365日 |
| waitForEvent の最大タイムアウト | 365日 | 365日 | 最大待機期間 |

**注:** `waiting` 状態（`step.sleep` または `step.waitForEvent` による）のインスタンスは同時実行インスタンス数の上限に含まれないため、数百万のワークフローを休止状態にできます。

## 料金

| 指標 | 無料 | 有料 | 備考 |
|--------|------|------|-------|
| リクエスト | 1日あたり100k | 月あたり10M + 0.30ドル/M | ワークフローの呼び出し |
| CPU 時間 | 呼び出しあたり10ms | 月あたり30M CPU-ms + 0.02ドル/M CPU-ms | 実際の CPU 使用量 |
| ストレージ | 1 GB | 月あたり1 GB + 0.20ドル/GB-月 | すべてのインスタンス（実行中/エラー/休止中/完了） |

## 参考資料

- [公式ドキュメント](https://developers.cloudflare.com/workflows/)
- [スタートガイド](https://developers.cloudflare.com/workflows/get-started/guide/)
- [Workers API](https://developers.cloudflare.com/workflows/build/workers-api/)
- [REST API](https://developers.cloudflare.com/api/resources/workflows/)
- [例](https://developers.cloudflare.com/workflows/examples/)
- [制限](https://developers.cloudflare.com/workflows/reference/limits/)
- [料金](https://developers.cloudflare.com/workflows/reference/pricing/)

参照先: [README.md](./README.md)、[configuration.md](./configuration.md)、[api.md](./api.md)、[patterns.md](./patterns.md)
