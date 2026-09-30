# Zaraz の設定

## ダッシュボードのセットアップ

1. ドメイン → Zaraz → セットアップを開始
2. ツールを追加（例: Google Analytics 4）
3. 認証情報を入力（GA4: `G-XXXXXXXXXX`）
4. トリガーを設定
5. 保存して公開

## トリガー

| 種類 | 発生条件 | 用途 |
|------|------|----------|
| ページビュー | ページ読み込み時 | ページビューの追跡 |
| クリック | 要素のクリック時 | ボタンの追跡 |
| フォーム送信 | フォーム送信時 | リードの獲得 |
| 履歴変更 | URL の変更時（SPA） | React/Vue のルーティング |
| 変数の一致 | カスタム条件 | 条件付き実行 |

### 履歴変更（SPA）

```
Type: History Change
Event: pageview
```

`pushState`、`replaceState`、ハッシュの変更時に実行されます。**手動でのトラッキングは不要です。**

### クリックトリガー

```
Type: Click
CSS Selector: .buy-button
Event: purchase_intent
Properties:
  button_text: {{system.clickElement.text}}
```

## ツールの設定

**GA4:**
```
Measurement ID: G-XXXXXXXXXX
Events: page_view, purchase, user_engagement
```

**Facebook Pixel:**
```
Pixel ID: 1234567890123456
Events: PageView, Purchase, AddToCart
```

**Google Ads:**
```
Conversion ID: AW-XXXXXXXXX
Conversion Label: YYYYYYYYYY
```

## 同意の管理

1. Settings → Consent → 目的を作成（analytics、marketing）
2. ツールを目的にマッピング
3. 動作を設定: 「同意が得られるまで読み込まない」

**プログラムによる同意の設定:**
```javascript
zaraz.consent.setAll({ analytics: true, marketing: true });
```

## プライバシー機能

| 機能 | デフォルト |
|---------|---------|
| IP アドレスの匿名化 | 有効 |
| Cookie の制御 | 同意目的を通じて設定 |
| GDPR/CCPA | 同意モーダル |

## テスト

1. **プレビューモード** - 公開せずにテスト
2. **デバッグモード** - `zaraz.debug = true`
3. **Network タブ** - 「zaraz」で絞り込み

## 上限

| リソース | 上限 |
|----------|-------|
| イベントプロパティ | 100KB |
| 同意の目的 | 20 |
