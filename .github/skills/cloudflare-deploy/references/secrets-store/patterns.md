# パターン

## シークレットのローテーション

バージョン付きの名前（`api_key_v1`、`api_key_v2`）を使ったダウンタイムなしのローテーション:

```typescript
interface Env {
  PRIMARY_KEY: { get(): Promise<string> };
  FALLBACK_KEY?: { get(): Promise<string> };
}

async function fetchWithAuth(url: string, key: string) {
  return fetch(url, { headers: { "Authorization": `Bearer ${key}` } });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    let resp = await fetchWithAuth("https://api.example.com", await env.PRIMARY_KEY.get());
    
    // Fallback during rotation
    if (!resp.ok && env.FALLBACK_KEY) {
      resp = await fetchWithAuth("https://api.example.com", await env.FALLBACK_KEY.get());
    }
    
    return resp;
  }
}
```

手順: `api_key_v2` を作成 → フォールバックバインディングを追加 → デプロイ → プライマリを切り替え → デプロイ → `v1` を削除

## KV による暗号化

```typescript
interface Env {
  CACHE: KVNamespace;
  ENCRYPTION_KEY: { get(): Promise<string> };
}

async function encryptValue(value: string, key: string): Promise<string> {
  const enc = new TextEncoder();
  const keyMaterial = await crypto.subtle.importKey(
    "raw", enc.encode(key), { name: "AES-GCM" }, false, ["encrypt"]
  );
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv }, keyMaterial, enc.encode(value)
  );
  
  const combined = new Uint8Array(iv.length + encrypted.byteLength);
  combined.set(iv);
  combined.set(new Uint8Array(encrypted), iv.length);
  return btoa(String.fromCharCode(...combined));
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const key = await env.ENCRYPTION_KEY.get();
    const encrypted = await encryptValue("sensitive-data", key);
    await env.CACHE.put("user:123:data", encrypted);
    return Response.json({ ok: true });
  }
}
```

## HMAC 署名

```typescript
interface Env {
  HMAC_SECRET: { get(): Promise<string> };
}

async function signRequest(data: string, secret: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(data));
  return btoa(String.fromCharCode(...new Uint8Array(sig)));
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const secret = await env.HMAC_SECRET.get();
    const payload = await request.text();
    const signature = await signRequest(payload, secret);
    return Response.json({ signature });
  }
}
```

## 監査とモニタリング

```typescript
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext) {
    const startTime = Date.now();
    try {
      const apiKey = await env.API_KEY.get();
      const resp = await fetch("https://api.example.com", {
        headers: { "Authorization": `Bearer ${apiKey}` }
      });
      
      ctx.waitUntil(
        fetch("https://log.example.com/log", {
          method: "POST",
          body: JSON.stringify({
            event: "secret_used",
            secret_name: "API_KEY",
            timestamp: new Date().toISOString(),
            duration_ms: Date.now() - startTime,
            success: resp.ok
          })
        })
      );
      return resp;
    } catch (error) {
      ctx.waitUntil(
        fetch("https://log.example.com/log", {
          method: "POST",
          body: JSON.stringify({
            event: "secret_access_failed",
            secret_name: "API_KEY",
            error: error instanceof Error ? error.message : "Unknown"
          })
        })
      );
      return new Response("Error", { status: 500 });
    }
  }
}
```

## Worker Secrets からの移行

`env.SECRET`（同期）を `await env.SECRET.get()`（非同期）に変更する。

手順:
1. Secrets Store に作成する: `wrangler secrets-store secret create <store-id> --name API_KEY --scopes workers --remote`
2. `wrangler.jsonc` にバインディングを追加する: `{"binding": "API_KEY", "store_id": "abc123", "secret_name": "api_key"}`
3. コードを更新する: `const key = await env.API_KEY.get();`
4. ステージング環境でテストしてデプロイする
5. 古いものを削除する: `wrangler secret delete API_KEY`

## Worker 間での共有

同じシークレットに異なるバインディング名を使う:

```jsonc
// worker-1: binding="SHARED_DB", secret_name="postgres_url"
// worker-2: binding="DB_CONN", secret_name="postgres_url"
```

## JSON シークレットの解析

構造化された設定を JSON シークレットとして保存する:

```typescript
interface Env {
  DB_CONFIG: { get(): Promise<string> };
}

interface DbConfig {
  host: string;
  port: number;
  username: string;
  password: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      const configStr = await env.DB_CONFIG.get();
      const config: DbConfig = JSON.parse(configStr);
      
      // Use parsed config
      const dbUrl = `postgres://${config.username}:${config.password}@${config.host}:${config.port}`;
      
      return Response.json({ connected: true });
    } catch (error) {
      if (error instanceof SyntaxError) {
        return new Response("Invalid config JSON", { status: 500 });
      }
      throw error;
    }
  }
}
```

JSON シークレットを保存する:

```bash
echo '{"host":"db.example.com","port":5432,"username":"app","password":"secret"}' | \
  wrangler secrets-store secret create <store-id> \
    --name DB_CONFIG --scopes workers --remote
```

## 統合

### Service Bindings

Auth Worker が Secrets Store を使って JWT に署名し、API Worker が Service Binding 経由で検証する。

Service Binding のパターンについては [workers](../workers/) を参照。

[api.md](./api.md)、[gotchas.md](./gotchas.md) を参照。
