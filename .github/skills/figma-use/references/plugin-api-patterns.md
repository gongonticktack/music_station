# プラグイン API パターン

> [use_figma スキル](../SKILL.md)の一部です。一般的な Figma Plugin API 操作のクイックリファレンスです。

## 目次

- 実行の基本
- ノードの作成
- 塗りと線
- オートレイアウト
- エフェクト
- 不透明度とブレンドモード
- 角丸とクリッピング
- グループ化と整理
- コンポーネントとバリアント
- スタイル
- 複製、ノードの検索、グリッド
- 制約とビューポート


## 実行の基本

### ページコンテキスト

`use_figma` の呼び出しごとにページコンテキストはリセットされます。`figma.currentPage` は常に最初のページから始まります。正しいページに切り替えるには、各呼び出しの冒頭で `await figma.setCurrentPageAsync(page)` を使用してください。

```javascript
const targetPage = figma.root.children.find(p => p.name === "My Page");
await figma.setCurrentPageAsync(targetPage);
// targetPage.children is now populated
```

### プラグインを閉じる

実行時には、成功時に `figma.closePlugin()` を、エラー時に `figma.closePluginWithFailure()` を必ず呼び出してください。

```javascript
figma.closePlugin("Success message describing what was done");
figma.closePluginWithFailure("Description of what went wrong");
```

`figma.notify()` は存在しません。すべての情報は close メッセージ文字列で返してください。

### 段階的に作業する

画面全体を一度の呼び出しで作らないでください。作業を小さな手順に分けます。
1. トークン／変数を作成する
2. テキストスタイルを作成する
3. 個々のコンポーネントを作成する
4. セクションを組み合わせる
5. 画面を組み立てる

各手順の間に `get_metadata` で構造を確認してください。大きな作成工程の後には `get_screenshot` を使い、早い段階で視覚的な問題を見つけてください。

## ノードの作成

### フレーム

```javascript
const frame = figma.createFrame();
frame.name = "Container";
frame.resize(1440, 900);
frame.x = 0;
frame.y = 0;
frame.fills = [{ type: "SOLID", color: { r: 0.98, g: 0.98, b: 0.99 } }];
```

### テキスト

```javascript
// MUST load font before any text operations
await figma.loadFontAsync({ family: "Inter", style: "Regular" });

const text = figma.createText();
text.fontName = { family: "Inter", style: "Regular" };
text.fontSize = 16;
text.lineHeight = { value: 24, unit: "PIXELS" };
text.letterSpacing = { value: 0, unit: "PERCENT" };
text.characters = "Hello World";
text.fills = [{ type: "SOLID", color: { r: 0.1, g: 0.1, b: 0.12 } }];
```

### 長方形

```javascript
const rect = figma.createRectangle();
rect.name = "Background";
rect.resize(400, 300);
rect.cornerRadius = 12;
rect.fills = [{ type: "SOLID", color: { r: 0.95, g: 0.95, b: 0.96 } }];
```

### 楕円

```javascript
const circle = figma.createEllipse();
circle.name = "Avatar Circle";
circle.resize(48, 48);
circle.fills = [{ type: "SOLID", color: { r: 0.85, g: 0.87, b: 0.90 } }];
```

### 線

```javascript
const line = figma.createLine();
line.name = "Divider";
line.resize(400, 0);
line.strokes = [{ type: "SOLID", color: { r: 0, g: 0, b: 0 }, opacity: 0.08 }];
line.strokeWeight = 1;
```

### SVG のインポート

```javascript
const svgString = `<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M5 12h14M12 5l7 7-7 7" stroke="black" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>`;

const node = figma.createNodeFromSvg(svgString);
node.name = "Icon/Arrow Right";
node.resize(24, 24);
```

## 塗りと線

### 単色の塗り

```javascript
node.fills = [{ type: "SOLID", color: { r: 0.2, g: 0.2, b: 0.25 } }];
```

### 不透明度を指定した塗り

```javascript
node.fills = [{ type: "SOLID", color: { r: 0.2, g: 0.2, b: 0.25 }, opacity: 0.5 }];
```

### 塗りなし（透明）

```javascript
node.fills = [];
```

### 線形グラデーション

```javascript
node.fills = [{
  type: "GRADIENT_LINEAR",
  gradientStops: [
    { color: { r: 0.2, g: 0.36, b: 0.96, a: 1 }, position: 0 },
    { color: { r: 0.56, g: 0.24, b: 0.88, a: 1 }, position: 1 }
  ],
  gradientTransform: [[1, 0, 0], [0, 1, 0]]
}];
```

### 線

```javascript
node.strokes = [{ type: "SOLID", color: { r: 0.85, g: 0.85, b: 0.87 } }];
node.strokeWeight = 1;
node.strokeAlign = "INSIDE";  // "CENTER", "OUTSIDE"
```

### 複数の塗り（レイヤー）

```javascript
node.fills = [
  { type: "SOLID", color: { r: 0.95, g: 0.95, b: 0.96 } },
  { type: "SOLID", color: { r: 0.2, g: 0.36, b: 0.96 }, opacity: 0.05 }
];
```

## オートレイアウト

### オートレイアウトの設定

```javascript
const frame = figma.createFrame();
frame.layoutMode = "VERTICAL";              // or "HORIZONTAL"
frame.primaryAxisSizingMode = "AUTO";       // Hug main axis
frame.counterAxisSizingMode = "FIXED";      // Fixed cross axis
frame.resize(360, 1);                        // Width fixed, height auto
frame.itemSpacing = 16;                      // Gap between children
frame.paddingTop = 24;
frame.paddingBottom = 24;
frame.paddingLeft = 24;
frame.paddingRight = 24;
```

### 配置

```javascript
// Main axis (direction of layout)
frame.primaryAxisAlignItems = "MIN";            // Start
frame.primaryAxisAlignItems = "CENTER";         // Center
frame.primaryAxisAlignItems = "MAX";            // End
frame.primaryAxisAlignItems = "SPACE_BETWEEN";  // Distribute

