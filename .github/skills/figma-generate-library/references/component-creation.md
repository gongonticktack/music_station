> [figma-generate-library スキル](../SKILL.md)の一部です。

# コンポーネント作成リファレンス

フェーズ3の完全ガイド：バリアントマトリクス、変数のバインド、コンポーネントプロパティ、ドキュメントを使ったコンポーネントの構築。

---

## 1. コンポーネントのアーキテクチャ

### 依存関係に基づく順序：分子より先に原子

必ず依存関係に沿った順序で構築します。原子のインスタンスを含む分子は、その原子が公開されるまで作成できません。推奨される順序：

```
階層 0（原子）: Icon, Avatar, Badge, Spinner
階層 1（分子）: Button, Checkbox, Toggle, Input, Select
階層 2（複合要素）: Card, Dialog, Menu, Navigation, Form
```

あるコンポーネントが別のコンポーネントのインスタンスを埋め込む場合、埋め込まれるコンポーネントを先に作成する必要があります。フェーズ0で依存関係グラフを作成し、計画に作成順序を記載します。

### ビルディングブロックのサブコンポーネント（M3パターン）

独立した状態遷移を持つ複雑なサブ要素は、`Building Blocks/`（公開）または `.Building Blocks/`（アセットパネルには非表示）を接頭辞とする独自のコンポーネントセットに切り出します。ドット接頭辞は、コンポーネントを公開アセットパネルに表示しないためのFigmaの慣例です。

**Building Blocksを使う場合：**
- サブ要素が独自のバリアント軸（状態、選択状態）を持ち、親コンポーネントで組み合わせ爆発が起きる場合
- サブ要素が繰り返し使われる場合（ナビ項目、テーブルセル、カレンダーセル、セグメントボタンのセグメント）
- サブ要素が親とは異なるバリアント軸を持つ場合

**例（M3セグメントボタン）：**
```
Building Blocks/Segmented button/Button segment (start)   [27 variants: Config × State × Selected]
Building Blocks/Segmented button/Button segment (middle)  [27 variants]
Building Blocks/Segmented button/Button segment (end)     [27 variants]

Segmented button  [16 variants: Segments=2-5 × Density=0/-1/-2/-3]
  各バリアントには、適切な Building Block のセグメントコンポーネントのインスタンスを含める。
```

親コンポーネントは構成と設定を管理し、Building Blockは独自のインタラクション状態を管理します。

### プライベートコンポーネント（`__`接頭辞）

チームライブラリに表示しない内部ヘルパーコンポーネントには、`__`接頭辞を使います（Shop Minisパターン）。ドキュメント専用コンポーネントには `_` を使います（UI3パターン）。

```
__asset          // private icon/asset holder
_Label/Direction // documentation annotation helper
```

---

## 2. コンポーネントページの作成

各コンポーネントは専用のページに配置します（デフォルトではコンポーネントごとに1ページ）。ページには、左上のドキュメント用フレームと、その右側または下側に配置するコンポーネントセットを含めます。

```javascript
(async () => {
  try {
    // Create or find the component page
    let page = figma.root.children.find(p => p.name === 'Button');
    if (!page) {
      page = figma.createPage();
      page.name = 'Button';
    }
    await figma.setCurrentPageAsync(page);

    // Documentation frame — positioned at (40, 40)
    const docFrame = figma.createFrame();
    docFrame.name = 'Button / Documentation';
    docFrame.x = 40;
    docFrame.y = 40;
    docFrame.resize(600, 400);
    docFrame.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }];
    docFrame.layoutMode = 'VERTICAL';
    docFrame.primaryAxisSizingMode = 'AUTO';
    docFrame.counterAxisSizingMode = 'FIXED';
    docFrame.paddingTop = 40;
    docFrame.paddingBottom = 40;
    docFrame.paddingLeft = 40;
    docFrame.paddingRight = 40;
    docFrame.itemSpacing = 16;

    // Title text node
    await figma.loadFontAsync({ family: 'Inter', style: 'Bold' });
    const title = figma.createText();
    title.fontName = { family: 'Inter', style: 'Bold' };
    title.fontSize = 32;
    title.characters = 'Button';
    docFrame.appendChild(title);

    // Description text node
    await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });
    const desc = figma.createText();
    desc.fontName = { family: 'Inter', style: 'Regular' };
    desc.fontSize = 14;
    desc.characters = 'Buttons allow users to take actions and make choices with a single tap.';
    docFrame.appendChild(desc);

    // Tag docFrame with pluginData for idempotency
    docFrame.setPluginData('dsb_run_id', RUN_ID);
    docFrame.setPluginData('dsb_key', 'doc/button');

    figma.closePlugin(JSON.stringify({ docFrameId: docFrame.id, pageId: page.id }));
  } catch (e) { figma.closePluginWithFailure(e.toString()); }
})();
```

---

## 3. ベースコンポーネント：オートレイアウト、子ノード、変数のバインド

ベースコンポーネントは、すべてのバリアントの複製元となるテンプレートです。次の条件を満たす必要があります。
1. オートレイアウトを使用している（手動配置ではない）
2. すべての子ノードが揃っている
3. すべての視覚プロパティが変数にバインドされている（ハードコード値がない）

### ベースとなるボタンコンポーネントの完全な例

