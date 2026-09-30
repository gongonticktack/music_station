# 落とし穴とよくある間違い

> [use_figma スキル](../SKILL.md)の一部です。既知の落とし穴を、誤った例と正しいコード例とともにすべて掲載しています。

## 目次

- コンポーネントプロパティとバリアント作成に関する落とし穴
- ペイント、色、変数バインディングに関する落とし穴
- ページコンテキストとプラグインのライフサイクルに関する落とし穴
- Auto Layout とサイズ設定の順序に関する落とし穴（HUG/FILL の相互作用を含む）
- バリアントのレイアウトとジオメトリに関する落とし穴
- 変数のスコープとモードに関する落とし穴
- ノードのクリーンアップと空の塗りに関する落とし穴
- detachInstance() とノード ID の無効化


## 新しいノードはデフォルトで (0,0) に配置され、既存のコンテンツと重なる

`figma.create*()` の呼び出しはすべて、ノードを位置 (0,0) に配置します。複数のノードをページに直接追加すると、すべてが既存のコンテンツの上に積み重なって配置されます。

**これはページに直接追加するノード（つまりトップレベルノード）に限って問題になります**。ほかのフレーム、コンポーネント、または Auto Layout コンテナの子として追加されたノードは親によって配置されるため、ノードを入れ子にするときに重なりを調べる必要はありません。

```js
// WRONG — top-level node lands at (0,0), overlapping existing page content
const frame = figma.createFrame()
frame.name = "My New Frame"
frame.resize(400, 300)
figma.currentPage.appendChild(frame)

// CORRECT — find existing content bounds and place the new top-level node to the right
const page = figma.currentPage
let maxX = 0
for (const child of page.children) {
  const right = child.x + child.width
  if (right > maxX) maxX = right
}
const frame = figma.createFrame()
frame.name = "My New Frame"
frame.resize(400, 300)
figma.currentPage.appendChild(frame)
frame.x = maxX + 100  // 100px gap from rightmost existing content
frame.y = 0

// NOT NEEDED — child nodes inside a parent don't need overlap scanning
const card = figma.createFrame()
card.layoutMode = 'VERTICAL'
const label = figma.createText()
card.appendChild(label)  // positioned by auto-layout, no x/y needed
```

## `addComponentProperty` はオブジェクトではなく文字列キーを返す — 決してキーをハードコードしたり推測したりしない

Figma はプロパティキーを動的に生成します（例: `"label#4:0"`）。サフィックスは予測できません。必ず戻り値を直接受け取り、そのまま使用してください。

```js
// WRONG — guessing / hardcoding the key
comp.addComponentProperty('label', 'TEXT', 'Button')
labelNode.componentPropertyReferences = { characters: 'label#0:1' }  // Error: key not found

// WRONG — treating the return value as an object
const result = comp.addComponentProperty('Label', 'TEXT', 'Button')
const propKey = Object.keys(result)[0]  // BUG: returns '0' (first char index of string!)
labelNode.componentPropertyReferences = { characters: propKey }  // Error: property '0' not found

// CORRECT — the return value IS the key string, use it directly
const propKey = comp.addComponentProperty('Label', 'TEXT', 'Button')
// propKey === "label#4:0" (exact value varies; never assume it)
labelNode.componentPropertyReferences = { characters: propKey }
```

同じことは `COMPONENT_SET` ノードにも当てはまります。`addComponentProperty` は常にプロパティキーを文字列として返します。

## 作成・変更したノード ID をすべて必ず返す

キャンバス上のノードを作成または変更するスクリプトはすべて、影響を受けたノード ID を追跡し、`figma.closePlugin()` の応答で返す必要があります。これらの ID がないと、後続の呼び出しでノードを参照、検証、またはクリーンアップできません。

```js
// WRONG — only returns the parent frame ID, loses track of children
const frame = figma.createFrame()
const rect = figma.createRectangle()
const text = figma.createText()
frame.appendChild(rect)
frame.appendChild(text)
figma.closePlugin(JSON.stringify({ nodeId: frame.id }))

// CORRECT — returns all created node IDs in a structured response
const frame = figma.createFrame()
const rect = figma.createRectangle()
const text = figma.createText()
frame.appendChild(rect)
frame.appendChild(text)
figma.closePlugin(JSON.stringify({
  createdNodeIds: [frame.id, rect.id, text.id],
  rootNodeId: frame.id
}))

// CORRECT — when mutating existing nodes, return those IDs too
const nodes = figma.currentPage.findAll(n => n.name === 'Card')
for (const n of nodes) {
  n.fills = [{ type: 'SOLID', color: { r: 1, g: 0, b: 0 } }]
}
figma.closePlugin(JSON.stringify({
  mutatedNodeIds: nodes.map(n => n.id),
  count: nodes.length
}))
```