// Cross axis
frame.counterAxisAlignItems = "MIN";     // Start
frame.counterAxisAlignItems = "CENTER";  // Center
frame.counterAxisAlignItems = "MAX";     // End
// NOTE: 'STRETCH' is NOT valid — use 'MIN' + child.layoutSizingX = 'FILL'
```

### 子要素のサイズ

```javascript
// IMPORTANT: FILL can only be set AFTER the child is appended to an auto-layout parent
parent.appendChild(child)
child.layoutSizingHorizontal = "FILL";   // Stretch to parent
child.layoutSizingHorizontal = "HUG";    // Shrink to content
child.layoutSizingHorizontal = "FIXED";  // Manual width

child.layoutSizingVertical = "FILL";
child.layoutSizingVertical = "HUG";
child.layoutSizingVertical = "FIXED";
```

### 折り返し（グリッド状のレイアウト）

```javascript
frame.layoutMode = "HORIZONTAL";
frame.layoutWrap = "WRAP";
frame.itemSpacing = 24;          // Horizontal gap
frame.counterAxisSpacing = 24;   // Vertical gap (between rows)
```

### オートレイアウト内での絶対位置指定

```javascript
child.layoutPositioning = "ABSOLUTE";
child.constraints = { horizontal: "MAX", vertical: "MIN" };  // Top-right
child.x = parentWidth - childWidth - 8;
child.y = 8;
```

## エフェクト

### ドロップシャドウ

```javascript
node.effects = [{
  type: "DROP_SHADOW",
  color: { r: 0, g: 0, b: 0, a: 0.08 },
  offset: { x: 0, y: 4 },
  radius: 16,
  spread: -2,
  visible: true,
  blendMode: "NORMAL"
}];
```

### インナーシャドウ

```javascript
node.effects = [{
  type: "INNER_SHADOW",
  color: { r: 0, g: 0, b: 0, a: 0.05 },
  offset: { x: 0, y: 1 },
  radius: 2,
  spread: 0,
  visible: true,
  blendMode: "NORMAL"
}];
```

### 背景ぼかし

```javascript
node.effects = [{
  type: "BACKGROUND_BLUR",
  radius: 16,
  visible: true
}];
```

### レイヤーぼかし

```javascript
node.effects = [{
  type: "LAYER_BLUR",
  radius: 8,
  visible: true
}];
```

### 複数のエフェクト

```javascript
node.effects = [
  { type: "DROP_SHADOW", color: { r: 0, g: 0, b: 0, a: 0.04 }, offset: { x: 0, y: 1 }, radius: 3, spread: 0, visible: true, blendMode: "NORMAL" },
  { type: "DROP_SHADOW", color: { r: 0, g: 0, b: 0, a: 0.06 }, offset: { x: 0, y: 8 }, radius: 24, spread: -4, visible: true, blendMode: "NORMAL" }
];
```

## 不透明度とブレンドモード

```javascript
node.opacity = 0.5;
node.blendMode = "NORMAL";    // "MULTIPLY", "SCREEN", "OVERLAY", "DARKEN", "LIGHTEN", etc.
```

## 角丸

```javascript
// Uniform
node.cornerRadius = 12;

// Per-corner
node.topLeftRadius = 12;
node.topRightRadius = 12;
node.bottomLeftRadius = 0;
node.bottomRightRadius = 0;
```

## クリッピング

```javascript
frame.clipsContent = true;   // Children clipped to frame bounds
```

## グループ化と整理

### グループ

```javascript
const group = figma.group([node1, node2, node3], figma.currentPage);
group.name = "Grouped Elements";
```

### セクション

```javascript
const section = figma.createSection();
section.name = "My Section";
section.resizeWithoutConstraints(800, 600);
section.x = 0;
section.y = 0;
// IMPORTANT: Sections don't auto-resize — always resize after adding content
```

### 子要素の追加

```javascript
parentFrame.appendChild(childNode);