```javascript
(async () => {
  try {
    const RUN_ID = 'ds-build-2024-001'; // replace with your actual run ID
    await figma.setCurrentPageAsync(
      figma.root.children.find(p => p.name === 'Button')
    );

    // Rehydrate variables from IDs stored in state ledger
    const bgVar     = await figma.variables.getVariableByIdAsync('VAR_ID_color_bg_primary');
    const textVar   = await figma.variables.getVariableByIdAsync('VAR_ID_color_text_on_primary');
    const paddingVar = await figma.variables.getVariableByIdAsync('VAR_ID_spacing_md');
    const radiusVar = await figma.variables.getVariableByIdAsync('VAR_ID_radius_md');
    const gapVar    = await figma.variables.getVariableByIdAsync('VAR_ID_spacing_sm');

    // --- Base component frame ---
    const comp = figma.createComponent();
    comp.name = 'Size=Medium, Style=Primary, State=Default';
    comp.layoutMode = 'HORIZONTAL';
    comp.primaryAxisSizingMode = 'AUTO';
    comp.counterAxisSizingMode = 'AUTO';
    comp.counterAxisAlignItems = 'CENTER';
    comp.primaryAxisAlignItems = 'CENTER';

    // Padding — bound to spacing variables
    comp.setBoundVariable('paddingTop',    paddingVar);
    comp.setBoundVariable('paddingBottom', paddingVar);
    comp.setBoundVariable('paddingLeft',   paddingVar);
    comp.setBoundVariable('paddingRight',  paddingVar);
    comp.setBoundVariable('itemSpacing',   gapVar);

    // Corner radius — bound to radius variable
    comp.setBoundVariable('topLeftRadius',     radiusVar);
    comp.setBoundVariable('topRightRadius',    radiusVar);
    comp.setBoundVariable('bottomLeftRadius',  radiusVar);
    comp.setBoundVariable('bottomRightRadius', radiusVar);

    // Background fill — bound to color variable
    const bgPaint = figma.variables.setBoundVariableForPaint(
      { type: 'SOLID', color: { r: 0, g: 0, b: 0 } },
      'color',
      bgVar
    );
    comp.fills = [bgPaint];

    // --- Label text node ---
    await figma.loadFontAsync({ family: 'Inter', style: 'Medium' });
    const label = figma.createText();
    label.name = 'label';
    label.fontName = { family: 'Inter', style: 'Medium' };
    label.fontSize = 14;
    label.characters = 'Button';
    label.layoutSizingHorizontal = 'HUG';
    label.layoutSizingVertical = 'HUG';

    // Text fill — bound to color variable
    const textPaint = figma.variables.setBoundVariableForPaint(
      { type: 'SOLID', color: { r: 1, g: 1, b: 1 } },
      'color',
      textVar
    );
    label.fills = [textPaint];
    comp.appendChild(label);

    // --- Icon placeholder (Rectangle for now — will be INSTANCE_SWAP) ---
    const iconBox = figma.createFrame();
    iconBox.name = 'icon';
    iconBox.resize(16, 16);
    iconBox.fills = [];
    iconBox.layoutSizingHorizontal = 'FIXED';
    iconBox.layoutSizingVertical = 'FIXED';
    comp.appendChild(iconBox);

    // Tag for idempotency
    comp.setPluginData('dsb_run_id', RUN_ID);
    comp.setPluginData('dsb_phase', 'phase3');
    comp.setPluginData('dsb_key', 'component/button/base');

    figma.closePlugin(JSON.stringify({ baseCompId: comp.id }));
  } catch (e) { figma.closePluginWithFailure(e.toString()); }
})();
```

**次のすべてを必ず変数にバインドします（ハードコードしない）：**

| プロパティ | 変数の型 | APIメソッド |
|---|---|---|
| 塗りの色 | COLOR | `setBoundVariableForPaint(..., 'color', var)` |
| 線の色 | COLOR | `setBoundVariableForPaint(..., 'color', var)` |
| テキストの塗り | COLOR | `setBoundVariableForPaint(..., 'color', var)` |
| パディング（4辺すべて） | FLOAT | `comp.setBoundVariable('paddingTop', var)` |
| 間隔 / itemSpacing | FLOAT | `comp.setBoundVariable('itemSpacing', var)` |
| 角丸半径（4隅すべて） | FLOAT | `comp.setBoundVariable('topLeftRadius', var)` etc. |
| 線の太さ | FLOAT | `comp.setBoundVariable('strokeWeight', var)` |

---

## 4. バリアントマトリクス

### 軸の定義

各コンポーネントについて、コードを書く前にバリアント軸を特定します。標準的な軸：

```
Button:
  Size   → [Small, Medium, Large]
  Style  → [Primary, Secondary, Outline, Ghost]
  State  → [Default, Hover, Focused, Pressed, Disabled]
  合計   = 3 × 4 × 5 = 60通り — 上限の30通りを超える → Style ごとに分割する
```

### 30通りの上限と分割方法

すべてのバリアント軸の値の積が30通りを超える場合は、マトリクスを分割します。方法：

1. **主要な軸で分割する**：Styleごとに個別のコンポーネントセット（Primary Button、Secondary Buttonなど）を作成する
2. **INSTANCE_SWAPを使う**：Iconなどの視覚的な軸をバリアントマトリクスから完全に外し、代わりにINSTANCE_SWAPプロパティとして公開する
3. **Building Blocksを使う**：独自の状態軸を持つサブ要素を切り出し、Building Blockコンポーネントセットにする

ButtonでSize × Stateが15通りの場合、Styleをバリアント軸に追加できるのは選択肢が2つ以下の場合のみです（15 × 2 = 30）。Styleがそれより多い場合は分割します。

### use_figmaですべてのバリアントを作成する

ベースコンポーネントを複製し、バリアントごとに異なる変数バインドを調整して作成します。前回の呼び出しの状態からベースコンポーネントIDを渡します。

