> [figma-generate-library スキル](../SKILL.md)の一部です。

# ドキュメント作成リファレンス

このリファレンスでは、デザインシステム構築のフェーズ2を扱います。対象は、カバーページ、基礎要素のドキュメントページ（カラースウォッチ、書体見本、スペーシングバー、シャドウカード、角丸のデモ）、ページレイアウトの寸法、コンポーネントのインラインドキュメントです。コードブロックはすべて、より大きなスクリプトに埋め込むことを想定した、完全な `use_figma` 対応 JavaScript です（ヘルパー関数形式で、IIFE ラッパーと `closePlugin` はありません）。

---

## 1. カバーページ

カバーページは、ファイル内の常に最初のページです。ファイルを開く人に背景情報を伝える、ブランドを反映したタイトルカードです。

### 含める内容

- ファイル名またはシステム名を大きな見出しで表示（48～72px）
- バージョン文字列または日付
- 短いタグライン（1文）
- 任意：プライマリブランドカラー変数を使った色ブロックの背景

### カバーページの寸法

カバーフレームは **1440 × 900px** にします。Figma のデフォルトのキャンバスサイズに合い、ページのサムネイルでも適切に表示されます。

### カバーページ用の use_figma

```javascript
async function createCoverPage(systemName, tagline, version, primaryColorVar) {
  // primaryColorVar: a Figma Variable object for the brand primary fill
  const page = figma.createPage();
  page.name = 'Cover';
  await figma.setCurrentPageAsync(page);

  await figma.loadFontAsync({ family: 'Inter', style: 'Bold' });
  await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });
  await figma.loadFontAsync({ family: 'Inter', style: 'Medium' });

  const frame = figma.createFrame();
  frame.name = 'Cover';
  frame.resize(1440, 900);
  frame.x = 0;
  frame.y = 0;
  frame.layoutMode = 'VERTICAL';
  frame.primaryAxisAlignItems = 'CENTER';
  frame.counterAxisAlignItems = 'CENTER';
  frame.itemSpacing = 16;
  frame.paddingTop = 0;
  frame.paddingBottom = 0;
  frame.paddingLeft = 0;
  frame.paddingRight = 0;

  // Background: bind to primary variable if provided, else solid dark
  if (primaryColorVar) {
    const bgPaint = figma.variables.setBoundVariableForPaint(
      { type: 'SOLID', color: { r: 0.05, g: 0.05, b: 0.05 } },
      'color',
      primaryColorVar
    );
    frame.fills = [bgPaint];
  } else {
    frame.fills = [{ type: 'SOLID', color: { r: 0.06, g: 0.06, b: 0.07 } }];
  }
  page.appendChild(frame);

  // System name heading
  const title = figma.createText();
  title.fontName = { family: 'Inter', style: 'Bold' };
  title.characters = systemName;
  title.fontSize = 64;
  title.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }];
  title.textAlignHorizontal = 'CENTER';
  frame.appendChild(title);

  // Tagline
  const tag = figma.createText();
  tag.fontName = { family: 'Inter', style: 'Regular' };
  tag.characters = tagline;
  tag.fontSize = 20;
  tag.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1, a: 0.7 } }];
  tag.textAlignHorizontal = 'CENTER';
  frame.appendChild(tag);

  // Version
  const ver = figma.createText();
  ver.fontName = { family: 'Inter', style: 'Medium' };
  ver.characters = version;
  ver.fontSize = 13;
  ver.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1, a: 0.45 } }];
  ver.textAlignHorizontal = 'CENTER';
  frame.appendChild(ver);

  return { page, frameId: frame.id };
}
```

---

## 2. 基礎要素ページ

基礎要素ページは、コンポーネントページよりも**前に**配置します。デザイナーやエンジニアが利用可能な基本要素をひと目で確認できるよう、デザイントークン（色、タイポグラフィ、スペーシング、シャドウ、境界線の角丸）を視覚的に説明します。

### ページレイアウトの寸法

ドキュメントの外枠フレームの幅は **1440px** にします。各セクションは縦に並べ、間隔を **64～100px** 空けます。各セクションのフレームは幅いっぱいの 1440px とし、高さは内容に合わせます。

