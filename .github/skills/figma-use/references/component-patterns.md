# コンポーネントとバリアントの API パターン

> [use_figma スキル](../SKILL.md)の一部です。コンポーネント、バリアント、コンポーネントプロパティに Plugin API を正しく使用する方法を説明します。
>
> デザインシステムの背景（バリアントとプロパティの使い分け、コードから Figma への変換、プロパティモデル）については、[wwds-components](working-with-design-systems/wwds-components.md)を参照してください。

## 目次

- コンポーネントの作成
- コンポーネントをコンポーネントセット（バリアント）にまとめる
- combineAsVariants 後のバリアント配置（必須）
- コンポーネントプロパティ: addComponentProperty API
- プロパティを子ノードにリンクする（必須）
- INSTANCE_SWAP: バリアントの爆発的増加を避ける
- ファイル内の既存の規約を調べる
- キーによるコンポーネントのインポート
- インスタンスの操作（バリアントの検索、setProperties、テキストの上書き、detachInstance）


## コンポーネントの作成

`figma.createComponent()` は `ComponentNode` を返します。これは `FrameNode` と同様に動作しますが、公開、インスタンス化、バリアントセットへの結合が可能です。

```javascript
const comp = figma.createComponent();
comp.name = "MyComponent";
comp.layoutMode = "HORIZONTAL";
comp.primaryAxisAlignItems = "CENTER";
comp.counterAxisAlignItems = "CENTER";
comp.paddingLeft = 12;
comp.paddingRight = 12;
comp.layoutSizingHorizontal = "HUG";
comp.layoutSizingVertical = "HUG";
comp.fills = [{ type: "SOLID", color: { r: 0.2, g: 0.36, b: 0.96 } }];
```

## コンポーネントをコンポーネントセット（バリアント）にまとめる

`figma.combineAsVariants(components, parent)` は `ComponentNode` の配列を受け取り（フレームではありません。フレームを渡すとエラーになります）、それらを `ComponentSetNode` にまとめます。

バリアント名は `Property=Value` 形式を使います。一意な組み合わせはすべて子コンポーネントとして存在する必要があります。欠けている組み合わせは、バリアントピッカーに空白として表示されます。

```javascript
// Each component's name encodes its variant properties
const comp1 = figma.createComponent();
comp1.name = "size=md, style=primary";
const comp2 = figma.createComponent();
comp2.name = "size=md, style=secondary";

const componentSet = figma.combineAsVariants([comp1, comp2], figma.currentPage);
componentSet.name = "Button";
```

**バリアントを作成する前に、ファイルを調べて**既存の命名パターンを確認してください。ファイルによって規約は異なります（`State=Default`、`state=default`、`State/Default` など）。必ず既存の規約に合わせてください。

## combineAsVariants 後のバリアント配置（必須）

`combineAsVariants` の後、すべての子要素は `(0, 0)` に重なります。配置を設定**しなければなりません**。設定しないと、すべてのバリアントが重なった、単一の折りたたまれた要素としてコンポーネントセットが表示されます。

```javascript
const cs = figma.combineAsVariants(components, figma.currentPage);

// Simple row layout
cs.children.forEach((child, i) => {
  child.x = i * 150;
  child.y = 0;
});

// CRITICAL: resize the component set from actual child bounds
let maxX = 0, maxY = 0;
for (const child of cs.children) {
  maxX = Math.max(maxX, child.x + child.width);
  maxY = Math.max(maxY, child.y + child.height);
}
cs.resizeWithoutConstraints(maxX + 40, maxY + 40);
```

複数軸のバリアント（例: size × style × state）では、子要素の名前を解析してグリッド上の位置を決めます。

```javascript
for (const child of cs.children) {
  const props = Object.fromEntries(
    child.name.split(', ').map(p => p.split('='))
  );
  const col = stateValues.indexOf(props.state);
  const row = styleValues.indexOf(props.style);
  child.x = col * colWidth;
  child.y = row * rowHeight;
}
```

