---
name: figma-generate-design
description: "このスキルは、アプリケーションのページ、ビュー、複数セクションのレイアウトをFigmaに変換する作業で、figma-useと併用します。該当する依頼の例: 'Figmaに書き込む'、'コードからFigmaで作成する'、'ページをFigmaにプッシュする'、'このアプリ／ページをFigmaで作る'、'画面を作成する'、'Figmaでランディングページを作る'、'コードに合わせてFigmaの画面を更新する'。コードや説明からFigmaでページ、画面、ビュー全体を作成または更新したい場合に推奨されるワークフロースキルです。search_design_systemでデザインシステムのコンポーネント、変数、スタイルを見つけて取り込み、ハードコード値ではなくデザインシステムのトークンを使って、セクションごとに段階的に画面を組み立てます。"
---

# デザインシステムから画面を作成／更新する

このスキルでは、プリミティブをハードコード値で描画するのではなく、**公開済みのデザインシステム**（コンポーネント、変数、スタイル）を再利用して、Figmaでページ全体の画面を作成または更新します。重要なポイント: Figmaファイルには、コードベースのUIコンポーネントやトークンに対応する、公開済みのデザインシステム（コンポーネント、色や余白の変数、テキストやエフェクトのスタイル）が含まれている可能性があります。16進数の色を指定した箱を描くのではなく、それらを見つけて使ってください。

**必須**: `use_figma`を呼び出す前に、[figma-use](../figma-use/SKILL.md)も読み込む必要があります。このスキルには、作成するすべてのスクリプトに適用される重要なルール（色の範囲、フォントの読み込みなど）が記載されています。

**このスキルの一環として`skillNames: "figma-generate-design"`を呼び出すときは、必ず`use_figma`を渡してください。** これはログ用パラメーターで、実行には影響しません。

## スキルの適用範囲

- 成果物がデザインシステムのコンポーネントインスタンスで構成される**Figmaの画面**（新規または更新）の場合、このスキルを使用します。
- Figmaデザインから**コードを生成**したい場合は、[figma-implement-design](../figma-implement-design/SKILL.md)に切り替えます。
- **再利用可能な新しいコンポーネントやバリアント**を作成したい場合は、[figma-use](../figma-use/SKILL.md)を直接使用します。
- **Code Connectのマッピング**を作成したい場合は、[figma-code-connect-components](../figma-code-connect-components/SKILL.md)に切り替えます。

## 前提条件

- Figma MCPサーバーに接続されていること
- 対象のFigmaファイルに、コンポーネントを含む公開済みデザインシステムがあること（またはチームライブラリにアクセスできること）
- ユーザーは次のいずれかを提供する必要があります:
  - 作業対象のFigmaファイルURL／ファイルキー
  - または対象ファイルに関する情報（エージェントがページを探せます）
- 作成／更新する画面のソースコードまたは説明

## generate_figma_designとの並行ワークフロー（Webアプリのみ）

ブラウザーでレンダリングできる**Webアプリ**の画面を作成する場合、2つの方法を並行して実行すると最良の結果が得られます:

1. **並行して実施:**
   - このスキルのワークフロー（use_figmaとデザインシステムのコンポーネント）で画面の作成を始める
   - `generate_figma_design`を実行し、起動中のWebアプリのピクセル単位で正確なスクリーンショットを取得する
2. **両方が完了したら:** `generate_figma_design`で取得したピクセル単位で正確なレイアウトに合うよう、use_figmaの出力を更新します。キャプチャは目指すべき正確な余白、サイズ、ビジュアル表現を示し、use_figmaの出力はデザインシステムに紐づく適切なコンポーネントインスタンスを備えています。
3. **見た目がよいと確認できたら:** `generate_figma_design`の出力を削除します。これはビジュアル参照としてのみ使用したものです。