### 基礎要素ページ全体の骨組み

```javascript
async function createFoundationsPage() {
  const page = figma.createPage();
  page.name = 'Foundations';
  await figma.setCurrentPageAsync(page);

  await figma.loadFontAsync({ family: 'Inter', style: 'Bold' });
  await figma.loadFontAsync({ family: 'Inter', style: 'Medium' });
  await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });

  // Root scroll frame
  const root = figma.createFrame();
  root.name = 'Foundations';
  root.layoutMode = 'VERTICAL';
  root.primaryAxisAlignItems = 'MIN';
  root.counterAxisAlignItems = 'MIN';
  root.itemSpacing = 80;
  root.paddingTop = 80;
  root.paddingBottom = 120;
  root.paddingLeft = 80;
  root.paddingRight = 80;
  root.layoutSizingHorizontal = 'FIXED';
  root.layoutSizingVertical = 'HUG';
  root.resize(1440, 1);
  root.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }];
  page.appendChild(root);

  return { page, root };
}
```

---

## 3. カラースウォッチ（変数にバインド）

カラースウォッチは、**実際の Figma 変数にバインドする必要があります**。スウォッチの塗りに16進数の値を直接指定しないでください。変数の値が変わると、ドキュメントも自動的に同期されます。

### 単色スウォッチ

```javascript
/**
 * Creates a single color swatch card (rectangle + variable name label).
 * The swatch rectangle fill is bound to the provided variable.
 *
 * @param {FrameNode} parent - The auto-layout row to append to.
 * @param {string} varName - Display name (e.g. "color/bg/primary").
 * @param {Variable} variable - The Figma Variable object to bind to.
 * @returns {FrameNode} The swatch frame.
 */
async function createColorSwatch(parent, varName, variable) {
  await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });

  const swatchFrame = figma.createFrame();
  swatchFrame.name = `Swatch/${varName}`;
  swatchFrame.layoutMode = 'VERTICAL';
  swatchFrame.primaryAxisAlignItems = 'MIN';
  swatchFrame.counterAxisAlignItems = 'MIN';
  swatchFrame.itemSpacing = 6;
  swatchFrame.layoutSizingHorizontal = 'FIXED';
  swatchFrame.layoutSizingVertical = 'HUG';
  swatchFrame.resize(88, 1);
  swatchFrame.fills = [];

  // Color rectangle — bound to variable
  const rect = figma.createRectangle();
  rect.resize(88, 88);
  rect.cornerRadius = 8;
  const paint = figma.variables.setBoundVariableForPaint(
    { type: 'SOLID', color: { r: 0.5, g: 0.5, b: 0.5 } },
    'color',
    variable
  );
  rect.fills = [paint];
  swatchFrame.appendChild(rect);

  // Name label
  const label = figma.createText();
  label.fontName = { family: 'Inter', style: 'Regular' };
  label.characters = varName.split('/').pop(); // show leaf name only
  label.fontSize = 10;
  label.fills = [{ type: 'SOLID', color: { r: 0.35, g: 0.35, b: 0.35 } }];
  label.layoutSizingHorizontal = 'FILL';
  swatchFrame.appendChild(label);

  // Full path tooltip label (smaller, lighter)
  const pathLabel = figma.createText();
  pathLabel.fontName = { family: 'Inter', style: 'Regular' };
  pathLabel.characters = varName;
  pathLabel.fontSize = 9;
  pathLabel.fills = [{ type: 'SOLID', color: { r: 0.6, g: 0.6, b: 0.6 } }];
  pathLabel.layoutSizingHorizontal = 'FILL';
  swatchFrame.appendChild(pathLabel);

  parent.appendChild(swatchFrame);
  return swatchFrame;
}
```

### カラーセクションの構築（プリミティブの行＋セマンティックのグリッド）

