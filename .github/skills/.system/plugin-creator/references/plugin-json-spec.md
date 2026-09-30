# プラグイン JSON の仕様例

```json
{
  "name": "plugin-name",
  "version": "1.2.0",
  "description": "Brief plugin description",
  "author": {
    "name": "Author Name",
    "email": "author@example.com",
    "url": "https://github.com/author"
  },
  "homepage": "https://docs.example.com/plugin",
  "repository": "https://github.com/author/plugin",
  "license": "MIT",
  "keywords": ["keyword1", "keyword2"],
  "skills": "./skills/",
  "hooks": "./hooks.json",
  "mcpServers": "./.mcp.json",
  "apps": "./.app.json",
  "interface": {
    "displayName": "Plugin Display Name",
    "shortDescription": "Short description for subtitle",
    "longDescription": "Long description for details page",
    "developerName": "OpenAI",
    "category": "Productivity",
    "capabilities": ["Interactive", "Write"],
    "websiteURL": "https://openai.com/",
    "privacyPolicyURL": "https://openai.com/policies/row-privacy-policy/",
    "termsOfServiceURL": "https://openai.com/policies/row-terms-of-use/",
    "defaultPrompt": [
      "Summarize my inbox and draft replies for me.",
      "Find open bugs and turn them into Linear tickets.",
      "Review today's meetings and flag scheduling gaps."
    ],
    "brandColor": "#3B82F6",
    "composerIcon": "./assets/icon.png",
    "logo": "./assets/logo.png",
    "screenshots": [
      "./assets/screenshot1.png",
      "./assets/screenshot2.png",
      "./assets/screenshot3.png"
    ]
  }
}
```

## フィールドガイド

### トップレベルのフィールド

- `name` (`string`): プラグインの識別子（ケバブケース、空白なし）。`plugin.json` を用意する場合は必須で、マニフェスト名とコンポーネントの名前空間として使用されます。
- `version` (`string`): プラグインのセマンティックバージョン。
- `description` (`string`): 用途の簡潔な説明。
- `author` (`object`): 公開者の情報。
  - `name` (`string`): 作者またはチームの名前。
  - `email` (`string`): 連絡先メールアドレス。
  - `url` (`string`): 作者またはチームのホームページやプロフィールの URL。
- `homepage` (`string`): プラグインの使い方を説明するドキュメントの URL。
- `repository` (`string`): ソースコードの URL。
- `license` (`string`): ライセンス識別子（例: `MIT`、`Apache-2.0`）。
- `keywords` (`string` の `array`): 検索・発見に使うタグ。
- `skills` (`string`): スキルのディレクトリまたはファイルへの相対パス。
- `hooks` (`string`): フック設定のパス。
- `mcpServers` (`string`): MCP 設定のパス。
- `apps` (`string`): プラグイン連携用のアプリマニフェストのパス。
- `interface` (`object`): プラグインの表示に使うインターフェースと UX のメタデータ。

### `interface` のフィールド

- `displayName` (`string`): プラグインに表示する、ユーザー向けの名前。
- `shortDescription` (`string`): コンパクトな表示で使う短いサブタイトル。
- `longDescription` (`string`): 詳細画面で使う長めの説明。
- `developerName` (`string`): 人が読める公開者名。
- `category` (`string`): プラグインのカテゴリ。
- `capabilities` (`string` の `array`): 実装に基づく機能の一覧。
- `websiteURL` (`string`): プラグインの公開ウェブサイト。
- `privacyPolicyURL` (`string`): プライバシーポリシーの URL。
- `termsOfServiceURL` (`string`): 利用規約の URL。
- `defaultPrompt` (`string` の `array`): 入力欄や UI に表示する、使い始めるためのプロンプト。
  - 文字列は最大 3 件にしてください。4 件目以降は無視され、表示されません。
  - 各文字列の上限は 128 文字です。超えた部分は切り詰められます。
  - UI で読みやすいよう、50 文字程度の短いプロンプトを推奨します。
- `brandColor` (`string`): プラグインカードのテーマカラー。
- `composerIcon` (`string`): アイコン画像へのパス。
- `logo` (`string`): ロゴ画像へのパス。
- `screenshots` (`string` の `array`): スクリーンショット画像のパス一覧。
  - スクリーンショットは PNG ファイル名を指定し、ファイルは `./assets/` に保存する必要があります。
  - ファイルパスはプラグインのルートからの相対パスにしてください。