## 色の値の範囲は 0〜1

```js
// WRONG — will throw validation error (ZeroToOne enforced)
node.fills = [{ type: 'SOLID', color: { r: 255, g: 0, b: 0 } }]

// CORRECT
node.fills = [{ type: 'SOLID', color: { r: 1, g: 0, b: 0 } }]
```

## 塗りと線は不変の配列

```js
// WRONG — modifying in place does nothing
node.fills[0].color = { r: 1, g: 0, b: 0 }

// CORRECT — clone, modify, reassign
const fills = JSON.parse(JSON.stringify(node.fills))
fills[0].color = { r: 1, g: 0, b: 0 }
node.fills = fills
```

## setBoundVariableForPaint は新しいペイントを返す

```js
// WRONG — ignoring return value
figma.variables.setBoundVariableForPaint(paint, "color", colorVar)
node.fills = [paint]  // paint is unchanged!

// CORRECT — capture the returned new paint
const boundPaint = figma.variables.setBoundVariableForPaint(paint, "color", colorVar)
node.fills = [boundPaint]
```

## 変数コレクションには最初からモードが 1 つある

```js
// A new collection already has one mode — rename it, don't try to add first
const collection = figma.variables.createVariableCollection("Colors")
// collection.modes = [{ modeId: "...", name: "Mode 1" }]
collection.renameMode(collection.modes[0].modeId, "Light")
const darkModeId = collection.addMode("Dark")
```

## combineAsVariants が受け取れるのは ComponentNode

```js
// WRONG — passing frames
const f1 = figma.createFrame()
figma.combineAsVariants([f1], figma.currentPage) // Error!

// CORRECT — passing components
const c1 = figma.createComponent()
c1.name = "variant=primary, size=md"
const c2 = figma.createComponent()
c2.name = "variant=secondary, size=md"
figma.combineAsVariants([c1, c2], figma.currentPage)
```

## ページ切り替え: 同期セッターはエラーを投げる

同期セッター `figma.currentPage = page` は、`use_figma` のランタイム（MCP、evals、assistant）では**エラーを投げます**。代わりに `await figma.setCurrentPageAsync(page)` を使用してください。ページを切り替えて、そのコンテンツを読み込みます。

```js
// WRONG — throws "Setting figma.currentPage is not supported in this runtime"
figma.currentPage = targetPage

// CORRECT — async method switches and loads content
await figma.setCurrentPageAsync(targetPage)
```

## `get_metadata` が確認できるのは 1 ページだけ — すべてのページを調べるには `use_figma` を使う

Figma ファイルには複数のページ（キャンバスノード）を含められます。`get_metadata` が操作するのは単一のノードまたはページで、ドキュメント全体を走査することはできません。すべてのページとそのトップレベルのコンテンツを調べるには、`use_figma` を使用します。

```js
// WRONG — calling get_metadata with the file root or expecting it to list all pages
// get_metadata only returns the subtree of the node you pass it

// CORRECT — use use_figma to list pages, then inspect each one
const pages = figma.root.children.map(p => `${p.name} id=${p.id} children=${p.children.length}`);
figma.closePlugin(pages.join('\n'));
```

アイコン、変数、コンポーネントが最初のページ以外にある場合があります。ファイルに既存のアセットがないと判断する前に、必ずすべてのページを列挙してください。

## figma.notify() は使わない

```js
// WRONG — throws "not implemented" error
figma.notify("Done!")

// CORRECT — use closePlugin for messaging
figma.closePlugin("Done!")
```

## スクリプトは必ず終了させる

```js
// WRONG — no closePlugin call, script hangs
(async () => {
  figma.createRectangle()
})()

// CORRECT — always close
(async () => {
  try {
    figma.createRectangle()
    figma.closePlugin("created")
  } catch(e) {
    figma.closePluginWithFailure(e.toString())
  }
})()
```

## ペイントのフィールドに対する setBoundVariable が機能するのは SOLID ペイントのみ

