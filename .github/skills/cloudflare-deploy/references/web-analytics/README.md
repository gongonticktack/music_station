# Cloudflare Web Analytics

訪問者のプライバシーを損なうことなく、Core Web Vitals、トラフィック指標、ユーザーインサイトを提供する、プライバシー優先のウェブ解析です。

## 概要

Cloudflare Web Analytics が提供する機能:
- **Core Web Vitals** - LCP、FID、CLS、INP、TTFB の監視
- **ページビューと訪問数** - Cookie を使わずにトラフィック傾向を把握
- **参照元とパス** - トラフィックの流入元と人気ページ
- **デバイスとブラウザーのデータ** - ユーザーエージェントの内訳
- **地域データ** - 国別の訪問者分布
- **プライバシー優先** - Cookie、フィンガープリント、個人を特定できる情報（PII）の収集なし
- **無料** - 費用なし、ページビュー数無制限

**重要:** Web Analytics は**ダッシュボード専用**です。プログラムからデータにアクセスするための API はありません。

## クイックスタートの判断ツリー

```
Is your site proxied through Cloudflare?
├─ YES → Use automatic injection (configuration.md)
│   ├─ Enable auto-injection in dashboard
│   └─ No code changes needed (unless Cache-Control: no-transform)
│
└─ NO → Use manual beacon integration (integration.md)
    ├─ Add JS snippet to HTML
    ├─ Use spa: true for React/Vue/Next.js
    └─ Configure CSP if needed
```

## 読む順序

1. **[configuration.md](configuration.md)** - プロキシ経由と非プロキシのサイトの設定
2. **[integration.md](integration.md)** - フレームワーク別のビーコン統合（React、Next.js、Vue、Nuxt など）
3. **[patterns.md](patterns.md)** - 一般的なユースケース（パフォーマンス監視、GDPR 同意、複数サイトのトラッキング）
4. **[gotchas.md](gotchas.md)** - トラブルシューティング（SPA のトラッキング、CSP の問題、ハッシュルーティングの制限）

## 各ファイルを使う場面

- **初めて設定する場合** → configuration.md から始めてください
- **React/Next.js/Vue/Nuxt を使う場合** → フレームワーク用コードは integration.md を参照してください
- **GDPR 同意に応じた読み込みが必要な場合** → patterns.md を参照してください
- **ビーコンが読み込まれない、またはデータがない場合** → gotchas.md を確認してください
- **SPA でナビゲーションがトラッキングされない場合** → `spa: true` の設定について integration.md を参照してください

## 主要な概念

### プロキシ経由と非プロキシのサイト

| 種類 | 説明 | ビーコンの挿入 | 上限 |
|------|-------------|------------------|-------|
| **プロキシ経由** | Cloudflare 経由の DNS（オレンジ色の雲） | 自動または手動 | 無制限 |
| **非プロキシ** | 外部ホスティング、ビーコンは手動 | 手動のみ | 最大 10 サイト |

### SPA モード

**最新のフレームワークでは必須です:**
```json
{"token": "YOUR_TOKEN", "spa": true}
```

`spa: true` がないと、クライアント側のナビゲーション（React Router、Vue Router、Next.js のルーティング）はトラッキングされません。記録されるのは初回のページ読み込みのみです。

### CSP の要件

Content Security Policy を使用する場合は、両方のドメインを許可してください:
```
script-src https://static.cloudflareinsights.com https://cloudflareinsights.com;
```

## 機能

### Core Web Vitals のデバッグ
- **LCP（Largest Contentful Paint）** - 読み込みの遅いヒーロー画像や要素を特定
- **FID（First Input Delay）** - インタラクションへの応答性（旧指標）
- **INP（Interaction to Next Paint）** - 現行のインタラクション応答性指標
- **CLS（Cumulative Layout Shift）** - 視覚的な安定性の問題
- **TTFB（Time to First Byte）** - サーバー応答のパフォーマンス

ダッシュボードには、デバッグ用の CSS セレクターとともに、問題のある要素が上位 5 件表示されます。

### トラフィックフィルター
- **ボットのフィルタリング** - 自動化されたトラフィックを指標から除外
- **日付範囲** - 任意の期間を分析
- **地域** - 国単位でフィルタリング
- **デバイスの種類** - デスクトップ、モバイル、タブレットの内訳
- **ブラウザー/OS** - ユーザーエージェントでフィルタリング

### ルール（高度な機能 - プランに依存）

高度な設定向けに、カスタムのトラッキングルールを作成できます:

**サンプルレートルール:**
- トラフィックの多いサイトでデータ収集の割合を下げる
- 例: データ量を抑えるため、訪問者の 50% のみをトラッキングする

**パスベースのルール:**
- ルートごとに異なる動作を設定
- 例: `/admin/*` または `/internal/*` をトラッキング対象から除外する

**ホストベースのルール:**
- 複数ドメインの設定
- 例: ステージングと本番のサブドメインを分けてトラッキングする

**利用可否:** ルール機能の利用可否は Cloudflare のプランによって異なります。ダッシュボードの Web Analytics → Rules を開き、利用可能か確認してください。Free プランでは、利用が制限されるか、利用できない場合があります。

## プランの上限

| 機能 | Free | 備考 |
|---------|------|-------|
| プロキシ経由のサイト | 無制限 | Cloudflare 経由の DNS |
| 非プロキシのサイト | 10 | 外部ホスティング |
| ページビュー数 | 無制限 | 件数の上限なし |
| データ保持期間 | 6 か月 | ローリング方式 |
| ルール | プランに依存 | ダッシュボードを確認 |

## プライバシーとコンプライアンス

- **Cookie なし** - クライアント側のストレージを一切使用しない
- **フィンガープリントなし** - サイトをまたいだトラッキングをしない
- **PII なし** - IP アドレスを保存しない
- **GDPR に配慮** - データ収集を最小限に抑える
- **CCPA に準拠** - 個人データを販売しない

**EU のオプトアウト:** ダッシュボードの設定で、EU の訪問者データを全面的に除外できます。

## 制限事項

- **ダッシュボード専用** - プログラムからアクセスするための API はありません
- **リアルタイムではない** - データ反映に 5〜10 分かかります
- **カスタムイベントなし** - 自動のページビューとナビゲーションのトラッキングのみ
- **History API のみ** - ハッシュベースのルーティング（`#/path`）には対応していません
- **セッションリプレイなし** - 指標のみで、ユーザーの録画はありません
- **フォームのトラッキングなし** - ページナビゲーションのトラッキングのみ

## 関連項目

- [Cloudflare Web Analytics Docs](https://developers.cloudflare.com/analytics/web-analytics/)
- [Core Web Vitals Guide](https://web.dev/vitals/)