```javascript
/**
 * Creates a complete color documentation section with a section heading,
 * a row of primitive swatches, and a grid of semantic swatches.
 *
 * @param {FrameNode} root - The root vertical stack frame.
 * @param {Variable[]} primitiveVars - Variables from the Primitives collection.
 * @param {Variable[]} semanticVars - Variables from the semantic Color collection.
 */
async function createColorSection(root, primitiveVars, semanticVars) {
  await figma.loadFontAsync({ family: 'Inter', style: 'Bold' });
  await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });

  // Section container
  const section = figma.createFrame();
  section.name = 'Section/Colors';
  section.layoutMode = 'VERTICAL';
  section.itemSpacing = 24;
  section.layoutSizingHorizontal = 'FILL';
  section.layoutSizingVertical = 'HUG';
  section.fills = [];
  root.appendChild(section);

  // Section heading
  const heading = figma.createText();
  heading.fontName = { family: 'Inter', style: 'Bold' };
  heading.characters = 'Colors';
  heading.fontSize = 32;
  heading.fills = [{ type: 'SOLID', color: { r: 0.07, g: 0.07, b: 0.07 } }];
  section.appendChild(heading);

  // Description
  const desc = figma.createText();
  desc.fontName = { family: 'Inter', style: 'Regular' };
  desc.characters = 'Primitive color palette and semantic color tokens. Semantic tokens reference primitives — always use semantic tokens in components.';
  desc.fontSize = 14;
  desc.fills = [{ type: 'SOLID', color: { r: 0.4, g: 0.4, b: 0.4 } }];
  desc.layoutSizingHorizontal = 'FILL';
  section.appendChild(desc);

  // Primitive swatches row
  const primLabel = figma.createText();
  primLabel.fontName = { family: 'Inter', style: 'Bold' };
  primLabel.characters = 'Primitives';
  primLabel.fontSize = 13;
  primLabel.fills = [{ type: 'SOLID', color: { r: 0.55, g: 0.55, b: 0.55 } }];
  section.appendChild(primLabel);

  const primRow = figma.createFrame();
  primRow.name = 'Primitives/Row';
  primRow.layoutMode = 'HORIZONTAL';
  primRow.itemSpacing = 12;
  primRow.layoutSizingHorizontal = 'FILL';
  primRow.layoutSizingVertical = 'HUG';
  primRow.fills = [];
  primRow.layoutWrap = 'WRAP';
  section.appendChild(primRow);

  for (const v of primitiveVars) {
    await createColorSwatch(primRow, v.name, v);
  }

  // Semantic swatches grid
  if (semanticVars.length > 0) {
    const semLabel = figma.createText();
    semLabel.fontName = { family: 'Inter', style: 'Bold' };
    semLabel.characters = 'Semantic';
    semLabel.fontSize = 13;
    semLabel.fills = [{ type: 'SOLID', color: { r: 0.55, g: 0.55, b: 0.55 } }];
    section.appendChild(semLabel);

    const semRow = figma.createFrame();
    semRow.name = 'Semantic/Row';
    semRow.layoutMode = 'HORIZONTAL';
    semRow.itemSpacing = 12;
    semRow.layoutSizingHorizontal = 'FILL';
    semRow.layoutSizingVertical = 'HUG';
    semRow.fills = [];
    semRow.layoutWrap = 'WRAP';
    section.appendChild(semRow);

    for (const v of semanticVars) {
      await createColorSwatch(semRow, v.name, v);
    }
  }

  return section;
}
```

---

## 4. 書体見本

タイポグラフィの見本では、各テキストスタイルを実際のサイズで表示し、サンプル文字列、スタイル名、仕様を添えます。

### 書体見本の行