### パスの規則とデフォルト

- パスの値は相対パスとし、`./` で始めてください。
- `skills`、`hooks`、`mcpServers` はデフォルトのコンポーネント検出に追加されるもので、デフォルトの設定を置き換えるものではありません。
- カスタムパスは、プラグインのルートに関する規則と命名・名前空間の規則に従う必要があります。
- このリポジトリの雛形生成では `.codex-plugin/plugin.json` を作成します。このスキルが生成するマニフェストの場所として扱ってください。

# マーケットプレイス JSON の仕様例

`marketplace.json` の場所は、プラグインの配置先によって異なります。

- リポジトリ内のプラグイン: `<repo-root>/.agents/plugins/marketplace.json`
- ローカルプラグイン: `~/.agents/plugins/marketplace.json`

```json
{
  "name": "openai-curated",
  "interface": {
    "displayName": "ChatGPT Official"
  },
  "plugins": [
    {
      "name": "linear",
      "source": {
        "source": "local",
        "path": "./plugins/linear"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Productivity"
    }
  ]
}
```

## マーケットプレイスのフィールドガイド

### トップレベルのフィールド

- `name` (`string`): マーケットプレイスの識別子またはカタログ名。
- `interface` (`object`、省略可): マーケットプレイスの表示用メタデータ。
- `plugins` (`array`): 順序付きのプラグイン項目。この順序によって、Codex でのプラグインの表示順が決まります。

### `interface` のフィールド

- `displayName` (`string`、省略可): ユーザーに表示するマーケットプレイスの名前。

### プラグイン項目のフィールド

- `name` (`string`): プラグインの識別子。プラグインのフォルダー名と `plugin.json` の `name` に一致させてください。
- `source` (`object`): プラグインの取得元を示す情報。
  - `source` (`string`): このリポジトリでの作業手順では `local` を使用してください。
  - `path` (`string`): マーケットプレイスのルートを基準とするプラグインの相対パス。
    - リポジトリ内のプラグイン: `./plugins/<plugin-name>`
    - `~/.agents/plugins/marketplace.json` に登録するローカルプラグイン: `./plugins/<plugin-name>`
  - リポジトリをルートとする場合もホームディレクトリをルートとする場合も、同じ相対パスの規則を使用します。
    - 例: `~/.agents/plugins/marketplace.json` では、`./plugins/<plugin-name>` は `~/plugins/<plugin-name>` を指します。
- `policy` (`object`): マーケットプレイスのポリシー設定。必ず含めてください。
  - `installation` (`string`): 利用可能かどうかを指定するポリシー。
    - 使用可能な値: `NOT_AVAILABLE`、`AVAILABLE`、`INSTALLED_BY_DEFAULT`
    - 新しい項目のデフォルト: `AVAILABLE`
  - `authentication` (`string`): 認証を行うタイミングのポリシー。
    - 使用可能な値: `ON_INSTALL`、`ON_USE`
    - 新しい項目のデフォルト: `ON_INSTALL`
  - `products` (`string` の `array`、省略可): このプラグイン項目の対象製品を上書きする設定。製品による利用制限が明示的に求められた場合を除き、省略してください。
- `category` (`string`): 表示カテゴリ。必ず含めてください。

### マーケットプレイスの生成規則

- `displayName` は個々のプラグイン項目ではなく、トップレベルの `interface` オブジェクト内に置きます。
- 新しいマーケットプレイスファイルを一から作成する場合は、トップレベルの `name` とともに `interface.displayName` を初期設定してください。
- 生成または更新するすべてのプラグイン項目に、`policy.installation`、`policy.authentication`、`category` を必ず含めてください。
- `policy.products` は上書き設定として扱い、明示的に求められた場合を除き省略してください。
- ユーザーから並べ替えの明示的な依頼がない限り、新しい項目は末尾に追加してください。
- 同じプラグインの既存項目は、意図的に上書きする場合にのみ置き換えてください。
- プラグインの配置先に合わせて、マーケットプレイスの場所を選んでください。
  - リポジトリ内のプラグイン: `<repo-root>/.agents/plugins/marketplace.json`
  - ローカルプラグイン: `~/.agents/plugins/marketplace.json`
