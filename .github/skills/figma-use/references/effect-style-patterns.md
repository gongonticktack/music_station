# エフェクトスタイル API のパターン

> [use_figma skill](../SKILL.md) の一部です。Plugin API を使ってエフェクトスタイルを作成、適用、調査する方法を説明します。
>
> デザインシステムの背景知識（エフェクトの種類、エフェクト上の変数バインディング、注意点）については、[wwds-effect-styles](working-with-design-systems/wwds-effect-styles.md) を参照してください。

## 目次

- エフェクトスタイルの一覧表示
- ドロップシャドウスタイルの作成
- エフェクトスタイルをノードに適用する

## エフェクトスタイルの一覧表示

```javascript
/**
 * Lists all local effect styles.
 *
 * @returns {Promise<Array<{id: string, name: string, key: string, effectCount: number}>>}
 */
async function listEffectStyles() {
  const styles = await figma.getLocalEffectStylesAsync();
  return styles.map(s => ({
    id: s.id,
    name: s.name,
    key: s.key,
    effectCount: s.effects.length
  }));
}
```

実行可能なスクリプト全体:

```javascript
(async () => {
  try {
    const results = await listEffectStyles();
    figma.closePlugin(JSON.stringify(results));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})()
```

## ドロップシャドウスタイルの作成

色は **RGBA の 0～1 の範囲**で指定します。`effects` は読み取り専用配列です。インプレースで変更せず、必ず再代入してください。

```javascript
/**
 * Creates a drop shadow effect style.
 *
 * @param {string} name - e.g. "Elevation/200"
 * @param {{ r: number, g: number, b: number, a: number }} color - RGBA, 0-1 range
 * @param {{ x: number, y: number }} offset
 * @param {number} radius - blur radius
 * @param {number} [spread=0]
 * @returns {EffectStyle}
 */
function createDropShadowStyle(name, color, offset, radius, spread) {
  const style = figma.createEffectStyle();
  style.name = name;
  style.effects = [{
    type: "DROP_SHADOW",
    color,
    offset,
    radius,
    spread: spread || 0,
    visible: true,
    blendMode: "NORMAL"
  }];
  return style;
}
```

実行可能なスクリプト全体:

```javascript
(async () => {
  try {
    const style = createDropShadowStyle(
      "Elevation/200",
      { r: 0, g: 0, b: 0, a: 0.15 },
      { x: 0, y: 4 },
      12,
      0
    );
    figma.closePlugin(JSON.stringify({ id: style.id, name: style.name }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})()
```

## エフェクトスタイルをノードに適用する

```javascript
/**
 * Applies an effect style to all nodes on the current page that match a given name pattern.
 *
 * @param {string} styleId - The ID of an EffectStyle.
 * @param {string} nodeNamePattern - Substring match against node names.
 * @returns {number} - Number of nodes the style was applied to.
 */
function applyEffectStyleToMatchingNodes(styleId, nodeNamePattern) {
  const nodes = figma.currentPage.findAll(n => n.name.includes(nodeNamePattern));
  let applied = 0;
  for (const node of nodes) {
    if ('effectStyleId' in node) {
      node.effectStyleId = styleId;
      applied++;
    }
  }
  return applied;
}
```

実行可能なスクリプト全体:

```javascript
(async () => {
  try {
    const applied = applyEffectStyleToMatchingNodes('STYLE_ID', 'Card');
    figma.closePlugin(JSON.stringify({ applied }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})()
```