```javascript
(async () => {
  try {
    const RUN_ID = 'ds-build-2024-001';
    const BASE_COMP_ID = 'BASE_ID_FROM_STATE'; // from state ledger

    await figma.setCurrentPageAsync(
      figma.root.children.find(p => p.name === 'Button')
    );

    const base = await figma.getNodeByIdAsync(BASE_COMP_ID);

    // Variable IDs from state ledger
    const vars = {
      // Primary style
      bg_primary:    await figma.variables.getVariableByIdAsync('VAR_ID_color_bg_primary'),
      text_primary:  await figma.variables.getVariableByIdAsync('VAR_ID_color_text_on_primary'),
      // Secondary style
      bg_secondary:  await figma.variables.getVariableByIdAsync('VAR_ID_color_bg_secondary'),
      text_secondary: await figma.variables.getVariableByIdAsync('VAR_ID_color_text_secondary'),
      // Disabled
      bg_disabled:   await figma.variables.getVariableByIdAsync('VAR_ID_color_bg_disabled'),
      text_disabled: await figma.variables.getVariableByIdAsync('VAR_ID_color_text_disabled'),
      // Sizes
      padding_sm: await figma.variables.getVariableByIdAsync('VAR_ID_spacing_sm'),
      padding_md: await figma.variables.getVariableByIdAsync('VAR_ID_spacing_md'),
      padding_lg: await figma.variables.getVariableByIdAsync('VAR_ID_spacing_lg'),
    };

    const axes = {
      Size:  ['Small', 'Medium', 'Large'],
      Style: ['Primary', 'Secondary'],
      State: ['Default', 'Hover', 'Disabled'],
    };

    const paddingBySize = { Small: vars.padding_sm, Medium: vars.padding_md, Large: vars.padding_lg };

    const components = [];

    for (const size of axes.Size) {
      for (const style of axes.Style) {
        for (const state of axes.State) {
          const clone = base.clone();
          clone.name = `Size=${size}, Style=${style}, State=${state}`;

          // Bind padding by size
          clone.setBoundVariable('paddingTop',    paddingBySize[size]);
          clone.setBoundVariable('paddingBottom', paddingBySize[size]);
          clone.setBoundVariable('paddingLeft',   paddingBySize[size]);
          clone.setBoundVariable('paddingRight',  paddingBySize[size]);

          // Bind fill by style + state
          const isDisabled = state === 'Disabled';
          const bgVar  = isDisabled ? vars.bg_disabled  : (style === 'Primary' ? vars.bg_primary  : vars.bg_secondary);
          const txtVar = isDisabled ? vars.text_disabled : (style === 'Primary' ? vars.text_primary : vars.text_secondary);

          const bgPaint = figma.variables.setBoundVariableForPaint(
            { type: 'SOLID', color: { r: 0, g: 0, b: 0 } }, 'color', bgVar
          );
          clone.fills = [bgPaint];

          const labelNode = clone.findOne(n => n.name === 'label');
          const textPaint = figma.variables.setBoundVariableForPaint(
            { type: 'SOLID', color: { r: 1, g: 1, b: 1 } }, 'color', txtVar
          );
          labelNode.fills = [textPaint];

          clone.setPluginData('dsb_run_id', RUN_ID);
          clone.setPluginData('dsb_key', `component/button/variant/${size}/${style}/${state}`);

          components.push(clone);
        }
      }
    }

    figma.closePlugin(JSON.stringify({ variantIds: components.map(c => c.id) }));
  } catch (e) { figma.closePluginWithFailure(e.toString()); }
})();
```
---

## 5. `combineAsVariants` + グリッドレイアウト

すべてのバリアントコンポーネントを作成したら、それらをComponentSetにまとめ、グリッド状に配置します。これは必ず別の`use_figma`呼び出しで行ってください。前の呼び出しの戻り値に含まれるすべてのバリアントIDを渡す必要があります。

### グリッド設計の慣例

プロフェッショナルなデザインシステムでは、バリアントを読みやすいグリッドに配置します。
- **列** = ユーザーが最も頻繁に操作するプロパティ（通常は**State**: Default、Hover、Focused、Pressed、Disabled）
- **行** = まとめて扱う構造上の軸（通常は**Size × Style**。Sizeの変化を最も細かくする）
- **間隔** = バリアント間を16～40px（20pxが無難な既定値。既存ファイルがあればそれに合わせる）
- **パディング** = ComponentSetフレーム内でグリッドの周囲に40px

```
見た目の構成:
                    Default    Hover     Focused   Pressed   Disabled
  ┌──────────────────────────────────────────────────────────────────┐
  │  Small/Primary   [comp]    [comp]    [comp]    [comp]    [comp] │
  │  Small/Secondary [comp]    [comp]    [comp]    [comp]    [comp] │
  │  Medium/Primary  [comp]    [comp]    [comp]    [comp]    [comp] │
  │  Medium/Secondary[comp]    [comp]    [comp]    [comp]    [comp] │
  │  Large/Primary   [comp]    [comp]    [comp]    [comp]    [comp] │
  │  Large/Secondary [comp]    [comp]    [comp]    [comp]    [comp] │
  └──────────────────────────────────────────────────────────────────┘
```

**列にStateを置く理由:** Stateは、デザイナーがインタラクションの一貫性を確認するために横方向へ見比べる軸です。Size/Styleは各行の「アイデンティティ」を定義します。これは、プロフェッショナルなデザインシステム（M3、Polaris、Simple DS）で採用されているグリッド構成と一致します。

### 行・列の見出しラベルを追加する

グリッドを配置したら、ナビゲーションを助けるテキストラベルをComponentSetの外側に追加します。これらはページ上でComponentSetと同階層に置き、ComponentSetの子にはしません。

```javascript
// Add column headers above the component set
const colLabels = ['Default', 'Hover', 'Focused', 'Pressed', 'Disabled'];
await figma.loadFontAsync({ family: 'Inter', style: 'Medium' });
for (let i = 0; i < colLabels.length; i++) {
  const label = figma.createText();
  label.fontName = { family: 'Inter', style: 'Medium' };
  label.characters = colLabels[i];
  label.fontSize = 11;
  label.fills = [{ type: 'SOLID', color: { r: 0.5, g: 0.5, b: 0.5 } }];
  label.x = cs.x + padding + i * (childWidth + gap);
  label.y = cs.y - 20;
}

// Add row headers to the left of the component set
const rowLabels = ['Small / Primary', 'Small / Secondary', 'Med / Primary', ...];
for (let i = 0; i < rowLabels.length; i++) {
  const label = figma.createText();
  label.fontName = { family: 'Inter', style: 'Medium' };
  label.characters = rowLabels[i];
  label.fontSize = 11;
  label.fills = [{ type: 'SOLID', color: { r: 0.5, g: 0.5, b: 0.5 } }];
  label.x = cs.x - 120;
  label.y = cs.y + padding + i * (childHeight + gap) + childHeight / 2 - 6;
}
```

