# トラブルシューティングとベストプラクティス

## よくあるエラー

### 「バンドラー／ビルド手順がない」— Pulumi がコードをそのままアップロードする

**問題:** Worker が「Cannot use import statement outside a module」というエラーで失敗する  
**原因:** Pulumi は Worker コードをバンドルせず、指定された内容をそのままアップロードする  
**解決策:** Pulumi でデプロイする前に Worker をビルドする

```typescript
// WRONG: Pulumi won't bundle this
const worker = new cloudflare.WorkerScript("worker", {
    content: fs.readFileSync("./src/index.ts", "utf8"), // Raw TS file
});

// RIGHT: Build first, then deploy
import * as command from "@pulumi/command";
const build = new command.local.Command("build", {
    create: "npm run build",
    dir: "./worker",
});
const worker = new cloudflare.WorkerScript("worker", {
    content: build.stdout.apply(() => fs.readFileSync("./worker/dist/index.js", "utf8")),
}, {dependsOn: [build]});
```

### 「wrangler.toml が読み込まれない」— 設定のずれ

**問題:** ローカルの wrangler dev は動作するが、Pulumi のデプロイは失敗する  
**原因:** Pulumi は wrangler.toml を無視するため、設定を複製する必要がある  
**解決策:** Pulumi の設定から wrangler.toml を生成するか、手動で同期を保つ

```typescript
// Pattern: Export Pulumi config to wrangler.toml
const workerConfig = {
    name: "my-worker",
    compatibilityDate: "2025-01-01",
    compatibilityFlags: ["nodejs_compat"],
};

new command.local.Command("generate-wrangler", {
    create: pulumi.interpolate`cat > wrangler.toml <<EOF
name = "${workerConfig.name}"
compatibility_date = "${workerConfig.compatibilityDate}"
compatibility_flags = ${JSON.stringify(workerConfig.compatibilityFlags)}
EOF`,
});
```

### 「変更なしと誤検出される」— コンテンツの SHA が変わらない

**問題:** Worker のコードを更新したのに、Pulumi が「変更なし」と表示する  
**原因:** コンテンツのハッシュが同一（空白またはコメントのみの変更）  
**解決策:** 更新を強制するため、ビルド時刻またはバージョンを追加する

```typescript
const version = Date.now().toString();
const worker = new cloudflare.WorkerScript("worker", {
    content: code,
    plainTextBindings: [{name: "VERSION", text: version}], // Forces new deployment
});
```

### 「pulumi up で D1 マイグレーションが実行されない」

**問題:** D1 データベースを作成した後も、データベーススキーマが適用されない  
**原因:** Pulumi はデータベースを作成するが、マイグレーションは実行しない  
**解決策:** dependsOn を指定して Command リソースを使う

```typescript
const db = new cloudflare.D1Database("db", {accountId, name: "mydb"});

// Run migrations after DB created
const migration = new command.local.Command("migrate", {
    create: pulumi.interpolate`wrangler d1 execute ${db.name} --file ./schema.sql`,
}, {dependsOn: [db]});

// Worker depends on migrations
const worker = new cloudflare.WorkerScript("worker", {
    d1DatabaseBindings: [{name: "DB", databaseId: db.id}],
}, {dependsOn: [migration]});
```

### 「必須プロパティ 'accountId' がない」

**問題:** `Error: Missing required property 'accountId'`  
**原因:** リソース設定にアカウント ID が指定されていない  
**解決策:** スタック設定に追加する

```yaml
# Pulumi.<stack>.yaml
config:
  cloudflare:accountId: "abc123..."
```

### 「バインディング名が一致しない」

**問題:** Worker が「env.MY_KV is undefined」というエラーで失敗する  
**原因:** Pulumi のバインディング名と Worker コード内の名前が異なる  
**解決策:** 大文字と小文字も含め、完全に一致させる

```typescript
// Pulumi
kvNamespaceBindings: [{name: "MY_KV", namespaceId: kv.id}]

// Worker code
export default { async fetch(request, env) { await env.MY_KV.get("key"); }}
```