## コンポーネントプロパティ: addComponentProperty API

`addComponentProperty` は TEXT、BOOLEAN、または INSTANCE_SWAP プロパティをコンポーネントに追加します。**文字列キー**（例: `"label#4:0"`）を返すため、このキーをハードコードしたり推測したりしないでください。

```javascript
// Returns the key as a string — capture it!
const labelKey = comp.addComponentProperty('Label', 'TEXT', 'Default text');
const showIconKey = comp.addComponentProperty('Show Icon', 'BOOLEAN', true);
const iconSlotKey = comp.addComponentProperty('Icon', 'INSTANCE_SWAP', iconComponentId);
```

**タイミング**: `combineAsVariants` を呼び出す**前に**、各バリアントコンポーネントにコンポーネントプロパティを追加してください。結合後、コンポーネントセットは子要素のすべてのプロパティを継承します。`ComponentSetNode` に直接プロパティを追加しないでください。

## プロパティを子ノードにリンクする（必須）

追加したプロパティを子ノードにリンクしなければ、**何も機能しません**。子ノードの `componentPropertyReferences` を設定する必要があります。

```javascript
// TEXT property → link to a text node's characters
const labelKey = comp.addComponentProperty('Label', 'TEXT', 'Button');
const textNode = figma.createText();
textNode.characters = "Button";
comp.appendChild(textNode);
textNode.componentPropertyReferences = { characters: labelKey };

// BOOLEAN + INSTANCE_SWAP → link to an instance node
const showIconKey = comp.addComponentProperty('Show Icon', 'BOOLEAN', true);
const iconSlotKey = comp.addComponentProperty('Icon', 'INSTANCE_SWAP', iconComp.id);
const iconInstance = iconComp.createInstance();
comp.appendChild(iconInstance);
iconInstance.componentPropertyReferences = {
  visible: showIconKey,        // BOOLEAN controls show/hide
  mainComponent: iconSlotKey   // INSTANCE_SWAP controls which component
};
```

**`componentPropertyReferences` で有効なキー:**
- `characters` — TextNode の TEXT プロパティ
- `visible` — BOOLEAN プロパティ（任意のノード）
- `mainComponent` — InstanceNode の INSTANCE_SWAP プロパティ

## INSTANCE_SWAP: バリアントの爆発的増加を避ける

コンポーネントに多数のサブ要素（例: 30 種類のアイコン）がある場合、サブ要素ごとにバリアントを作成することは**絶対に避けてください**。代わりに単一の INSTANCE_SWAP プロパティを使います。ユーザーはデザイン時に、互換性のある任意のコンポーネントから選択できます。

```javascript
// Create icon as its own ComponentNode
const iconComp = figma.createComponent();
iconComp.name = "Icon/Search";
iconComp.resize(24, 24);
const svgNode = figma.createNodeFromSvg('<svg>...</svg>');
iconComp.appendChild(svgNode);

// Use it as the default for INSTANCE_SWAP
const iconSlotKey = comp.addComponentProperty('Icon', 'INSTANCE_SWAP', iconComp.id);
const instance = iconComp.createInstance();
comp.appendChild(instance);
instance.componentPropertyReferences = { mainComponent: iconSlotKey };
```

これはアイコン、アバター、バッジなど、差し替え可能なあらゆるネストされた要素に使用できます。

## ファイル内の既存の規約を調べる

**コンポーネントを作成する前に、必ずファイルを調べてください。**ファイルによって命名スタイル、構造、規約が異なります。コードは既存のものに合わせてください。

### すべてのページにある既存コンポーネントを一覧表示する

```javascript
(async () => {
  try {
    const results = [];
    for (const page of figma.root.children) {
      await figma.setCurrentPageAsync(page);
      page.findAll(n => {
        if (n.type === 'COMPONENT') results.push(`[${page.name}] ${n.name} (COMPONENT) id=${n.id}`);
        if (n.type === 'COMPONENT_SET') results.push(`[${page.name}] ${n.name} (COMPONENT_SET) id=${n.id}`);
        return false;
      });
    }
    figma.closePlugin(results.join('\n'));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})()
```