**注:** これらのラベルはドキュメント用の補助要素であり、コンポーネントの一部ではありません。デザイナーがバリアントグリッドを把握しやすくするためのものです。

### グリッドレイアウトのコード

```javascript
(async () => {
  try {
    const VARIANT_IDS = ['ID1', 'ID2', '...']; // from state ledger
    const PAGE_ID = 'PAGE_ID'; // from state ledger

    await figma.setCurrentPageAsync(await figma.getNodeByIdAsync(PAGE_ID));

    // Collect component nodes
    const components = await Promise.all(
      VARIANT_IDS.map(id => figma.getNodeByIdAsync(id))
    );

    // Combine as variants
    const cs = figma.combineAsVariants(components, figma.currentPage);
    cs.name = 'Button';

    // Grid layout: position each variant based on its property values
    // Determine column axis (State) and row axes (Size × Style)
    const axes = {
      Size:  ['Small', 'Medium', 'Large'],
      Style: ['Primary', 'Secondary'],
      State: ['Default', 'Hover', 'Disabled'],
    };
    const COL_AXIS = 'State';  // columns
    const ROW_AXES = ['Size', 'Style']; // rows (Size changes fastest)

    const gap = 16;
    const padding = 40;

    // Measure child dimensions (all should be same height within Size tier)
    // Use the first child as reference for column width
    const childWidth  = 120; // approximate; refine after first screenshot
    const childHeight = 40;

    cs.children.forEach(child => {
      const props = {};
      child.name.split(', ').forEach(part => {
        const [k, v] = part.split('=');
        props[k] = v;
      });

      const colIdx = axes[COL_AXIS].indexOf(props[COL_AXIS]);
      // Row = Size index * number of styles + Style index
      const rowIdx = axes.Size.indexOf(props.Size) * axes.Style.length
                   + axes.Style.indexOf(props.Style);

      child.x = padding + colIdx * (childWidth  + gap);
      child.y = padding + rowIdx * (childHeight + gap);
    });

    // Resize component set to fit all children + padding
    let maxX = 0, maxY = 0;
    for (const child of cs.children) {
      maxX = Math.max(maxX, child.x + child.width);
      maxY = Math.max(maxY, child.y + child.height);
    }
    cs.resizeWithoutConstraints(maxX + padding, maxY + padding);

    // Style the component set frame
    cs.fills = [{ type: 'SOLID', color: { r: 0.95, g: 0.95, b: 0.98 } }];
    cs.cornerRadius = 8;

    // Position component set on page (to the right of doc frame)
    cs.x = 680;
    cs.y = 40;

    cs.setPluginData('dsb_run_id', 'ds-build-2024-001');
    cs.setPluginData('dsb_key', 'componentset/button');

    figma.closePlugin(JSON.stringify({ componentSetId: cs.id }));
  } catch (e) { figma.closePluginWithFailure(e.toString()); }
})();
```

**`combineAsVariants`の重要なルール:**
- `components`は、`ComponentNode`オブジェクトのみを含む空でない配列でなければなりません（frameやgroupは不可）
- 結合後、子要素は(0,0)に重なって配置されるため、必ず手動で位置を調整してください
- ComponentSetフレームをコンテンツに合わせるには、配置後に`resizeWithoutConstraints`を呼び出す必要があります
- `figma.createComponentSet()`はありません。空のComponentSetは作成できません

---

## 6. コンポーネントのプロパティ

TEXT、BOOLEAN、INSTANCE_SWAPプロパティは個々のバリアントではなく、ComponentSetに追加します。`addComponentProperty`の戻り値は実際のプロパティキーです（末尾に`#id:id`が付加されます）。このキーを保存し、`componentPropertyReferences`の設定時にすぐ使用してください。

### TEXTプロパティ

インスタンス内のテキストを編集可能にします。

```javascript
// On the ComponentSetNode (cs):
const labelKey = cs.addComponentProperty('Label', 'TEXT', 'Button');
// labelKey is now something like "Label#0:1"

// Wire to the label child in each variant:
for (const child of cs.children) {
  const labelNode = child.findOne(n => n.name === 'label');
  if (labelNode) {
    labelNode.componentPropertyReferences = { characters: labelKey };
  }
}
```

### BOOLEANプロパティ

子ノードの表示・非表示を切り替えます。

```javascript
const showIconKey = cs.addComponentProperty('Show Icon', 'BOOLEAN', true);

for (const child of cs.children) {
  const iconNode = child.findOne(n => n.name === 'icon');
  if (iconNode) {
    iconNode.componentPropertyReferences = { visible: showIconKey };
  }
}
```

### INSTANCE_SWAPプロパティ

ネストされたコンポーネントインスタンス（例: アイコン）を差し替えられるようにします。

```javascript
// defaultIconCompId is the ID of the default icon component (from state ledger)
const iconKey = cs.addComponentProperty('Icon', 'INSTANCE_SWAP', DEFAULT_ICON_COMP_ID);

for (const child of cs.children) {
  const iconSlot = child.findOne(n => n.name === 'icon');
  if (iconSlot && iconSlot.type === 'INSTANCE') {
    iconSlot.componentPropertyReferences = { mainComponent: iconKey };
  }
}
```

**アイコンごとにバリアントを作るのではなく、INSTANCE_SWAPを使用してください。**「Icon=ChevronRight、Icon=ChevronLeft、…」のような項目をVARIANT軸として追加してはいけません。組み合わせが爆発的に増えてしまいます。1つのINSTANCE_SWAPプロパティで、すべてのアイコンを扱えます。

### INSTANCE_SWAP用のアイコンコンポーネントを作成する