```javascript
/**
 * Creates a single type specimen row: style name (small label) + sample text +
 * specification line (family · style · size · line-height).
 *
 * @param {FrameNode} parent - The parent vertical stack.
 * @param {string} styleName - The text style name (e.g. "Display Large").
 * @param {string} fontFamily - Font family (e.g. "Inter").
 * @param {string} fontStyle - Font style (e.g. "Bold").
 * @param {number} fontSize - Font size in pixels.
 * @param {number} lineHeight - Line height in pixels.
 * @returns {FrameNode} The specimen row frame.
 */
async function createTypeSpecimen(parent, styleName, fontFamily, fontStyle, fontSize, lineHeight) {
  await figma.loadFontAsync({ family: fontFamily, style: fontStyle });
  await figma.loadFontAsync({ family: 'Inter', style: 'Medium' });
  await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });

  const row = figma.createFrame();
  row.name = `Type/${styleName}`;
  row.layoutMode = 'VERTICAL';
  row.itemSpacing = 6;
  row.paddingTop = 16;
  row.paddingBottom = 16;
  row.layoutSizingHorizontal = 'FILL';
  row.layoutSizingVertical = 'HUG';
  row.fills = [];
  parent.appendChild(row);

  // Style name label (small, muted)
  const nameText = figma.createText();
  nameText.fontName = { family: 'Inter', style: 'Medium' };
  nameText.characters = styleName;
  nameText.fontSize = 11;
  nameText.fills = [{ type: 'SOLID', color: { r: 0.55, g: 0.55, b: 0.55 } }];
  nameText.layoutSizingHorizontal = 'FILL';
  row.appendChild(nameText);

  // Sample text rendered in the actual style
  const specimen = figma.createText();
  specimen.fontName = { family: fontFamily, style: fontStyle };
  specimen.characters = 'The quick brown fox jumps over the lazy dog';
  specimen.fontSize = fontSize;
  specimen.lineHeight = { value: lineHeight, unit: 'PIXELS' };
  specimen.fills = [{ type: 'SOLID', color: { r: 0.07, g: 0.07, b: 0.07 } }];
  specimen.layoutSizingHorizontal = 'FILL';
  row.appendChild(specimen);

  // Specification line
  const specs = figma.createText();
  specs.fontName = { family: 'Inter', style: 'Regular' };
  specs.characters = `${fontFamily} ${fontStyle} · ${fontSize}px · ${lineHeight}px line height`;
  specs.fontSize = 11;
  specs.fills = [{ type: 'SOLID', color: { r: 0.65, g: 0.65, b: 0.65 } }];
  specs.layoutSizingHorizontal = 'FILL';
  row.appendChild(specs);

  // Divider line
  const divider = figma.createRectangle();
  divider.resize(1280, 1);
  divider.fills = [{ type: 'SOLID', color: { r: 0.9, g: 0.9, b: 0.9 } }];
  divider.layoutSizingHorizontal = 'FILL';
  row.appendChild(divider);

  return row;
}
```

### タイポグラフィセクションのビルダー

```javascript
/**
 * Creates a complete typography documentation section.
 * Pass an array of style definitions; the function renders one specimen per entry.
 *
 * @param {FrameNode} root - Root vertical stack.
 * @param {Array<{name, family, style, size, lineHeight}>} typeStyles - Style definitions.
 */
async function createTypographySection(root, typeStyles) {
  await figma.loadFontAsync({ family: 'Inter', style: 'Bold' });

  const section = figma.createFrame();
  section.name = 'Section/Typography';
  section.layoutMode = 'VERTICAL';
  section.itemSpacing = 0;
  section.layoutSizingHorizontal = 'FILL';
  section.layoutSizingVertical = 'HUG';
  section.fills = [];
  root.appendChild(section);

  const heading = figma.createText();
  heading.fontName = { family: 'Inter', style: 'Bold' };
  heading.characters = 'Typography';
  heading.fontSize = 32;
  heading.fills = [{ type: 'SOLID', color: { r: 0.07, g: 0.07, b: 0.07 } }];
  section.appendChild(heading);

  for (const ts of typeStyles) {
    await createTypeSpecimen(section, ts.name, ts.family, ts.style, ts.size, ts.lineHeight);
  }

  return section;
}
```

---

## 5. 間隔バー

間隔バーは、各間隔トークンを、その間隔値と同じ幅の塗りつぶされた長方形で表示します。小さい値には短いバー、大きい値には長いバーを使うため、値を視覚的にすぐ把握できます。

### 間隔バーの行