```js
// Only SOLID paint type supports color variable binding
// Gradient paints, image paints, etc. will throw
const solidPaint = { type: 'SOLID', color: { r: 0, g: 0, b: 0 } }
const bound = figma.variables.setBoundVariableForPaint(solidPaint, "color", colorVar)
```

## 明示的な変数モードはコンポーネントごとに設定する必要がある

```js
// WRONG — all variants render with the default (first) mode
const colorCollection = figma.variables.createVariableCollection("Colors")
// ... create variables and modes ...
// Components all show the first mode's values by default!

// CORRECT — set explicit mode on each component to get variant-specific values
component.setExplicitVariableModeForCollection(colorCollection.id, targetModeId)
```

## `TextStyle.setBoundVariable` はヘッドレスの use_figma では使用できない

`setBoundVariable` は型付き API の `TextStyle` に存在しますが、`use_figma` 経由でスクリプトを実行する場合（MCP、ヘッドレスの assistant モード）には**使用できません**。呼び出すと `"not a function"` が投げられます。

```js
// WRONG — throws "not a function" in use_figma / headless
const ts = figma.createTextStyle()
ts.setBoundVariable("fontSize", fontSizeVar)

// CORRECT (headless) — set raw values; bind variables interactively in Figma later
const ts = figma.createTextStyle()
ts.fontSize = 24
```

これは `TextStyle` にのみ影響します。**ノード**（`node.setBoundVariable(...)`）および**ペイントオブジェクト**（`figma.variables.setBoundVariableForPaint(...)`）での変数バインディングは、ヘッドレスモードでも引き続き想定どおり機能します。

テキストスタイルでライブの変数バインディングが必要な場合は、`use_figma` を使ってスタイルを生の値で作成してから、Figma の Styles パネルまたは完全な対話型プラグインで変数をバインドしてください。

## `lineHeight` と `letterSpacing` には数値だけでなくオブジェクトを指定する

```js
// WRONG — throws or silently does nothing
style.lineHeight = 1.5
style.lineHeight = 24
style.letterSpacing = 0

// CORRECT
style.lineHeight = { unit: "AUTO" }                    // auto/intrinsic
style.lineHeight = { value: 24, unit: "PIXELS" }       // fixed pixel height
style.lineHeight = { value: 150, unit: "PERCENT" }     // percentage of font size

style.letterSpacing = { value: 0, unit: "PIXELS" }     // no tracking
style.letterSpacing = { value: -0.5, unit: "PIXELS" }  // tight
style.letterSpacing = { value: 5, unit: "PERCENT" }    // percent-based
```

このルールは `TextStyle` と `TextNode` の両方のプロパティに適用されます。また、`use_figma`、対話型プラグイン、その他すべてのプラグイン API コンテキストでも同様です。

## フォントスタイル名はファイルによって異なる — 決めつける前に確認する

フォントスタイル名は、プロバイダーや Figma ファイルごとに異なります。`"SemiBold"` と `"Semi Bold"` は別の文字列です。間違ったスタイル文字列でフォントを読み込むと、**エラーが表面化しないまま失敗したり、エラーになったりします**。共通の標準リストはありません。

```js
// WRONG — guessing style names
await figma.loadFontAsync({ family: "Inter", style: "SemiBold" }) // may throw

// CORRECT — probe which style names are available
const candidates = ["SemiBold", "Semi Bold", "Semibold"]
for (const style of candidates) {
  try {
    await figma.loadFontAsync({ family: "Inter", style })
    // capture the one that works
    break
  } catch (_) {}
}
```

タイプスケールのスクリプトを作成するときは、フォントスタイルをハードコードする前に、対象のファイルで必ず確認してください。

## combineAsVariants はヘッドレスモードで自動レイアウトしない

```js
// WRONG — all variants stack at position (0, 0), resulting in a tiny ComponentSet
const components = [comp1, comp2, comp3]
const cs = figma.combineAsVariants(components, figma.currentPage)
// cs.width/height will be the size of a SINGLE variant!

// CORRECT — manually layout children in a grid after combining
const cs = figma.combineAsVariants(components, figma.currentPage)
const colWidth = 120
const rowHeight = 56
cs.children.forEach((child, i) => {
  const col = i % numCols
  const row = Math.floor(i / numCols)
  child.x = col * colWidth
  child.y = row * rowHeight
})
// CRITICAL: resize from actual child bounds, not formula — formula errors leave variants outside the boundary
let maxX = 0, maxY = 0
for (const child of cs.children) {
  maxX = Math.max(maxX, child.x + child.width)
  maxY = Math.max(maxY, child.y + child.height)
}
cs.resizeWithoutConstraints(maxX + 40, maxY + 40)
```