INSTANCE_SWAPの既定値には、実在するComponent IDが必要です。INSTANCE_SWAPを設定する前に、少なくとも1つのアイコンコンポーネントを用意してください。SVGからアイコンを作成する方法は次のとおりです。

```javascript
(async () => {
  try {
    // Create a simple icon component from SVG
    const svgNode = figma.createNodeFromSvg(
      '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">' +
      '<path d="M9 18l6-6-6-6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>' +
      '</svg>'
    );

    // Wrap in a component
    const iconComp = figma.createComponent();
    iconComp.name = 'Icon/ChevronRight';
    iconComp.resize(24, 24);
    iconComp.clipsContent = true;

    // Move SVG children into the component
    for (const child of [...svgNode.children]) {
      iconComp.appendChild(child);
    }
    svgNode.remove();

    // Bind the icon fill to a color variable (so it respects themes)
    // Find vector children and bind their fills
    iconComp.findAll(n => n.type === 'VECTOR').forEach(vec => {
      // For stroke-based icons:
      if (vec.strokes.length > 0) {
        const strokePaint = figma.variables.setBoundVariableForPaint(
          { type: 'SOLID', color: { r: 0, g: 0, b: 0 } }, 'color', iconColorVar
        );
        vec.strokes = [strokePaint];
      }
    });

    iconComp.setPluginData('dsb_run_id', RUN_ID);
    iconComp.setPluginData('dsb_key', 'icon/chevron-right');

    figma.closePlugin(JSON.stringify({ iconCompId: iconComp.id }));
  } catch (e) { figma.closePluginWithFailure(e.toString()); }
})();
```

**その後、返された`iconCompId`をINSTANCE_SWAPの既定値として使用します。**
```javascript
const iconKey = cs.addComponentProperty('Icon', 'INSTANCE_SWAP', ICON_COMP_ID);
```

**`preferredValues`で差し替え候補を制限する:**
INSTANCE_SWAPプロパティの追加後、差し替えメニューに表示するコンポーネントを任意で絞り込めます。
```javascript
// Get the property definitions to find the exact key
const props = cs.componentPropertyDefinitions;
const iconPropKey = Object.keys(props).find(k => k.startsWith('Icon'));

// Set preferred values (array of component keys or instance IDs)
cs.editComponentProperty(iconPropKey, {
  preferredValues: [
    { type: 'COMPONENT', key: chevronRightComp.key },
    { type: 'COMPONENT', key: chevronLeftComp.key },
    { type: 'COMPONENT', key: closeComp.key },
  ],
});
```

**アイコンライブラリのヒント:** UIコンポーネントを作る前に、専用の`Icons`ページにすべてのアイコンコンポーネントを作成してください。その後、INSTANCE_SWAPプロパティの設定時に各アイコンのIDを参照します。

### `componentPropertyReferences`の対応関係

`componentPropertyReferences`オブジェクトは、ノード自身のプロパティをコンポーネントプロパティキーに対応付けます。

| ノードのプロパティ | コンポーネントプロパティの型 | 用途 |
|---|---|---|
| `characters` | TEXT | 編集可能なテキストコンテンツ |
| `visible` | BOOLEAN | 表示・非表示の切り替え |
| `mainComponent` | INSTANCE_SWAP | ネストされたインスタンスの差し替え |

---

## 7. 冪等性を保つための`pluginData`タグ付け

作成したノードにはすべて、作成直後にタグを付けてください。これにより、安全なクリーンアップ、再開、冪等性チェックが可能になります。

```javascript
// After creating any node:
node.setPluginData('dsb_run_id', RUN_ID);   // identifies the build run
node.setPluginData('dsb_phase', 'phase3');  // which phase created it
node.setPluginData('dsb_key', KEY);         // unique logical key for this entity

// Reading back:
const runId = node.getPluginData('dsb_run_id'); // '' if not set
const key   = node.getPluginData('dsb_key');
```

**キーの命名規則:** エンティティの階層を反映した、`/`区切りの論理パスを使用してください。
```
'component/button/base'
'component/button/variant/Medium/Primary/Default'
'componentset/button'
'doc/button'
'page/button'
```

**作成前の冪等性チェック:** ノードを作成する前に、現在のページを走査し、同じ`dsb_key`を持つ既存ノードがないか確認してください。

```javascript
const existing = figma.currentPage.findAll(n =>
  n.getPluginData('dsb_key') === 'componentset/button'
);
if (existing.length > 0) {
  // Skip creation — already done. Return existing node's ID.
  figma.closePlugin(JSON.stringify({ componentSetId: existing[0].id }));
  return;
}
```

---

## 8. ドキュメント

### ページタイトルと説明のフレーム

ドキュメントフレーム（セクション 2 を参照）には次の内容を含めます。
1. コンポーネント名を大きなタイトルで表示（32px 以上、太字）
2. コンポーネントの概要と使用する場面を説明する 1～3 文
3. 仕様に関する注記（サイズ、間隔の値、アクセシビリティに関する注記）

### コンポーネントの `description` プロパティ

ComponentSet に説明を設定します。これは Figma のプロパティパネルに表示され、ドキュメントとしてエクスポートされます。

```javascript
cs.description = 'Buttons allow users to take actions and make choices. Use Primary for the highest-emphasis action on a page.';
```

### `documentationLinks`

外部ドキュメント（Storybook、デザイン仕様、トークンのリファレンス）へのリンクを設定します。

```javascript
cs.documentationLinks = [
  { uri: 'https://your-storybook.com/button' }
];
```

### ノード名と構成

- ComponentSet：コンポーネント名のみ — `'Button'`
- 個別のバリアント：`'Property=Value, Property=Value'` 形式（ファイル内の既存の大文字・小文字の表記に合わせる）
- 子ノード：意味の分かる名前 — `'label'`、`'icon'`、`'container'`、`'state-layer'`
- ドキュメントフレーム：`'ComponentName / Documentation'`

---

## 9. 検証

次のコンポーネントに進む前に、コンポーネントの作成または変更後は必ず検証します。

### `get_metadata` による構造チェック

