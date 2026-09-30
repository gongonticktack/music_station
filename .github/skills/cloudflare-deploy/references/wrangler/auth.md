# 認証

Workers または Pages をデプロイする前に、Cloudflare で認証します。

## 簡単な判断フロー

```
Need to authenticate?
├─ Interactive/local dev → wrangler login (recommended)
├─ CI/CD or headless → CLOUDFLARE_API_TOKEN env var
└─ Terraform/Pulumi → See respective references
```

## wrangler login（推奨）

ローカル開発向けの一度限りの OAuth フロー:

```bash
npx wrangler login     # Opens browser, completes OAuth
npx wrangler whoami    # Verify: shows email + account ID
```

認証情報はローカルに保存されます。以降のすべてのコマンドで使用できます。

## API トークン（CI/CD）

自動化パイプラインやブラウザーにアクセスできない環境向け:

1. 次のページに移動: **https://dash.cloudflare.com/profile/api-tokens**
2. **Create Token** をクリック
3. テンプレートとして **「Edit Cloudflare Workers」** を使用（Workers、Pages、KV、D1、R2 をカバー）
4. トークンをコピー（表示されるのは一度だけ）
5. 環境変数を設定:

```bash
export CLOUDFLARE_API_TOKEN="your-token-here"
```

### タスク別の最小権限

| タスク | テンプレート／権限 |
|------|------------------------|
| Workers／Pages のデプロイ | 「Edit Cloudflare Workers」テンプレート |
| 読み取り専用アクセス | 「Read All Resources」テンプレート |
| カスタムスコープ | Account:Read + Workers Scripts:Edit + 個別のリソース |

## トラブルシューティング

| エラー | 原因 | 対処方法 |
|-------|-------|-----|
| 「Not logged in」 | 認証情報がない | `wrangler login` を実行するか、`CLOUDFLARE_API_TOKEN` を設定する |
| 「Authentication error」 | トークンが無効または期限切れ | ダッシュボードでトークンを再生成する |
| 「Missing account」 | 選択したアカウントが違う | 確認するには `wrangler whoami` を実行し、wrangler.jsonc に `account_id` を追加する |
| ローカルではトークンが使えるが CI では失敗する | トークンのスコープが別のアカウントになっている | 両方のアカウント ID が一致していることを確認する |
| 「Insufficient permissions」 | トークンに必要なスコープがない | 正しい権限を設定した新しいトークンを作成する |

## 認証の確認

```bash
npx wrangler whoami
```

出力には次の情報が表示されます:
- メールアドレス（OAuth ログインの場合）
- アカウント ID と名前
- トークンのスコープ（API トークンの場合）

終了コードが 0 以外の場合は、認証されていません。

## 関連項目

- [terraform/README.md](../terraform/README.md) - Terraform プロバイダーの認証
- [pulumi/README.md](../pulumi/README.md) - Pulumi プロバイダーの認証