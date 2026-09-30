---
name: render-deploy
description: コードベースを分析し、render.yaml Blueprint を生成して、Dashboard へのディープリンクを提供することで、アプリケーションを Render にデプロイします。Render のクラウドプラットフォームでアプリケーションをデプロイ、ホスト、公開、またはセットアップしたいユーザーに使用します。
---

# Render にデプロイする

Render は **Git 連携**サービスと **ビルド済み Docker イメージ**サービスに対応しています。

このスキルでは **Git 連携**の手順を扱います。
1. **Blueprint 方式** - Infrastructure-as-Code デプロイ用の render.yaml を生成する
2. **直接作成** - MCP ツールでサービスをすぐに作成する

`runtime: image` を使用すれば、Blueprint から **ビルド済み Docker イメージ**を実行することもできます。ただし、`render.yaml` は Git リポジトリ内に置く必要があります。

Git リモートがない場合は、作業を止めて、次のいずれかをユーザーに依頼してください。
- Git リモートを作成して push する（Blueprint だけが必要なら最小構成でかまいません）、または
- Render Dashboard/API を使ってビルド済み Docker イメージをデプロイする（MCP ではイメージ連携サービスを作成できません）。

## 前提条件

- サンドボックスによってデプロイ時のネットワーク呼び出しがブロックされた場合は、`sandbox_permissions=require_escalated` を指定して再実行します。
- デプロイには数分かかることがあります。適切なタイムアウト値を使用してください。

## このスキルを使う場面

ユーザーが次のことを希望する場合に、このスキルを有効にします。
- アプリケーションを Render にデプロイする
- render.yaml Blueprint ファイルを作成する
- プロジェクトの Render デプロイをセットアップする
- Render のクラウドプラットフォームでアプリケーションをホストまたは公開する
- データベース、cron ジョブ、その他の Render リソースを作成する

## 初めて使うユーザー向けの簡単な手順

詳しい分析に入る前に、次の短い質問をして手間を減らします。
1. Git リポジトリからデプロイするか、ビルド済み Docker イメージからデプロイするかを確認します。
2. Render にアプリが必要とするものをすべて用意させるか（ユーザーの説明から必要そうなものを判断します）、アプリだけを用意してインフラはユーザー側で持ち込むかを確認します。依存関係が不明な場合は、データベース、worker、cron、その他のサービスが必要かを短く追加確認します。

その後、以下の該当する方法に進みます。

## ソースの種類を選ぶ

**Git リポジトリを使う場合:** Blueprint と直接作成のどちらにも必要です。リポジトリは GitHub、GitLab、または Bitbucket に push されている必要があります。

**ビルド済み Docker イメージを使う場合:** Render はイメージ連携サービスで対応しています。MCP では **対応していません**。Dashboard/API を使用します。次の情報を確認してください。
- イメージ URL（レジストリ + タグ）
- レジストリ認証情報（非公開の場合）
- サービスタイプ（web/worker）とポート

ユーザーが Docker イメージを選んだ場合は、Render Dashboard のイメージデプロイ手順を案内するか、Git リモートを追加してもらいます（これにより `runtime: image` を使った Blueprint を利用できます）。

## デプロイ方法を選ぶ（Git リポジトリ）

どちらの方法でも、GitHub、GitLab、または Bitbucket に push された Git リポジトリが必要です。（`runtime: image` を使う場合、リポジトリは最小構成で、`render.yaml` だけを含んでいてもかまいません。）

| 方法 | 適しているケース | メリット |
|--------|----------|------|
| **Blueprint** | 複数サービスのアプリ、IaC ワークフロー | バージョン管理でき、再現性があり、複雑な構成に対応 |
| **直接作成** | 単一サービス、すばやいデプロイ | すぐに作成でき、render.yaml ファイルが不要 |

### 方法選択の目安

ユーザーが特定の方法を希望していない限り、以下の判断ルールを既定で使用します。まずコードベースを分析し、デプロイの意図が不明な場合（例: DB、worker、cron）に限って質問します。

