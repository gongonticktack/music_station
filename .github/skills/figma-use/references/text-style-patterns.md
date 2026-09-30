# テキストスタイル API のパターン

> [use_figma skill](../SKILL.md) の一部です。Plugin API を使ってテキストスタイルを作成、適用、確認する方法を説明します。
>
> デザインシステムの背景（テキストスタイルを作成するタイミング、トークンとの関係、ヘッドレス環境での制限）については、[wwds-text-styles](working-with-design-systems/wwds-text-styles.md) を参照してください。

## 目次

- テキストスタイルの一覧表示
- テキストスタイルの作成
- フォントスタイルの調査
- タイプランプの作成（複数ステップ）
- ノードへのテキストスタイルの適用

## テキストスタイルの一覧表示

```javascript
/**
 * Lists all local text styles with their key properties.
 *
 * @returns {Promise<Array<{id: string, name: string, key: string, fontSize: number, fontName: FontName, lineHeight: LineHeight, letterSpacing: LetterSpacing}>>}
 */
async function listTextStyles() {
  const styles = await figma.getLocalTextStylesAsync();
  return styles.map(s => ({
    id: s.id,
    name: s.name,
    key: s.key,
    fontSize: s.fontSize,
    fontName: s.fontName,
    lineHeight: s.lineHeight,
    letterSpacing: s.letterSpacing
  }));
}
```

実行可能な完全なスクリプト:

```javascript
(async () => {
  try {
    const results = await listTextStyles();
    figma.closePlugin(JSON.stringify(results));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})()
```

## テキストスタイルの作成

`fontName` を設定する前に、フォントを**必ず**読み込んでください。`lineHeight` と `letterSpacing` は `{value, unit}` オブジェクトで指定する必要があります。数値だけを指定するとエラーになります。

```javascript
/**
 * Creates a text style with all typographic properties set.
 * Font MUST be loaded before calling.
 *
 * @param {string} name - Slash-delimited name, e.g. "body/base"
 * @param {{ family: string, style: string }} fontName
 * @param {number} fontSize - In pixels
 * @param {{ value: number, unit: 'PIXELS' | 'PERCENT' } | { unit: 'AUTO' }} lineHeight
 * @param {{ value: number, unit: 'PIXELS' | 'PERCENT' }} [letterSpacing]
 * @param {string} [description] - e.g. the CSS variable name "CSS: var(--font-body-base)"
 * @returns {TextStyle}
 */
function createTextStyleFull(name, fontName, fontSize, lineHeight, letterSpacing, description) {
  const style = figma.createTextStyle();
  style.name = name;
  style.fontName = fontName;
  style.fontSize = fontSize;
  style.lineHeight = lineHeight; // { unit: 'AUTO' } | { value, unit: 'PIXELS'|'PERCENT' }
  if (letterSpacing) style.letterSpacing = letterSpacing;
  if (description) style.description = description;
  return style;
}
```

## フォントスタイルの調査

フォントスタイル名はプロバイダーやファイルによって異なります（`"SemiBold"` と `"Semi Bold"` など）。名前をハードコードする前に、必ず調べてください。

```javascript
/**
 * Probes available font styles for a given family.
 * Useful when font style names are unknown (e.g. "SemiBold" vs "Semi Bold").
 *
 * @param {string} family - Font family name, e.g. "Inter"
 * @param {string[]} stylesToTest - Candidate style names to probe
 * @returns {Promise<string[]>} - Style names that loaded successfully
 */
async function probeAvailableFontStyles(family, stylesToTest) {
  const available = [];
  for (const style of stylesToTest) {
    try {
      await figma.loadFontAsync({ family, style });
      available.push(style);
    } catch (_) {}
  }
  return available;
}
```

## タイプランプの作成（複数ステップ）

フォントの読み込み、重複排除、冪等性に対応します。各エントリー: `[name, fontFamily, fontStyle, fontSize_px, lineHeight, cssVar]`。

**ヘッドレス環境での注意:** `setBoundVariable` の `TextStyle` は `use_figma` ではサポートされていません。この関数は生の値を設定します。変数をバインドするには、作成後に Figma で手動操作してください。

```javascript
/**
 * Creates a full type ramp from a token definition array.
 * Handles font loading, deduplication, and idempotency.
 *
 * Each entry: [name, fontFamily, fontStyle, fontSize_px, lineHeight, cssVar]
 *   - lineHeight: { unit: 'AUTO' } or { value: number, unit: 'PIXELS' | 'PERCENT' }
 *
 * @param {Array} defs - Array of [name, fontFamily, fontStyle, fontSize, lineHeight, cssVar] tuples
 * @returns {Promise<{ created: string[], skipped: string[] }>}
 */
async function createTypeRamp(defs) {
  const uniqueFonts = new Set();
  for (const [, family, style] of defs) {
    uniqueFonts.add(JSON.stringify({ family, style }));
  }
  await Promise.all(
    [...uniqueFonts].map(f => figma.loadFontAsync(JSON.parse(f)))
  );

  const existing = new Set(
    (await figma.getLocalTextStylesAsync()).map(s => s.name)
  );

  const created = [];
  const skipped = [];

  for (const [name, family, style, fontSize, lineHeight, cssVar] of defs) {
    if (existing.has(name)) {
      skipped.push(name);
      continue;
    }
    const ts = figma.createTextStyle();
    ts.name = name;
    ts.fontName = { family, style };
    ts.fontSize = fontSize;
    ts.lineHeight = lineHeight ?? { unit: 'AUTO' };
    if (cssVar) ts.description = `CSS: var(${cssVar})`;
    created.push(name);
  }

  return { created, skipped };
}
```

実行可能な完全なスクリプト:

```javascript
(async () => {
  try {
    const defs = [
      ['heading/xl', 'Inter', 'Bold',      48, { unit: 'PIXELS', value: 56 }, '--font-heading-xl'],
      ['heading/lg', 'Inter', 'Bold',      36, { unit: 'PIXELS', value: 44 }, '--font-heading-lg'],
      ['body/base',  'Inter', 'Regular',   16, { unit: 'AUTO' },              '--font-body-base'],
      ['body/sm',    'Inter', 'Regular',   14, { unit: 'AUTO' },              '--font-body-sm'],
      ['code/base',  'Roboto Mono', 'Regular', 14, { unit: 'AUTO' },          '--font-code-base'],
    ];
    const result = await createTypeRamp(defs);
    figma.closePlugin(JSON.stringify(result));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})()
```

## ノードへのテキストスタイルの適用

```javascript
/**
 * Applies a text style to all TEXT nodes on the current page that match a given name pattern.
 *
 * @param {string} styleId - The ID of a TextStyle.
 * @param {string} nodeNamePattern - Substring match against node names.
 * @returns {Promise<number>} - Number of nodes the style was applied to.
 */
async function applyTextStyleToMatchingNodes(styleId, nodeNamePattern) {
  const textNodes = figma.currentPage.findAllWithCriteria({ types: ['TEXT'] });
  let applied = 0;
  for (const node of textNodes) {
    if (node.name.includes(nodeNamePattern)) {
      await node.setTextStyleIdAsync(styleId);
      applied++;
    }
  }
  return applied;
}
```

実行可能な完全なスクリプト:

```javascript
(async () => {
  try {
    const applied = await applyTextStyleToMatchingNodes('STYLE_ID', 'Heading');
    figma.closePlugin(JSON.stringify({ applied }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})()
```