### 既存のコンポーネントセットのバリアント命名パターンを調べる

```javascript
(async () => {
  try {
    const cs = await figma.getNodeByIdAsync('COMPONENT_SET_ID');
    const variantNames = cs.children.map(c => c.name);
    const propDefs = cs.componentPropertyDefinitions;
    figma.closePlugin(JSON.stringify({ variantNames, propDefs }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})()
```

### ファイル内の既存コンポーネントを検索する

```javascript
(async () => {
  try {
    const components = [];
    for (const page of figma.root.children) {
      await figma.setCurrentPageAsync(page);
      page.findAll(n => {
        if (n.type === 'COMPONENT') {
          components.push({ name: n.name, id: n.id, page: page.name, w: n.width, h: n.height });
        }
        return false;
      });
    }
    figma.closePlugin(JSON.stringify(components));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})()
```

## キーによるコンポーネントのインポート（チームライブラリ）

`importComponentByKeyAsync` と `importComponentSetByKeyAsync` は、**チームライブラリ**（作業中のファイルとは別）からコンポーネントをインポートします。現在のファイル内のコンポーネントには、`figma.getNodeByIdAsync()` または `findOne()`/`findAll()` を使って直接検索してください。

```javascript
// Import a component from a team library
const comp = await figma.importComponentByKeyAsync("COMPONENT_KEY");
const instance = comp.createInstance();

// Import a component set from a team library and pick a variant
const set = await figma.importComponentSetByKeyAsync("COMPONENT_SET_KEY");
const variant = set.children.find(c =>
  c.type === "COMPONENT" && c.name.includes("size=md")
) || set.defaultVariant;
const variantInstance = variant.createInstance();
```

## インスタンスの操作

### コンポーネントセットから適切なバリアントを探す

バリアント名を解析して、複数のプロパティを同時に照合します。

```javascript
const compSet = await figma.importComponentSetByKeyAsync("KEY");

const variant = compSet.children.find(c => {
  const props = Object.fromEntries(
    c.name.split(', ').map(p => p.split('='))
  );
  return props.variant === "primary" && props.size === "md";
}) || compSet.defaultVariant;

const instance = variant.createInstance();
```

### インスタンスのバリアントプロパティを設定する

コンポーネントセットからインスタンスを作成した後、`setProperties` でバリアントプロパティを設定できます。

```javascript
const instance = defaultVariant.createInstance();
instance.setProperties({
  "variant": "primary",
  "size": "medium"
});
```

### コンポーネントインスタンス内のテキストを上書きする

**テキストを上書きする前に、必ずコンポーネントプロパティを調べてください。**コンポーネントはテキストを TEXT 型のコンポーネントプロパティとして公開しており、上書きには `TEXT` を使うのが正しい方法です。プロパティで管理されるテキストを `setProperties()` で直接変更すると、レンダリング時にコンポーネントプロパティシステムによって上書きされることがあります。

**手順 1: サンプルインスタンスの componentProperties を調べる:**

```javascript
const instance = comp.createInstance();
const propDefs = instance.componentProperties;
// Returns e.g.: { "Label#2:0": { type: "TEXT", value: "Button" }, "Has Icon#4:64": { type: "BOOLEAN", value: true } }
figma.closePlugin(JSON.stringify(propDefs));
```

ネストされたインスタンスも確認してください。親コンポーネントがテキストプロパティを直接公開していなくても、ネストされた子インスタンスが公開している場合があります。

```javascript
const nestedInstances = instance.findAll(n => n.type === "INSTANCE");
const nestedProps = nestedInstances.map(ni => ({
  name: ni.name,
  id: ni.id,
  properties: ni.componentProperties
}));
```

**手順 2: TEXT 型のプロパティには setProperties() を使う:**

