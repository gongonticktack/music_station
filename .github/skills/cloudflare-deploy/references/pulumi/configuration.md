# リソースの設定

## Workers（cloudflare.WorkerScript）

```typescript
import * as cloudflare from "@pulumi/cloudflare";
import * as fs from "fs";

const worker = new cloudflare.WorkerScript("my-worker", {
    accountId: accountId,
    name: "my-worker",
    content: fs.readFileSync("./dist/worker.js", "utf8"),
    module: true, // ES modules
    compatibilityDate: "2025-01-01",
    compatibilityFlags: ["nodejs_compat"],
    
    // v6.x: Observability
    logpush: true, // Enable Workers Logpush
    tailConsumers: [{service: "log-consumer"}], // Stream logs to Worker
    
    // v6.x: Placement
    placement: {mode: "smart"}, // Smart placement for latency optimization
    
    // Bindings
    kvNamespaceBindings: [{name: "MY_KV", namespaceId: kv.id}],
    r2BucketBindings: [{name: "MY_BUCKET", bucketName: bucket.name}],
    d1DatabaseBindings: [{name: "DB", databaseId: db.id}],
    queueBindings: [{name: "MY_QUEUE", queue: queue.id}],
    serviceBindings: [{name: "OTHER_SERVICE", service: other.name}],
    plainTextBindings: [{name: "ENV_VAR", text: "value"}],
    secretTextBindings: [{name: "API_KEY", text: secret}],
    
    // v6.x: Advanced bindings
    analyticsEngineBindings: [{name: "ANALYTICS", dataset: "my-dataset"}],
    browserBinding: {name: "BROWSER"}, // Browser Rendering
    aiBinding: {name: "AI"}, // Workers AI
    hyperdriveBindings: [{name: "HYPERDRIVE", id: hyperdriveConfig.id}],
});
```

## Workers KV（cloudflare.WorkersKvNamespace）

```typescript
const kv = new cloudflare.WorkersKvNamespace("my-kv", {
    accountId: accountId,
    title: "my-kv-namespace",
});

// Write values
const kvValue = new cloudflare.WorkersKvValue("config", {
    accountId: accountId,
    namespaceId: kv.id,
    key: "config",
    value: JSON.stringify({foo: "bar"}),
});
```

## R2 バケット（cloudflare.R2Bucket）

```typescript
const bucket = new cloudflare.R2Bucket("my-bucket", {
    accountId: accountId,
    name: "my-bucket",
    location: "auto", // or "wnam", etc.
});
```

## D1 データベース（cloudflare.D1Database）

```typescript
const db = new cloudflare.D1Database("my-db", {accountId, name: "my-database"});

// Migrations via wrangler
import * as command from "@pulumi/command";
const migration = new command.local.Command("d1-migration", {
    create: pulumi.interpolate`wrangler d1 execute ${db.name} --file ./schema.sql`,
}, {dependsOn: [db]});
```

## キュー（cloudflare.Queue）

```typescript
const queue = new cloudflare.Queue("my-queue", {accountId, name: "my-queue"});

// Producer
const producer = new cloudflare.WorkerScript("producer", {
    accountId, name: "producer", content: code,
    queueBindings: [{name: "MY_QUEUE", queue: queue.id}],
});

// Consumer
const consumer = new cloudflare.WorkerScript("consumer", {
    accountId, name: "consumer", content: code,
    queueConsumers: [{queue: queue.name, maxBatchSize: 10, maxRetries: 3}],
});
```

## Pages プロジェクト（cloudflare.PagesProject）

```typescript
const pages = new cloudflare.PagesProject("my-site", {
    accountId, name: "my-site", productionBranch: "main",
    buildConfig: {buildCommand: "npm run build", destinationDir: "dist"},
    source: {
        type: "github",
        config: {owner: "my-org", repoName: "my-repo", productionBranch: "main"},
    },
    deploymentConfigs: {
        production: {
            environmentVariables: {NODE_VERSION: "18"},
            kvNamespaces: {MY_KV: kv.id},
            d1Databases: {DB: db.id},
        },
    },
});
```

## DNS レコード（cloudflare.DnsRecord）

```typescript
const zone = cloudflare.getZone({name: "example.com"});
const record = new cloudflare.DnsRecord("www", {
    zoneId: zone.then(z => z.id), name: "www", type: "A",
    content: "192.0.2.1", ttl: 3600, proxied: true,
});
```

## Workers のドメイン／ルート

```typescript
// Route (pattern-based)
const route = new cloudflare.WorkerRoute("my-route", {
    zoneId: zoneId,
    pattern: "example.com/api/*",
    scriptName: worker.name,
});

// Domain (dedicated subdomain)
const domain = new cloudflare.WorkersDomain("my-domain", {
    accountId: accountId,
    hostname: "api.example.com",
    service: worker.name,
    zoneId: zoneId,
});
```

## アセットの設定（v6.x）

Workers から静的アセットを配信します。

```typescript
const worker = new cloudflare.WorkerScript("app", {
    accountId: accountId,
    name: "my-app",
    content: code,
    assets: {
        path: "./public", // Local directory
        // Assets uploaded and served from Workers
    },
});
```

## v6.x のバージョン管理されたデプロイ（高度な設定）

段階的なロールアウトには、3 リソースのパターンを使用します。

```typescript
// 1. Worker (container for versions)
const worker = new cloudflare.Worker("api", {
    accountId: accountId,
    name: "api-worker",
});

// 2. Version (immutable code + config)
const version = new cloudflare.WorkerVersion("v1", {
    accountId: accountId,
    workerId: worker.id,
    content: fs.readFileSync("./dist/worker.js", "utf8"),
    compatibilityDate: "2025-01-01",
    compatibilityFlags: ["nodejs_compat"],
    // Note: Bindings configured at deployment level
});

// 3. Deployment (version + bindings + traffic split)
const deployment = new cloudflare.WorkersDeployment("prod", {
    accountId: accountId,
    workerId: worker.id,
    versionId: version.id,
    // Bindings applied to deployment
    kvNamespaceBindings: [{name: "MY_KV", namespaceId: kv.id}],
});
```

**使用する場面:** ブルーグリーンデプロイ、カナリアリリース、段階的なロールアウト  
**使用しない場面:** 単一バージョンのシンプルなデプロイ（WorkerScript を使用）

---
参照: [README.md](./README.md)、[api.md](./api.md)、[patterns.md](./patterns.md)、[gotchas.md](./gotchas.md)