### 「API トークンの権限が不足している」

**問題:** `Error: authentication error (10000)`  
**原因:** トークンに必要な権限がない  
**解決策:** トークンに次の権限を付与する: Account.Workers Scripts:Edit, Account.Account Settings:Read

### 「インポート後にリソースが見つからない」

**問題:** インポートしたリソースが、次の `pulumi up` で変更対象として表示される  
**原因:** 実際のリソースと Pulumi 設定の状態が一致していない  
**解決策:** プロパティ名と型が完全に一致しているか確認する

```bash
pulumi import cloudflare:index/workerScript:WorkerScript my-worker <account_id>/<worker_name>
pulumi preview # If shows changes, adjust Pulumi code to match actual resource
```

### 「v6.x Worker のバージョニングが分かりにくい」

**問題:** Worker はデプロイされたが、トラフィックを受信しない  
**原因:** v6.x では Worker、WorkerVersion、WorkersDeployment の 3 つのリソースが必要  
**解決策:** WorkerScript（自動バージョニング）を使うか、完全なバージョニングパターンを使う

```typescript
// SIMPLE: WorkerScript auto-versions (default behavior)
const worker = new cloudflare.WorkerScript("worker", {
    accountId, name: "my-worker", content: code,
});

// ADVANCED: Manual versioning for gradual rollouts (v6.x)
const worker = new cloudflare.Worker("worker", {accountId, name: "my-worker"});
const version = new cloudflare.WorkerVersion("v1", {
    accountId, workerId: worker.id, content: code, compatibilityDate: "2025-01-01",
});
const deployment = new cloudflare.WorkersDeployment("prod", {
    accountId, workerId: worker.id, versionId: version.id,
});
```

## ベストプラクティス

1. **常に compatibilityDate を設定する** — Worker の動作を固定し、破壊的変更を防ぐ
2. **デプロイ前にビルドする** — Pulumi はバンドルしないため、Command リソースまたは CI のビルド手順を使う
3. **バインディング名を一致させる** — 大文字と小文字を区別し、Pulumi と Worker コードで同じ名前にする
4. **マイグレーションには dependsOn を使う** — Worker のデプロイ前に D1 マイグレーションが実行されるようにする
5. **Worker のコンテンツをバージョン管理する** — コンテンツ変更時に再デプロイを強制するため、VERSION バインディングを追加する
6. **シークレットはスタック設定に保存する** — API キーには `pulumi config set --secret` を使う

## 制限事項

| リソース | 上限 | 備考 |
|----------|-------|-------|
| Worker スクリプトのサイズ | 10 MB | 圧縮後、すべての依存関係を含む |
| Worker の CPU 時間 | 50ms（無料）、30s（有料） | リクエストごと |
| 名前空間あたりの KV キー数 | 無制限 | 書き込み 1000 ops/sec、読み取り 100k ops/sec |
| R2 ストレージ | 無制限 | クラス A 操作: 月 100 万回まで無料、クラス B: 月 1,000 万回まで無料 |
| D1 データベース | アカウントあたり 50,000 | 無料プラン: アカウントあたり 10 個、各 5 GB |
| キュー | アカウントあたり 10,000 | 無料プラン: 1 日あたり 100 万操作 |
| Pages プロジェクト | アカウントあたり 500 | 無料プラン: 100 プロジェクト |
| API リクエスト | プランによって異なる | 無料プランでは約 1200 req/5min |

## 参考資料

- **Pulumi Registry:** https://www.pulumi.com/registry/packages/cloudflare/
- **API ドキュメント:** https://www.pulumi.com/registry/packages/cloudflare/api-docs/
- **GitHub:** https://github.com/pulumi/pulumi-cloudflare
- **Cloudflare ドキュメント:** https://developers.cloudflare.com/
- **Workers ドキュメント:** https://developers.cloudflare.com/workers/

---
参照: [README.md](./README.md)、[configuration.md](./configuration.md)、[api.md](./api.md)、[patterns.md](./patterns.md)