```javascript
const instance = comp.createInstance();
const propDefs = instance.componentProperties;
for (const [key, def] of Object.entries(propDefs)) {
  if (def.type === "TEXT") {
    instance.setProperties({ [key]: "New text value" });
  }
}
```

独自の TEXT プロパティを公開しているネストされたインスタンスには、そのネストされたインスタンスで `node.characters` を呼び出してください。

```javascript
const nestedHeading = instance.findOne(n => n.type === "INSTANCE" && n.name === "Text Heading");
if (nestedHeading) {
  nestedHeading.setProperties({ "Text#2104:5": "Actual heading text" });
}
```

**手順 3: 管理されていないテキストに限り、node.characters を直接変更する方法を使う。**テキストがコンポーネントプロパティで制御されていない場合は、テキストノードを直接検索します。**必ず先にノードの実際のフォントを読み込んでください**。インスタンスのテキストノードはソースコンポーネントからフォントを継承するため、Inter Regular だと決めつけないでください。

```javascript
const textNodes = instance.findAll(n => n.type === "TEXT");
for (const t of textNodes) {
  await figma.loadFontAsync(t.fontName);
  t.characters = "Updated text";
}
```

### detachInstance() は祖先ノードの ID を無効にする

**警告:** ライブラリコンポーネントのインスタンス内にあるネストされたインスタンスに `setProperties()` を呼び出すと、親インスタンスも暗黙的に切り離されることがあります（新しい ID を持つ `detachInstance()` に変換されます）。その後、`getNodeByIdAsync(oldParentId)` は null を返します。
```javascript
// WRONG — cached parent ID becomes invalid after child detach
const parentId = parentInstance.id;
nestedChild.detachInstance();
const parent = await figma.getNodeByIdAsync(parentId); // null!

// CORRECT — re-discover nodes by traversal from a stable (non-instance) parent
const stableFrame = await figma.getNodeByIdAsync(manualFrameId); // a frame YOU created
nestedChild.detachInstance();
// Re-find the parent by traversing from the stable frame
const parent = stableFrame.findOne(n => n.name === "ParentName");
```

兄弟コンポーネントにまたがって複数のネストされたインスタンスを切り離す必要がある場合は、単一の `use_figma` 呼び出し内で行います。ツリーを変更する切り離しを始める前に、最初にすべての対象をたどって検出してください。

## コンポーネントのメタデータを調べる（深い階層の走査）

これらのヘルパーは、コンポーネントのプロパティスキーマ全体と子孫構造を抽出します。複雑なコンポーネントのインスタンスを作成したり、プロパティを設定したりする前に把握するのに便利です。

