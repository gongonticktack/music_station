# Cache Reserve の注意点

## よくあるエラー

### 「Cache Reserve にアセットがキャッシュされない」

**原因:** アセットがキャッシュ対象外、TTL が 10 時間未満、Content-Length ヘッダーがない、またはキャッシュを妨げるヘッダー（Set-Cookie、Vary: *）が存在する  
**解決策:** TTL を 10 時間以上に設定し（`Cache-Control: public, max-age=36000`）、Content-Length ヘッダーを追加し、Set-Cookie ヘッダーを削除して、`Vary: Accept-Encoding`（* ではない）を設定します。

### 「Range リクエストが機能しない」（動画のシークに失敗する）

**原因:** Cache Reserve は Range リクエスト（HTTP 206 Partial Content）を**サポートしていません**。  
**解決策:** Range リクエストは Cache Reserve を完全に迂回します。シーク可能な動画をストリーミングする場合:
- エッジキャッシュのみを使用する（TTL は短くなります）
- Range リクエストの多いワークロードには、直接アクセスできる R2 の利用を検討する
- シーク可能なコンテンツは Cache Reserve の永続化によるメリットを得られないことを受け入れる

### 「オリジンの帯域幅が予想より多い」

**原因:** Cache Reserve は、訪問者には圧縮して配信する場合でも、オリジンからは**非圧縮**のコンテンツを取得します。  
**解決策:** 
- オリジンの帯域幅に応じた料金が発生する場合は、非圧縮データ転送のコストを考慮する
- Cache Reserve は訪問者向けに自動で圧縮する（訪問者の帯域幅を節約できます）
- オリジンの送信量削減と、非圧縮での取得コスト増加を比較する

### 「Cloudflare Images が Cache Reserve でキャッシュされない」

**原因:** `Vary: Accept` ヘッダーによるフォーマットネゴシエーションを使用する Cloudflare Images は、Cache Reserve と互換性がありません。  
**解決策:** 
- Cache Reserve は、フォーマットネゴシエーション用に Vary が設定された画像を警告なしにスキップします
- オリジナル画像（変換されていないもの）は、引き続き対象となる場合があります
- 変換済み画像には Cloudflare Images のバリアントまたはエッジキャッシュを使用します

### 「Class A 操作のコストが高い」

**原因:** キャッシュミスが頻発する、TTL が短い、または再検証が頻繁に行われる  
**解決策:** 安定したコンテンツの TTL を長くし（24 時間以上）、Tiered Cache を有効にして Cache Reserve への直接的なミスを減らすか、stale-while-revalidate を使用します。

### 「パージが期待どおりに機能しない」

**原因:** タグによるパージは再検証を開始するだけで、Cache Reserve のストレージからは削除されません。  
**解決策:** すぐに削除するには URL によるパージを使用します。完全に削除するには、Cache Reserve を無効にしてからすべてのデータを消去します。

### 「O2O（Orange-to-Orange）アセットがキャッシュされない」

**原因:** Orange-to-Orange（Cloudflare 上でプロキシされたゾーンが、別のプロキシされたゾーンにリクエストすること）は Cache Reserve を迂回します。  
**解決策:** 
- **O2O とは**: ゾーン A（プロキシ）→ ゾーン B（プロキシ）。どちらも Cloudflare 上にあります。
- **検出方法**: `cf-cache-status` が `BYPASS` になっていないか確認し、リクエスト経路を調べます
- **回避策**: O2O のプロキシチェーンの代わりに R2 またはオリジンへの直接アクセスを使用します

### 「データを消去する前に Cache Reserve をオフにする必要がある」

**原因:** Cache Reserve が有効なまま、Cache Reserve のデータを消去しようとしている  
**解決策:** まず Cache Reserve を無効にし、伝播を待ってから（5 秒）、データを消去します（完了まで最大 24 時間かかることがあります）。

## 制限事項

| 制限 | 値 | 備考 |
|-------|-------|-------|
| 最小 TTL | 10 時間（36000 秒） | TTL がこれより短いアセットは対象外 |
| デフォルトの保持期間 | 30 日（2592000 秒） | 設定可能 |
| 最大ファイルサイズ | R2 の制限と同じ | 実用上の制限なし |
| パージ／消去にかかる時間 | 最大 24 時間 | 完全に伝播するまでの時間 |
| 必要なプラン | 有料の Cache Reserve または Smart Shield | 無料プランでは利用不可 |
| Content-Length ヘッダー | 必須 | 対象となるには存在している必要があります |
| Set-Cookie ヘッダー | キャッシュを妨げる | 存在してはなりません（または private ディレクティブを使用） |
| Vary ヘッダー | * は指定不可 | Vary: Accept-Encoding は使用可能 |
| 画像変換 | バリアントは対象外 | オリジナル画像のみ |
| Range リクエスト | **サポート対象外** | HTTP 206 は Cache Reserve を迂回 |
| 圧縮 | 非圧縮で取得 | 訪問者には圧縮して配信 |
| Worker による制御 | ゾーン単位のみ | リクエスト単位では制御不可 |
| O2O リクエスト | 迂回される | Orange-to-Orange は対象外 |

## 追加リソース

- **公式ドキュメント**: https://developers.cloudflare.com/cache/advanced-configuration/cache-reserve/
- **API リファレンス**: https://developers.cloudflare.com/api/resources/cache/subresources/cache_reserve/
- **Cache Rules**: https://developers.cloudflare.com/cache/how-to/cache-rules/
- **Workers Cache API**: https://developers.cloudflare.com/workers/runtime-apis/cache/
- **R2 ドキュメント**: https://developers.cloudflare.com/r2/
- **Smart Shield**: https://developers.cloudflare.com/smart-shield/
- **Tiered Cache**: https://developers.cloudflare.com/cache/how-to/tiered-cache/

## トラブルシューティングのフローチャート

Cache Reserve にアセットがキャッシュされない場合:

```
1. Is Cache Reserve enabled for zone?
   → No: Enable via Dashboard or API
   → Yes: Continue to step 2

2. Is Tiered Cache enabled?
   → No: Enable Tiered Cache (required!)
   → Yes: Continue to step 3

3. Does asset have TTL ≥ 10 hours?
   → No: Increase via Cache Rules (edge_ttl override)
   → Yes: Continue to step 4

4. Is Content-Length header present?
   → No: Fix origin to include Content-Length
   → Yes: Continue to step 5

5. Is Set-Cookie header present?
   → Yes: Remove Set-Cookie or scope appropriately
   → No: Continue to step 6

6. Is Vary header set to *?
   → Yes: Change to specific value (e.g., Accept-Encoding)
   → No: Continue to step 7

7. Is this a range request?
   → Yes: Range requests bypass Cache Reserve (not supported)
   → No: Continue to step 8

8. Is this an O2O (Orange-to-Orange) request?
   → Yes: O2O bypasses Cache Reserve
   → No: Continue to step 9

9. Check Logpush CacheReserveUsed field
   → Filter logs to see if assets ever hit Cache Reserve
   → Verify cf-cache-status header (should be HIT after first request)
```

## 関連項目

- [README](./README.md) - 概要と基本概念
- [Configuration](./configuration.md) - セットアップと Cache Rules
- [API Reference](./api.md) - パージと監視
- [Patterns](./patterns.md) - ベストプラクティスと最適化