```javascript
/**
 * Creates a single spacing bar: a colored rectangle sized to the spacing value,
 * with a label showing name + pixel value + code syntax.
 *
 * @param {FrameNode} parent - Parent vertical stack.
 * @param {string} name - Token name (e.g. "spacing/sm").
 * @param {number} value - Spacing value in pixels.
 * @param {Variable} variable - Figma Variable to bind the width to.
 * @param {string} codeSyntax - CSS variable string (e.g. "var(--spacing-sm)").
 */
async function createSpacingBar(parent, name, value, variable, codeSyntax) {
  await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });

  const row = figma.createFrame();
  row.name = `Spacing/${name}`;
  row.layoutMode = 'HORIZONTAL';
  row.counterAxisAlignItems = 'CENTER';
  row.itemSpacing = 16;
  row.layoutSizingHorizontal = 'FILL';
  row.layoutSizingVertical = 'HUG';
  row.fills = [];
  parent.appendChild(row);

  // The bar rectangle — width bound to spacing variable
  const bar = figma.createRectangle();
  bar.resize(value, 16);
  bar.cornerRadius = 3;
  bar.fills = [{ type: 'SOLID', color: { r: 0.22, g: 0.47, b: 0.98 } }];
  // Bind width to the spacing variable so it reflects the actual token value
  if (variable) {
    bar.setBoundVariable('width', variable);
  }
  row.appendChild(bar);

  // Label: "spacing/sm  8px  var(--spacing-sm)"
  const label = figma.createText();
  label.fontName = { family: 'Inter', style: 'Regular' };
  label.characters = `${name}  ${value}px  ${codeSyntax}`;
  label.fontSize = 12;
  label.fills = [{ type: 'SOLID', color: { r: 0.35, g: 0.35, b: 0.35 } }];
  row.appendChild(label);

  return row;
}
```

### 間隔セクションのビルダー

```javascript
/**
 * Creates the full spacing documentation section.
 *
 * @param {FrameNode} root - Root vertical stack.
 * @param {Array<{name, value, variable, codeSyntax}>} spacingTokens - Token definitions.
 */
async function createSpacingSection(root, spacingTokens) {
  await figma.loadFontAsync({ family: 'Inter', style: 'Bold' });

  const section = figma.createFrame();
  section.name = 'Section/Spacing';
  section.layoutMode = 'VERTICAL';
  section.itemSpacing = 12;
  section.layoutSizingHorizontal = 'FILL';
  section.layoutSizingVertical = 'HUG';
  section.fills = [];
  root.appendChild(section);

  const heading = figma.createText();
  heading.fontName = { family: 'Inter', style: 'Bold' };
  heading.characters = 'Spacing';
  heading.fontSize = 32;
  heading.fills = [{ type: 'SOLID', color: { r: 0.07, g: 0.07, b: 0.07 } }];
  section.appendChild(heading);

  for (const tok of spacingTokens) {
    await createSpacingBar(section, tok.name, tok.value, tok.variable, tok.codeSyntax);
  }

  return section;
}
```

---

## 6. シャドウカード（エレベーション）

エレベーションのドキュメントでは、ドロップシャドウが段階的に強くなるカードを並べ、それぞれに名前と効果のパラメーターを付けます。

### 単一のシャドウカード

```javascript
/**
 * Creates a shadow card: a white rectangle with a drop shadow effect,
 * labeled with the elevation name and shadow parameters.
 *
 * @param {FrameNode} parent - The horizontal row to append to.
 * @param {string} name - Elevation name (e.g. "Shadow/Medium").
 * @param {DropShadowEffect[]} effects - Array of Figma effect objects.
 */
async function createShadowCard(parent, name, effects) {
  await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });
  await figma.loadFontAsync({ family: 'Inter', style: 'Medium' });

  const card = figma.createFrame();
  card.name = `ShadowCard/${name}`;
  card.layoutMode = 'VERTICAL';
  card.primaryAxisAlignItems = 'CENTER';
  card.counterAxisAlignItems = 'CENTER';
  card.itemSpacing = 8;
  card.paddingTop = 16;
  card.paddingBottom = 16;
  card.resize(120, 120);
  card.cornerRadius = 8;
  card.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }];
  card.effects = effects;
  parent.appendChild(card);

  // Elevation name
  const nameLabel = figma.createText();
  nameLabel.fontName = { family: 'Inter', style: 'Medium' };
  nameLabel.characters = name.split('/').pop();
  nameLabel.fontSize = 12;
  nameLabel.textAlignHorizontal = 'CENTER';
  nameLabel.fills = [{ type: 'SOLID', color: { r: 0.2, g: 0.2, b: 0.2 } }];
  card.appendChild(nameLabel);

  // Effect parameters as small text
  if (effects.length > 0) {
    const e = effects[0];
    if (e.type === 'DROP_SHADOW') {
      const params = figma.createText();
      params.fontName = { family: 'Inter', style: 'Regular' };
      params.characters = `x:${e.offset.x} y:${e.offset.y}\nblur:${e.radius}`;
      params.fontSize = 10;
      params.textAlignHorizontal = 'CENTER';
      params.fills = [{ type: 'SOLID', color: { r: 0.55, g: 0.55, b: 0.55 } }];
      card.appendChild(params);
    }
  }

  return card;
}
```

