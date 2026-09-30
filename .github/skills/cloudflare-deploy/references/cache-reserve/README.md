# Cloudflare Cache Reserve

**R2 を基盤とする、コンテンツを長期間保持するための永続キャッシュストレージ**

## Smart Shield との統合

Cache Reserve は **Smart Shield** の一部であり、Cloudflare の包括的なセキュリティおよびパフォーマンススイートに含まれます。

- **Smart Shield Advanced ティア**: 2TB の Cache Reserve ストレージを含む
- **単体での購入**: Smart Shield を利用しない場合は別途購入可能
- **移行**: 既存の単体プラン利用者は Smart Shield バンドルに移行可能

**判断の目安**: すでに Smart Shield Advanced を利用していますか？ Cache Reserve が含まれています。それ以外の場合は、単体購入と Smart Shield へのアップグレードを比較検討してください。

## 概要

Cache Reserve は、R2 を基盤とする Cloudflare の大規模な永続キャッシュストレージ層です。最上位の上位ティアキャッシュとして機能し、キャッシュ可能なコンテンツを長期間（30 日以上）保存して、キャッシュヒットを最大化し、オリジンのエグレス料金を抑え、アクセス頻度の低いコンテンツへの繰り返しリクエストからオリジンを保護します。

## 基本概念

### Cache Reserve とは？

- **永続ストレージ層**: R2 を基盤とし、階層型キャッシュの上位に配置
- **長期保持**: デフォルトの保持期間は 30 日で、アクセスのたびに延長
- **自動動作**: 既存の CDN とシームレスに連携し、コード変更は不要
- **オリジンの保護**: キャッシュ済みコンテンツをより長期間配信し、オリジンのエグレスを大幅に削減
- **使用量に応じた料金**: ストレージと読み書き操作の料金のみを支払う

### キャッシュ階層

```
Visitor Request
    ↓
Lower-Tier Cache (closest to visitor)
    ↓ (on miss)
Upper-Tier Cache (closest to origin)
    ↓ (on miss)
Cache Reserve (R2 persistent storage)
    ↓ (on miss)
Origin Server
```

### 動作の仕組み

1. **キャッシュミス時**: コンテンツをオリジンから取得し、Cache Reserve とエッジキャッシュに同時に書き込みます
2. **エッジからの削除時**: コンテンツがエッジキャッシュから削除されても、Cache Reserve には残ることがあります
3. **次回のリクエスト時**: エッジキャッシュがミスし、Cache Reserve がヒットすると、コンテンツがエッジキャッシュに復元されます
4. **保持期間**: アセットは最後のアクセスから 30 日間 Cache Reserve に保持されます（TTL で設定可能）

## Cache Reserve を使う場面

```
Need persistent caching?
├─ High origin egress costs → Cache Reserve ✓
├─ Long-tail content (archives, media libraries) → Cache Reserve ✓
├─ Already using Smart Shield Advanced → Included! ✓
├─ Video streaming with seeking (range requests) → ✗ Not supported
├─ Dynamic/personalized content → ✗ Use edge cache only
├─ Need per-request cache control from Workers → ✗ Use R2 directly
└─ Frequently updated content (< 10hr lifetime) → ✗ Not eligible
```

## アセットの対象条件

Cache Reserve に保存されるのは、**すべて**の条件を満たすアセットのみです。

- Cloudflare の標準ルールに従ってキャッシュ可能である
- TTL が 10 時間（36000 秒）以上である
- `Content-Length` ヘッダーが存在する
- オリジナルファイルである（変換済み画像ではない）

### 対象条件のチェックリスト

このチェックリストを使って、アセットが対象になるか確認してください。

- [ ] ゾーンで Cache Reserve が有効になっている
- [ ] ゾーンで Tiered Cache が有効になっている（必須）
- [ ] アセットの TTL が 10 時間（36,000 秒）以上である
- [ ] オリジンのレスポンスに `Content-Length` ヘッダーがある
- [ ] `Set-Cookie` ヘッダーがない（または private ディレクティブを使用している）
- [ ] `Vary` ヘッダーが `*` ではない（`Accept-Encoding` は使用可能）
- [ ] 画像変換バリアントではない（オリジナル画像は対象）
- [ ] 範囲リクエストではない（HTTP 206 は非対応）
- [ ] O2O（Orange-to-Orange）プロキシリクエストではない

**Cache Reserve の対象となるには、すべての項目にチェックが入っている必要があります。**

### 対象外

- TTL が 10 時間未満のアセット
- `Content-Length` ヘッダーのないレスポンス
- 画像変換バリアント（オリジナル画像は対象）
- `Set-Cookie` ヘッダーを含むレスポンス
- `Vary: *` ヘッダーを含むレスポンス
- 同じゾーン上の R2 パブリックバケットにあるアセット
- O2O（Orange-to-Orange）セットアップリクエスト
- **範囲リクエスト**（動画のシーク、部分コンテンツのダウンロード）

## クイックスタート

```bash
# Enable via Dashboard
https://dash.cloudflare.com/caching/cache-reserve
# Click "Enable Storage Sync" or "Purchase" button
```

**前提条件:**
- 有料の Cache Reserve プランまたは Smart Shield Advanced が必要
- 最適なパフォーマンスには Tiered Cache が必要

## 基本コマンド

```bash
# Check Cache Reserve status
curl -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/cache/cache_reserve" \
  -H "Authorization: Bearer $API_TOKEN"

# Enable Cache Reserve
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/cache/cache_reserve" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"value": "on"}'

# Check asset cache status
curl -I https://example.com/asset.jpg | grep -i cache
```

## このリファレンスの内容

| 作業 | ファイル |
|------|-------|
| Cache Reserve がユースケースに適しているか評価する | README.md（このファイル） |
| ゾーンで Cache Reserve を有効にする | README.md + [configuration.md](./configuration.md) |
| Workers と併用する（制限を把握する） | [api.md](./api.md) |
| SDK または IaC（TypeScript、Python、Terraform）でセットアップする | [configuration.md](./configuration.md) |
| コストを最適化し、問題をデバッグする | [patterns.md](./patterns.md) + [gotchas.md](./gotchas.md) |
| 対象条件を理解し、トラブルシューティングを行う | [gotchas.md](./gotchas.md) → [patterns.md](./patterns.md) |

**ファイル:**
- [configuration.md](./configuration.md) - セットアップ、API、SDK、Cache Rules
- [api.md](./api.md) - パージ、監視、Workers との統合
- [patterns.md](./patterns.md) - ベストプラクティス、コスト最適化、デバッグ
- [gotchas.md](./gotchas.md) - よくある問題、制限、トラブルシューティング

## 関連項目
- [r2](../r2/) - R2 ストレージを基盤とする Cache Reserve
- [workers](../workers/) - Cache API を使った Workers との統合
