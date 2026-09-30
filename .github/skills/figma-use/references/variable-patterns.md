# 変数とトークンの API パターン

> [use_figma skill](../SKILL.md) の一部です。Plugin API を使って変数を正しく作成、バインド、スコープ設定、エイリアス設定する方法を説明します。
>
> デザインシステムのコンテキスト（エイリアス戦略、モードの決定、コード構文の方針、グループ化の規約）については、[wwds-variables](working-with-design-systems/wwds-variables.md) を参照してください。

## 目次

- 変数コレクションとモードの作成
- 変数の作成（全タイプ）
- ノードのプロパティへの変数のバインド
- 変数スコープ：概要と設定方法
- 変数のエイリアス設定（VARIABLE_ALIAS）
- コード構文（setVariableCodeSyntax）
- ファイル内の既存変数の確認
- エフェクトスタイル（影用）


## 変数コレクションとモードの作成

```javascript
const collection = figma.variables.createVariableCollection("MyCollection");

// A new collection starts with 1 mode named "Mode 1" — always rename it
collection.renameMode(collection.modes[0].modeId, "Light");

// Add additional modes (returns the new modeId)
const darkModeId = collection.addMode("Dark");
const lightModeId = collection.modes[0].modeId;
```

**モード数の上限はプランによって異なります：** Free は 1 モード、Professional は最大 4 モード、Organization/Enterprise は 40 以上です。多数のモードが必要な場合は、複数のコレクションに分けてください。

## 変数の作成（全タイプ）

`figma.variables.createVariable(name, collection, resolvedType)` — 第 2 引数にはコレクションオブジェクトまたは ID 文字列を指定できます（オブジェクトを推奨）。

```javascript
// COLOR — values use {r, g, b, a} (all 0–1 range, includes alpha)
const colorVar = figma.variables.createVariable("my-color", collection, "COLOR");
colorVar.setValueForMode(modeId, { r: 0.2, g: 0.36, b: 0.96, a: 1 });

// FLOAT — for spacing, radii, sizing, numeric values
const floatVar = figma.variables.createVariable("my-spacing", collection, "FLOAT");
floatVar.setValueForMode(modeId, 16);

// STRING — for font families, font style names, any text value
const stringVar = figma.variables.createVariable("my-font", collection, "STRING");
stringVar.setValueForMode(modeId, "Inter");

// BOOLEAN
const boolVar = figma.variables.createVariable("my-flag", collection, "BOOLEAN");
boolVar.setValueForMode(modeId, true);
```

**注：** ペイントの色には `{r, g, b}`（アルファ値なし）を使いますが、COLOR 変数の値には `{r, g, b, a}`（アルファ値あり）を使います。混同しないでください。

## ノードのプロパティへの変数のバインド

### 色のバインド（塗り、線）

`setBoundVariableForPaint` は**新しいペイント**を返します。戻り値を必ず受け取ってください。

```javascript
// Create a base paint, bind the variable, assign the result
const basePaint = { type: 'SOLID', color: { r: 0, g: 0, b: 0 } };
const boundPaint = figma.variables.setBoundVariableForPaint(basePaint, "color", colorVar);
node.fills = [boundPaint];

// Only SOLID paints support color variable binding — gradients/images will throw
```

### 数値のバインド（間隔、角丸、サイズ）

`setBoundVariable` は FLOAT/STRING/BOOLEAN 変数をノードのプロパティにバインドします。

```javascript
// Padding
node.setBoundVariable("paddingTop", spacingVar);
node.setBoundVariable("paddingBottom", spacingVar);
node.setBoundVariable("paddingLeft", spacingVar);
node.setBoundVariable("paddingRight", spacingVar);

// Gap
node.setBoundVariable("itemSpacing", gapVar);
node.setBoundVariable("counterAxisSpacing", gapVar);

// Corner radius — use individual corners, NOT cornerRadius
node.setBoundVariable("topLeftRadius", radiusVar);
node.setBoundVariable("topRightRadius", radiusVar);
node.setBoundVariable("bottomLeftRadius", radiusVar);
node.setBoundVariable("bottomRightRadius", radiusVar);

// Size
node.setBoundVariable("width", sizeVar);
node.setBoundVariable("height", sizeVar);
node.setBoundVariable("minWidth", sizeVar);
node.setBoundVariable("maxWidth", sizeVar);

// Other
node.setBoundVariable("opacity", opacityVar);
node.setBoundVariable("strokeWeight", strokeVar);
```

**setBoundVariable ではバインドできません：** `fontSize`、`fontWeight`、`lineHeight` — これらはテキストノードに直接設定してください。