**次の条件をすべて満たす場合は、直接作成（MCP）を使います。**
- サービスが単一（Web アプリ 1 つ、または静的サイト 1 つ）
- 個別の worker/cron サービスがない
- 接続するデータベースまたは Key Value がない
- 環境変数が単純で、共有環境変数グループを使わない
この方法が適していて、MCP がまだ設定されていない場合は、作業を止めて、先に MCP のセットアップを案内します。

**次のいずれかに該当する場合は、Blueprint を使います。**
- 複数のサービスがある（web + worker、API + frontend など）
- データベース、Redis/Key Value、またはその他のデータストアが必要
- cron ジョブ、バックグラウンド worker、またはプライベートサービスがある
- 再現可能な IaC が必要、または render.yaml をリポジトリにコミットしたい
- 一貫した構成が必要なモノレポまたは複数環境のセットアップ

判断できない場合は簡単に確認しますが、安全のため既定では Blueprint を選びます。単一サービスの場合は、直接作成（MCP）を強く推奨し、必要に応じて MCP のセットアップを案内します。

## 前提条件の確認

デプロイを始める際は、次の要件を順番に確認します。

**1. ソースの種類を確認する（Git または Docker）**

Git ベースの方法（Blueprint または直接作成）を使う場合、リポジトリは GitHub/GitLab/Bitbucket に push されている必要があります。ビルド済みイメージを参照する Blueprint でも、`render.yaml` を含む Git リポジトリが必要です。

```bash
git remote -v
```

- リモートがない場合は作業を止め、リモートを作成して push するか、Docker イメージのデプロイに切り替えるようユーザーに依頼します。

**2. MCP ツールが利用可能か確認する（単一サービスでは推奨）**

MCP ツールを使うと最もスムーズです。次を試して利用可能か確認します。
```
list_services()
```

MCP ツールが利用できる場合、ほとんどの操作では CLI のインストールを省略できます。

**3. Render CLI がインストールされているか確認する（Blueprint の検証用）**
```bash
render --version
```
インストールされていない場合は、インストールを提案します。
- macOS: `brew install render`
- Linux/macOS: `curl -fsSL https://raw.githubusercontent.com/render-oss/cli/main/bin/install.sh | sh`

**4. MCP をセットアップする（MCP が未設定の場合）**

MCP が未設定のために `list_services()` が失敗する場合は、MCP をセットアップするか（推奨）、CLI の代替手段で続けるかを確認します。MCP を選んだ場合は、使用している AI ツールを確認し、該当する以下の手順を案内します。必ずユーザーの API キーを使用してください。

### Cursor

次の手順をユーザーに案内します。

1) Render API キーを取得します。
```
https://dashboard.render.com/u/*/settings#api-keys
```

2) これを `~/.cursor/mcp.json` に追加します（`<YOUR_API_KEY>` を置き換えます）。
```json
{
  "mcpServers": {
    "render": {
      "url": "https://mcp.render.com/mcp",
      "headers": {
        "Authorization": "Bearer <YOUR_API_KEY>"
      }
    }
  }
}
```

3) Cursor を再起動してから、`list_services()` を再試行します。

### Claude Code

次の手順をユーザーに案内します。

1) Render API キーを取得します。
```
https://dashboard.render.com/u/*/settings#api-keys
```

2) Claude Code で MCP サーバーを追加します（`<YOUR_API_KEY>` を置き換えます）。
```bash
claude mcp add --transport http render https://mcp.render.com/mcp --header "Authorization: Bearer <YOUR_API_KEY>"
```

3) Claude Code を再起動してから、`list_services()` を再試行します。

### Codex

次の手順をユーザーに案内します。

1) Render API キーを取得します。
```
https://dashboard.render.com/u/*/settings#api-keys
```

2) シェルで設定します。
```bash
export RENDER_API_KEY="<YOUR_API_KEY>"
```

3) Codex CLI で MCP サーバーを追加します。
```bash
codex mcp add render --url https://mcp.render.com/mcp --bearer-token-env-var RENDER_API_KEY
```

4) Codex を再起動してから、`list_services()` を再試行します。

### その他のツール

別の AI アプリを使っている場合は、そのツールのセットアップ手順とインストール方法を Render MCP ドキュメントで確認するよう案内します。

### Workspace の選択

MCP の設定後、次のようなプロンプトでアクティブな Render workspace を設定してもらいます。