### シャドウセクションのビルダー

```javascript
/**
 * Creates the full elevation/shadow documentation section.
 *
 * @param {FrameNode} root - Root vertical stack.
 * @param {Array<{name, effects}>} shadowTokens - Shadow definitions.
 */
async function createShadowSection(root, shadowTokens) {
  await figma.loadFontAsync({ family: 'Inter', style: 'Bold' });

  const section = figma.createFrame();
  section.name = 'Section/Elevation';
  section.layoutMode = 'VERTICAL';
  section.itemSpacing = 24;
  section.layoutSizingHorizontal = 'FILL';
  section.layoutSizingVertical = 'HUG';
  section.fills = [];
  root.appendChild(section);

  const heading = figma.createText();
  heading.fontName = { family: 'Inter', style: 'Bold' };
  heading.characters = 'Elevation';
  heading.fontSize = 32;
  heading.fills = [{ type: 'SOLID', color: { r: 0.07, g: 0.07, b: 0.07 } }];
  section.appendChild(heading);

  // Cards row — extra top padding so shadows are visible
  const row = figma.createFrame();
  row.name = 'Elevation/Row';
  row.layoutMode = 'HORIZONTAL';
  row.itemSpacing = 32;
  row.paddingTop = 24;
  row.paddingBottom = 40;
  row.layoutSizingHorizontal = 'FILL';
  row.layoutSizingVertical = 'HUG';
  row.fills = [{ type: 'SOLID', color: { r: 0.97, g: 0.97, b: 0.97 } }];
  row.cornerRadius = 8;
  row.paddingLeft = 24;
  row.paddingRight = 24;
  section.appendChild(row);

  for (const tok of shadowTokens) {
    await createShadowCard(row, tok.name, tok.effects);
  }

  return section;
}
```

---

## 7. 角丸デモ

角丸のドキュメントでは、各角丸値を適用した長方形を並べ、それぞれにトークン名とピクセル値を付けます。

### 単一の角丸カード