## COLOR 変数の値は {r, g, b, a}（アルファ値を含む）を使う

```js
// Paint colors use {r, g, b} (no alpha — opacity is a separate paint property)
node.fills = [{ type: 'SOLID', color: { r: 1, g: 0, b: 0 } }]

// But COLOR variable values use {r, g, b, a} — alpha maps to paint opacity
const colorVar = figma.variables.createVariable("bg", collection, "COLOR")
colorVar.setValueForMode(modeId, { r: 1, g: 0, b: 0, a: 1 })  // opaque red
colorVar.setValueForMode(modeId, { r: 0, g: 0, b: 0, a: 0 })  // fully transparent

// ⚠️ Don't confuse: {r, g, b} for paint colors vs {r, g, b, a} for variable values
```

## `layoutSizingVertical`/`layoutSizingHorizontal` = `'FILL'` を設定するには、先に auto-layout の親が必要

```js
// WRONG — setting FILL before the node is a child of an auto-layout frame
const child = figma.createFrame()
child.layoutSizingVertical = 'FILL'  // ERROR: "FILL can only be set on children of auto-layout frames"
parent.appendChild(child)

// CORRECT — append to auto-layout parent FIRST, then set FILL
const child = figma.createFrame()
parent.appendChild(child)            // parent must have layoutMode set
child.layoutSizingVertical = 'FILL'  // Works!
```

## HUG の親では FILL の子が縮む

`HUG` の親は `FILL` の子に適切なサイズを与えられません。子の `layoutSizingHorizontal = "FILL"` に対して親が `"HUG"` の場合、子は最小サイズまで縮みます。FILL の子を広げるには、親を `"FILL"` または `"FIXED"` にする必要があります。これは、セレクトフィールド、入力欄、アクション行でテキストが切り詰められるよくある原因です。

```js
// WRONG — parent hugs, so FILL children get zero extra space
const parent = figma.createFrame()
parent.layoutMode = 'HORIZONTAL'
parent.layoutSizingHorizontal = 'HUG'
const child = figma.createFrame()
parent.appendChild(child)
child.layoutSizingHorizontal = 'FILL'  // collapses to min size!

// CORRECT — parent must be FIXED or FILL for FILL children to expand
const parent = figma.createFrame()
parent.layoutMode = 'HORIZONTAL'
parent.resize(400, 50)
parent.layoutSizingHorizontal = 'FIXED'  // or 'FILL' if inside another auto-layout
const child = figma.createFrame()
parent.appendChild(child)
child.layoutSizingHorizontal = 'FILL'  // expands to fill remaining 400px
```

## HUG の親で `layoutGrow` を使うとコンテンツが圧縮される

```js
// WRONG — layoutGrow on a child when parent has primaryAxisSizingMode='AUTO' (hug)
// causes the child to SHRINK below its natural size instead of expanding
const parent = figma.createComponent()
parent.layoutMode = 'VERTICAL'
parent.primaryAxisSizingMode = 'AUTO'  // hug contents
const content = figma.createFrame()
content.layoutMode = 'VERTICAL'
content.primaryAxisSizingMode = 'AUTO'
parent.appendChild(content)
content.layoutGrow = 1  // BUG: content compresses, children hidden!

// CORRECT — only use layoutGrow when parent has FIXED sizing with extra space
content.layoutGrow = 0  // let content take its natural size
// OR: set parent to FIXED sizing first
parent.primaryAxisSizingMode = 'FIXED'
parent.resizeWithoutConstraints(300, 500)
content.layoutGrow = 1  // NOW it correctly fills remaining space
```

## `resize()` は `primaryAxisSizingMode` と `counterAxisSizingMode` を FIXED にリセットする