```
Set my Render workspace to [WORKSPACE_NAME]
```

**5. 認証を確認する（CLI の代替手段のみ）**

MCP が利用できない場合は CLI を使い、アカウントにアクセスできることを確認します。
```bash
# Check if user is logged in (use -o json for non-interactive mode)
render whoami -o json
```
`render whoami` が失敗するか、データが空の場合、CLI は認証されていません。CLI が常に自動でプロンプトを表示するとは限らないため、ユーザーに明示的に認証を促します。

どちらも設定されていない場合は、希望する方法をユーザーに尋ねます。
- **API Key（CLI）**: `export RENDER_API_KEY="rnd_xxxxx"`（https://dashboard.render.com/u/*/settings#api-keys から取得）
- **ログイン**: `render login`（OAuth 用のブラウザーが開きます）

**6. Workspace のコンテキストを確認する**

アクティブな workspace を確認します。
```
get_selected_workspace()
```

または CLI で確認します。
```bash
render workspace current -o json
```

利用可能な workspace を一覧表示するには、次を実行します。
```
list_workspaces()
```

workspace を切り替える必要がある場合は、Dashboard または CLI（`render workspace set`）で切り替えてもらいます。

前提条件が満たされたら、デプロイの手順に進みます。

---

# 方法 1: Blueprint によるデプロイ（複雑なアプリに推奨）

## Blueprint の手順

### ステップ 1: コードベースを分析する

コードベースを分析して、フレームワーク/ランタイム、ビルドと起動のコマンド、必要な環境変数、データストア、ポートのバインドを特定します。[references/codebase-analysis.md](references/codebase-analysis.md) の詳細なチェックリストを使用してください。

### ステップ 2: render.yaml を生成する

Blueprint の仕様に従って `render.yaml` Blueprint ファイルを作成します。

完全な仕様: [references/blueprint-spec.md](references/blueprint-spec.md)

**重要なポイント:**
- ユーザーが別途指定しない限り、常に `plan: free` を使用します
- アプリに必要な環境変数をすべて含めます
- シークレットには `sync: false` を指定します（ユーザーが Dashboard で入力します）
- 適切なサービスタイプ（`web`、`worker`、`cron`、`static`、または `pserv`）を使用します
- 適切なランタイムを使用します: [references/runtimes.md](references/runtimes.md)

**基本構造:**
```yaml
services:
  - type: web
    name: my-app
    runtime: node
    plan: free
    buildCommand: npm ci
    startCommand: npm start
    envVars:
      - key: DATABASE_URL
        fromDatabase:
          name: postgres
          property: connectionString
      - key: JWT_SECRET
        sync: false  # User fills in Dashboard

databases:
  - name: postgres
    databaseName: myapp_db
    plan: free
```

**サービスタイプ:**
- `web`: HTTP サービス、API、Web アプリケーション（外部からアクセス可能）
- `worker`: バックグラウンドのジョブ処理（外部からアクセス不可）
- `cron`: cron スケジュールで実行する定期タスク
- `static`: 静的サイト（HTML/CSS/JS を CDN 経由で配信）
- `pserv`: プライベートサービス（同一アカウント内のみ）

サービスタイプの詳細: [references/service-types.md](references/service-types.md)
ランタイムの選択肢: [references/runtimes.md](references/runtimes.md)
テンプレート例: [assets/](assets/)

### ステップ 2.5: 直後に行う手順（必ず案内）

`render.yaml` を作成したら、ユーザーに簡潔で明確なチェックリストを必ず提示し、CLI が利用できる場合は直ちに検証を実行します。
1. **認証（CLI）**: `render whoami -o json` を実行します（未ログインの場合は `render login` を実行するか、`RENDER_API_KEY` を設定します）。
2. **検証（推奨）**: `render blueprints validate` を実行します。
   - CLI がインストールされていない場合は、インストールを提案し、コマンドを提示します。
3. **コミットして push**: `git add render.yaml && git commit -m "Add Render deployment configuration" && git push origin main`
4. **Dashboard を開く**: Blueprint のディープリンクを使い、求められたら Git OAuth を完了します。
5. **シークレットを入力**: `sync: false` と指定された環境変数を設定します。
6. **デプロイ**: 「Apply」をクリックして、デプロイの状況を確認します。