```javascript
/**
 * Creates a single border radius card: a square with corner radius applied,
 * labeled with the token name and pixel value.
 *
 * @param {FrameNode} parent - The horizontal row to append to.
 * @param {string} name - Token name (e.g. "radius/md").
 * @param {number} value - Corner radius in pixels (0 for none, 9999 for full).
 * @param {Variable} [variable] - Optional Figma Variable to bind corner radius.
 */
async function createRadiusCard(parent, name, value, variable) {
  await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });
  await figma.loadFontAsync({ family: 'Inter', style: 'Medium' });

  const wrapper = figma.createFrame();
  wrapper.name = `Radius/${name}`;
  wrapper.layoutMode = 'VERTICAL';
  wrapper.primaryAxisAlignItems = 'CENTER';
  wrapper.counterAxisAlignItems = 'CENTER';
  wrapper.itemSpacing = 8;
  wrapper.fills = [];
  wrapper.layoutSizingHorizontal = 'FIXED';
  wrapper.layoutSizingVertical = 'HUG';
  wrapper.resize(96, 1);
  parent.appendChild(wrapper);

  const rect = figma.createRectangle();
  rect.resize(72, 72);
  rect.fills = [{ type: 'SOLID', color: { r: 0.22, g: 0.47, b: 0.98, a: 0.15 } }];
  rect.strokes = [{ type: 'SOLID', color: { r: 0.22, g: 0.47, b: 0.98 } }];
  rect.strokeWeight = 1.5;

  // Cap display value — 9999 is how Figma represents "full/pill"
  const displayRadius = Math.min(value, 36);
  rect.cornerRadius = displayRadius;

  // Bind to variable if provided
  if (variable) {
    rect.setBoundVariable('cornerRadius', variable);
  }
  wrapper.appendChild(rect);

  const nameLabel = figma.createText();
  nameLabel.fontName = { family: 'Inter', style: 'Medium' };
  nameLabel.characters = name.split('/').pop();
  nameLabel.fontSize = 11;
  nameLabel.textAlignHorizontal = 'CENTER';
  nameLabel.fills = [{ type: 'SOLID', color: { r: 0.2, g: 0.2, b: 0.2 } }];
  wrapper.appendChild(nameLabel);

  const valueLabel = figma.createText();
  valueLabel.fontName = { family: 'Inter', style: 'Regular' };
  valueLabel.characters = value >= 9999 ? 'full' : `${value}px`;
  valueLabel.fontSize = 10;
  valueLabel.textAlignHorizontal = 'CENTER';
  valueLabel.fills = [{ type: 'SOLID', color: { r: 0.55, g: 0.55, b: 0.55 } }];
  wrapper.appendChild(valueLabel);

  return wrapper;
}
```

### 角丸セクションのビルダー

```javascript
/**
 * Creates the full border radius documentation section.
 *
 * @param {FrameNode} root - Root vertical stack.
 * @param {Array<{name, value, variable}>} radiusTokens - Radius token definitions.
 */
async function createRadiusSection(root, radiusTokens) {
  await figma.loadFontAsync({ family: 'Inter', style: 'Bold' });

  const section = figma.createFrame();
  section.name = 'Section/Radius';
  section.layoutMode = 'VERTICAL';
  section.itemSpacing = 24;
  section.layoutSizingHorizontal = 'FILL';
  section.layoutSizingVertical = 'HUG';
  section.fills = [];
  root.appendChild(section);

  const heading = figma.createText();
  heading.fontName = { family: 'Inter', style: 'Bold' };
  heading.characters = 'Border Radius';
  heading.fontSize = 32;
  heading.fills = [{ type: 'SOLID', color: { r: 0.07, g: 0.07, b: 0.07 } }];
  section.appendChild(heading);

  const row = figma.createFrame();
  row.name = 'Radius/Row';
  row.layoutMode = 'HORIZONTAL';
  row.itemSpacing = 24;
  row.paddingTop = 24;
  row.paddingBottom = 24;
  row.paddingLeft = 24;
  row.paddingRight = 24;
  row.layoutSizingHorizontal = 'FILL';
  row.layoutSizingVertical = 'HUG';
  row.fills = [{ type: 'SOLID', color: { r: 0.97, g: 0.97, b: 0.97 } }];
  row.cornerRadius = 8;
  section.appendChild(row);

  for (const tok of radiusTokens) {
    await createRadiusCard(row, tok.name, tok.value, tok.variable);
  }

  return section;
}
```

---

## 8. コンポーネントと並べるドキュメント

各コンポーネントページには、キャンバス上にドキュメント用フレームを直接配置し、コンポーネントセットの左側に置きます。別ファイルを用意しなくても、ドキュメントとコンポーネントを同期した状態に保てます。

### コンポーネントページのドキュメント用フレーム

