# Workers Playground のパターン

## JSON API

```javascript
export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === '/api/hello') return Response.json({ message: 'Hello' });
    if (url.pathname === '/api/echo' && request.method === 'POST') {
      return Response.json({ received: await request.json() });
    }
    return Response.json({ error: 'Not found' }, { status: 404 });
  }
};
```

## ルーターパターン

```javascript
const routes = {
  '/': () => new Response('Home'),
  '/api/users': () => Response.json([{ id: 1, name: 'Alice' }])
};

export default {
  async fetch(request) {
    const handler = routes[new URL(request.url).pathname];
    return handler ? handler() : new Response('Not Found', { status: 404 });
  }
};
```

## プロキシパターン

```javascript
export default {
  async fetch(request) {
    const url = new URL(request.url);
    url.hostname = 'api.example.com';
    return fetch(url.toString(), {
      method: request.method, headers: request.headers, body: request.body
    });
  }
};
```

## CORS の処理

```javascript
export default {
  async fetch(request) {
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization'
        }
      });
    }
    const response = await fetch('https://api.example.com', request);
    const modified = new Response(response.body, response);
    modified.headers.set('Access-Control-Allow-Origin', '*');
    return modified;
  }
};
```

## キャッシュ

```javascript
export default {
  async fetch(request) {
    if (request.method !== 'GET') return fetch(request);
    const cache = caches.default;
    let response = await cache.match(request);
    if (!response) {
      response = await fetch('https://api.example.com');
      if (response.status === 200) await cache.put(request, response.clone());
    }
    return response;
  }
};
```

## Hono フレームワーク

```javascript
import { Hono } from 'https://esm.sh/hono@3';
const app = new Hono();
app.get('/', (c) => c.text('Hello'));
app.get('/api/users/:id', (c) => c.json({ id: c.req.param('id') }));
app.notFound((c) => c.json({ error: 'Not found' }, 404));
export default app;
```

## 認証

```javascript
export default {
  async fetch(request) {
    const auth = request.headers.get('Authorization');
    if (!auth?.startsWith('Bearer ')) {
      return Response.json({ error: 'Unauthorized' }, { status: 401 });
    }
    const token = auth.substring(7);
    if (token !== 'secret-token') {
      return Response.json({ error: 'Invalid token' }, { status: 403 });
    }
    return Response.json({ message: 'Authenticated' });
  }
};
```

## エラー処理

```javascript
export default {
  async fetch(request) {
    try {
      const response = await fetch('https://api.example.com');
      if (!response.ok) throw new Error(`API returned ${response.status}`);
      return response;
    } catch (error) {
      return Response.json({ error: error.message }, { status: 500 });
    }
  }
};
```

**注:** インメモリの状態（Map や変数）は Worker のコールドスタート時にリセットされます。永続化には Durable Objects または KV を使用してください。