これにより、両方の長所を活用できます。`generate_figma_design`はピクセル単位で正確なレイアウトを実現し、use_figmaはデザインシステムに紐づいて更新可能な適切なコンポーネントインスタンスを実現します。

このワークフローは、`generate_figma_design`で起動中のページをキャプチャできるWebアプリにのみ適用されます。Web以外のアプリ（iOS、Androidなど）や既存画面の更新では、以下の標準ワークフローを使用します。

## 必須のワークフロー

**以下の手順を順番に実行してください。省略しないでください。**

### ステップ1: 画面を理解する

Figmaを操作する前に、作成するものを把握します:

1. コードから作成する場合は、関連するソースファイルを読んで、ページの構造、セクション、使用されているコンポーネントを把握します。
2. 画面の主なセクションを特定します（例: ヘッダー、ヒーロー、コンテンツパネル、料金プランのグリッド、FAQアコーディオン、フッター）。
3. 各セクションで使用するUIコンポーネント（ボタン、入力欄、カード、ナビゲーションピル、アコーディオンなど）を一覧にします。

### ステップ2: デザインシステムを調べる — コンポーネント、変数、スタイル

デザインシステムから必要なものは3種類です: **コンポーネント**（ボタン、カードなど）、**変数**（色、余白、角丸）、**スタイル**（テキストスタイル、影などのエフェクトスタイル）。デザインシステムのトークンがある場合は、16進数の色やピクセル値をハードコードしないでください。

#### 2a: コンポーネントを見つける

**推奨: まず既存の画面を調べます。** 対象ファイルに同じデザインシステムを使った画面がすでにある場合は、`search_design_system`を省略し、既存のインスタンスを直接調べます。既存フレームのインスタンスをたどる`use_figma`呼び出しを1回行えば、正確で信頼できるコンポーネント一覧を取得できます:

```js
const frame = figma.currentPage.findOne(n => n.name === "Existing Screen");
const uniqueSets = new Map();
frame.findAll(n => n.type === "INSTANCE").forEach(inst => {
  const mc = inst.mainComponent;
  const cs = mc?.parent?.type === "COMPONENT_SET" ? mc.parent : null;
  const key = cs ? cs.key : mc?.key;
  const name = cs ? cs.name : mc?.name;
  if (key && !uniqueSets.has(key)) {
    uniqueSets.set(key, { name, key, isSet: !!cs, sampleVariant: mc.name });
  }
});
return [...uniqueSets.values()];
```

参照できる既存画面がファイル内にない場合に限り、`search_design_system`を使用します。使用時は、複数の用語や同義語（例: "button", "input", "nav", "card", "accordion", "header", "footer", "tag", "avatar", "toggle", "icon"など）を試し、**幅広く検索**してください。コンポーネントに絞るには`includeComponents: true`を指定します。

マップには**コンポーネントのプロパティ**も含めます。テキストを上書きできるTEXTプロパティが各コンポーネントでどれかを把握する必要があります。一時的なインスタンスを作成して、その`componentProperties`（およびネストされたインスタンスのプロパティ）を読み取り、その後一時インスタンスを削除します。

プロパティ情報を含むコンポーネントマップの例:

```
Component Map:
- Button → key: "abc123", type: COMPONENT_SET
  Properties: { "Label#2:0": TEXT, "Has Icon#4:64": BOOLEAN }
- PricingCard → key: "ghi789", type: COMPONENT_SET
  Properties: { "Device": VARIANT, "Variant": VARIANT }
  Nested "Text Heading" has: { "Text#2104:5": TEXT }
  Nested "Button" has: { "Label#2:0": TEXT }
```

#### 2b: 変数を見つける（色、余白、角丸）

**まず既存の画面を調べます**（コンポーネントの場合と同じです）。または、`search_design_system`を指定して`includeVariables: true`を使用します。