コンポーネントセットの作成後、ComponentSet ノードに対して `get_metadata` を呼び出し、次を確認します。
- `variantGroupProperties` に、想定される軸と正しい値の配列が含まれている
- `componentPropertyDefinitions` に、想定される TEXT/BOOLEAN/INSTANCE_SWAP プロパティが含まれている
- `children.length` が想定されるバリアント数と一致している（例：3×2×3 の場合は 18）
- `'Component 1'` という名前の子ノードがない（名前のないコンポーネントはバグの兆候です）

### `get_screenshot` — 視覚的な検証（重要）

`get_screenshot` は指定したノードの**画像**を返します。ドキュメントやグリッドラベルを含むページ全体を確認するには、コンポーネントセットではなく**コンポーネントページノード**に対して呼び出します。

```
Tool: get_screenshot
Args: { nodeId: "PAGE_NODE_ID", fileKey: "FILE_KEY" }
```

**スクリーンショットの使い方：**

1. **ユーザーに表示する** — これが主な目的です。ユーザーチェックポイントの一部としてスクリーンショットを提示します。「こちらが Button コンポーネントです。見た目はこれでよさそうですか？」
2. **自分で分析する** — 画像認識機能がある場合は、以下の視覚チェックリストを確認します。画像を扱えない（テキストのみのエージェント）場合は、`get_metadata` による構造検証のみを行い、作成した内容を文章で説明します。

**視覚的な検証チェックリスト**（スクリーンショットを確認する際に各項目をチェックします）：

| # | チェック項目 | 「良好」な状態 | 「問題あり」の状態 |
|---|-------|----------------------|------------------------|
| 1 | **グリッドレイアウト** | バリアントが整然とした行と列に並び、間隔が均一 | すべてのバリアントが左上（0,0）に積み重なっている（スタッキングのバグ） |
| 2 | **塗りの色** | スタイルのバリアントごとに、コンポーネントの色が正しく異なる | すべて黒、または同じ色（変数のバインドに失敗） |
| 3 | **サイズの違い** | Small のバリアントが Large より明らかに小さい | すべて同じサイズ（高さやパディングが変数にバインドされていない） |
| 4 | **テキストの読みやすさ** | ラベルが正しいフォントと色で表示されている | テキストが見えない（白地に白）、欠落している、または「undefined」と表示される |
| 5 | **間隔とパディング** | 内側のパディングが見え、コンポーネントが「ぴったり詰め込まれた」状態ではない | コンポーネントが窮屈に見える、または内側の余白が見えない |
| 6 | **状態の違い** | Hover/Pressed のバリアントの色が Default と明らかに異なる | すべての状態が同じ見た目（状態別の塗りが適用されていない） |
| 7 | **無効状態** | 有効状態より不透明度が低い、または色が淡い | Disabled が Default と同じ見た目 |
| 8 | **ドキュメントフレーム** | コンポーネントグリッドの上または横にタイトルと説明文が見える | ドキュメントがない、またはコンポーネントセットと重なっている |
| 9 | **グリッドラベル** | コンポーネントセットの周囲に行・列の見出しが見える（追加した場合） | ラベルがグリッドと重なっている、または表示されていない |
| 10 | **コンポーネントセットの境界** | すべてのバリアントを、均等な余白のあるグレーの背景フレームが囲んでいる | フレームが小さすぎる（バリアントが切れている）、または大きすぎる |

**スクリーンショットの状態 → 診断 → 修正の対応表：**

| スクリーンショットに表示される状態 | 診断 | 修正スクリプト |
|-----------------|-----------|------------|
| すべてのバリアントが左上に積み重なっている | `combineAsVariants` の後にグリッドレイアウトが適用されていない | グリッドレイアウトスクリプト（§5）を再実行する |
| すべてが黒、または同じ色 | 変数のバインドに失敗した、または変数にアクティブモードの値がない | 変数のバインドを再実行し、モードの値を確認する |
| テキストが表示されない | フォントが読み込まれていない、またはテキストの塗りが背景と同じ色 | `loadFontAsync` が呼び出されたことを確認し、テキストの塗りを `color/text/*` 変数にバインドする |
| すべてのバリアントが同じサイズ | パディングや高さがサイズ変数にバインドされていない | サイズ固有のトークンを指定して `bindVariablesToComponent` を再実行する |
| コンポーネントセットのフレームが極端に小さい | `resizeWithoutConstraints` が呼び出されていない、または誤った寸法が使われている | 子ノードから境界を再計算してサイズを変更する |
| ドキュメントフレームがコンポーネントと重なっている | コンポーネントセットがドキュメントフレームと同じ x,y に配置されている | コンポーネントセットを移動する：`cs.x = docFrame.x + docFrame.width + 60` |

**視覚的な分析ができない場合：**
モデルが画像を処理できない（テキストのみのモード）場合は、代わりに構造を検証します。
1. コンポーネントセットに対して `get_metadata` を呼び出し、子ノード数、プロパティ定義、バリアント名を確認する
2. 主要なプロパティをサンプリングする `use_figma` を実行する：
```javascript
(async () => {
  try {
    const cs = await figma.getNodeByIdAsync(CS_ID);
    const sample = cs.children.slice(0, 3).map(c => ({
      name: c.name,
      width: c.width, height: c.height,
      x: c.x, y: c.y,
      fills: c.fills?.map(f => f.type === 'SOLID' ?
        { r: f.color.r.toFixed(2), g: f.color.g.toFixed(2), b: f.color.b.toFixed(2), boundVar: f.boundVariables?.color?.id } : f.type
      ),
    }));
    figma.closePlugin(JSON.stringify({ sampleVariants: sample, totalChildren: cs.children.length }));
  } catch (e) { figma.closePluginWithFailure(e.toString()); }
})();
```
これにより、視覚機能がなくても、位置（グリッドが機能しているか）、寸法（サイズに違いがあるか）、塗りの情報（バインドが機能しているか）を確認できます。

