# APIとデータソース

## 出力とエクスポート

リソース識別子をエクスポートします:

```typescript
export const kvId = kv.id;
export const bucketName = bucket.name;
export const workerUrl = worker.subdomain;
export const dbId = db.id;
```

## リソースの依存関係

出力による暗黙的な依存関係:

```typescript
const kv = new cloudflare.WorkersKvNamespace("kv", {
    accountId: accountId,
    title: "my-kv",
});

// Worker depends on KV (implicit via kv.id)
const worker = new cloudflare.WorkerScript("worker", {
    accountId: accountId,
    name: "my-worker",
    content: code,
    kvNamespaceBindings: [{name: "MY_KV", namespaceId: kv.id}], // Creates dependency
});
```

明示的な依存関係:

```typescript
const migration = new command.local.Command("migration", {
    create: pulumi.interpolate`wrangler d1 execute ${db.name} --file ./schema.sql`,
}, {dependsOn: [db]});

const worker = new cloudflare.WorkerScript("worker", {
    accountId: accountId,
    name: "worker",
    content: code,
    d1DatabaseBindings: [{name: "DB", databaseId: db.id}],
}, {dependsOn: [migration]}); // Ensure migrations run first
```

## API呼び出しでの出力の使用

```typescript
const db = new cloudflare.D1Database("db", {accountId, name: "my-db"});

db.id.apply(async (dbId) => {
    const response = await fetch(
        `https://api.cloudflare.com/client/v4/accounts/${accountId}/d1/database/${dbId}/query`,
        {method: "POST", headers: {"Authorization": `Bearer ${apiToken}`, "Content-Type": "application/json"},
         body: JSON.stringify({sql: "CREATE TABLE users (id INT)"})}
    );
    return response.json();
});
```

## カスタム動的プロバイダー

プロバイダーに含まれていないリソース向け:

```typescript
import * as pulumi from "@pulumi/pulumi";

class D1MigrationProvider implements pulumi.dynamic.ResourceProvider {
    async create(inputs: any): Promise<pulumi.dynamic.CreateResult> {
        const response = await fetch(
            `https://api.cloudflare.com/client/v4/accounts/${inputs.accountId}/d1/database/${inputs.databaseId}/query`,
            {method: "POST", headers: {"Authorization": `Bearer ${inputs.apiToken}`, "Content-Type": "application/json"},
             body: JSON.stringify({sql: inputs.sql})}
        );
        return {id: `${inputs.databaseId}-${Date.now()}`, outs: await response.json()};
    }
    async update(id: string, olds: any, news: any): Promise<pulumi.dynamic.UpdateResult> {
        if (olds.sql !== news.sql) await this.create(news);
        return {};
    }
    async delete(id: string, props: any): Promise<void> {}
}

class D1Migration extends pulumi.dynamic.Resource {
    constructor(name: string, args: any, opts?: pulumi.CustomResourceOptions) {
        super(new D1MigrationProvider(), name, args, opts);
    }
}

const migration = new D1Migration("migration", {
    accountId, databaseId: db.id, apiToken, sql: "CREATE TABLE users (id INT)",
}, {dependsOn: [db]});
```

## データソース

**ゾーンを取得:**
```typescript
const zone = cloudflare.getZone({name: "example.com"});
const zoneId = zone.then(z => z.id);
```

**アカウントを取得（API経由）:**
Cloudflare APIを直接使用するか、カスタム動的リソースを使用してください。

## 既存リソースのインポート

```bash
# Import worker
pulumi import cloudflare:index/workerScript:WorkerScript my-worker <account_id>/<worker_name>

# Import KV namespace
pulumi import cloudflare:index/workersKvNamespace:WorkersKvNamespace my-kv <namespace_id>

# Import R2 bucket
pulumi import cloudflare:index/r2Bucket:R2Bucket my-bucket <account_id>/<bucket_name>

# Import D1 database
pulumi import cloudflare:index/d1Database:D1Database my-db <account_id>/<database_id>

# Import DNS record
pulumi import cloudflare:index/dnsRecord:DnsRecord my-record <zone_id>/<record_id>
```

## シークレット管理

```typescript
import * as pulumi from "@pulumi/pulumi";

const config = new pulumi.Config();
const apiKey = config.requireSecret("apiKey"); // Encrypted in state

const worker = new cloudflare.WorkerScript("worker", {
    accountId: accountId,
    name: "my-worker",
    content: code,
    secretTextBindings: [{name: "API_KEY", text: apiKey}],
});
```

シークレットを保存します:
```bash
pulumi config set --secret apiKey "secret-value"
```

## 変換パターン

作成前にリソース引数を変更します:

```typescript
import {Transform} from "@pulumi/pulumi";

interface BucketArgs {
    accountId: pulumi.Input<string>;
    transform?: {bucket?: Transform<cloudflare.R2BucketArgs>};
}

function createBucket(name: string, args: BucketArgs) {
    const bucketArgs: cloudflare.R2BucketArgs = {
        accountId: args.accountId,
        name: name,
        location: "auto",
    };
    const finalArgs = args.transform?.bucket?.(bucketArgs) ?? bucketArgs;
    return new cloudflare.R2Bucket(name, finalArgs);
}
```

## v6.xのWorkerバージョニングリソース

**Worker** - バージョンを格納するコンテナ:
```typescript
const worker = new cloudflare.Worker("api", {accountId, name: "api-worker"});
export const workerId = worker.id;
```

**WorkerVersion** - 不変のコードと設定:
```typescript
const version = new cloudflare.WorkerVersion("v1", {
    accountId, workerId: worker.id,
    content: fs.readFileSync("./dist/worker.js", "utf8"),
    compatibilityDate: "2025-01-01",
});
export const versionId = version.id;
```

**WorkersDeployment** - バインディングを含むアクティブなデプロイ:
```typescript
const deployment = new cloudflare.WorkersDeployment("prod", {
    accountId, workerId: worker.id, versionId: version.id,
    kvNamespaceBindings: [{name: "MY_KV", namespaceId: kv.id}],
});
```

**用途:** 高度なデプロイ（カナリア、ブルーグリーン）。ほとんどのアプリでは`WorkerScript`（自動バージョニング）を使用してください。

---
参照: [README.md](./README.md)、[configuration.md](./configuration.md)、[patterns.md](./patterns.md)、[gotchas.md](./gotchas.md)