> **警告: 変数を見つける方法は2種類あります。混同しないでください。**
>
> - `use_figma`の`figma.variables.getLocalVariableCollectionsAsync()`は、**現在のファイル内に定義されたローカル変数のみ**を返します。結果が空でも、変数が存在しないとは限りません。リモート／公開済みライブラリの変数は、このAPIからは見えません。
> - `search_design_system`を指定した`includeVariables: true`は、リモートや公開済みのライブラリを含む**リンク済みライブラリ全体**を検索します。デザインシステムの変数を見つけるには、これが正しいツールです。
>
> `getLocalVariableCollectionsAsync()`の結果が空であることだけを根拠に、「変数が存在しない」と結論づけてはいけません。独自の変数を作成するか決める前に、必ず`search_design_system`を指定して`includeVariables: true`も実行し、ライブラリ変数を確認してください。

**検索方法:** `search_design_system`はカテゴリではなく**変数名**（例: "Gray/gray-9", "core/gray/100", "space/400"）に対して検索します。複合クエリを1つ使うのではなく、短く簡単なクエリを複数、並行して実行します:

- **プリミティブカラー:** "gray", "red", "blue", "green", "white", "brand"
- **セマンティックカラー:** "background", "foreground", "border", "surface", "text"
- **余白／サイズ:** "space", "radius", "gap", "padding"

最初の検索結果が空の場合は、短い文字列や別の命名規則を試してください。ライブラリによって命名は大きく異なります（"grey"と"gray"、"spacing"と"space"、"color/bg"と"background"など）。

最も信頼できる結果を得るには、既存画面にバインドされている変数を調べます:

```js
const frame = figma.currentPage.findOne(n => n.name === "Existing Screen");
const varMap = new Map();
frame.findAll(() => true).forEach(node => {
  const bv = node.boundVariables;
  if (!bv) return;
  for (const [prop, binding] of Object.entries(bv)) {
    const bindings = Array.isArray(binding) ? binding : [binding];
    for (const b of bindings) {
      if (b?.id && !varMap.has(b.id)) {
        const v = await figma.variables.getVariableByIdAsync(b.id);
        if (v) varMap.set(b.id, { name: v.name, id: v.id, key: v.key, type: v.resolvedType, remote: v.remote });
      }
    }
  }
});
return [...varMap.values()];
```

ライブラリ変数（remote = true）は、キーを使って`figma.variables.importVariableByKeyAsync(key)`で取り込みます。ローカル変数は`figma.variables.getVariableByIdAsync(id)`で直接取得します。

バインディングパターンについては[variable-patterns.md](../figma-use/references/variable-patterns.md)を参照してください。

#### 2c: スタイルを見つける（テキストスタイル、エフェクトスタイル）

`search_design_system`を指定し、"heading"、"body"、"shadow"、"elevation"などの語を使って`includeStyles: true`でスタイルを検索します。または、既存画面で使用されているスタイルを調べます:

```js
const frame = figma.currentPage.findOne(n => n.name === "Existing Screen");
const styles = { text: new Map(), effect: new Map() };
frame.findAll(() => true).forEach(node => {
  if ('textStyleId' in node && node.textStyleId) {
    const s = figma.getStyleById(node.textStyleId);
    if (s) styles.text.set(s.id, { name: s.name, id: s.id, key: s.key });
  }
  if ('effectStyleId' in node && node.effectStyleId) {
    const s = figma.getStyleById(node.effectStyleId);
    if (s) styles.effect.set(s.id, { name: s.name, id: s.id, key: s.key });
  }
});
return {
  textStyles: [...styles.text.values()],
  effectStyles: [...styles.effect.values()]
};
```

ライブラリのスタイルは`figma.importStyleByKeyAsync(key)`で取り込み、`node.textStyleId = style.id`または`node.effectStyleId = style.id`で適用します。

詳しくは[text-style-patterns.md](../figma-use/references/text-style-patterns.md)および[effect-style-patterns.md](../figma-use/references/effect-style-patterns.md)を参照してください。