**スクリーンショットを撮るタイミング：**
- コンポーネントの作成が完了するたび（必須 — ユーザーチェックポイントの一部）
- ファンデーションのドキュメントページを作成した後
- 最終 QA の後（すべてのページを撮影）
- 中間ステップのたびには撮影しない（ツール呼び出しの無駄になる）

### よくある問題

| 症状 | 考えられる原因 | 修正方法 |
|---|---|---|
| すべてのバリアントが (0,0) に積み重なる | `combineAsVariants` を呼び出したが、子ノードを再配置していない | グリッドレイアウトスクリプトを再実行する |
| バリアントの色が間違っている | `combineAsVariants` の後に変数のバインドを適用した | コンポーネントセットの子ノードに再バインドする |
| バリアント数が違う | クローンループのインデックス処理に誤りがある | 結合前に `components.map(c => c.name)` を出力する |
| BOOLEAN プロパティの効果がない | `componentPropertyReferences` を子ノードではなく、コンポーネントセットのフレームに設定した | 実際の子ノードを見つけ、そこに参照を設定する |
| INSTANCE_SWAP に交換オプションが表示されない | デフォルト値が有効なコンポーネント ID ではない | `defaultValue` に実在するコンポーネント ID を指定する |
| `combineAsVariants` が例外をスローする | 配列内に `ComponentNode` ではないノードが少なくとも 1 つある | 配列をフィルタリングする：`nodes.filter(n => n.type === 'COMPONENT')` |
| `addComponentProperty` が予期しないキーを返す | これは想定どおり — キーには `#id:id` サフィックスが付く | 戻り値をただちに保存する：`const key = cs.addComponentProperty(...)` |

---

## 10. 完全な実例：Button コンポーネント

この例では、Button コンポーネントに対する `use_figma` 呼び出しの全手順と、呼び出し間での状態の受け渡しを示します。`RUN_ID` と変数 ID は、状態台帳にある実際の値に置き換えてください。

### 呼び出し 1：コンポーネントページを作成する

**目標：** Button ページを作成する（または見つける）。
**状態入力：** なし
**状態出力：** `{ pageId }`

```javascript
(async () => {
  try {
    let page = figma.root.children.find(p => p.name === 'Button');
    if (!page) { page = figma.createPage(); page.name = 'Button'; }
    page.setPluginData('dsb_run_id', 'ds-build-2024-001');
    page.setPluginData('dsb_key', 'page/button');
    figma.closePlugin(JSON.stringify({ pageId: page.id }));
  } catch (e) { figma.closePluginWithFailure(e.toString()); }
})();
```

### 呼び出し 2：ドキュメントフレームを作成する

**目標：** タイトルと説明のフレームを追加する。
**状態入力：** `{ pageId }`
**状態出力：** `{ docFrameId }`

```javascript
(async () => {
  try {
    const PAGE_ID = 'PAGE_ID_FROM_STATE';
    const page = await figma.getNodeByIdAsync(PAGE_ID);
    await figma.setCurrentPageAsync(page);

    // Idempotency check
    const existing = page.findAll(n => n.getPluginData('dsb_key') === 'doc/button');
    if (existing.length > 0) {
      figma.closePlugin(JSON.stringify({ docFrameId: existing[0].id }));
      return;
    }

    await figma.loadFontAsync({ family: 'Inter', style: 'Bold' });
    await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });

    const docFrame = figma.createFrame();
    docFrame.name = 'Button / Documentation';
    docFrame.x = 40; docFrame.y = 40;
    docFrame.layoutMode = 'VERTICAL';
    docFrame.primaryAxisSizingMode = 'AUTO';
    docFrame.counterAxisSizingMode = 'FIXED';
    docFrame.resize(560, 100);
    docFrame.paddingTop = 40; docFrame.paddingBottom = 40;
    docFrame.paddingLeft = 40; docFrame.paddingRight = 40;
    docFrame.itemSpacing = 16;
    docFrame.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }];

    const title = figma.createText();
    title.fontName = { family: 'Inter', style: 'Bold' };
    title.fontSize = 32;
    title.characters = 'Button';
    docFrame.appendChild(title);

    const desc = figma.createText();
    desc.fontName = { family: 'Inter', style: 'Regular' };
    desc.fontSize = 14;
    desc.characters = 'Buttons allow users to take actions with a single tap. Use Primary for the highest-emphasis action on a page, Secondary for supporting actions.';
    desc.layoutSizingHorizontal = 'FILL';
    docFrame.appendChild(desc);

    docFrame.setPluginData('dsb_run_id', 'ds-build-2024-001');
    docFrame.setPluginData('dsb_key', 'doc/button');

    figma.closePlugin(JSON.stringify({ docFrameId: docFrame.id }));
  } catch (e) { figma.closePluginWithFailure(e.toString()); }
})();
```

### 呼び出し 3：ベースコンポーネントを作成する

**目標：** オートレイアウトとすべての変数バインドを備えたベースコンポーネントを作成する。
**状態入力：** `{ pageId }` + フェーズ 1 の変数 ID
**状態出力：** `{ baseCompId }`

*（完全なコードはセクション 3 を参照 — 状態台帳にある実際の変数 ID を置き換えてください。）*

### 呼び出し 4：すべてのバリアントを作成する

**目標：** ベースを複製し、18 個すべてのバリアント（Size 3 種類 × Style 2 種類 × State 3 種類）を作成する。
**状態入力：** `{ pageId, baseCompId }` + 変数 ID
**状態出力：** `{ variantIds: ['id1', 'id2', ..., 'id18'] }`

