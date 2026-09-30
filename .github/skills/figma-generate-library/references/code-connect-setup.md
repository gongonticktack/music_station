> [figma-generate-library スキル](../SKILL.md)の一部です。

# Code Connect セットアップリファレンス

このリファレンスでは、figma-generate-library エージェントが利用できる Code Connect ツール一式を説明します。対象は、`add_code_connect_map` ツール、検証用の `get_code_connect_map`、一括適用用の `send_code_connect_mappings`、変数のコード構文、フレームワークラベル、コンポーネントごとにマッピングするか最後にまとめて行うかの判断です。

---

## 1. Code Connect の機能

Code Connect は、Figma のコンポーネントノードとコード実装を紐付けます。これにより、次のことが可能になります。

- 開発者がコンポーネントを調べるとき、**Dev Mode** に自動生成された近似コードではなく、実際のコードスニペット（コードベースから取得）が表示されます。
- **MCP `get_design_context`** は、デザイントークンとともに `componentName`、`source`、レンダリング済みスニペットを返し、AI によるコード生成の精度を高めます。
- **`search_design_system`** は、Figma コンポーネントのメタデータとともにコード参照を返せます。

---

## 2. 3 つの MCP ツール

### 2a. add_code_connect_map — 単一マッピング

1 つの Figma ノードを 1 つのコードコンポーネントにマッピングします。

**パラメーター:**

| パラメーター | 型 | 必須 | 備考 |
|-----------|------|----------|-------|
| `nodeId` | string | 必須（remote）/ 任意（desktop） | 形式は `123:456`。公開済みのコンポーネントまたはコンポーネントセットである必要があります。 |
| `fileKey` | string | 必須（remote） | Figma ファイルキー。 |
| `source` | string | 必須 | コードベース内のパス（例: `src/components/Button.tsx`）または URL。 |
| `componentName` | string | 必須 | コードコンポーネント名（例: `Button`）。 |
| `label` | enum | 必須 | フレームワークラベル。有効な値はセクション 4 を参照してください。 |
| `template` | string | 任意 | 実行可能な JS テンプレートコード。指定すると、単純な **component_browser** マッピングではなく **figmadoc**（テンプレート）マッピングが作成されます。`pixie_mcp_enable_writing_code_connect_templates` feature flag が必要です。 |
| `templateDataJson` | string | 任意 | 任意フィールド `isParserless`、`imports`、`nestable`、`props` を含む JSON 文字列。 |

**2 種類のマッピング:**

1. **単純なマッピング（component_browser）:** `source`、`componentName`、`label` のみを指定します。Figma コンポーネントをコードパスと名前に関連付けます。Dev Mode は Figma のプロパティ名から基本的な JSX スニペットを生成します。これがデフォルトです。まずはこちらを使用してください。

2. **テンプレートマッピング（figmadoc）:** `template` も指定します。テンプレートはサンドボックス化された QuickJS 環境で実行され、実際のインスタンスのプロパティ値に基づいてスニペットを動的にレンダリングします。ユーザーがプロパティ単位の正確な Code Connect を必要としている場合に使用してください。

**一般的なエラーコード:**

| エラー | 意味 | 対処方法 |
|-------|---------|-----|
| `CODE_CONNECT_MAPPING_ALREADY_EXISTS` | コンポーネントはすでにマッピング済みです | まず Figma UI で既存のマッピングを解除します |
| `CODE_CONNECT_ASSET_NOT_FOUND` | 公開済みコンポーネントが見つかりません | コンポーネントがライブラリに公開されていることを確認します |
| `CODE_CONNECT_INSUFFICIENT_PERMISSIONS` | 編集権限がありません | ファイルの編集権限をリクエストします |
| `CODE_CONNECT_NO_LIBRARY_FOUND` | ファイルがライブラリとして公開されていません | まずファイルを Figma ライブラリとして公開します |

**使用例:**

```
Tool: add_code_connect_map
Args: {
  nodeId: "123:456",
  fileKey: "abc123",
  source: "src/components/Button.tsx",
  componentName: "Button",
  label: "React"
}
```

---

### 2b. get_code_connect_map — 検証

ノードの現在の Code Connect マッピングを取得します。マッピングが保存されたことを確認するため、`add_code_connect_map` の直後に使用してください。また、既存の状態を監査するため、`send_code_connect_mappings` の前にも使用してください。

**パラメーター:**

| パラメーター | 型 | 必須 | 備考 |
|-----------|------|----------|-------|
| `nodeId` | string | 任意 | 確認するノード。ファイル内のすべてのマッピングを取得する場合は省略します。 |
| `fileKey` | string | 必須（remote） | Figma ファイルキー。 |
| `codeConnectLabel` | string | 任意 | 特定のフレームワークラベルに結果を絞り込みます。 |

**戻り値:** `nodeId -> { componentName, source, label, snippet, snippetImports }` のマップ。

**検証方法:**

