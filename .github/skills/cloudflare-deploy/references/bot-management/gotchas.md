# Bot Management の注意点

## よくあるエラー

### 「Bot Score = 0」

**原因:** Bot Management が実行されていない（Cloudflare 内部リクエスト、ゾーンへの Worker ルーティング（Orange-to-Orange）、または BM より前にリクエストが処理された場合（Redirect Rules など））  
**解決策:** リクエストの流れを確認し、リクエストのライフサイクル中に Bot Management が実行されるようにする

### 「JavaScript Detections が機能しない」

**原因:** 次の理由により `js_detection.passed` が常に false または未定義になる: CSP ヘッダーで `/cdn-cgi/challenge-platform/` が許可されていない、初回ページ訪問時に使用している（先に HTML ページが必要）、広告ブロッカーまたは JavaScript が無効、ダッシュボードで JSD が有効になっていない、または Block アクションを使用している（Managed Challenge を使う必要がある）  
**解決策:** CSP ヘッダー `Content-Security-Policy: script-src 'self' /cdn-cgi/challenge-platform/;` を追加し、JSD が有効で、アクションに Managed Challenge が設定されていることを確認する

### 「誤検知（正規ユーザーがブロックされる）」

**原因:** ボット検出が正規ユーザーを誤って検出している  
**解決策:** Bot Analytics で該当する IP/パスを確認し、検出元（ML、ヒューリスティックなど）を特定する。`(cf.bot_management.score lt 30 and http.request.uri.path eq "/problematic-path")` のような例外ルールを Action: Skip (Bot Management) で作成するか、IP/ASN/国で許可リストに登録する

### 「検知漏れ（ボットを検出できない）」

**原因:** ボットが検出を回避している  
**解決策:** スコアのしきい値を下げる（30 → 50）、JavaScript Detections を有効にする、JA3/JA4 フィンガープリントルールを追加する、またはフォールバックとしてレート制限を使用する

### 「検証済みボットがブロックされる」

**原因:** ボットが Bot Management ではなく WAF Managed Rules によってブロックされている  
**解決策:** 特定のルール ID に対する WAF 例外を作成し、逆引き DNS でボットを検証する

### 「IP 更新中に Yandex Bot がブロックされる」

**原因:** Yandex はボットの IP を更新します。伝播中、新しい IP は48時間認識されません  
**解決策:** 
1. Security Events で Yandex をブロックしている特定の WAF ルール ID を確認する
2. WAF 例外を作成する:
   ```txt
   (http.user_agent contains "YandexBot" and ip.src in {<yandex-ip-range>})
   Action: Skip (WAF Managed Ruleset)
   ```
3. Bot Analytics を48時間監視する
4. 伝播完了後に例外を削除する

問題は48時間後に自動的に解消します。継続する場合は Cloudflare Support に連絡してください。

### 「JA3/JA4 が取得できない」

**原因:** HTTPS 以外のトラフィック、Worker 経由のトラフィック、Worker 経由の Orange-to-Orange トラフィック、または Bot Management がスキップされている  
**解決策:** JA3/JA4 は HTTPS/TLS トラフィックでのみ利用できます。リクエストのルーティングを確認してください

**JA3/JA4 はユーザー固有ではありません:** 同じブラウザー/ライブラリのバージョンなら、同じフィンガープリントになります
- ユーザー識別には使わない
- クライアントのプロファイリングにのみ使用する
- ブラウザーの更新でフィンガープリントが変わる

## ボットの検証方法

Cloudflare は次の方法でボットを検証します:

1. **逆引き DNS（IP 検証）:** 従来の方法。ボットの IP が想定されるドメインに解決される
2. **Web Bot Auth:** 最新の暗号学的検証。伝播がより速い

`verifiedBot=true` の場合、ボットは少なくとも1つの方法で検証に合格しています。

**非アクティブな検証済みボット:** 24時間トラフィックがない IP は削除されます。

## 検出エンジンの動作

| エンジン | スコア | タイミング | プラン | 注記 |
|--------|-------|--------|------|-------|
| ヒューリスティック | 常に1 | 即時 | すべて | 既知のフィンガープリント。ML より優先 |
| ML | 1-99 | 即時 | すべて | 検出の大半を占める |
| 異常検知 | 影響 | ベースライン作成後 | Enterprise | オプション、ベースライン分析 |
| JavaScript Detections | 合格/不合格 | JS 実行後 | Pro 以上 | ヘッドレスブラウザー検出 |
| Cloudflare Service | N/A | N/A | Enterprise | Zero Trust の内部ソース |

**優先順位:** ヒューリスティック > ML。ヒューリスティックに一致すると、ML の結果にかかわらず score=1 になります。

## 制限事項

| 制限 | 値 | 注記 |
|-------|-------|-------|
| Bot Score = 0 | 未計算を意味する | スコア = 100 ではない |
| 初回リクエストの JSD データ | 利用できない場合がある | JSD データは後続のリクエストに表示される |
| スコアの精度 | 100% の保証はない | 誤検知/検知漏れの可能性がある |
| 初回 HTML ページ訪問時の JSD | 非対応 | 後続のページ読み込みが必要 |
| JSD の要件 | JavaScript が有効なブラウザー | JavaScript が無効な場合や広告ブロッカーがある場合は動作しない |
| JSD による ETag の削除 | HTML レスポンスから ETag を削除する | キャッシュ動作に影響する場合がある |
| JSD の CSP 互換性 | 特定の CSP が必要 | 一部の CSP 設定とは互換性がない |
| JSD の meta CSP タグ | 非対応 | HTTP ヘッダーを使用する必要がある |
| JSD の WebSocket サポート | 非対応 | WebSocket エンドポイントでは JSD は動作しない |
| JSD のモバイルアプリ対応 | ネイティブアプリでは検証を通過できない | ブラウザーでのみ動作する |
| JA3/JA4 のトラフィック種別 | HTTPS/TLS のみ | HTTPS 以外のトラフィックでは利用できない |
| JA3/JA4 の Worker ルーティング | Worker 経由のトラフィックでは取得できない | リクエストのルーティングを確認する |
| JA3/JA4 の一意性 | ユーザーごとに一意ではない | 同じブラウザー/ライブラリを使うクライアント間で共有される |
| JA3/JA4 の安定性 | 更新で変わる可能性がある | ブラウザー/ライブラリの更新がフィンガープリントに影響する |
| WAF カスタムルール（Free） | 5 | プランによって異なる |
| WAF カスタムルール（Pro） | 20 | プランによって異なる |
| WAF カスタムルール（Business） | 100 | プランによって異なる |
| WAF カスタムルール（Enterprise） | 1,000+ | プランによって異なる |
| Workers の CPU 時間 | プランによって異なる | ボットロジックに適用 |
| Bot Analytics のサンプリング | 1-10% の適応型 | トラフィック量の多いゾーンほど積極的にサンプリングされる |
| Bot Analytics の履歴 | 最大30日 | 履歴データの保持上限 |
| JSD の CSP 要件 | `/cdn-cgi/challenge-platform/` を許可する必要がある | JSD の動作に必要 |

### プランの制限

| 機能 | Free | Pro/Business | Enterprise |
|---------|------|--------------|------------|
| 詳細スコア（1-99） | いいえ | いいえ | はい |
| JA3/JA4 | いいえ | いいえ | はい |
| 異常検知 | いいえ | いいえ | はい |
| 企業プロキシの検出 | いいえ | いいえ | はい |
| 検証済みボットのカテゴリ | 限定 | 限定 | 全カテゴリ |
| WAF カスタムルール | 5 | 20/100 | 1,000+ |