```javascript
(async () => {
  try {
    const RUN_ID = 'ds-build-2024-001';
    const BASE_ID = 'BASE_COMP_ID_FROM_STATE';
    const PAGE_ID = 'PAGE_ID_FROM_STATE';
    // Variable IDs from state ledger:
    const VAR = {
      bg_primary:     'VAR_ID_1',
      text_primary:   'VAR_ID_2',
      bg_secondary:   'VAR_ID_3',
      text_secondary: 'VAR_ID_4',
      bg_disabled:    'VAR_ID_5',
      text_disabled:  'VAR_ID_6',
      padding_sm:     'VAR_ID_7',
      padding_md:     'VAR_ID_8',
      padding_lg:     'VAR_ID_9',
    };

    const page = await figma.getNodeByIdAsync(PAGE_ID);
    await figma.setCurrentPageAsync(page);

    const base = await figma.getNodeByIdAsync(BASE_ID);

    // Load all variables
    const vars = {};
    for (const [k, v] of Object.entries(VAR)) {
      vars[k] = await figma.variables.getVariableByIdAsync(v);
    }

    const axes = {
      Size:  ['Small', 'Medium', 'Large'],
      Style: ['Primary', 'Secondary'],
      State: ['Default', 'Hover', 'Disabled'],
    };
    const paddingMap = { Small: vars.padding_sm, Medium: vars.padding_md, Large: vars.padding_lg };

    const components = [];
    for (const size of axes.Size) {
      for (const style of axes.Style) {
        for (const state of axes.State) {
          const clone = base.clone();
          clone.name = `Size=${size}, Style=${style}, State=${state}`;

          clone.setBoundVariable('paddingTop',    paddingMap[size]);
          clone.setBoundVariable('paddingBottom', paddingMap[size]);
          clone.setBoundVariable('paddingLeft',   paddingMap[size]);
          clone.setBoundVariable('paddingRight',  paddingMap[size]);

          const isDisabled = state === 'Disabled';
          const bgV  = isDisabled ? vars.bg_disabled  : (style === 'Primary' ? vars.bg_primary  : vars.bg_secondary);
          const txV  = isDisabled ? vars.text_disabled : (style === 'Primary' ? vars.text_primary : vars.text_secondary);

          clone.fills = [figma.variables.setBoundVariableForPaint(
            { type: 'SOLID', color: { r: 0, g: 0, b: 0 } }, 'color', bgV
          )];

          const labelNode = clone.findOne(n => n.name === 'label');
          labelNode.fills = [figma.variables.setBoundVariableForPaint(
            { type: 'SOLID', color: { r: 1, g: 1, b: 1 } }, 'color', txV
          )];

          clone.setPluginData('dsb_run_id', RUN_ID);
          clone.setPluginData('dsb_key', `component/button/variant/${size}/${style}/${state}`);
          components.push(clone);
        }
      }
    }

    figma.closePlugin(JSON.stringify({ variantIds: components.map(c => c.id) }));
  } catch (e) { figma.closePluginWithFailure(e.toString()); }
})();
```
### 呼び出し 5: combineAsVariants + grid layout

**目的:** 18 個すべてのバリアントを ComponentSet にまとめ、グリッド状に配置します。
**状態入力:** `{ pageId, variantIds }`（18 個の ID）
**状態出力:** `{ componentSetId }`

*(コード全文はセクション 5 を参照してください。)*

### 呼び出し 6: コンポーネントプロパティの追加

**目的:** TEXT、BOOLEAN、INSTANCE_SWAP プロパティを追加し、子ノードに接続します。
**状態入力:** `{ pageId, componentSetId }`
**状態出力:** `{ componentSetId, properties: { labelKey, showIconKey, iconKey } }`

```javascript
(async () => {
  try {
    const CS_ID = 'CS_ID_FROM_STATE';
    const DEFAULT_ICON_ID = 'ICON_COMP_ID_FROM_STATE';
    const page = figma.root.children.find(p => p.name === 'Button');
    await figma.setCurrentPageAsync(page);

    const cs = await figma.getNodeByIdAsync(CS_ID);
    cs.description = 'Buttons allow users to take actions and make choices with a single tap.';
    cs.documentationLinks = [{ uri: 'https://your-storybook.com/button' }];

    // Add properties — save returned keys
    const labelKey    = cs.addComponentProperty('Label', 'TEXT', 'Button');
    const showIconKey = cs.addComponentProperty('Show Icon', 'BOOLEAN', true);
    const iconKey     = cs.addComponentProperty('Icon', 'INSTANCE_SWAP', DEFAULT_ICON_ID);

    // Wire to children
    for (const child of cs.children) {
      const labelNode = child.findOne(n => n.name === 'label');
      if (labelNode) labelNode.componentPropertyReferences = { characters: labelKey };

      const iconNode = child.findOne(n => n.name === 'icon');
      if (iconNode) {
        iconNode.componentPropertyReferences = {
          visible: showIconKey,
          ...(iconNode.type === 'INSTANCE' ? { mainComponent: iconKey } : {}),
        };
      }
    }

    figma.closePlugin(JSON.stringify({
      componentSetId: cs.id,
      properties: { labelKey, showIconKey, iconKey },
    }));
  } catch (e) { figma.closePluginWithFailure(e.toString()); }
})();
```

### 呼び出し 7: get_metadata による検証

**目的:** 構造を確認します。バリアント数、プロパティ、軸を検証します。
**操作:** ComponentSet のノード ID（状態から取得）に対して `get_metadata` を呼び出します。結果で次を確認します。
- `children.length === 18`
- `variantGroupProperties` に `Size`、`Style`、`State` のキーがあり、それぞれ正しい値の配列を持つ
- `componentPropertyDefinitions` に `Label`、`Show Icon`、`Icon` のエントリーがある

### 呼び出し 8: get_screenshot による検証

**目的:** 見た目を確認します。レイアウト、色、テキストを検証します。
**操作:** Button ページで `get_screenshot` を呼び出します。スクリーンショットを確認してください。バリアントが縦に積み重なっている場合は、呼び出し 5 を再実行します。色が正しくない場合は、変数のバインディングを調べます。

### チェックポイント

呼び出し 8 の後: スクリーンショットをユーザーに表示します。「18 個のバリアントを含む Button コンポーネントです。これで正しく見えますか？」と尋ねます。ユーザーの承認を得るまで、次のコンポーネントに進まないでください。