// Insert at a specific index
parentFrame.insertChild(0, childNode);  // Insert at beginning
```

## コンポーネントとバリアント

### コンポーネントの作成

```javascript
const component = figma.createComponent();
component.name = "Button/Primary";
component.description = "Primary action button.";
```

### インスタンスの作成

```javascript
const instance = component.createInstance();
instance.x = 200;
instance.y = 100;
```

### キーによるコンポーネントのインポート（チームライブラリ）

これらのメソッドは**チームライブラリ**（同じファイルではありません）からコンポーネントをインポートします。現在のファイル内のコンポーネントには、`figma.getNodeByIdAsync()` または `findOne()`／`findAll()` を使用してください。

```javascript
// Import a published component from a team library by its key
const comp = await figma.importComponentByKeyAsync(componentKey)
const instance = comp.createInstance()

// Import a published component set from a team library by its key
const set = await figma.importComponentSetByKeyAsync(componentSetKey)
const variant = set.defaultVariant
const variantInstance = variant.createInstance()
```

### バリアントとして結合

```javascript
// IMPORTANT: Pass ComponentNodes (not frames)
const componentSet = figma.combineAsVariants(
  [variantA, variantB, variantC],
  figma.currentPage
);
componentSet.name = "Button";
componentSet.description = "Button component with multiple variants.";

// CRITICAL: Layout variants in a grid after combining (they stack at 0,0)
let maxX = 0, maxY = 0;
componentSet.children.forEach((child, i) => {
  child.x = (i % numCols) * colWidth;
  child.y = Math.floor(i / numCols) * rowHeight;
});
for (const child of componentSet.children) {
  maxX = Math.max(maxX, child.x + child.width);
  maxY = Math.max(maxY, child.y + child.height);
}
componentSet.resizeWithoutConstraints(maxX + 40, maxY + 40);
```

### コンポーネントプロパティ

```javascript
// addComponentProperty returns a STRING key — capture it!
const labelKey = component.addComponentProperty("label", "TEXT", "Button");
const showIconKey = component.addComponentProperty("showIcon", "BOOLEAN", true);
const iconSlotKey = component.addComponentProperty("iconSlot", "INSTANCE_SWAP", defaultIconId);

// MUST link properties to child nodes via componentPropertyReferences
labelNode.componentPropertyReferences = { characters: labelKey };
iconInstance.componentPropertyReferences = {
  visible: showIconKey,
  mainComponent: iconSlotKey
};
```

## スタイル

### テキストスタイル

```javascript
await figma.loadFontAsync({ family: "Inter", style: "Regular" });

const style = figma.createTextStyle();
style.name = "Body/Default";
style.fontName = { family: "Inter", style: "Regular" };
style.fontSize = 16;
style.lineHeight = { value: 24, unit: "PIXELS" };
style.letterSpacing = { value: 0, unit: "PERCENT" };

// Apply to a text node
textNode.textStyleId = style.id;
```

### エフェクトスタイル

```javascript
const shadowStyle = figma.createEffectStyle();
shadowStyle.name = "Shadow/Subtle";
shadowStyle.effects = [{
  type: "DROP_SHADOW",
  color: { r: 0, g: 0, b: 0, a: 0.06 },
  offset: { x: 0, y: 2 },
  radius: 8,
  spread: 0,
  visible: true,
  blendMode: "NORMAL"
}];

// Apply to a node
frame.effectStyleId = shadowStyle.id;
```

## クローンと複製

```javascript
const clone = originalNode.clone();
clone.x = originalNode.x + originalNode.width + 40;
clone.name = "Copy of " + originalNode.name;
```

## ノードの検索

```javascript
// Find by name on current page
const node = figma.currentPage.findOne(n => n.name === "My Frame");

// Find all by type
const allTexts = figma.currentPage.findAll(n => n.type === "TEXT");

// Find all by name pattern
const allButtons = figma.currentPage.findAll(n => n.name.startsWith("Button/"));
```

## レイアウトグリッド

```javascript
frame.layoutGrids = [
  {
    pattern: "COLUMNS",
    alignment: "STRETCH",
    count: 12,
    gutterSize: 24,
    offset: 80,
    visible: true
  }
];
```
## 制約（Auto Layout ではないフレーム）

```javascript
child.constraints = {
  horizontal: "LEFT_RIGHT",  // LEFT, RIGHT, CENTER, LEFT_RIGHT, SCALE
  vertical: "TOP"            // TOP, BOTTOM, CENTER, TOP_BOTTOM, SCALE
};
```

## ビューポートとズーム

```javascript
// Zoom to fit specific nodes
figma.viewport.scrollAndZoomIntoView([frame1, frame2]);
```