```js
// WRONG — resize() after setting sizing mode overwrites it back to FIXED
const frame = figma.createComponent()
frame.layoutMode = 'VERTICAL'
frame.primaryAxisSizingMode = 'AUTO'  // hug height
frame.counterAxisSizingMode = 'FIXED'
frame.resize(300, 10)  // BUG: resets BOTH axes to 'FIXED'! Height stays at 10px forever.

// CORRECT — call resize() FIRST, then set sizing modes
const frame = figma.createComponent()
frame.layoutMode = 'VERTICAL'
frame.resize(300, 10)  // set initial dimensions first
frame.counterAxisSizingMode = 'FIXED'  // keep width fixed at 300
frame.primaryAxisSizingMode = 'AUTO'   // NOW set height to hug — this sticks!
// Or use the modern shorthand (equivalent):
// frame.layoutSizingHorizontal = 'FIXED'
// frame.layoutSizingVertical = 'HUG'
```

## 親を変更してもノードの位置は自動でリセットされない

```js
// WRONG — assuming positions reset when moving a node into a new parent
const node = figma.createRectangle()
node.x = 500; node.y = 500;
figma.currentPage.appendChild(node)
section.appendChild(node)  // node still at (500, 500) relative to section!

// CORRECT — explicitly set x/y after ANY reparenting operation
section.appendChild(node)
node.x = 80; node.y = 80;  // reset to desired position within section
```

## 幅の異なる行が混在するグリッドレイアウトでは重なりが発生する

```js
// WRONG — using a single column offset for rows with different-width items
// e.g. vertical cards (320px) and horizontal cards (500px) in a 2-row grid
for (let i = 0; i < allCards.length; i++) {
  allCards[i].x = (i % 4) * 370  // 370 works for 320px cards but NOT 500px cards!
}

// CORRECT — compute each row's spacing independently based on actual child widths
const gap = 50
let x = 0
for (const card of horizontalCards) {
  card.x = x
  x += card.width + gap  // use actual width, not a fixed column size
}
```

## セクションはコンテンツに合わせて自動でサイズ変更されない

```js
// WRONG — section stays at default size, content overflows
const section = figma.createSection()
section.name = "My Section"
section.appendChild(someNode) // node may be outside section bounds

// CORRECT — explicitly resize after adding content
const section = figma.createSection()
section.name = "My Section"
section.appendChild(someNode)
section.resizeWithoutConstraints(
  Math.max(someNode.width + 100, 800),
  Math.max(someNode.height + 100, 600)
)
```

## `counterAxisAlignItems` は `'STRETCH'` をサポートしない

```js
// WRONG — 'STRETCH' is not a valid enum value
comp.counterAxisAlignItems = 'STRETCH'
// Error: Invalid enum value. Expected 'MIN' | 'MAX' | 'CENTER' | 'BASELINE', received 'STRETCH'

// CORRECT — use 'MIN' on the parent, then set children to FILL on the cross axis
comp.counterAxisAlignItems = 'MIN'
comp.appendChild(child)
// For vertical layout, stretch width:
child.layoutSizingHorizontal = 'FILL'
// For horizontal layout, stretch height:
child.layoutSizingVertical = 'FILL'
```

## 変数コレクションのモード数上限はプランによって異なる

```js
// Figma limits modes per collection based on the team/org plan:
//   Free: 1 mode only (no addMode)
//   Professional: up to 4 modes
//   Organization/Enterprise: up to 40+ modes
//
// WRONG — creating 20 modes on a Professional plan will fail silently or throw
const coll = figma.variables.createVariableCollection("Variants")
for (let i = 0; i < 20; i++) coll.addMode("mode" + i) // May fail!

// CORRECT — if you need many modes, split across multiple collections
// E.g., instead of 1 collection with 20 modes (variant×color):
//   Collection A: 4 modes (variant: plain/outlined/soft/solid)
//   Collection B: 5 modes (color: neutral/primary/danger/success/warning)
// Then use setExplicitVariableModeForCollection for BOTH on each component
```

## 変数のスコープは既定で `ALL_SCOPES` — 必ず明示的に設定する

```js
// WRONG — variable appears in every property picker (fills, text, strokes, spacing, etc.)
const bgColor = figma.variables.createVariable("Background/Default", coll, "COLOR")
// bgColor.scopes defaults to ["ALL_SCOPES"] — pollutes all dropdowns

// CORRECT — restrict to relevant property pickers
const bgColor = figma.variables.createVariable("Background/Default", coll, "COLOR")
bgColor.scopes = ["FRAME_FILL", "SHAPE_FILL", "EFFECT_COLOR"]  // fill pickers only

const textColor = figma.variables.createVariable("Text/Default", coll, "COLOR")
textColor.scopes = ["TEXT_FILL"]  // text color picker only

const borderColor = figma.variables.createVariable("Border/Default", coll, "COLOR")
borderColor.scopes = ["STROKE_COLOR"]  // stroke picker only

const spacing = figma.variables.createVariable("Space/400", coll, "FLOAT")
spacing.scopes = ["GAP"]  // gap/spacing pickers only

// Hide primitives that are only referenced via aliases
const primitive = figma.variables.createVariable("Brand/500", coll, "COLOR")
primitive.scopes = []  // hidden from all pickers
```