```
1. ノードを指定して add_code_connect_map を呼び出す。
2. 直後に get_code_connect_map(nodeId, fileKey) を呼び出す。
3. 返されたオブジェクトの componentName と source が想定どおりか確認する。
4. マッピングがない場合は、ステップ 1 のエラーコードを確認する。
```

---

### 2c. send_code_connect_mappings — 一括適用

1 回の呼び出しで複数の Code Connect マッピングを適用します。`get_code_connect_suggestions` が未マッピングのコンポーネントをまとめて返した後、またはフェーズ 4 の最後に一括マッピングを行うときに使用してください。

**パラメーター:**

| パラメーター | 型 | 必須 | 備考 |
|-----------|------|----------|-------|
| `nodeId` | string | 任意 | マッピング配列が空の場合にデザインのフォールバックに使用するコンテキストノード。 |
| `fileKey` | string | 必須（remote） | Figma ファイルキー。 |
| `mappings` | array | 必須 | マッピングオブジェクトの配列。 |

**各マッピングオブジェクト:**

| フィールド | 型 | 必須 | 備考 |
|-------|------|----------|-------|
| `nodeId` | string | 必須 | Figma ノード識別子。 |
| `componentName` | string | 必須 | コードコンポーネント名。 |
| `source` | string | 必須 | コードベース内のパス。 |
| `label` | enum | 必須 | フレームワークラベル。 |
| `template` | string | 任意 | figmadoc マッピング用の JS テンプレートコード。 |
| `templateDataJson` | string | 任意 | JSON テンプレートメタデータ。 |

**動作:**

- すべてのマッピングは、バックエンドへの POST によって並列処理されます。
- いずれかのマッピングが失敗した場合、エラーはマッピングごとに報告され、残りは成功します。
- すべて成功すると、対象ノードに対して `get_design_context` が呼び出され、新しいデザインコンテキストが返されます。

**一括処理の手順:**

```
1. {nodeId, componentName, source, label} の組をすべて集める。
2. send_code_connect_mappings({ fileKey, mappings: [...all pairs...] }) を呼び出す。
3. 報告されたエラーを確認し、失敗したものには add_code_connect_map を個別に呼び出す。
4. いくつかのノードに get_code_connect_map を呼び出して抜き取り確認する。
```

---

## 3. 変数のコード構文（トークンの往復変換）

変数にコード構文を設定すると、Figma トークンとコードベースのトークンシステムの間に双方向リンクが作成されます。これにより、Dev Mode では生の hex 値の代わりに、デザイン値の隣に `var(--color-bg-primary)` を表示できます。

**3 つのプラットフォーム:**

```javascript
// In use_figma:
variable.setVariableCodeSyntax('WEB', 'var(--color-bg-primary)');
variable.setVariableCodeSyntax('ANDROID', 'Theme.colorBgPrimary');
variable.setVariableCodeSyntax('iOS', 'Color.bgPrimary');
```

- `WEB` — CSS カスタムプロパティ、デザイントークン JSON、あらゆる Web フレームワークで使用します。
- `ANDROID` — Jetpack Compose のテーマ参照と Android リソース名で使用します。
- `iOS` — SwiftUI の Color 拡張と UIKit の色メソッドで使用します。

**導出ルール（優先順位順）:**

1. **最善:** コードベース内のトークン名をそのまま使用します。コードベースで CSS カスタムプロパティ（`--`）、Swift の色拡張、Kotlin のテーマ参照を検索し、見つかった文字列をそのまま使います。
2. **適切:** Figma の変数名を一貫した方法で変換します。`/` とスペースを `-` に置き換え、先頭に `var(--`、末尾に `)` を付けます。
   - 例: `color/bg/primary` → `var(--color-bg-primary)`
3. **避けること:** コードベースに存在しない名前を推測したり作り出したりしないでください。

**一貫性のルール:** 変換方法は統一してください。ある変数に `var(--color-bg-primary)` を使う場合、そのコレクション内のすべての変数で同じ `var(--{path-with-hyphens})` パターンを使用します。

**WEB 構文の一括設定例:**

```javascript
// In use_figma — set WEB code syntax on all variables in a collection
const collections = figma.variables.getLocalVariableCollections();
for (const coll of collections) {
  if (coll.name !== 'Color') continue;
  for (const varId of coll.variableIds) {
    const v = figma.variables.getVariableById(varId);
    if (!v) continue;
    // Derive: "color/bg/primary" → "var(--color-bg-primary)"
    const cssName = 'var(--' + v.name.toLowerCase().replace(/\//g, '-').replace(/\s+/g, '-') + ')';
    v.setVariableCodeSyntax('WEB', cssName);
  }
}
```

---

## 4. フレームワークラベル

以下のラベルは、すべての Code Connect MCP 操作で有効です。コードベースのフレームワークに合ったラベルを使用してください。