### ステップ 3: 構成を検証する

デプロイ前に render.yaml ファイルを検証し、エラーを見つけます。CLI がインストールされている場合はコマンドを直接実行し、CLI がない場合に限ってユーザーに操作を促します。

```bash
render whoami -o json  # Ensure CLI is authenticated (won't always prompt)
render blueprints validate
```

検証エラーがあれば、次に進む前に修正します。よくある問題:
- 必須フィールド（`name`、`type`、`runtime`）がない
- ランタイムの値が無効
- YAML 構文が正しくない
- 環境変数の参照が無効

構成ガイド: [references/configuration-guide.md](references/configuration-guide.md)

### ステップ 4: コミットして push する

**重要:** デプロイ前に、`render.yaml` ファイルをリポジトリにマージする必要があります。

`render.yaml` ファイルがコミットされ、Git リモートに push されていることを確認します。

```bash
git add render.yaml
git commit -m "Add Render deployment configuration"
git push origin main
```

まだ Git リモートがない場合は、ここで作業を止め、GitHub/GitLab/Bitbucket リポジトリを作成し、それを `origin` として追加して push するようユーザーに案内してから続けます。

**この手順が重要な理由:** Dashboard のディープリンクは、リポジトリから render.yaml を読み込みます。ファイルがマージされて push されていないと、Render は構成を見つけられず、デプロイに失敗します。

次の手順に進む前に、リモートリポジトリにファイルがあることを確認します。

### ステップ 5: ディープリンクを生成する

Git リポジトリの URL を取得します。

```bash
git remote get-url origin
```

これは Git プロバイダーから URL を返します。**URL が SSH 形式の場合は、HTTPS に変換してください:**

| SSH 形式 | HTTPS 形式 |
|------------|--------------|
| `git@github.com:user/repo.git` | `https://github.com/user/repo` |
| `git@gitlab.com:user/repo.git` | `https://gitlab.com/user/repo` |
| `git@bitbucket.org:user/repo.git` | `https://bitbucket.org/user/repo` |

**変換パターン:** `git@<host>:` を `https://<host>/` に置き換え、末尾の `.git` を削除します。

HTTPS のリポジトリ URL を使って Dashboard のディープリンクを作成します。
```
https://dashboard.render.com/blueprint/new?repo=<REPOSITORY_URL>
```

例:
```
https://dashboard.render.com/blueprint/new?repo=https://github.com/username/repo-name
```

### ステップ 6: ユーザーを案内する

**重要:** ディープリンクをクリックする前に、ユーザーが render.yaml ファイルをリポジトリにマージし、プッシュ済みであることを確認してください。ファイルがリポジトリにない場合、Render は Blueprint 設定を読み込めず、デプロイに失敗します。

次の手順とともに、ユーザーにディープリンクを提示します。

1. **render.yaml がマージ済みであることを確認** - GitHub/GitLab/Bitbucket 上のリポジトリにファイルが存在することを確認します
2. ディープリンクをクリックして Render Dashboard を開きます
3. 求められた場合は Git プロバイダーの OAuth 認証を完了します
4. Blueprint に名前を付けます（または render.yaml の既定値を使用します）
5. シークレットの環境変数（`sync: false` と指定されたもの）を入力します
6. サービスとデータベースの設定を確認します
7. 「Apply」をクリックしてデプロイします

デプロイは自動的に開始されます。ユーザーは Render Dashboard で進行状況を確認できます。

### ステップ 7: デプロイを検証する

ユーザーが Dashboard からデプロイした後、すべてが正常に動作していることを確認します。

**MCP でデプロイ状況を確認:**
```
list_deploys(serviceId: "<service-id>", limit: 1)
```
デプロイ成功を確認するには、`status: "live"` を探します。

**実行時エラーを確認（デプロイから 2～3 分待ってから実施）:**
```
list_logs(resource: ["<service-id>"], level: ["error"], limit: 20)
```

**サービスの健全性メトリクスを確認:**
```
get_metrics(
  resourceId: "<service-id>",
  metricTypes: ["http_request_count", "cpu_usage", "memory_usage"]
)
```