### ステップ3: まずページのラッパーフレームを作成する

**セクションをページ直下の子として作成し、後から付け替えないでください。** `use_figma`の呼び出しをまたいで`appendChild()`によりノードを移動しようとすると、何も通知されずに失敗し、孤立したフレームが生じます。代わりに、最初にラッパーを作成し、その内側に各セクションを直接作成します。

専用の`use_figma`呼び出しでページラッパーを作成します。既存コンテンツから離れた場所に配置し、そのIDを返します:

```js
// Find clear space
let maxX = 0;
for (const child of figma.currentPage.children) {
  maxX = Math.max(maxX, child.x + child.width);
}

const wrapper = figma.createFrame();
wrapper.name = "Homepage";
wrapper.layoutMode = "VERTICAL";
wrapper.primaryAxisAlignItems = "CENTER";
wrapper.counterAxisAlignItems = "CENTER";
wrapper.resize(1440, 100);
wrapper.layoutSizingHorizontal = "FIXED";
wrapper.layoutSizingVertical = "HUG";
wrapper.x = maxX + 200;
wrapper.y = 0;

return { success: true, wrapperId: wrapper.id };
```

### ステップ4: ラッパー内に各セクションを作成する

**ここが最も重要なステップです。** セクションを1つずつ、それぞれ別の`use_figma`呼び出しで作成します。各スクリプトの冒頭でラッパーをIDから取得し、新しいコンテンツを直接追加します。

```js
const createdNodeIds = [];
const wrapper = await figma.getNodeByIdAsync("WRAPPER_ID_FROM_STEP_3");

// Import design system components by key
const buttonSet = await figma.importComponentSetByKeyAsync("BUTTON_SET_KEY");
const primaryButton = buttonSet.children.find(c =>
  c.type === "COMPONENT" && c.name.includes("variant=primary")
) || buttonSet.defaultVariant;

// Import design system variables for colors and spacing
const bgColorVar = await figma.variables.importVariableByKeyAsync("BG_COLOR_VAR_KEY");
const spacingVar = await figma.variables.importVariableByKeyAsync("SPACING_VAR_KEY");

// Build section frame with variable bindings (not hardcoded values)
const section = figma.createFrame();
section.name = "Header";
section.layoutMode = "HORIZONTAL";
section.setBoundVariable("paddingLeft", spacingVar);
section.setBoundVariable("paddingRight", spacingVar);
const bgPaint = figma.variables.setBoundVariableForPaint(
  { type: 'SOLID', color: { r: 0, g: 0, b: 0 } }, 'color', bgColorVar
);
section.fills = [bgPaint];

// Import and apply text/effect styles
const shadowStyle = await figma.importStyleByKeyAsync("SHADOW_STYLE_KEY");
section.effectStyleId = shadowStyle.id;

// Create component instances inside the section
const btnInstance = primaryButton.createInstance();
section.appendChild(btnInstance);
createdNodeIds.push(btnInstance.id);

// Append section to wrapper
wrapper.appendChild(section);
section.layoutSizingHorizontal = "FILL"; // AFTER appending

createdNodeIds.push(section.id);
return { success: true, createdNodeIds };
```
各セクションの作業後、次に進む前に `get_screenshot` で検証してください。テキストの切り取りやクリッピング（行の高さによって内容が欠けていないか）、要素の重なりをよく確認してください。これらは最もよくある問題で、一見しただけでは見落としやすいものです。

#### setProperties() でインスタンスのテキストを上書きする