### エフェクトのバインド

```javascript
const effectCopy = JSON.parse(JSON.stringify(node.effects[0]));
const newEffect = figma.variables.setBoundVariableForEffect(effectCopy, "color", colorVar);
// ⚠️ Returns a NEW effect — must capture return value!
node.effects = [newEffect];
// Valid fields: "color" (COLOR), "radius" | "spread" | "offsetX" | "offsetY" (FLOAT)
```

### フレームへのモードの適用

```javascript
// All bound children of this frame will resolve to the specified mode's values
frame.setExplicitVariableModeForCollection(collection.id, modeId);
```

これを設定しない場合、すべてのノードでコレクションのデフォルト（最初の）モードが使われます。

## 変数スコープ：概要と設定方法

`variable.scopes` は、どの Figma プロパティのピッカーにその変数を表示するかを制御します。デフォルトは `["ALL_SCOPES"]` で、あらゆる場所に表示されます。これはほとんどの場合、望ましくありません。

```javascript
variable.scopes = ["FRAME_FILL", "SHAPE_FILL"];  // only fill pickers
variable.scopes = ["TEXT_FILL"];                   // only text color picker
variable.scopes = ["GAP"];                         // only gap/spacing pickers
variable.scopes = ["CORNER_RADIUS"];               // only radius pickers
variable.scopes = [];                              // hidden from all pickers
```

**有効なスコープ値：**
`ALL_SCOPES`、`TEXT_CONTENT`、`CORNER_RADIUS`、`WIDTH_HEIGHT`、`GAP`、`ALL_FILLS`、`FRAME_FILL`、`SHAPE_FILL`、`TEXT_FILL`、`STROKE_COLOR`、`STROKE_FLOAT`、`EFFECT_FLOAT`、`EFFECT_COLOR`、`OPACITY`、`FONT_FAMILY`、`FONT_STYLE`、`FONT_WEIGHT`、`FONT_SIZE`、`LINE_HEIGHT`、`LETTER_SPACING`、`PARAGRAPH_SPACING`、`PARAGRAPH_INDENT`

**変数を作成する前に、必ず既存ファイルのスコープのパターンを確認してください** — すでに使われている規約に合わせます。下記の「既存変数の確認」を参照してください。

## 変数のエイリアス設定（VARIABLE_ALIAS）

変数の値はエイリアスを介して別の変数を参照できます。セマンティックトークンがプリミティブトークンを参照する際に使う方法です。

```javascript
// Set a variable's value as an alias to another variable
semanticVar.setValueForMode(modeId, {
  type: 'VARIABLE_ALIAS',
  id: primitiveVar.id
});
```

プリミティブが変更されると、すべてのモードでセマンティック変数が自動的に更新されます。

## コード構文（setVariableCodeSyntax）

Figma の変数を対応するコードに関連付けます。プラットフォームごとに 1 回呼び出してください。

```javascript
variable.setVariableCodeSyntax('WEB', 'var(--color-bg-default)');
variable.setVariableCodeSyntax('ANDROID', 'colorBgDefault');
variable.setVariableCodeSyntax('iOS', 'Color.bgDefault');

// Read back: variable.codeSyntax → { WEB: '...', ANDROID: '...', iOS: '...' }
```

**Figma の名前から CSS 名を導出する場合は、スラッシュとスペースの両方をハイフンに置き換えてください：**

