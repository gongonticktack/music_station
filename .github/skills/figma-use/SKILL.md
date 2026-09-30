---
name: figma-use
description: "**必須の前提条件** — `use_figma` ツールを呼び出す前に、必ずこのスキルを読み込んでください。先にこのスキルを読み込まずに `use_figma` を直接呼び出してはいけません。省略すると、よくある原因特定の難しい失敗が発生します。JavaScriptをFigmaファイルのコンテキストで実行する必要がある書き込み操作や、個別の読み取り操作をユーザーが希望した場合に適用します。例: ノードの作成・編集・削除、変数やトークンの設定、コンポーネントやバリアントの構築、オートレイアウトや塗りの変更、プロパティへの変数のバインド、ファイル構造のプログラムによる調査。"
---

# use_figma — Figma Plugin APIスキル

`use_figma` MCPを使用して、Plugin API経由でFigmaファイル内のJavaScriptを実行します。詳細なリファレンスドキュメントはすべて `references/` にあります。

**`skillNames: "figma-use"` を呼び出す際は、必ず `use_figma` を渡してください。** これはスキルの使用状況を追跡するためのログ用パラメーターであり、実行には影響しません。

**コードからFigmaでページ全体、画面、または複数セクションのレイアウトを構築・更新するタスクの場合は、** [figma-generate-design](../figma-generate-design/SKILL.md) も読み込んでください。このスキルでは、`search_design_system` でデザインシステムのコンポーネントを見つけてインポートし、画面を段階的に組み立てるワークフローを説明しています。この2つのスキルは連携して機能します。こちらはAPIのルールを扱い、もう一方は画面構築のワークフローを扱います。

最初に、何が可能かを把握するため [plugin-api-standalone.index.md](references/plugin-api-standalone.index.md) を読み込んでください。Plugin APIのコードを書くよう求められた場合は、この情報をもとに [plugin-api-standalone.d.ts](references/plugin-api-standalone.d.ts) をgrepし、関連する型、メソッド、プロパティを確認してください。これがAPIの仕様を確認するための決定版の情報源です。型定義ファイルは大きいため、一度にすべて読み込まず、必要に応じて関連箇所をgrepしてください。

重要: デザインシステムを扱う場合は、まず [working-with-design-systems/wwds.md](references/working-with-design-systems/wwds.md) を読み込み、Figmaでデザインシステムを扱う際の重要な概念、プロセス、ガイドラインを把握してください。その後、必要に応じてコンポーネント、変数、テキストスタイル、エフェクトスタイルに関する個別のリファレンスを読み込んでください。

## 1. 重要なルール