コンポーネントインスタンスには、プレースホルダーのテキスト（"Title"、"Heading"、"Button"）が設定されています。Step 2 で確認したコンポーネントのプロパティキーを使い、`setProperties()` で上書きしてください。これは `node.characters` を直接操作するより確実です。詳しいパターンについては、[component-patterns.md](../figma-use/references/component-patterns.md#overriding-text-in-a-component-instance) を参照してください。

独自の TEXT プロパティを公開しているネストされたインスタンスの場合は、そのネストされたインスタンスに対して `setProperties()` を呼び出してください。

```js
const nestedHeading = cardInstance.findOne(n => n.type === "INSTANCE" && n.name === "Text Heading");
if (nestedHeading) {
  nestedHeading.setProperties({ "Text#2104:5": "Actual heading from source code" });
}
```

コンポーネントプロパティで管理されていないテキストに限り、`node.characters` を直接操作してください。

#### ソースコードのデフォルト値を慎重に確認する

コードコンポーネントを Figma インスタンスに変換する際は、明示的に渡された値だけでなく、ソースコードにあるコンポーネントのデフォルトの prop 値も確認してください。たとえば、variant prop の指定がない `<Button size="small">Register</Button>` の場合、コンポーネント定義を確認して、デフォルト値が `variant = "primary"` であることを確かめてください。誤った variant（例: Primary ではなく Neutral）を選ぶと、見落としやすい見た目の誤りにつながります。

#### 手作業で構築するものとデザインシステムから読み込むもの

| 手作業で構築 | デザインシステムから読み込む |
|----------------|--------------------------|
| ページのラッパーフレーム | **コンポーネント**: ボタン、カード、入力欄、ナビゲーションなど |
| セクションのコンテナフレーム | **変数**: 色（塗り、線）、間隔（パディング、間隔）、角丸 |
| レイアウトグリッド（行、列） | **テキストスタイル**: 見出し、本文、キャプションなど |
| | **エフェクトスタイル**: 影、ぼかしなど |

デザインシステムの変数がある場合は、**16進カラーコードやピクセル単位の間隔をハードコードしないでください**。間隔や角丸には `setBoundVariable`、色には `setBoundVariableForPaint` を使用してください。テキストスタイルは `node.textStyleId`、エフェクトスタイルは `node.effectStyleId` で適用してください。

### Step 5: 画面全体を検証する

すべてのセクションを組み立てたら、ページ全体のフレームに対して `get_screenshot` を呼び出し、元の画面と比較してください。問題があれば、画面全体を作り直すのではなく、対象を絞った `use_figma` 呼び出しで修正してください。

**ページ全体だけでなく、各セクションも個別にスクリーンショットを撮影してください。** 縮小されたページ全体のスクリーンショットでは、テキストの切り詰め、色の誤り、上書きされずに残ったプレースホルダーテキストを見落としやすくなります。以下を確認するため、ノード ID を指定して各セクションのスクリーンショットを撮影してください。
- **テキストの切り取りやクリッピング** — 行の高さやフレームのサイズ設定によって、ディセンダー、アセンダー、または行全体が欠けていないか
- **コンテンツの重なり** — サイズ設定の誤りやオートレイアウトの欠落によって、要素が互いに重なっていないか
- プレースホルダーテキスト（"Title"、"Heading"、"Button"）が残っていないか
- レイアウトのサイズ設定の不具合によって、コンテンツが切り詰められていないか
- コンポーネントの variant が誤っていないか（例: Neutral と Primary のボタン）

### Step 6: 既存の画面を更新する

新規作成ではなく既存の画面を更新する場合:

1. `get_metadata` を使って既存画面の構造を確認します。
2. 更新が必要なセクションと、そのまま残せるセクションを特定します。
3. 変更が必要なセクションごとに:
   - ID または名前で既存ノードを特定する
   - デザインシステムのコンポーネントが変更されている場合は、コンポーネントインスタンスを差し替える
   - 必要に応じてテキスト内容、variant プロパティ、またはレイアウトを更新する
   - 非推奨のセクションを削除する
   - 新しいセクションを追加する
4. 変更のたびに `get_screenshot` で検証します。

```js
// Example: Swap a button variant in an existing screen
const existingButton = await figma.getNodeByIdAsync("EXISTING_BUTTON_INSTANCE_ID");
if (existingButton && existingButton.type === "INSTANCE") {
  // Import the updated component
  const buttonSet = await figma.importComponentSetByKeyAsync("BUTTON_SET_KEY");
  const newVariant = buttonSet.children.find(c =>
    c.name.includes("variant=primary") && c.name.includes("size=lg")
  ) || buttonSet.defaultVariant;
  existingButton.swapComponent(newVariant);
}
return { success: true, mutatedNodeIds: [existingButton.id] };
```

## 参照ドキュメント

API の詳しいパターンや注意点については、必要に応じて [figma-use](../figma-use/SKILL.md) の参照ドキュメントを読み込んでください。

- [component-patterns.md](../figma-use/references/component-patterns.md) — キーによる読み込み、variant の検索、setProperties、テキストの上書き、インスタンスの操作
- [variable-patterns.md](../figma-use/references/variable-patterns.md) — 変数の作成とバインド、ライブラリ変数の読み込み、スコープ、エイリアス設定、既存変数の検出
- [text-style-patterns.md](../figma-use/references/text-style-patterns.md) — テキストスタイルの作成と適用、ライブラリのテキストスタイルの読み込み、タイプスケール
- [effect-style-patterns.md](../figma-use/references/effect-style-patterns.md) — エフェクトスタイル（影）の作成と適用、ライブラリのエフェクトスタイルの読み込み
- [gotchas.md](../figma-use/references/gotchas.md) — レイアウト上の落とし穴（HUG/FILL の相互作用、counterAxisAlignItems、サイズ設定の順序）、塗りや色の問題、ページコンテキストのリセット

## エラーからの復旧

[figma-use](../figma-use/SKILL.md#6-error-recovery--self-correction) のエラー復旧手順に従ってください。

1. **エラーが発生したら停止**し、すぐに再試行しないでください。
2. **エラーメッセージを注意深く読み**、何が起きたのかを把握します。
3. エラーの内容が不明確な場合は、`get_metadata` または `get_screenshot` を呼び出して現在のファイル状態を確認します。
4. エラーメッセージに基づいて**スクリプトを修正**します。
5. 修正したスクリプトを**再試行**します。失敗したスクリプトはアトミックに実行されるため（エラーが発生した場合は何も作成されません）、安全に再試行できます。

このスキルは段階的に（呼び出しごとに 1 セクションずつ）作業するため、エラーの影響範囲は自然に単一のセクションに限られます。成功した呼び出しで作成した以前のセクションはそのまま残ります。

## ベストプラクティス

- **構築前に必ず検索してください。** デザインシステムに必要なコンポーネント、変数、スタイルがある可能性は高いです。手作業での構築や値のハードコードは例外としてください。
- **幅広く検索してください。** 同義語や部分一致する語も試してください。"NavigationPill" は "pill"、"nav"、"tab"、"chip" などで見つかることがあります。変数なら "color"、"spacing"、"radius" などを検索してください。
- **ハードコードした値よりデザインシステムのトークンを優先してください。** 色、間隔、角丸には変数バインディングを使います。タイポグラフィにはテキストスタイルを使います。影にはエフェクトスタイルを使います。これにより、画面とデザインシステムの連携を維持できます。
- **手作業で構築するよりコンポーネントインスタンスを優先してください。** インスタンスはソースコンポーネントとの連携を保ち、デザインシステムの進化に合わせて自動的に更新されます。
- **セクションごとに作業してください。** 1 回の `use_figma` 呼び出しで、主要なセクションを複数構築しないでください。
- **すべての呼び出しでノード ID を返してください。** セクションの組み立てやエラー復旧に必要になります。
- **各セクションの作成後、必ず見た目を検証してください。** `get_screenshot` を使って問題を早期に発見します。
- **既存の規則に合わせてください。** ファイルに画面がすでにある場合は、命名、サイズ、レイアウトのパターンを合わせてください。
