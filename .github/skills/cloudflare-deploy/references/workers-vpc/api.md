# TCP ソケット API リファレンス

Cloudflare Workers TCP Sockets API（`cloudflare:sockets`）の完全な API リファレンスです。

## コア関数: `connect()`

```typescript
function connect(
  address: SocketAddress,
  options?: SocketOptions
): Socket
```

指定したアドレスへのアウトバウンド TCP 接続を作成します。

### パラメーター

#### `SocketAddress`

```typescript
interface SocketAddress {
  hostname: string; // DNS hostname or IP address
  port: number;     // TCP port (1-65535, excluding blocked ports)
}
```

| フィールド | 型 | 説明 | 例 |
|-------|------|-------------|---------|
| `hostname` | `string` | 接続先のホスト名または IP アドレス | `"db.internal.net"`、`"10.0.1.50"` |
| `port` | `number` | TCP ポート番号 | `5432`、`443`、`22` |

DNS 名は接続時に解決されます。IPv4、IPv6、プライベート IP（10.x、172.16.x、192.168.x）に対応しています。

#### `SocketOptions`

```typescript
interface SocketOptions {
  secureTransport?: "off" | "on" | "starttls";
  allowHalfOpen?: boolean;
}
```

| フィールド | 型 | 既定値 | 説明 |
|-------|------|---------|-------------|
| `secureTransport` | `"off" \| "on" \| "starttls"` | `"off"` | TLS モード |
| `allowHalfOpen` | `boolean` | `false` | 半閉鎖接続を許可 |

**`secureTransport` のモード:**

| モード | 動作 | 用途 |
|------|----------|----------|
| `"off"` | 暗号化なしの通常の TCP | テスト、信頼できる内部ネットワーク |
| `"on"` | TLS ハンドシェイクを直ちに実行 | HTTPS、安全なデータベース、SSH |
| `"starttls"` | 通常の接続を開始し、`startTls()` で後からアップグレード | Postgres、SMTP、IMAP |

**`allowHalfOpen`:** `false`（既定値）の場合、読み取りストリームを閉じると書き込みストリームも自動的に閉じます。`true` の場合、各ストリームは独立します。

### 戻り値

読み取り／書き込みストリームを持つ `Socket` オブジェクトです。

## ソケットインターフェース

```typescript
interface Socket {
  // Streams
  readable: ReadableStream<Uint8Array>;
  writable: WritableStream<Uint8Array>;
  
  // Connection state
  opened: Promise<SocketInfo>;
  closed: Promise<void>;
  
  // Methods
  close(): Promise<void>;
  startTls(): Socket;
}
```

### プロパティ

#### `readable: ReadableStream<Uint8Array>`

ソケットからデータを読み取るストリームです。データを読み込むには `getReader()` を使用します。

```typescript
const reader = socket.readable.getReader();
const { done, value } = await reader.read(); // Read one chunk
```

#### `writable: WritableStream<Uint8Array>`

ソケットにデータを書き込むストリームです。データを送信するには `getWriter()` を使用します。

```typescript
const writer = socket.writable.getWriter();
await writer.write(new TextEncoder().encode("HELLO\r\n"));
await writer.close();
```

#### `opened: Promise<SocketInfo>`

接続に成功すると解決し、失敗すると拒否される Promise です。

```typescript
interface SocketInfo {
  remoteAddress?: string; // May be undefined
  localAddress?: string;  // May be undefined
}

try {
  const info = await socket.opened;
} catch (error) {
  // Connection failed
}
```

#### `closed: Promise<void>`

ソケットが完全に閉じられたとき（両方向）の解決する Promise です。

### メソッド

#### `close(): Promise<void>`

保留中の書き込みの完了を待ってから、ソケットを正常に閉じます。

```typescript
const socket = connect({ hostname: "api.internal", port: 443 });
try {
  // Use socket
} finally {
  await socket.close(); // Always call in finally block
}
```

#### `startTls(): Socket`

接続を TLS にアップグレードします。`secureTransport: "starttls"` が指定されている場合にのみ使用できます。

```typescript
const socket = connect(
  { hostname: "db.internal", port: 5432 },
  { secureTransport: "starttls" }
);

// Send protocol-specific StartTLS command
const writer = socket.writable.getWriter();
await writer.write(new TextEncoder().encode("STARTTLS\r\n"));

// Upgrade to TLS - use returned socket, not original
const secureSocket = socket.startTls();
const secureWriter = secureSocket.writable.getWriter();
```

## 完全な例

```typescript
import { connect } from 'cloudflare:sockets';

export default {
  async fetch(req: Request): Promise<Response> {
    const socket = connect({ hostname: "echo.example.com", port: 7 }, { secureTransport: "on" });

    try {
      await socket.opened;
      
      const writer = socket.writable.getWriter();
      await writer.write(new TextEncoder().encode("Hello, TCP!\n"));
      await writer.close();

      const reader = socket.readable.getReader();
      const { value } = await reader.read();
      
      return new Response(value);
    } finally {
      await socket.close();
    }
  }
};
```

複数チャンクの読み取り、エラー処理、プロトコルの実装については [patterns.md](./patterns.md) を参照してください。

## クイックリファレンス

| タスク | コード |
|------|------|
| インポート | `import { connect } from 'cloudflare:sockets';` |
| 接続 | `connect({ hostname: "host", port: 443 })` |
| TLS を使用 | `connect(addr, { secureTransport: "on" })` |
| StartTLS | ハンドシェイク後に `socket.startTls()` |
| 書き込み | `await writer.write(data); await writer.close();` |
| 読み取り | `const { value } = await reader.read();` |
| エラー処理 | `try { await socket.opened; } catch { }` |
| 必ず閉じる | `try { } finally { await socket.close(); }` |

## 関連項目

- [patterns.md](./patterns.md) - 実際のプロトコル実装
- [configuration.md](./configuration.md) - Wrangler のセットアップと環境変数
- [gotchas.md](./gotchas.md) - 制限とエラー処理