| ラベル | 用途 |
|-------|---------|
| `React` | React / JSX / TSX コンポーネント |
| `Web Components` | ネイティブ Web Components、Lit、FAST |
| `Vue` | Vue 2 および Vue 3 の SFC |
| `Svelte` | Svelte コンポーネント |
| `Storybook` | Code Connect 統合を含む Storybook ストーリー |
| `Javascript` | プレーンな JavaScript、フレームワーク非依存 |
| `Swift` | Swift / UIKit |
| `Swift UIKit` | UIKit 専用 |
| `Objective-C UIKit` | UIKit を使用する Objective-C |
| `SwiftUI` | SwiftUI ビューコンポーネント |
| `Compose` | Jetpack Compose（Android） |
| `Java` | Java Android コンポーネント |
| `Kotlin` | Kotlin Android（Compose 以外） |
| `Android XML Layout` | Android XML レイアウトファイル |
| `Flutter` | Flutter / Dart ウィジェット |
| `Markdown` | ドキュメントまたは MDX コンポーネント |

**HTML に関する注意:** `HTML` ラベルは Code Connect CLI の HTML パーサー（Angular、Vue、フレームワーク固有のパーサーを使わない Web Components 向け）で使用されますが、MCP ツールでは `Web Components` または `Vue` を直接使用します。選択する前にコードベースのフレームワークを確認してください。

---

## 5. コンポーネントごとのマッピングと最後にまとめて行う方法

### コンポーネントごと（新規構築で推奨）

コンポーネントを作成した直後、コンテキストが新しいうちに Code Connect をマッピングします（SKILL.md のワークフローのフェーズ 3、手順 3h）。

**利点:**
- 作成スクリプトからノード ID をすでに取得しています。
- この Figma コンポーネントに対応するコードコンポーネントが正確に分かっています（対応するように設計したばかりです）。
- 依存するコンポーネントを構築する前にエラーを検出できます。

**使用する場面:** 既存のコードコンポーネントと明確に 1 対 1 で対応する Figma コンポーネントを作成する場合。

### 最後にまとめて（フェーズ 4 での一括マッピング）

未マッピングのコンポーネントをすべて集め、`send_code_connect_mappings` を 1 回呼び出してマッピングします。

**利点:**
- N 回個別に呼び出す代わりに、一括で 1 回呼び出せます。
- `get_code_connect_suggestions` を使って、未マッピングのコンポーネントを自動的に見つけられます。
- 作成過程を管理していない既存の Figma ファイルをインポートする場合に適しています。

**使用する場面:** 既存ファイルに Code Connect を後付けする場合、またはコードベースとのマッピングに調査が必要で、すべてのコンポーネントの作成後に調べるほうが適している場合。

### ハイブリッド方式（大規模システムで推奨）

- フェーズ 3 でアトム（Button、Input、Badge、Avatar）を**コンポーネントごと**にマッピングします。
- 分子と有機体は、分子のスニペットがアトムの Code Connect ID を参照するため、すべてのアトムをマッピングした後、フェーズ 4 で**最後にまとめて**マッピングします。

---

## 6. Dev Mode での検証

マッピング後:

1. ブラウザーまたはデスクトップアプリで Figma ファイルを開きます。
2. Dev Mode に切り替えます（ツールバーの `</>` アイコン）。
3. コンポーネントのインスタンスを選択します（メインコンポーネントではなく、ページ上に配置されたインスタンス）。
4. Inspect パネルに、自動生成コードの代わりに Code Connect の出力が表示されていることを確認します。
5. スニペットがない、または `[auto-generated]` と表示される場合は、MCP 経由で `get_code_connect_map` を実行してマッピングが存在することを確認し、次にコンポーネントが公開済みであることを確認します。

**MCP 経由（エージェントのワークフローではより高速）:**

```
get_code_connect_map(nodeId: "<the component set node ID>", fileKey: "<file key>")
```

応答には `componentName`、`source`、`label`、空でない `snippet` が含まれている必要があります。

---

## 7. 重要な制約

- **公開済みコンポーネントのみ:** `add_code_connect_map` では、コンポーネントがライブラリに公開済みである必要があります。ファイルがまだ公開されていない場合、マッピングは `CODE_CONNECT_NO_LIBRARY_FOUND` で失敗します。
- **ノードごとにラベルあたり 1 つのマッピング:** 1 つのノードに複数のマッピング（フレームワークラベルごとに 1 つ）を設定できますが、各ラベルにつき 1 つまでです。同じノードに 2 つ目の React マッピングを追加しようとすると、`CODE_CONNECT_MAPPING_ALREADY_EXISTS` が返されます。
- **テンプレートマッピングには機能フラグが必要:** `template` パラメーターには `pixie_mcp_enable_writing_code_connect_templates` feature flag が必要です。ユーザーがテンプレートレベルの Code Connect を明示的にリクエストしていない限り、単純なマッピングを使用してください。
- **シンプルに始め、必要に応じて高度化:** 常にシンプルなマッピング（`source` + `componentName` + `label`）から始めてください。ユーザーがプロパティ単位で正確にスニペットを表示する必要がある場合にのみ、`template`を追加してください。
