## よくある問題

### 接続タイムアウト

**問題:** 接続に失敗する、またはタイムアウトする  
**原因:** オリジンのファイアウォールが Cloudflare の IP 範囲をブロックしている、オリジンのサービスが稼働していない、DNS が正しくない  
**解決方法:**
1. オリジンのファイアウォールで Cloudflare の IP 範囲が許可されていることを確認します
2. オリジンのサービスが正しいポートで稼働していることを確認します
3. DNS レコードが CNAME（A/AAAA ではない）であることを確認します
4. オリジンの IP/ホスト名が正しいことを確認します

```bash
# Test connectivity
nc -zv app.example.com 22
dig app.example.com
```

### クライアント IP が Cloudflare の IP として表示される

**問題:** オリジンのログに実際のクライアント IP ではなく Cloudflare の IP が表示される  
**原因:** Proxy Protocol が有効になっていないか、オリジンが設定されていない  
**解決方法:**
```typescript
// Enable in Spectrum app
const app = await client.spectrum.apps.create({
  // ...
  proxy_protocol: 'v1',  // TCP: v1/v2; UDP: simple
});
```

**オリジンの設定:**
- **nginx**: `listen 22 proxy_protocol;`
- **HAProxy**: `bind :22 accept-proxy`

### TLS エラー

**問題:** TLS ハンドシェイクの失敗、525 エラー  
**原因:** TLS モードの不一致

| エラー | TLS モード | 問題 | 解決方法 |
|-------|----------|---------|----------|
| 接続拒否 | `full`/`strict` | オリジンが TLS に対応していない | `tls: "off"` を使用するか、TLS を有効にします |
| 525 証明書が無効 | `strict` | 自己署名証明書 | `tls: "full"` を使用するか、有効な証明書を設定します |
| ハンドシェイクのタイムアウト | `flexible` | オリジンが TLS を要求している | `tls: "full"` を使用します |

**デバッグ:**
```bash
openssl s_client -connect app.example.com:443 -showcerts
```

### SMTP の逆引き DNS

**問題:** メールサーバーが Spectrum 経由の SMTP を拒否する  
**原因:** Spectrum の IP に PTR（逆引き DNS）レコードがない  
**影響:** 多くのメールサーバーはスパム対策のため、有効な rDNS を要求します

**解決方法:**
- 送信 SMTP: Spectrum 経由は推奨されません
- 受信 SMTP: Cloudflare Email Routing を使用します
- 内部リレー: 宛先側で Spectrum の IP を許可リストに登録します

### Proxy Protocol の互換性

**問題:** 接続はできるが、アプリの動作が正しくない  
**原因:** オリジンが Proxy Protocol に対応していない

**解決方法:**
1. オリジンが該当バージョンに対応していることを確認します（v1: 広く対応、v2: HAProxy 1.5 以降/nginx 1.11 以降）
2. まず `proxy_protocol: 'off'` でテストします
3. ヘッダーを解析するようオリジンを設定します

**nginx TCP:**
```nginx
stream {
    server {
        listen 22 proxy_protocol;
        proxy_pass backend:22;
    }
}
```

**HAProxy:**
```
frontend ft_ssh
    bind :22 accept-proxy
```

### アナリティクスデータの保持期間

**問題:** 過去のデータを利用できない  
**原因:** 保持期間はプランによって異なる

| プラン | リアルタイム | 履歴データ |
|------|-----------|------------|
| Pro | 直近 1 時間 | ❌ |
| Business | 直近 1 時間 | 限定的 |
| Enterprise | 直近 1 時間 | 90 日以上 |

**解決方法:** 保持期間内にクエリを実行するか、外部システムにエクスポートします

### Enterprise 専用機能

**問題:** 機能を利用できない、またはエラーが発生する  
**原因:** Enterprise プランが必要

**Enterprise 専用:**
- ポート範囲（`tcp/25565-25575`）
- すべての TCP/UDP ポート（Pro/Business では選択されたポートのみ）
- アナリティクスデータの延長保持
- 高度なロードバランシング

### IPv6 に関する考慮事項

**問題:** IPv6 クライアントが接続できない、またはオリジンが IPv6 に対応していない  
**解決方法:** `edge_ips.connectivity` を設定します

```typescript
const app = await client.spectrum.apps.create({
  // ...
  edge_ips: {
    type: 'dynamic',
    connectivity: 'ipv4',  // Options: 'all', 'ipv4', 'ipv6'
  },
});
```

**オプション:**
- `all`: デュアルスタック（デフォルト。オリジンが IPv4 と IPv6 の両方に対応している必要があります）
- `ipv4`: IPv4 のみ（オリジンが IPv6 に対応していない場合に使用）
- `ipv6`: IPv6 のみ（まれなケース）

## 制限

| リソース | Pro/Business | Enterprise |
|----------|--------------|------------|
| アプリの最大数 | 約 10～15 | 100 以上 |
| プロトコル | 選択制 | すべての TCP/UDP |
| ポート範囲 | ❌ | ✅ |
| アナリティクス | 約 1 時間 | 90 日以上 |

## 関連項目

- [patterns.md](patterns.md) - プロトコルの例
- [configuration.md](configuration.md) - TLS/Proxy の設定