```javascript
/**
 * Creates the documentation frame for a component page: title, description,
 * and usage notes, positioned at x=0 with the component set to its right.
 *
 * @param {PageNode} page - The component page (must already be current).
 * @param {string} componentName - The component name.
 * @param {string} description - What the component does and when to use it.
 * @param {string[]} usageNotes - Bullet points for usage guidance.
 * @returns {FrameNode} The documentation frame.
 */
async function createComponentDocFrame(page, componentName, description, usageNotes) {
  await figma.loadFontAsync({ family: 'Inter', style: 'Bold' });
  await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });

  const doc = figma.createFrame();
  doc.name = '_Doc';
  doc.layoutMode = 'VERTICAL';
  doc.itemSpacing = 16;
  doc.paddingTop = 40;
  doc.paddingBottom = 40;
  doc.paddingLeft = 40;
  doc.paddingRight = 40;
  doc.layoutSizingHorizontal = 'FIXED';
  doc.layoutSizingVertical = 'HUG';
  doc.resize(360, 1);
  doc.fills = [];
  doc.x = 0;
  doc.y = 0;
  page.appendChild(doc);

  // Component name — large heading
  const title = figma.createText();
  title.fontName = { family: 'Inter', style: 'Bold' };
  title.characters = componentName;
  title.fontSize = 28;
  title.fills = [{ type: 'SOLID', color: { r: 0.07, g: 0.07, b: 0.07 } }];
  title.layoutSizingHorizontal = 'FILL';
  doc.appendChild(title);

  // Description
  const descText = figma.createText();
  descText.fontName = { family: 'Inter', style: 'Regular' };
  descText.characters = description;
  descText.fontSize = 13;
  descText.lineHeight = { value: 20, unit: 'PIXELS' };
  descText.fills = [{ type: 'SOLID', color: { r: 0.35, g: 0.35, b: 0.35 } }];
  descText.layoutSizingHorizontal = 'FILL';
  doc.appendChild(descText);

  // Divider
  const divider = figma.createRectangle();
  divider.resize(280, 1);
  divider.fills = [{ type: 'SOLID', color: { r: 0.88, g: 0.88, b: 0.88 } }];
  divider.layoutSizingHorizontal = 'FILL';
  doc.appendChild(divider);

  // Usage notes
  if (usageNotes.length > 0) {
    const usageHeading = figma.createText();
    usageHeading.fontName = { family: 'Inter', style: 'Bold' };
    usageHeading.characters = 'Usage';
    usageHeading.fontSize = 13;
    usageHeading.fills = [{ type: 'SOLID', color: { r: 0.07, g: 0.07, b: 0.07 } }];
    doc.appendChild(usageHeading);

    for (const note of usageNotes) {
      const noteText = figma.createText();
      noteText.fontName = { family: 'Inter', style: 'Regular' };
      noteText.characters = `• ${note}`;
      noteText.fontSize = 12;
      noteText.lineHeight = { value: 18, unit: 'PIXELS' };
      noteText.fills = [{ type: 'SOLID', color: { r: 0.4, g: 0.4, b: 0.4 } }];
      noteText.layoutSizingHorizontal = 'FILL';
      doc.appendChild(noteText);
    }
  }

  return doc;
}
```

---

## 9. 重要なルール

1. **スウォッチを変数にバインドする** — 色の塗りには `setBoundVariableForPaint`、スペーシングバーには `setBoundVariable('width', ...)`、角丸カードには `setBoundVariable('cornerRadius', ...)` を使用します。対応する変数がある値をハードコードしないでください。
2. **コンポーネントページより前に Foundations ページを配置する** — ファイル構造の区切りと最初のコンポーネントページの間に、必ず挿入します。
3. **プリミティブ層とセマンティック層の両方を表示する** — システムに Primitives コレクションとセマンティックな Color コレクションがある場合は、Foundations ページで両方を明確なセクション名を付けてドキュメント化します。
4. **ページフレームの幅 = 1440px** — Simple DS、Polaris、Material 3 で共通の慣例です。`get_metadata` で既存の別の慣例が検出されない限り、この幅を使用します。
5. **セクション間隔 = 64～80px** — 色、タイポグラフィ、スペーシング、シャドウ、角丸の各セクション間には、ページを見やすくするため、少なくとも 64px の間隔を設けます。
6. **既存ページのスタイルに合わせる** — 対象ファイルでページ名に絵文字の接頭辞を使っていたり、装飾的な区切りスタイルを使っていたりする場合は、それを Foundations ページ名にも反映します。
7. **ラベルにコード構文を含める** — 変数にコード構文が設定されている場合は、開発者がそのままコピーできるよう、スウォッチやバーのラベルに CSS 変数名を表示します。