1.  **データを返すには `return` を使用してください。** 戻り値は自動的にJSONシリアライズされます（オブジェクト、配列、文字列、数値）。`figma.closePlugin()` を呼び出したり、コードを非同期IIFEで囲んだりしてはいけません。これらは自動的に処理されます。
2.  **トップレベルの `await` と `return` を使ったプレーンなJavaScriptを書いてください。** コードは自動的に非同期コンテキストでラップされます。`(async () => { ... })()` で囲んではいけません。
3.  `figma.notify()` は **「not implemented」エラーをスローします** — 絶対に使用しないでください
3a. `getPluginData()` / `setPluginData()` は `use_figma` で **サポートされていません** — 使用しないでください。代わりに `getSharedPluginData()` / `setSharedPluginData()`（こちらはサポートされています）を使うか、ノードIDを返して後続の呼び出しに渡してください。
4.  `console.log()` の出力は返されません — 出力には `return` を使用してください
5.  **小さな手順に分けて段階的に作業してください。** 大きな操作は複数の `use_figma` 呼び出しに分割します。各手順の後に検証してください。これはバグを防ぐうえで最も重要な実践方法です。
6.  色の値は **0～1の範囲**（0～255ではありません）です: `{r: 1, g: 0, b: 0}` = 赤
7.  塗りと線は **読み取り専用の配列**です — 複製して変更し、再代入してください
8.  テキストを操作する前にフォントを **必ず** 読み込んでください: `await figma.loadFontAsync({family, style})`
9. **ページは段階的に読み込まれます** — `await figma.setCurrentPageAsync(page)` を使ってページを切り替え、コンテンツを読み込んでください（下記「ページのルール」を参照）
10. `setBoundVariableForPaint` は **新しい** paintを返します — 受け取って再代入してください
11. `createVariable` はコレクション **オブジェクトまたはID文字列** を受け取ります（オブジェクトを推奨）
12. **`layoutSizingHorizontal/Vertical = 'FILL'` は `parent.appendChild(child)` の後に設定する必要があります** — 先に設定するとエラーになります。オートレイアウトではないノードに対して `'HUG'` を設定する場合も同様です。
13. **新しいトップレベルノードは (0,0) から離れた位置に配置してください。** ページに直接追加したノードは、デフォルトで (0,0) に配置されます。`figma.currentPage.children` を調べて、空いている位置（例: 最も右にあるノードの右側）を見つけてください。これはページレベルのノードにのみ適用されます。ほかのフレームやオートレイアウトコンテナ内にネストされたノードの位置は、親によって決まります。[Gotchas](references/gotchas.md) を参照してください。
14. **`use_figma` でエラーが発生したら、作業を止めてください。すぐに再試行してはいけません。** 失敗したスクリプトは **アトミック** です — スクリプトでエラーが発生すると、まったく実行されず、ファイルにも変更は加えられません。エラーメッセージを注意深く読み、スクリプトを修正してから再試行してください。[エラーからの復旧](#6-error-recovery--self-correction) を参照してください。
15. **作成・変更したすべてのノードIDを `return` する必要があります。** スクリプトで新しいノードを作成したり、キャンバス上の既存ノードを変更したりした場合は、影響を受けたすべてのノードIDを集め、構造化オブジェクトで返してください（例: `return { createdNodeIds: [...], mutatedNodeIds: [...] }`）。後続の呼び出しでそれらのノードを参照、検証、またはクリーンアップするために不可欠です。
16. **変数の作成時には、必ず `variable.scopes` を明示的に設定してください。** デフォルトの `ALL_SCOPES` はすべてのプロパティ選択メニューに項目を増やしてしまいます。通常、これは望ましくありません。背景には `["FRAME_FILL", "SHAPE_FILL"]`、テキストカラーには `["TEXT_FILL"]`、間隔には `["GAP"]` など、用途に合ったスコープを使ってください。全リストは [variable-patterns.md](references/variable-patterns.md) を参照してください。
17. **すべてのPromiseに `await` を付けてください。** Promiseを未処理のままにしてはいけません。未処理の非同期呼び出し（例: `figma.loadFontAsync(...)` に `await` を付けない、または `figma.setCurrentPageAsync(page)` に `await` を付けない）は、実行完了を待たずに進むため、目に見えない失敗や競合状態を引き起こします。非同期処理が完了する前にスクリプトが戻り、データが欠けたり、変更が一部しか適用されなかったりする場合があります。

> 各ルールの詳しい誤り／正しい例については、[よくある落とし穴と間違い](references/gotchas.md) を参照してください。

## 2. ページのルール（重要）

**`use_figma` の呼び出しごとにページコンテキストはリセットされます** — 毎回、`figma.currentPage` は最初のページを指します。

### ページの切り替え

`await figma.setCurrentPageAsync(page)` を使ってページを切り替え、コンテンツを読み込んでください。同期セッターの `figma.currentPage = page` は `use_figma` の実行環境で **エラーをスローします**。

```js
// Switch to a specific page (loads its content)
const targetPage = figma.root.children.find((p) => p.name === "My Page");
await figma.setCurrentPageAsync(targetPage);
// targetPage.children is now populated

// Iterate over all pages
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  // page.children is now loaded — read or modify them here
}
```

### スクリプト実行をまたぐ場合

各 `figma.currentPage` 呼び出しの開始時に、`use_figma` は **最初のページ** にリセットされます。複数回の呼び出しにまたがるワークフローでデフォルト以外のページを対象とする場合は、各呼び出しの冒頭で `await figma.setCurrentPageAsync(page)` を呼び出してください。

ファイルの状態を段階的に構築したり、別のスクリプトを書く前に情報を取得したりするために、`use_figma` を複数回呼び出せます。たとえば、既存ノードのメタデータを取得するスクリプトを書いて、そのデータを `return` し、続くスクリプトで使って該当ノードを変更します。

## 3. `return` は出力手段

エージェントに見えるのは、あなたが `return` した値 **だけ** です。それ以外はすべて見えません。

- **IDを返す（重要）**: キャンバスノードを作成・変更するスクリプトはすべて、影響を受けたノードIDを返す **必要があります** — 例: `return { createdNodeIds: [...], mutatedNodeIds: [...] }`。これは任意ではなく、必須要件です。
- **進捗の報告**: `return { createdNodeIds: [...], count: 5, errors: [] }`
- **エラー情報**: スローされたエラーは自動的に捕捉され、返されます — そのまま伝播させるか、明示的に `throw` してください。
- `console.log()` の出力はエージェントに **返されません**
- 後続の呼び出しで作成済みオブジェクトを参照できるよう、ID、件数、状態など、次の操作に使えるデータを必ず返してください

## 4. エディターモード

`use_figma` は **デザインモード**（`"figma"`、デフォルト）で動作します。FigJam（`"figjam"`）では利用可能なノード型が異なり、ほとんどのデザインノードがブロックされます。

デザインモードで利用可能: Rectangle, Frame, Component, Text, Ellipse, Star, Line, Vector, Polygon, BooleanOperation, Slice, Page, Section, TextPath。

デザインモードで **使用不可**: Sticky, Connector, ShapeWithText, CodeBlock, Slide, SlideRow, Webpage。

## 5. 段階的なワークフロー（バグを防ぐ方法）

バグの最もよくある原因は、1回の `use_figma` 呼び出しで多くを行おうとすることです。**小さな手順に分けて作業し、そのつど検証してください。**

### 基本パターン

1. **まず調査します。** 何かを作成する前に、読み取り専用の `use_figma` を実行し、ファイル内にすでに存在するもの（ページ、コンポーネント、変数、命名規則）を確認してください。既存のものに合わせます。
2. **1回の呼び出しにつき1つの作業を行います。** 変数を作成する呼び出し、コンポーネントを作成する呼び出し、レイアウトを組み立てる呼び出し、というように分けます。1つのスクリプトで画面全体を構築しようとしないでください。
3. **各呼び出しからIDを返します。** 作成したノードID、変数ID、コレクションIDは必ずオブジェクトとして `return` してください（例: `return { createdNodeIds: [...] }`）。これらは後続の呼び出しへの入力に必要です。
4. **各手順の後に検証します。** `get_metadata` で構造（件数、名前、階層、位置）を確認してください。大きな節目では `get_screenshot` を使い、視覚的な問題がないか確認します。
5. **先へ進む前に修正します。** 検証で問題が見つかったら、次の手順に進む前に修正してください。問題がある状態を土台にして作業を進めないでください。

### 複雑なタスクで推奨される手順

```
ステップ 1: ファイルを調査 — 既存のページ、コンポーネント、変数、慣習を把握する
ステップ 2: 必要ならトークンと変数を作る
            → get_metadata で検証する
ステップ 3: 個々のコンポーネントを作る
            → get_metadata と get_screenshot で検証する
ステップ 4: コンポーネントのインスタンスからレイアウトを組み立てる
            → get_screenshot で検証する
ステップ 5: 最終確認を行う
```

### 各手順で検証する内容

| 完了した作業 | `get_metadata` で確認 | `get_screenshot` で確認 |
|---|---|---|
| 変数の作成 | コレクション数、変数数、モード名 | — |
| コンポーネントの作成 | 子ノード数、バリアント名、プロパティ定義 | バリアントが見えること、折りたたまれていないこと、グリッドを読み取れること |
| 変数のバインド | ノードのプロパティにバインドが反映されていること | 色／トークンが正しく解決されていること |
| レイアウトの組み立て | インスタンスノードに mainComponent があること、階層が正しいこと | テキストが切れていないこと、要素が重なっていないこと、間隔が正しいこと |

<a id="6-error-recovery--self-correction"></a>
## 6. エラーからの復旧と自己修正

**`use_figma` はアトミックです — 失敗したスクリプトは実行されません。** スクリプトでエラーが発生すると、ファイルに変更は加えられず、呼び出し前と同じ状態のままです。つまり、部分的に作成されたノードや、失敗したスクリプトによる孤立要素は残らず、修正後の再試行も安全です。

### `use_figma` がエラーを返した場合

1. **停止してください。** すぐにコードを修正して再試行してはいけません。
2. **エラーメッセージを注意深く読んでください。** APIの使い方の誤り、フォントの未読み込み、無効なプロパティ値など、何が起きたのかを正確に把握します。
3. **エラーが不明瞭な場合は、** `get_metadata` または `get_screenshot` を呼び出し、現在のファイル状態を把握してください。
4. **エラーメッセージに基づいてスクリプトを修正します。**
5. 修正版のスクリプトを **再試行します**。

### よくある自己修正のパターン

| エラーメッセージ | 考えられる原因 | 修正方法 |
|---|---|---|
| `"not implemented"` | `figma.notify()` を使用した | 削除し、出力には `return` を使用する |
| `"node must be an auto-layout frame..."` | オートレイアウトの親に追加する前に `FILL` / `HUG` を設定した | `appendChild` を `layoutSizingX = 'FILL'` より前に移動する |
| `"Setting figma.currentPage is not supported"` | 同期ページセッターを使用した | `await figma.setCurrentPageAsync(page)` を使用する |
| プロパティ値が範囲外 | 色チャンネルが1を超えている（0～1ではなく0～255を使用した） | 255で割る |
| `"Cannot read properties of null"` | ノードが存在しない（IDが違う、またはページが違う） | ページコンテキストを確認し、IDを検証する |
| スクリプトが停止する／応答がない | 無限ループまたは未解決のPromise | `while(true)` や `await` の付け忘れを確認し、コードが終了することを確かめる |
| `"The node with id X does not exist"` | 子ノードの `detachInstance()` によって親インスタンスが暗黙的にデタッチされ、IDが変わった | 安定した（インスタンスではない）親フレームからたどって、ノードを再検出する |

### スクリプトは成功したのに結果がおかしい場合

1. `get_metadata` を呼び出し、構造上の正しさ（階層、数、位置）を確認します。
2. `get_screenshot` を呼び出し、視覚的な正しさを確認します。テキストの切り抜き・クリッピング（行の高さによって内容が切れていないか）や要素の重なりをよく確認してください。こうした問題はよく起こり、見落としやすいものです。
3. 差異を特定します。構造上の問題（階層が誤っている、ノードがない）でしょうか。それとも視覚上の問題（色が誤っている、レイアウトが崩れている、内容が切れている）でしょうか。
4. 問題のある部分だけを修正する、対象を絞った修正スクリプトを書きます。すべてを作り直してはいけません。

> 検証ワークフローの全体については、[検証とエラーからの復旧](references/validation-and-recovery.md)を参照してください。

## 7. 実行前チェックリスト

`use_figma` を呼び出す前に、必ず次を確認してください。

- [ ] データを返すためにコードが `return` を使用している（`figma.closePlugin()` は使用していない）
- [ ] コードが async IIFE でラップされていない（自動的にラップされます）
- [ ] `return` の値に、実行可能な情報（ID、数など）を含む構造化データが含まれている
- [ ] `figma.notify()` をどこでも使用していない
- [ ] 出力に `console.log()` を使用していない（代わりに `return` を使用する）
- [ ] すべての色が 0～1 の範囲を使用している（0～255 ではない）
- [ ] 塗りと線は新しい配列として再代入されている（インプレースで変更していない）
- [ ] ページの切り替えには `await figma.setCurrentPageAsync(page)` を使用している（同期セッターは例外をスローする）
- [ ] `layoutSizingVertical/Horizontal = 'FILL'` は `parent.appendChild(child)` の後に設定されている
- [ ] テキストプロパティを変更する前に `loadFontAsync()` を呼び出している
- [ ] `lineHeight`/`letterSpacing` は `{unit, value}` 形式を使用している（数値だけではない）
- [ ] サイズ設定モードを設定する前に `resize()` を呼び出している（resize によって FIXED にリセットされるため）
- [ ] 複数ステップのワークフローでは、前の呼び出しで取得した ID を変数ではなく文字列リテラルとして渡している
- [ ] 新しい最上位ノードは、既存の内容と重ならないよう (0,0) から離れた位置に配置されている
- [ ] 作成・変更したすべてのノード ID を収集し、`return` の値に含めている
- [ ] すべての非同期呼び出し（`loadFontAsync`、`setCurrentPageAsync`、`importComponentByKeyAsync` など）が `await` されている。Promise を投げっぱなしにしていない

## 8. 作成前に規約を確認する

**何かを作成する前に、必ず Figma ファイルを確認してください。** ファイルによって、命名規則、変数の構成、コンポーネントのパターンは異なります。コードは既存の規約に合わせ、新しい規約を押しつけないようにしてください。

規約（命名、スコープ、構造など）が不明な場合は、まず Figma ファイルを確認し、次にユーザーのコードベースを確認してください。どちらにも存在しない場合に限り、一般的なパターンを使ってください。

### 簡単な確認用スクリプト

**すべてのページと最上位ノードを一覧表示する:**
```js
const pages = figma.root.children.map(p => `${p.name} id=${p.id} children=${p.children.length}`);
return pages.join('\n');
```

**すべてのページにある既存のコンポーネントを一覧表示する:**
```js
const results = [];
for (const page of figma.root.children) {
  await figma.setCurrentPageAsync(page);
  page.findAll(n => {
    if (n.type === 'COMPONENT' || n.type === 'COMPONENT_SET')
      results.push(`[${page.name}] ${n.name} (${n.type}) id=${n.id}`);
    return false;
  });
}
return results.join('\n');
```

**既存の変数コレクションとその規約を一覧表示する:**
```js
const collections = await figma.variables.getLocalVariableCollectionsAsync();
const results = collections.map(c => ({
  name: c.name, id: c.id,
  varCount: c.variableIds.length,
  modes: c.modes.map(m => m.name)
}));
return results;
```

## 9. 参考ドキュメント

タスクの内容に応じて、必要なものを読み込んでください。

| ドキュメント | 読み込むタイミング | 内容 |
|-----|-------------|----------------|
| [gotchas.md](references/gotchas.md) | `use_figma` の前 | 判明しているすべての落とし穴と、誤ったコード／正しいコードの例 |
| [common-patterns.md](references/common-patterns.md) | 動作するコード例が必要なとき | スクリプトのひな型：図形、テキスト、オートレイアウト、変数、コンポーネント、複数ステップのワークフロー |
| [plugin-api-patterns.md](references/plugin-api-patterns.md) | ノードの作成・編集時 | 塗り、線、オートレイアウト、エフェクト、グループ化、複製、スタイル |
| [api-reference.md](references/api-reference.md) | 正確な API の仕様が必要なとき | ノードの作成、変数 API、主要プロパティ、動作するものとしないもの |
| [validation-and-recovery.md](references/validation-and-recovery.md) | 複数ステップの書き込みやエラーからの復旧時 | `get_metadata` と `get_screenshot` のワークフロー、必須のエラー復旧手順 |
| [component-patterns.md](references/component-patterns.md) | コンポーネント／バリアントの作成時 | combineAsVariants、コンポーネントプロパティ、INSTANCE_SWAP、バリアントのレイアウト、既存コンポーネントの検出、メタデータの走査 |
| [variable-patterns.md](references/variable-patterns.md) | 変数の作成・バインド時 | コレクション、モード、スコープ、エイリアス、バインドのパターン、既存変数の検出 |
| [text-style-patterns.md](references/text-style-patterns.md) | テキストスタイルの作成・適用時 | 文字サイズの段階、フォントの調査、スタイルの一覧表示、ノードへのスタイル適用 |
| [effect-style-patterns.md](references/effect-style-patterns.md) | エフェクトスタイルの作成・適用時 | ドロップシャドウ、スタイルの一覧表示、ノードへのスタイル適用 |
| [plugin-api-standalone.index.md](references/plugin-api-standalone.index.md) | API 全体の仕様を把握する必要があるとき | Plugin API のすべての型、メソッド、プロパティの一覧 |
| [plugin-api-standalone.d.ts](references/plugin-api-standalone.d.ts) | 正確な型シグネチャが必要なとき | 型定義ファイル全体。特定のシンボルを grep で検索し、一度にすべて読み込まないでください |

## 10. スニペットの例

このドキュメントには、各所にスニペットが記載されています。これらには再利用できる便利な Plugin API コードが含まれています。そのまま使うことも、作業の出発点として使うこともできます。汎用的なスニペットとして記録するのがよい重要な概念があれば、今後再利用できるように明記してファイルに保存してください。