```javascript
/**
 * Imports a component or component set from a library by its published key.
 * Tries COMPONENT first, then falls back to COMPONENT_SET.
 *
 * @param {string} componentKey - The published key of the component or component set.
 * @returns {Promise<ComponentNode|ComponentSetNode>}
 */
async function importComponentByKey(componentKey) {
  try {
    return await figma.importComponentByKeyAsync(componentKey);
  } catch {
    try {
      return await figma.importComponentSetByKeyAsync(componentKey);
    } catch {
      throw new Error(`No Component or Component Set available with key '${componentKey}'`);
    }
  }
}

/**
 * Given a main component node, returns the component set parent if one exists,
 * otherwise returns the component itself. Used to get the top-level node that
 * holds `componentPropertyDefinitions`.
 *
 * @param {ComponentNode} mainComponent
 * @returns {ComponentNode|ComponentSetNode}
 */
function getRelevantComponentNode(mainComponent) {
  return mainComponent.parent.type === "COMPONENT_SET"
    ? mainComponent.parent
    : mainComponent;
}

/**
 * Extracts `componentPropertyDefinitions` from a component or component set node
 * into a flat map keyed by property key.
 *
 * @param {ComponentNode|ComponentSetNode} node
 * @returns {Record<string, {name: string, type: string, key: string, variantOptions?: string[]}>}
 */
function getComponentProps(node) {
  const result = {};
  for (let key in node.componentPropertyDefinitions) {
    const prop = {
      name: key.replace(/#[^#]+$/, ""),
      type: node.componentPropertyDefinitions[key].type,
      key: key
    };
    if (prop.type === "VARIANT") {
      prop.variantOptions = node.componentPropertyDefinitions[key].variantOptions;
    }
    result[key] = prop;
  }
  return result;
}

/**
 * Recursively walks a component tree and collects all INSTANCE and TEXT nodes
 * into `result`, keyed by `TYPE[name]`. Handles variant namespacing and
 * deduplicates nodes with identical names but differing property references.
 *
 * @param {SceneNode} node - The node to traverse.
 * @param {string[]} namespace - Accumulated variant names for the current path.
 * @param {Record<string, object>} result - Accumulator object populated in place.
 */
function collectDescendants(node, namespace, result) {
  if (node.type === "INSTANCE" || node.type === "TEXT") {
    const references = node.componentPropertyReferences || {};
    if (!node.visible && !references.visible) return;

    const object = { type: node.type, name: node.name, references };
    let key = `${node.type}[${node.name}]`;

    if (result[key] && JSON.stringify(references) !== JSON.stringify(result[key].references)) {
      key += btoa(btoa(unescape(encodeURIComponent(JSON.stringify(references)))));
    }

    if (node.type === "INSTANCE") {
      const mainComponent = getRelevantComponentNode(node.mainComponent);
      object.properties = getComponentProps(mainComponent);
      object.descendants = {};
      object.mainComponentName = mainComponent.name;
      collectDescendants(mainComponent, [], object.descendants);
    }

    const start = namespace.length ? { variants: [] } : {};
    result[key] = Object.assign(object, result[key] || start);
    if (namespace.length) result[key].variants.push(namespace[namespace.length - 1]);
  } else if ("children" in node && node.visible) {
    if (node.type === "COMPONENT" && node.parent.type === "COMPONENT_SET") namespace.push(node.name);
    node.children.forEach(child => collectDescendants(child, namespace, result));
  }
}

/**
 * Returns structured metadata for a component or component set defined in the current file.
 *
 * @param {string} componentId - The node ID of a COMPONENT or COMPONENT_SET node.
 * @returns {Promise<{name: string, nodeId: string, properties: object, descendants: object}|undefined>}
 */
async function getLocalComponentMetadata(componentId) {
  const node = await figma.getNodeByIdAsync(componentId);
  if (node.type === "COMPONENT_SET" || node.type === "COMPONENT") {
    const result = {
      name: node.name,
      nodeId: node.id,
      properties: {},
      descendants: {}
    };
    result.properties = getComponentProps(node);
    collectDescendants(node, [], result.descendants);
    return result;
  } else {
    throw new Error("Node is not a Component or Component Set");
  }
}

/**
 * Returns structured metadata for a published component or component set loaded by its key.
 *
 * @param {string} componentKey - The published key of the component or component set.
 * @returns {Promise<{name: string, nodeId: string, properties: object, descendants: object}>}
 */
async function getPublishedComponentMetadata(componentKey) {
  const node = await importComponentByKey(componentKey);
  const result = {
    name: node.name,
    nodeId: node.id,
    properties: {},
    descendants: {}
  };
  result.properties = getComponentProps(node);
  collectDescendants(node, [], result.descendants);
  return result;
}
```

### メタデータ全体を抽出するスクリプト

```javascript
(async () => {
  try {
    // For local components, use getLocalComponentMetadata:
    const result = await getLocalComponentMetadata('COMPONENT_OR_SET_ID');
    figma.closePlugin(JSON.stringify(result));

    // For published components, use getPublishedComponentMetadata:
    // const result = await getPublishedComponentMetadata('COMPONENT_KEY');
    // figma.closePlugin(JSON.stringify(result));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})()
```