```javascript
// WRONG — leaves spaces in CSS variable name
`var(--${figmaName.replace(/\//g, '-').toLowerCase()})`

// CORRECT — replace all whitespace and slashes
`var(--${figmaName.replace(/[\s\/]+/g, '-').toLowerCase()})`

// BEST — use the original CSS variable name from the source, not a derived one
`var(${token.cssVar})`
```

## ファイル内の既存変数の確認

**新しい変数を作成する前に、必ずファイル内の既存変数を確認してください。** ファイルごとに命名規則、スコープのパターン、コレクションの構成は異なります。既存の規約に合わせてください。

### モード情報を含めてコレクションを一覧表示する

```javascript
(async () => {
  try {
    const collections = figma.variables.getLocalVariableCollections();
    const results = collections.map(c => ({
      name: c.name,
      id: c.id,
      varCount: c.variableIds.length,
      modes: c.modes.map(m => ({ name: m.name, id: m.modeId }))
    }));
    figma.closePlugin(JSON.stringify(results));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})()
```

### 既存変数で使われているスコープのパターンを確認する

```javascript
(async () => {
  try {
    const collections = figma.variables.getLocalVariableCollections();
    const scopeGroups = {};
    for (const c of collections) {
      for (const id of c.variableIds) {
        const v = figma.variables.getVariableById(id);
        const key = JSON.stringify(v.scopes);
        if (!scopeGroups[key]) scopeGroups[key] = [];
        scopeGroups[key].push(v.name);
      }
    }
    figma.closePlugin(JSON.stringify(scopeGroups));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})()
```

### 再利用用に名前→変数の対応表を作成する

```javascript
const varByName = {};
for (const v of figma.variables.getLocalVariables()) {
  varByName[v.name] = v;
}

// Bind to existing variable by name — no hex values needed
function bindFill(node, varName) {
  const v = varByName[varName];
  if (!v) throw new Error(`Variable not found: ${varName}`);
  const paint = figma.variables.setBoundVariableForPaint(
    { type: 'SOLID', color: { r: 0, g: 0, b: 0 } }, 'color', v
  );
  node.fills = [paint];
}
```

**ファイル内に一致するものがないトークンに限り、新しい変数を作成してください。** 対応表を作成したら、必要なトークンと照合し、差分に当たる変数だけを作成します。

## すべての変数の詳細を含めてコレクションを一覧表示する

非同期 API は、各変数のコード構文やスコープを含む、より詳細なデータを返します。

```javascript
/**
 * Lists all local variable collections defined in the current Figma file,
 * including metadata for their modes and variables.
 *
 * @returns {Promise<Array<{
 *   name: string,
 *   id: string,
 *   modes: Array<[name: string, modeId: string]>,
 *   variables: Array<[name: string, id: string, codeSyntax: object, scopes: string[]]>
 * }>>}
 */
async function listVariableCollectionsAndVariables() {
  const collections = await figma.variables.getLocalVariableCollectionsAsync();
  const results = [];
  for (const collection of collections) {
    const vars = [];
    for (const id of collection.variableIds) {
      const v = await figma.variables.getVariableByIdAsync(id);
      vars.push([v.name, v.id, v.codeSyntax, v.scopes]);
    }
    results.push({
      name: collection.name,
      id: collection.id,
      modes: collection.modes.map(m => [m.name, m.modeId]),
      variables: vars
    });
  }
  return results;
}
```

そのまま実行できる完全なスクリプト：

```javascript
(async () => {
  try {
    const results = await listVariableCollectionsAndVariables();
    figma.closePlugin(JSON.stringify(results));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})()
```

## コード構文の設定と削除

変数が定義されているファイル内で実行する必要があります。

```javascript
/**
 * Set the code syntax for a variable for a specific platform.
 *
 * @param {string} variableId
 * @param {'WEB'|'ANDROID'|'iOS'} platform
 * @param {string} syntax
 */
async function setVariableCodeSyntax(variableId, platform, syntax) {
  const variable = await figma.variables.getVariableByIdAsync(variableId);
  variable.setVariableCodeSyntax(platform, syntax);
}

/**
 * Remove code syntax for a variable for one or more platforms.
 *
 * @param {string} variableId
 * @param {Array<'WEB'|'ANDROID'|'iOS'>} platforms — defaults to all three
 */
async function removeVariableCodeSyntax(variableId, platforms = ["WEB", "ANDROID", "iOS"]) {
  const variable = await figma.variables.getVariableByIdAsync(variableId);
  for (const platform of platforms) {
    variable.removeVariableCodeSyntax(platform);
  }
}

/**
 * Set a value for a variable in a specific mode.
 * For aliases, value must be: { type: 'VARIABLE_ALIAS', id: '<variableId>' }
 *
 * @param {string} variableId
 * @param {string} modeId
 * @param {string|number|boolean|RGB|RGBA|{type: 'VARIABLE_ALIAS', id: string}} value
 */
async function setVariableValueForMode(variableId, modeId, value) {
  const variable = await figma.variables.getVariableByIdAsync(variableId);
  variable.setValueForMode(modeId, value);
}
```

## エフェクトスタイル（影用）

影は変数として保存できません。エフェクトスタイルを使ってください。詳しいパターンについては、[effect-style-patterns.md](effect-style-patterns.md) を参照してください。

```javascript
const shadow = figma.createEffectStyle();
shadow.name = "Shadow/Subtle";
shadow.effects = [{
  type: "DROP_SHADOW",
  color: { r: 0, g: 0, b: 0, a: 0.06 },
  offset: { x: 0, y: 2 },
  radius: 8,
  spread: 0,
  visible: true,
  blendMode: "NORMAL"
}];

// Apply to a node
frame.effectStyleId = shadow.id;
```