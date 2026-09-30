# 設定

## セットアップ方法

### プロキシ経由のサイト（自動）

ダッシュボード → Web Analytics → サイトを追加 → ホスト名を選択 → 完了

| 挿入オプション | 説明 |
|------------------|-------------|
| 有効 | すべての訪問者に自動挿入（デフォルト） |
| 有効（EU を除外） | EU では挿入しない（GDPR 対応） |
| 手動スニペットで有効化 | ビーコンを手動で追加 |
| 無効 | トラッキングを一時停止 |

**レスポンスに次が含まれる場合は失敗します:** `Cache-Control: public, no-transform`

**必要な CSP:**
```
script-src https://static.cloudflareinsights.com https://cloudflareinsights.com;
```

### 非プロキシ経由のサイト（手動）

ダッシュボード → Web Analytics → サイトを追加 → ホスト名を入力 → スニペットをコピー

```html
<script defer src='https://static.cloudflareinsights.com/beacon.min.js' 
        data-cf-beacon='{"token": "YOUR_TOKEN", "spa": true}'></script>
```

**制限:** 1 アカウントにつき非プロキシ経由のサイトは 10 件まで

## SPA モード

**次の場合は `spa: true` を有効にします:** React Router、Next.js、Vue Router、Nuxt、SvelteKit、Angular

**次の場合は `spa: false` のままにします:** 従来型のマルチページアプリ、静的サイト、WordPress

**ハッシュルーティング（`#/path`）は非対応です** - History API によるルーティングを使用してください。

## トークン管理

- 確認場所: ダッシュボード → Web Analytics → サイトを管理
- **シークレットではありません** - ドメインに紐付けられており、HTML に公開しても安全です
- サイトごとに固有のトークンが割り当てられます

## 環境設定

```typescript
// Only load in production
if (process.env.NODE_ENV === 'production') {
  // Load beacon
}
```

または環境変数を使って環境ごとのトークンを設定します。

## インストールを確認する

1. DevTools の Network で `cloudflareinsights` をフィルターし、`beacon.min.js` とデータリクエストを確認
2. コンソールに CSP/CORS エラーがないことを確認
3. 5～10 分後にダッシュボードにページビューが表示されることを確認

## ルール（プランに依存）

次の項目はダッシュボードで設定します:
- **サンプル率** - トラフィックの多いサイトで収集率を下げる
- **パスベース** - ルートごとに動作を変える
- **ホストベース** - ドメインごとにトラッキングを分ける

## データ保持

- 直近 6 か月のローリング期間
- 1 時間単位の集計
- 生データのエクスポート不可、ダッシュボードのみ