## fills が空のノードで塗りをバインドする場合

```js
// WRONG — binding to a node with no fills does nothing
const comp = figma.createComponent()
comp.fills = [] // transparent
// Can't bind a color variable to fills that don't exist

// CORRECT — add a placeholder SOLID fill, then bind the variable
const comp = figma.createComponent()
const basePaint = { type: 'SOLID', color: { r: 0, g: 0, b: 0 } }
const boundPaint = figma.variables.setBoundVariableForPaint(basePaint, "color", colorVar)
comp.fills = [boundPaint]
// The variable's resolved value (which may be transparent) will control the actual color
```

## モード名は内容が分かるものにする — 'Mode 1' のままにしない

新しい `VariableCollection` は、常に `'Mode 1'` という名前のモードを 1 つ持った状態で作成されます。必ずすぐに名前を変更してください。単一モードのコレクションには `'Default'`、複数モードのコレクションには元データの名前 (例: `'Light'`/`'Dark'`、`'Desktop'`/`'Tablet'`/`'Mobile'`) を使います。

    // 誤り — 汎用的な名前では意味が分からない
    const coll = figma.variables.createVariableCollection('Colors')
    // coll.modes[0].name === 'Mode 1' — そのまま残している
    const darkId = coll.addMode('Mode 2')

    // 正しい — 元データに合わせてすぐに名前を変更する
    const coll = figma.variables.createVariableCollection('Colors')
    coll.renameMode(coll.modes[0].modeId, 'Light')   // 以前は 'Mode 1'
    const darkId = coll.addMode('Dark')

    // 単一モードのコレクションの場合 (プリミティブ、余白など)
    const spacing = figma.variables.createVariableCollection('Spacing')
    spacing.renameMode(spacing.modes[0].modeId, 'Default')  // 以前は 'Mode 1'

## CSS 変数名に空白を含めてはいけない

Figma の変数名から `var(--name)` 文字列を組み立てるときは、スラッシュと空白の両方をハイフンに置き換え、小文字に変換してください。

    // 誤り — スラッシュだけを置換すると 'var(--color-bg-brand secondary hover)' のような空白が残る
    v.setVariableCodeSyntax('WEB', `var(--${figmaName.replace(/\//g, '-').toLowerCase()})`)

    // 正しい — 空白とスラッシュをまとめて置換する
    v.setVariableCodeSyntax('WEB', `var(--${figmaName.replace(/[\s\/]+/g, '-').toLowerCase()})`)

**ベストプラクティス**: Figma 名から生成するのではなく、元のトークンファイルにある CSS 変数名をそのまま使ってください。

    // 推奨 — 元の CSS 名を直接使う
    v.setVariableCodeSyntax('WEB', `var(${token.cssVar})`)  // 例: '--color-bg-brand-secondary-hover'

## `detachInstance()` は祖先ノードの ID を無効にする

ライブラリコンポーネントのインスタンス内にあるネストされたインスタンスで `detachInstance()` を呼ぶと、親インスタンスも暗黙的にデタッチされることがあります (INSTANCE から FRAME に変換され、新しい ID が付与されます)。以前にキャッシュした親の ID は無効になります。

```js
// WRONG — using cached parent ID after child detach
const parentId = parentInstance.id;
nestedChild.detachInstance();
const parent = await figma.getNodeByIdAsync(parentId); // null! ID changed.

// CORRECT — re-discover by traversal from a stable (non-instance) frame
const stableFrame = await figma.getNodeByIdAsync(manualFrameId);
nestedChild.detachInstance();
const parent = stableFrame.findOne(n => n.name === "ParentName");
```

兄弟要素内のネストされたインスタンスを複数デタッチする場合は、1 回の `use_figma` 呼び出しで行ってください — デタッチによってツリーが変更される前に、たどって対象をすべて特定します。