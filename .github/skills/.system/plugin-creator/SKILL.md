---
name: plugin-creator
description: 必須の `.codex-plugin/plugin.json`、任意のプラグイン用フォルダーやファイル、公開またはテスト前に編集できる基本的なプレースホルダーを備えたプラグインディレクトリを作成します。Codex が新しいローカルプラグインを作成する場合、任意のプラグイン構成を追加する場合、またはプラグインの表示順と利用可否のメタデータを管理するために、リポジトリルートの `.agents/plugins/marketplace.json` のエントリを生成・更新する場合に使用します。
---

# プラグインの作成

## クイックスタート

1. 雛形作成スクリプトを実行します。

```bash
  # Plugin names are normalized to lower-case hyphen-case and must be <= 64 chars.
  # The generated folder and plugin.json name are always the same.
# Run from repo root (or replace .agents/... with the absolute path to this SKILL).
# By default creates in <repo_root>/plugins/<plugin-name>.
python3 .agents/skills/plugin-creator/scripts/create_basic_plugin.py <plugin-name>
```

2. `<plugin-path>/.codex-plugin/plugin.json` を開き、`[TODO: ...]` のプレースホルダーを置き換えます。

3. プラグインを Codex UI の表示順に含める場合は、リポジトリのマーケットプレイスエントリを生成または更新します。

```bash
# marketplace.json always lives at <repo-root>/.agents/plugins/marketplace.json
python3 .agents/skills/plugin-creator/scripts/create_basic_plugin.py my-plugin --with-marketplace
```

ホームディレクトリ内のローカルプラグインでは、`<home>` をルートとして扱い、次を使用します。

```bash
python3 .agents/skills/plugin-creator/scripts/create_basic_plugin.py my-plugin \
  --path ~/plugins \
  --marketplace-path ~/.agents/plugins/marketplace.json \
  --with-marketplace
```

4. 必要に応じて、付随する任意のフォルダーを生成・調整します。

```bash
python3 .agents/skills/plugin-creator/scripts/create_basic_plugin.py my-plugin --path <parent-plugin-directory> \
  --with-skills --with-hooks --with-scripts --with-assets --with-mcp --with-apps --with-marketplace
```

`<parent-plugin-directory>` は、プラグインフォルダー `<plugin-name>` を作成する親ディレクトリです（例: `~/code/plugins`）。

## このスキルが作成するもの

- ユーザーがプラグインの場所を明示していない場合は、マーケットプレイスエントリを生成する前に、リポジトリ内のプラグインとホームディレクトリ内のプラグインのどちらを希望するか確認します。
- プラグインのルートを `/<parent-plugin-directory>/<plugin-name>/` に作成します。
- `/<parent-plugin-directory>/<plugin-name>/.codex-plugin/plugin.json` を必ず作成します。
- マニフェストには、スキーマ全体の構造、プレースホルダー値、および完全な `interface` セクションを設定します。
- `--with-marketplace` が指定されている場合、`<repo-root>/.agents/plugins/marketplace.json` を作成または更新します。
  - マーケットプレイスファイルがまだ存在しない場合は、最初のプラグインエントリを追加する前に、トップレベルの `name` と `interface.displayName` のプレースホルダーを用意します。
- `<plugin-name>` は skill-creator の命名規則に従って正規化します。
  - `My Plugin` → `my-plugin`
  - `My--Plugin` → `my-plugin`
  - アンダースコア、空白、句読点は `-` に変換します
  - 結果は小文字のハイフン区切りとし、連続するハイフンを1つにまとめます
- 必要に応じて、次のものも作成できます。
  - `skills/`
  - `hooks/`
  - `scripts/`
  - `assets/`
  - `.mcp.json`
  - `.app.json`

## マーケットプレイスの作業手順

- `marketplace.json` は必ず `<repo-root>/.agents/plugins/marketplace.json` に置きます。
- ホームディレクトリ内のローカルプラグインには、`<home>` をルートとして同じ規則を適用します。
  `~/.agents/plugins/marketplace.json` と `./plugins/<plugin-name>` を使用します。
- マーケットプレイスのルートメタデータには、トップレベルの `name` と、任意の `interface.displayName` を設定できます。
- `plugins[]` 内のプラグインの順序を Codex での表示順として扱います。ユーザーがリストの並べ替えを明示的に求めない限り、新しいエントリは末尾に追加します。
- `displayName` は、個々の `plugins[]` エントリではなく、マーケットプレイスの `interface` オブジェクト内に置きます。
- 生成する各マーケットプレイスエントリには、次のすべてを含めます。
  - `policy.installation`
  - `policy.authentication`
  - `category`
- 新しいエントリのデフォルト値は次のとおりです。
  - `policy.installation: "AVAILABLE"`
  - `policy.authentication: "ON_INSTALL"`
- ユーザーが別の許可された値を明示的に指定した場合にのみ、デフォルト値を変更します。
- `policy.installation` に指定できる値は次のとおりです。
  - `NOT_AVAILABLE`
  - `AVAILABLE`
  - `INSTALLED_BY_DEFAULT`
- `policy.authentication` に指定できる値は次のとおりです。
  - `ON_INSTALL`
  - `ON_USE`
- `policy.products` は上書き指定として扱います。ユーザーが製品による制限を明示的に求めない限り、省略します。
- 生成するプラグインエントリの形式は次のとおりです。

```json
{
  "name": "plugin-name",
  "source": {
    "source": "local",
    "path": "./plugins/plugin-name"
  },
  "policy": {
    "installation": "AVAILABLE",
    "authentication": "ON_INSTALL"
  },
  "category": "Productivity"
}
```

- 同じプラグイン名の既存のマーケットプレイスエントリを意図的に置き換える場合にのみ、`--force` を使用します。
- `<repo-root>/.agents/plugins/marketplace.json` がまだ存在しない場合は、トップレベルの `"name"`、`"displayName"` を含む `"interface"` オブジェクト、および `plugins` 配列を持つファイルを作成してから、新しいエントリを追加します。

- 新規のマーケットプレイスファイルでは、ルートオブジェクトを次の形式にします。

```json
{
  "name": "[TODO: marketplace-name]",
  "interface": {
    "displayName": "[TODO: Marketplace Display Name]"
  },
  "plugins": [
    {
      "name": "plugin-name",
      "source": {
        "source": "local",
        "path": "./plugins/plugin-name"
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

## 必須の動作

- 外側のフォルダー名と `plugin.json` の `"name"` は、常に同じ正規化済みプラグイン名にします。
- 必須の構造を削除せず、`.codex-plugin/plugin.json` を維持します。
- 人または後続の手順が明示的に値を埋めるまで、マニフェストの値はプレースホルダーのままにします。
- 既存のプラグインパス内にファイルを作成する場合、意図的に上書きするときにのみ `--force` を使用します。
- 既存のマーケットプレイスの `interface.displayName` を保持します。
- マーケットプレイスエントリを生成する場合は、値がデフォルトであっても `policy.installation`、`policy.authentication`、`category` を必ず書き込みます。
- `policy.products` は、ユーザーがその上書き指定を明示的に求めた場合にのみ追加します。
- マーケットプレイスの `source.path` は、リポジトリルートからの相対パス `./plugins/<plugin-name>` にします。

## 正確な仕様サンプルの参照先

プラグインマニフェストとマーケットプレイスエントリの正規サンプル JSON は、次を参照してください。

- `references/plugin-json-spec.md`

## 検証

`SKILL.md` を編集した後、次を実行します。

```bash
python3 <path-to-skill-creator>/scripts/quick_validate.py .agents/skills/plugin-creator
```