エラーが見つかった場合は、以下の **デプロイ後の検証と基本的なトリアージ** セクションに進みます。

---

# 方法 2: サービスを直接作成する（単一サービスの迅速なデプロイ）

Infrastructure-as-Code を使わないシンプルなデプロイでは、MCP ツールからサービスを直接作成します。

## 直接作成を使う場合

- 単一の Web サービスまたは静的サイト
- 手早く作成するプロトタイプやデモ
- リポジトリに render.yaml ファイルが不要な場合
- 既存のプロジェクトにデータベースや cron ジョブを追加する場合

## 直接作成の前提条件

**リポジトリを Git プロバイダーにプッシュしておく必要があります。** Render はリポジトリをクローンしてサービスをビルド、デプロイします。

```bash
git remote -v  # Verify remote exists
git push origin main  # Ensure code is pushed
```

対応プロバイダー: GitHub、GitLab、Bitbucket

リモートが存在しない場合は作業を止め、ユーザーにリモートを作成してプッシュするよう案内するか、Docker イメージのデプロイに切り替えます。

**注:** MCP はイメージベースのサービス作成に対応していません。ビルド済み Docker イメージをデプロイするには Dashboard/API を使ってください。

## 直接作成のワークフロー

以下の簡潔な手順を使い、MCP コマンドの完全な例と後続の設定については [references/direct-creation.md](references/direct-creation.md) を参照してください。

### ステップ 1: コードベースを分析する
ランタイム、ビルド／起動コマンド、環境変数、データストアを特定するには、[references/codebase-analysis.md](references/codebase-analysis.md) を使います。

### ステップ 2: MCP でリソースを作成する
サービス（Web または静的サイト）と、必要なデータベースまたは Key-Value ストアを作成します。[references/direct-creation.md](references/direct-creation.md) を参照してください。

MCP が Git 認証情報の不足またはリポジトリへのアクセスに関するエラーを返した場合は、作業を止め、Render Dashboard で Git プロバイダーを接続するようユーザーに案内してから再試行します。

### ステップ 3: 環境変数を設定する
作成後、MCP で必要な環境変数を追加します。[references/direct-creation.md](references/direct-creation.md) を参照してください。

MCP 経由で渡したくない場合は、Dashboard でシークレットを設定できることをユーザーに伝えます。

### ステップ 4: デプロイを検証する
デプロイ状況、ログ、メトリクスを確認します。[references/direct-creation.md](references/direct-creation.md) を参照してください。

---

サービスの検出、設定の詳細、クイックコマンド、一般的な問題については、[references/deployment-details.md](references/deployment-details.md) を参照してください。

---

# デプロイ後の検証と基本的なトリアージ（すべての方法）

手順は簡潔にし、繰り返し実行できるようにします。チェックに失敗した場合は、再デプロイする前に修正します。

1. 最新のデプロイが `live` で、トラフィックを処理していることを確認します
2. ヘルスエンドポイント（またはルート）にアクセスし、200 レスポンスを確認します
3. 最近のエラーログを確認し、明確な失敗の兆候がないか調べます
4. 必須の環境変数とポートのバインド（`0.0.0.0:$PORT`）を確認します

詳細なチェックリストとコマンド: [references/post-deploy-checks.md](references/post-deploy-checks.md)

サービスが起動しない場合、またはヘルスチェックがタイムアウトする場合は、基本的なトリアージガイドを使います:
[references/troubleshooting-basics.md](references/troubleshooting-basics.md)

## トラブルシューティング

### ネットワークアクセスの権限昇格

タイムアウト、DNS エラー、接続リセットなどのネットワーク問題でデプロイに失敗した場合は、権限を昇格してデプロイを再実行します（`sandbox_permissions=require_escalated` を使用）。サンドボックスのネットワーク制限により外向きリクエストがブロックされる場合、デプロイには昇格したネットワークアクセスが必要です。

ユーザーへの案内例:

```
The deploy needs escalated network access to deploy to Render. I can rerun the command with escalated permissions—want me to proceed?
```

任意: メトリクス／DB チェック／エラーカタログなど、より詳細な診断が必要な場合は、
`render-debug` スキルのインストールを提案します。基本的なデプロイ手順には必要ありません。
