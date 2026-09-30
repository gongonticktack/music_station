> [figma-generate-library スキル](../SKILL.md) の一部です。

# トークン作成リファレンス

このドキュメントでは、フェーズ 1 として、変数コレクション、モード、プリミティブ、セマンティックエイリアス、スコープ、コード構文、スタイル、検証の作成について説明します。すべてのコードは `use_figma` 用にコピーしてすぐに使えます。

---

## 1. コレクションの構成

トークン数と複雑さに合ったパターンを選択します。

### シンプルパターン（50 トークン未満）

1 つのコレクション、2 つのモード。小規模なプロジェクトやブランドキットに適しています。

```
Collection: "Tokens"    modes: ["Light", "Dark"]
  color/bg/primary → Light: #FFFFFF, Dark: #1A1A1A
  spacing/sm = 8
```

### 標準パターン（50～200 トークン）— 推奨される開始点

プリミティブとセマンティックを分けます。実例として参考になるのは Figma の Simple Design System（SDS）です。7 つのコレクション、368 個の変数で、セマンティックカラーにはライト／ダークモード、プリミティブには単一モードを使います。

```
Collection: "Primitives"    modes: ["Value"]       ← raw hex values, no modes
  blue/500 = #3B82F6
  gray/900 = #111827
  white/1000 = #FFFFFF

Collection: "Color"         modes: ["Light", "Dark"] ← aliases to Primitives
  color/bg/primary → Light: alias Primitives/white/1000, Dark: alias Primitives/gray/900
  color/text/primary → Light: alias Primitives/gray/900, Dark: alias Primitives/white/1000

Collection: "Spacing"       modes: ["Value"]
  spacing/xs = 4, spacing/sm = 8, spacing/md = 16, spacing/lg = 24, spacing/xl = 32

Collection: "Typography Primitives"  modes: ["Value"]
  family/sans = "Inter", scale/01 = 12, scale/02 = 14, scale/03 = 16, weight/regular = 400

Collection: "Typography"    modes: ["Value"]        ← aliases to Typography Primitives
  body/font-family → alias family/sans
  body/size-md → alias scale/03
```

### 高度なパターン（200 トークン以上）— M3 モデル

複数のセマンティックコレクションと 4～8 個のモードを使います。ライト／ダーク × コントラスト × ブランド、またはレスポンシブなブレークポイントが必要な場合に使用します。

```
Collection: "M3"           modes: ["Light", "Dark", "Light High Contrast", "Dark High Contrast", ...]
Collection: "Typeface"     modes: ["Baseline", "Wireframe"]
Collection: "Typescale"    modes: ["Value"]  ← aliases into Typeface
Collection: "Shape"        modes: ["Value"]
```

M3 の重要なポイント：セマンティックカラー変数 196 個すべてが 1 つのコレクションに 8 つのモードで格納されています。フレームのモードを一度切り替えるだけで、すべての色が同時に更新されます。

---

## 2. コレクションとモードの作成

### プリミティブコレクションの作成

```javascript
(async () => {
  try {
    const RUN_ID = "ds-build-2024-001"; // use the same RUN_ID throughout the build

    // Create the collection
    const primColl = figma.variables.createVariableCollection("Primitives");

    // Rename the default "Mode 1" to "Value"
    primColl.renameMode(primColl.modes[0].modeId, "Value");
    const valueMode = primColl.modes[0].modeId;

    // Tag for idempotency
    primColl.setPluginData('dsb_run_id', RUN_ID);
    primColl.setPluginData('dsb_key', 'collection/primitives');

    figma.closePlugin(JSON.stringify({
      collectionId: primColl.id,
      modeId: valueMode,
      name: primColl.name
    }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

### ライト／ダークモードを持つセマンティックカラーコレクションの作成

```javascript
(async () => {
  try {
    const RUN_ID = "ds-build-2024-001";

    const colorColl = figma.variables.createVariableCollection("Color");

    // Rename default "Mode 1" to "Light"
    colorColl.renameMode(colorColl.modes[0].modeId, "Light");
    const lightModeId = colorColl.modes[0].modeId;

    // Add "Dark" mode — requires Professional plan or higher
    // Throws "in addMode: Limited to N modes only" on Starter plan
    const darkModeId = colorColl.addMode("Dark");

    colorColl.setPluginData('dsb_run_id', RUN_ID);
    colorColl.setPluginData('dsb_key', 'collection/color');

    figma.closePlugin(JSON.stringify({
      collectionId: colorColl.id,
      lightModeId,
      darkModeId
    }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

**モードプランの上限：** Starter = 1 モード、Professional = 4 モード、Organization/Enterprise = 40 モードです。`addMode` がエラーになる場合、ファイルは Starter プランです。ユーザーに伝え、どう進めるか確認してください。

### スペーシングコレクションの作成（単一モード）

```javascript
(async () => {
  try {
    const RUN_ID = "ds-build-2024-001";

    const spacingColl = figma.variables.createVariableCollection("Spacing");
    spacingColl.renameMode(spacingColl.modes[0].modeId, "Value");
    const valueMode = spacingColl.modes[0].modeId;

    spacingColl.setPluginData('dsb_run_id', RUN_ID);
    spacingColl.setPluginData('dsb_key', 'collection/spacing');

    figma.closePlugin(JSON.stringify({
      collectionId: spacingColl.id,
      modeId: valueMode
    }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

---

## 3. すべての変数タイプの作成

### hex → {r, g, b} 変換ヘルパー

Figma Plugin API の色の値域は 0～255 ではなく 0～1 です。色変数を作成するスクリプトには、このヘルパーを組み込んでください。

```javascript
function hexToRgb(hex) {
  const clean = hex.replace('#', '');
  return {
    r: parseInt(clean.substring(0, 2), 16) / 255,
    g: parseInt(clean.substring(2, 4), 16) / 255,
    b: parseInt(clean.substring(4, 6), 16) / 255
  };
}

// With alpha channel (for semi-transparent primitives like Black/200 at 10%):
function hexToRgba(hex) {
  const clean = hex.replace('#', '');
  const hasAlpha = clean.length === 8;
  return {
    r: parseInt(clean.substring(0, 2), 16) / 255,
    g: parseInt(clean.substring(2, 4), 16) / 255,
    b: parseInt(clean.substring(4, 6), 16) / 255,
    a: hasAlpha ? parseInt(clean.substring(6, 8), 16) / 255 : 1
  };
}

// Usage:
// hexToRgb('#3B82F6')        → {r: 0.231, g: 0.510, b: 0.965}
// hexToRgb('#14AE5C')        → {r: 0.078, g: 0.682, b: 0.361}
// hexToRgba('#0c0c0d1a')     → {r: 0.047, g: 0.047, b: 0.051, a: 0.102}
```

### プリミティブカラー変数の作成（実際の SDS データ）

これは Simple Design System の `Color Primitives` コレクションの一部（Blue ファミリー。実際のデザインシステムで使われる標準パターン）を作成します。

```javascript
(async () => {
  try {
    function hexToRgb(hex) {
      const c = hex.replace('#', '');
      return { r: parseInt(c.slice(0,2),16)/255, g: parseInt(c.slice(2,4),16)/255, b: parseInt(c.slice(4,6),16)/255 };
    }

    const RUN_ID = "ds-build-2024-001";

    // Get the Primitives collection created in the previous step
    const collections = await figma.variables.getLocalVariableCollectionsAsync();
    const primColl = collections.find(c => c.getPluginData('dsb_key') === 'collection/primitives');
    if (!primColl) throw new Error("Primitives collection not found — run collection creation first");
    const valueMode = primColl.modes[0].modeId;

    // Define primitives — use real values from your codebase
    const primitiveColors = [
      // Blue scale
      { name: 'blue/100', hex: '#EFF6FF' },
      { name: 'blue/200', hex: '#DBEAFE' },
      { name: 'blue/300', hex: '#93C5FD' },
      { name: 'blue/400', hex: '#60A5FA' },
      { name: 'blue/500', hex: '#3B82F6' },
      { name: 'blue/600', hex: '#2563EB' },
      { name: 'blue/700', hex: '#1D4ED8' },
      { name: 'blue/800', hex: '#1E40AF' },
      { name: 'blue/900', hex: '#1E3A8A' },
      // Gray scale
      { name: 'gray/100', hex: '#F9FAFB' },
      { name: 'gray/200', hex: '#F3F4F6' },
      { name: 'gray/300', hex: '#D1D5DB' },
      { name: 'gray/400', hex: '#9CA3AF' },
      { name: 'gray/500', hex: '#6B7280' },
      { name: 'gray/600', hex: '#4B5563' },
      { name: 'gray/700', hex: '#374151' },
      { name: 'gray/800', hex: '#1F2937' },
      { name: 'gray/900', hex: '#111827' },
      // White / Black
      { name: 'white/1000', hex: '#FFFFFF' },
      { name: 'black/1000', hex: '#000000' },
    ];

    const created = [];
    for (const { name, hex } of primitiveColors) {
      const v = figma.variables.createVariable(name, primColl, 'COLOR');
      v.setValueForMode(valueMode, hexToRgb(hex));
      // Primitives: EMPTY scopes (hidden from all pickers — designers use semantics)
      v.scopes = [];
      // Code syntax from the actual CSS variable name
      v.setVariableCodeSyntax('WEB', `var(--color-${name.replace('/', '-')})`);
      v.setPluginData('dsb_run_id', RUN_ID);
      v.setPluginData('dsb_key', `primitive/${name}`);
      created.push({ name, id: v.id });
    }

    figma.closePlugin(JSON.stringify({ created, count: created.length }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

**プリミティブの重要なスコープルール：** `v.scopes = []` を設定します。これにより、すべてのピッカーでプリミティブが非表示になります。デザイナーにはセマンティックトークンだけが表示されるようにします。例外は、半透明のオーバーレイ用プリミティブ（アルファ値を持つ Black/White）です。これらには `["EFFECT_COLOR"]` を設定し、シャドウ用ピッカーに表示されるようにします。

### FLOAT 変数の作成（スペーシング、角丸、フォントサイズ）

```javascript
(async () => {
  try {
    const RUN_ID = "ds-build-2024-001";
    const collections = await figma.variables.getLocalVariableCollectionsAsync();
    const spacingColl = collections.find(c => c.getPluginData('dsb_key') === 'collection/spacing');
    if (!spacingColl) throw new Error("Spacing collection not found");
    const valueMode = spacingColl.modes[0].modeId;

    const spacingTokens = [
      { name: 'spacing/xs',  value: 4,  scope: 'GAP', cssVar: '--spacing-xs' },
      { name: 'spacing/sm',  value: 8,  scope: 'GAP', cssVar: '--spacing-sm' },
      { name: 'spacing/md',  value: 16, scope: 'GAP', cssVar: '--spacing-md' },
      { name: 'spacing/lg',  value: 24, scope: 'GAP', cssVar: '--spacing-lg' },
      { name: 'spacing/xl',  value: 32, scope: 'GAP', cssVar: '--spacing-xl' },
      { name: 'spacing/2xl', value: 48, scope: 'GAP', cssVar: '--spacing-2xl' },
    ];

    const radiusTokens = [
      { name: 'radius/none', value: 0,    scope: 'CORNER_RADIUS', cssVar: '--radius-none' },
      { name: 'radius/sm',   value: 4,    scope: 'CORNER_RADIUS', cssVar: '--radius-sm' },
      { name: 'radius/md',   value: 8,    scope: 'CORNER_RADIUS', cssVar: '--radius-md' },
      { name: 'radius/lg',   value: 16,   scope: 'CORNER_RADIUS', cssVar: '--radius-lg' },
      { name: 'radius/full', value: 9999, scope: 'CORNER_RADIUS', cssVar: '--radius-full' },
    ];

    const created = [];
    for (const { name, value, scope, cssVar } of [...spacingTokens, ...radiusTokens]) {
      const v = figma.variables.createVariable(name, spacingColl, 'FLOAT');
      v.setValueForMode(valueMode, value);
      v.scopes = [scope];
      v.setVariableCodeSyntax('WEB', `var(${cssVar})`);
      v.setPluginData('dsb_run_id', RUN_ID);
      v.setPluginData('dsb_key', name);
      created.push({ name, value, id: v.id });
    }

    figma.closePlugin(JSON.stringify({ created, count: created.length }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

### STRING 変数の作成（フォントファミリー、フォントスタイル）

```javascript
(async () => {
  try {
    const RUN_ID = "ds-build-2024-001";
    const collections = await figma.variables.getLocalVariableCollectionsAsync();
    const typoPrimColl = collections.find(c => c.getPluginData('dsb_key') === 'collection/typography-primitives');
    if (!typoPrimColl) throw new Error("Typography Primitives collection not found");
    const valueMode = typoPrimColl.modes[0].modeId;

    const fontTokens = [
      { name: 'family/sans',  value: 'Inter',       scope: 'FONT_FAMILY', cssVar: '--font-family-sans' },
      { name: 'family/mono',  value: 'Roboto Mono',  scope: 'FONT_FAMILY', cssVar: '--font-family-mono' },
      // Font style strings — these are the Figma fontName.style values:
      { name: 'weight/regular',  value: 'Regular',   scope: 'FONT_STYLE',  cssVar: '--font-weight-regular' },
      { name: 'weight/medium',   value: 'Medium',    scope: 'FONT_STYLE',  cssVar: '--font-weight-medium' },
      { name: 'weight/semibold', value: 'Semi Bold', scope: 'FONT_STYLE',  cssVar: '--font-weight-semibold' },
      { name: 'weight/bold',     value: 'Bold',      scope: 'FONT_STYLE',  cssVar: '--font-weight-bold' },
    ];

    const created = [];
    for (const { name, value, scope, cssVar } of fontTokens) {
      const v = figma.variables.createVariable(name, typoPrimColl, 'STRING');
      v.setValueForMode(valueMode, value);
      v.scopes = [scope];
      v.setVariableCodeSyntax('WEB', `var(${cssVar})`);
      v.setPluginData('dsb_run_id', RUN_ID);
      v.setPluginData('dsb_key', `typo-prim/${name}`);
      created.push({ name, value, id: v.id });
    }

    figma.closePlugin(JSON.stringify({ created, count: created.length }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

### BOOLEAN変数の作成

BOOLEAN変数にはスコープがありません（BOOLEAN型ではスコープはサポートされていません）。

```javascript
(async () => {
  try {
    const RUN_ID = "ds-build-2024-001";
    const collections = await figma.variables.getLocalVariableCollectionsAsync();
    const coll = collections.find(c => c.getPluginData('dsb_key') === 'collection/tokens');
    if (!coll) throw new Error("Collection not found");
    const valueMode = coll.modes[0].modeId;

    const v = figma.variables.createVariable('feature-flags/show-beta-badge', coll, 'BOOLEAN');
    v.setValueForMode(valueMode, false);
    // No scopes — BOOLEAN does not support scopes
    v.setPluginData('dsb_run_id', RUN_ID);
    v.setPluginData('dsb_key', 'feature-flags/show-beta-badge');

    figma.closePlugin(JSON.stringify({ id: v.id, name: v.name }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

---

## 4. 変数のエイリアス設定（VARIABLE_ALIAS）— プリミティブ → セマンティックの連鎖

セマンティックトークンは、`VARIABLE_ALIAS`を介してプリミティブを参照します。これがライト／ダークテーマを機能させる中核となるパターンです。

**アーキテクチャ:**
```
Color Primitives collection (1 mode: Value)
  blue/500 = #3B82F6          ← raw value

Color collection (2 modes: Light, Dark)
  color/bg/accent/default:
    Light → VARIABLE_ALIAS → Primitives/blue/500
    Dark  → VARIABLE_ALIAS → Primitives/blue/300
```

### セマンティックエイリアスを作成する完全なスクリプト（SDSスタイル）

```javascript
(async () => {
  try {
    function hexToRgb(hex) {
      const c = hex.replace('#', '');
      return { r: parseInt(c.slice(0,2),16)/255, g: parseInt(c.slice(2,4),16)/255, b: parseInt(c.slice(4,6),16)/255 };
    }

    const RUN_ID = "ds-build-2024-001";
    const collections = await figma.variables.getLocalVariableCollectionsAsync();

    const primColl = collections.find(c => c.getPluginData('dsb_key') === 'collection/primitives');
    const colorColl = collections.find(c => c.getPluginData('dsb_key') === 'collection/color');
    if (!primColl || !colorColl) throw new Error("Collections not found — run primitive/color collection creation first");

    const primValueMode = primColl.modes[0].modeId;
    const lightModeId = colorColl.modes.find(m => m.name === 'Light').modeId;
    const darkModeId = colorColl.modes.find(m => m.name === 'Dark').modeId;

    // Load all primitive variables for lookup
    const allVars = await figma.variables.getLocalVariablesAsync();
    const primsByKey = {};
    for (const v of allVars) {
      if (v.variableCollectionId === primColl.id) {
        primsByKey[v.getPluginData('dsb_key')] = v;
      }
    }

    function getPrim(name) {
      const v = primsByKey[`primitive/${name}`];
      if (!v) throw new Error(`Primitive not found: primitive/${name}`);
      return v;
    }

    // Define semantic → [lightPrimitiveName, darkPrimitiveName]
    // Following the SDS pattern: Background/{Intent}/{Emphasis}
    const semanticColors = [
      // Background
      { name: 'color/bg/default/default',   lightPrim: 'white/1000', darkPrim: 'gray/900',
        cssVar: '--color-bg-default-default', scopes: ['FRAME_FILL', 'SHAPE_FILL'] },
      { name: 'color/bg/default/secondary', lightPrim: 'gray/100', darkPrim: 'gray/800',
        cssVar: '--color-bg-default-secondary', scopes: ['FRAME_FILL', 'SHAPE_FILL'] },
      { name: 'color/bg/brand/default',     lightPrim: 'blue/600', darkPrim: 'blue/300',
        cssVar: '--color-bg-brand-default', scopes: ['FRAME_FILL', 'SHAPE_FILL'] },
      // Text
      { name: 'color/text/default/default', lightPrim: 'gray/900', darkPrim: 'white/1000',
        cssVar: '--color-text-default-default', scopes: ['TEXT_FILL'] },
      { name: 'color/text/default/secondary', lightPrim: 'gray/500', darkPrim: 'gray/400',
        cssVar: '--color-text-default-secondary', scopes: ['TEXT_FILL'] },
      { name: 'color/text/brand/default',   lightPrim: 'blue/700', darkPrim: 'blue/200',
        cssVar: '--color-text-brand-default', scopes: ['TEXT_FILL'] },
      // Border
      { name: 'color/border/default/default', lightPrim: 'gray/300', darkPrim: 'gray/600',
        cssVar: '--color-border-default-default', scopes: ['STROKE_COLOR'] },
      { name: 'color/border/brand/default',   lightPrim: 'blue/500', darkPrim: 'blue/400',
        cssVar: '--color-border-brand-default', scopes: ['STROKE_COLOR'] },
    ];

    const created = [];
    for (const { name, lightPrim, darkPrim, cssVar, scopes } of semanticColors) {
      const v = figma.variables.createVariable(name, colorColl, 'COLOR');
      // Alias to primitive in Light mode
      v.setValueForMode(lightModeId, figma.variables.createVariableAlias(getPrim(lightPrim)));
      // Alias to primitive in Dark mode
      v.setValueForMode(darkModeId, figma.variables.createVariableAlias(getPrim(darkPrim)));
      // Set scopes (semantic layer — these ARE shown in pickers)
      v.scopes = scopes;
      // Code syntax
      v.setVariableCodeSyntax('WEB', `var(${cssVar})`);
      v.setPluginData('dsb_run_id', RUN_ID);
      v.setPluginData('dsb_key', name);
      created.push({ name, id: v.id });
    }

    figma.closePlugin(JSON.stringify({ created, count: created.length }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

**API の主なポイント:**
- `figma.variables.createVariableAlias(variable)` — Variable オブジェクトを受け取り、`{type:'VARIABLE_ALIAS', id: variable.id}` を返す
- エイリアス先の変数は、セマンティック変数と同じ `resolvedType` を持たなければなりません
- セマンティックレイヤーで生の値を重複させないでください。必ずエイリアスを使用します

---

## 5. 変数のスコープ — 完全リファレンス表

| セマンティック上の役割 | 推奨スコープ | 変数の型 |
|---|---|---|
| プリミティブカラー（生値） | `[]` — 空。すべてのピッカーで非表示 | COLOR |
| 半透明オーバーレイのプリミティブ | `["EFFECT_COLOR"]` | COLOR |
| 背景の塗り（フレーム、シェイプ） | `["FRAME_FILL", "SHAPE_FILL"]` | COLOR |
| テキストカラー | `["TEXT_FILL"]` | COLOR |
| アイコン／シェイプの塗り | `["SHAPE_FILL", "STROKE_COLOR"]` | COLOR |
| ボーダー／ストロークの色 | `["STROKE_COLOR"]` | COLOR |
| 背景とボーダーの組み合わせ | `["FRAME_FILL", "SHAPE_FILL", "STROKE_COLOR"]` | COLOR |
| 影の色 | `["EFFECT_COLOR"]` | COLOR |
| アイテム間のスペーシング／間隔 | `["GAP"]` | FLOAT |
| パディング（間隔と分ける場合） | `["GAP"]` | FLOAT |
| 角丸の半径 | `["CORNER_RADIUS"]` | FLOAT |
| 幅／高さの寸法 | `["WIDTH_HEIGHT"]` | FLOAT |
| フォントサイズ | `["FONT_SIZE"]` | FLOAT |
| 行の高さ | `["LINE_HEIGHT"]` | FLOAT |
| 字間 | `["LETTER_SPACING"]` | FLOAT |
| フォントウェイト（数値） | `["FONT_WEIGHT"]` | FLOAT |
| ストローク幅 | `["STROKE_FLOAT"]` | FLOAT |
| エフェクトのぼかし半径 | `["EFFECT_FLOAT"]` | FLOAT |
| 不透明度 | `["OPACITY"]` | FLOAT |
| フォントファミリー | `["FONT_FAMILY"]` | STRING |
| フォントスタイル（例: "Semi Bold"） | `["FONT_STYLE"]` | STRING |
| 真偽値フラグ | *(スコープは未対応)* | BOOLEAN |

**どの変数にも `ALL_SCOPES` を使用しないでください。** 関係のないトークンがすべてのピッカーに表示されてしまいます。標準的な例である Simple Design System（SDS）では、各変数に用途を絞ったスコープを設定しています。

**`ALL_FILLS` に関する注意:** `ALL_FILLS` は塗りのスコープの中で他と併用できません。`FRAME_FILL`、`SHAPE_FILL`、`TEXT_FILL` をまとめて対象にします。これを設定すると、個別の塗りスコープを追加できません。細かく指定するには、個別のスコープを設定してください。

### 変数作成後の一括スコープ設定

スコープを設定せずに変数を作成し、一括で設定する必要がある場合:

```javascript
(async () => {
  try {
    const allVars = await figma.variables.getLocalVariablesAsync();

    // Scope mapping: partial name match → scopes
    const scopeRules = [
      { match: 'color/bg/',     scopes: ['FRAME_FILL', 'SHAPE_FILL'] },
      { match: 'color/text/',   scopes: ['TEXT_FILL'] },
      { match: 'color/icon/',   scopes: ['SHAPE_FILL', 'STROKE_COLOR'] },
      { match: 'color/border/', scopes: ['STROKE_COLOR'] },
      { match: 'spacing/',      scopes: ['GAP'] },
      { match: 'radius/',       scopes: ['CORNER_RADIUS'] },
      { match: 'blue/',         scopes: [] },   // primitives — hide
      { match: 'gray/',         scopes: [] },
      { match: 'white/',        scopes: [] },
      { match: 'black/',        scopes: [] },
    ];

    const updated = [];
    for (const v of allVars) {
      if (v.remote) continue; // skip library variables
      for (const rule of scopeRules) {
        if (v.name.startsWith(rule.match)) {
          v.scopes = rule.scopes;
          updated.push({ name: v.name, scopes: rule.scopes });
          break;
        }
      }
    }

    figma.closePlugin(JSON.stringify({ updated, count: updated.length }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

---

## 6. コード構文 — WEB/ANDROID/iOS

すべての変数にコード構文を設定する必要があります。これにより、開発者への引き継ぎ機能が利用できます:

**コード構文の役割:** 開発者が Figma Dev Mode で、変数に紐づくプロパティ（塗り、パディング、角丸など）を持つ要素を調べると、表示されるコードスニペットには Figma の変数名ではなく、その変数のコード構文名が使われます。たとえば、ボタンの背景塗りが `color/bg/primary` に紐づいている場合、CSS スニペットには `background: var(--color-bg-primary)` が表示され、`color/bg/primary` は表示されません。コード構文を設定していないと、Dev Mode には生の16進数カラー値が表示されるか、役に立つ情報が何も表示されません。

変数ごとに最大 **3 種類の構文**を設定できます。プラットフォーム（Web、iOS、Android）ごとに1つです。コードベースが複数のプラットフォームを対象としている場合は3つすべてを設定し、Web 専用プロジェクトの場合は WEB のみを設定してください。

```javascript
// WEB: MUST include the var() wrapper — this is the full CSS function syntax
variable.setVariableCodeSyntax('WEB', 'var(--color-bg-primary)');
//                                     ^^^^                   ^
//                              var() wrapper is REQUIRED

// ANDROID: Kotlin property name — camelCase, no wrapper
variable.setVariableCodeSyntax('ANDROID', 'colorBgPrimary');

// iOS: Swift property — dot-notation, no wrapper
variable.setVariableCodeSyntax('iOS', 'Color.bgPrimary');
```

> **重要 — WEB のコード構文では、必ず `var()` のラッパーを使用してください。** `--color-bg-primary` だけを設定し（`var()` を付けないと）、Dev Mode には CSS 変数への参照ではなく、生の16進数カラー値が表示されます。必ず完全な `var(--name)` 形式を使用してください。ANDROID と iOS ではラッパーを使用しません。

**CSS 変数名からプラットフォーム別の名前を導出するルール:**

| プラットフォーム | パターン | 例 |
|---|---|---|
| WEB | **`var(--{css-var-name})`** — `var()` のラッパーが必要 | `var(--sds-color-bg-primary)` |
| ANDROID | キャメルケース、ラッパーなし、`--` 接頭辞を削除 | `sdsColorBgPrimary` |
| iOS | `.` の後はパスカルケース、ラッパーなし、`--` 接頭辞を削除 | `Color.SdsColorBgPrimary` または `Color.bgPrimary` |

**コードベースで実際に使われている CSS 変数名を必ず使用してください** — Figma の変数名から導出しないでください。コードで `--sds-color-background-brand-default` が使われている場合、その文字列をそのまま WEB のコード構文に使います（追加する `var()` のラッパーを除く）。

### コード構文の一括設定

```javascript
(async () => {
  try {
    const allVars = await figma.variables.getLocalVariablesAsync();
    const updated = [];

    for (const v of allVars) {
      if (v.remote) continue;
      // If code syntax already set, skip
      if (v.codeSyntax['WEB']) continue;

      // FALLBACK: derive from Figma name: color/bg/primary → var(--color-bg-primary)
      // PREFERRED: pass in a cssVarMap built from actual codebase CSS variable names
      // e.g. cssVarMap = { 'color/bg/primary': '--color-bg-primary', ... }
      const cssName = cssVarMap?.[v.name]
        ?? v.name.replace(/\//g, '-').replace(/\s/g, '-').toLowerCase();
      v.setVariableCodeSyntax('WEB', `var(--${cssName})`);
      updated.push({ name: v.name, web: `var(--${cssName})` });
    }

    figma.closePlugin(JSON.stringify({ updated, count: updated.length }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

注: 導出した名前は、代替手段としてのみ使用します。実際の CSS 変数名が判明している場合は、必ずそれを優先して上書き設定してください。
---

## 7. エフェクトスタイル（シャドウ）とテキストスタイル

シャドウと複合タイポグラフィは変数にできません。これらはスタイルです。

### エフェクトスタイル（シャドウ）の作成

SDS（15 個のエフェクトスタイル）と SDS のシャドウパターン `Shadow/{Level}` を参照してください。

```javascript
(async () => {
  try {
    const RUN_ID = "ds-build-2024-001";

    // Shadow definitions — CSS equivalent in comments
    // CSS: 0 1px 2px rgba(0,0,0,0.05)
    const shadows = [
      {
        name: 'Shadow/Subtle',
        effects: [{
          type: 'DROP_SHADOW',
          color: { r: 0, g: 0, b: 0, a: 0.05 },
          offset: { x: 0, y: 1 },
          radius: 2,
          spread: 0,
          visible: true,
          blendMode: 'NORMAL'
        }]
      },
      {
        // CSS: 0 4px 6px -1px rgba(0,0,0,0.10), 0 2px 4px -1px rgba(0,0,0,0.06)
        name: 'Shadow/Medium',
        effects: [
          {
            type: 'DROP_SHADOW',
            color: { r: 0, g: 0, b: 0, a: 0.10 },
            offset: { x: 0, y: 4 },
            radius: 6,
            spread: -1,
            visible: true,
            blendMode: 'NORMAL'
          },
          {
            type: 'DROP_SHADOW',
            color: { r: 0, g: 0, b: 0, a: 0.06 },
            offset: { x: 0, y: 2 },
            radius: 4,
            spread: -1,
            visible: true,
            blendMode: 'NORMAL'
          }
        ]
      },
      {
        // CSS: 0 10px 15px -3px rgba(0,0,0,0.10), 0 4px 6px -2px rgba(0,0,0,0.05)
        name: 'Shadow/Strong',
        effects: [
          {
            type: 'DROP_SHADOW',
            color: { r: 0, g: 0, b: 0, a: 0.10 },
            offset: { x: 0, y: 10 },
            radius: 15,
            spread: -3,
            visible: true,
            blendMode: 'NORMAL'
          },
          {
            type: 'DROP_SHADOW',
            color: { r: 0, g: 0, b: 0, a: 0.05 },
            offset: { x: 0, y: 4 },
            radius: 6,
            spread: -2,
            visible: true,
            blendMode: 'NORMAL'
          }
        ]
      }
    ];

    // M3-style dual shadow (umbra + penumbra pattern):
    const m3Shadows = [
      {
        name: 'Elevation/1',
        effects: [
          { type: 'DROP_SHADOW', color: {r:0,g:0,b:0,a:0.30}, offset:{x:0,y:1}, radius:2, spread:0, visible:true, blendMode:'NORMAL' },
          { type: 'DROP_SHADOW', color: {r:0,g:0,b:0,a:0.15}, offset:{x:0,y:1}, radius:3, spread:1, visible:true, blendMode:'NORMAL' }
        ]
      },
      {
        name: 'Elevation/2',
        effects: [
          { type: 'DROP_SHADOW', color: {r:0,g:0,b:0,a:0.30}, offset:{x:0,y:1}, radius:2, spread:0, visible:true, blendMode:'NORMAL' },
          { type: 'DROP_SHADOW', color: {r:0,g:0,b:0,a:0.15}, offset:{x:0,y:2}, radius:6, spread:2, visible:true, blendMode:'NORMAL' }
        ]
      },
      {
        name: 'Elevation/3',
        effects: [
          { type: 'DROP_SHADOW', color: {r:0,g:0,b:0,a:0.30}, offset:{x:0,y:1}, radius:3, spread:0, visible:true, blendMode:'NORMAL' },
          { type: 'DROP_SHADOW', color: {r:0,g:0,b:0,a:0.15}, offset:{x:0,y:4}, radius:8, spread:3, visible:true, blendMode:'NORMAL' }
        ]
      }
    ];

    const created = [];
    for (const { name, effects } of shadows) {
      const style = figma.createEffectStyle();
      style.name = name;
      style.effects = effects;
      style.setPluginData('dsb_run_id', RUN_ID);
      style.setPluginData('dsb_key', `effect-style/${name}`);
      created.push({ name, id: style.id });
    }

    figma.closePlugin(JSON.stringify({ created, count: created.length }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

### テキストスタイルの作成

テキストスタイルを作成する前に、フォントを読み込む必要があります。

```javascript
(async () => {
  try {
    const RUN_ID = "ds-build-2024-001";

    // Define text styles — based on SDS typography hierarchy
    const textStyles = [
      // Display / Hero
      { name: 'Display/Hero',    family: 'Inter', style: 'Bold',      size: 72, lineHeight: 80, letterSpacing: -1.5 },
      // Headings
      { name: 'Heading/H1',      family: 'Inter', style: 'Bold',      size: 48, lineHeight: 56, letterSpacing: -1.0 },
      { name: 'Heading/H2',      family: 'Inter', style: 'Bold',      size: 40, lineHeight: 48, letterSpacing: -0.5 },
      { name: 'Heading/H3',      family: 'Inter', style: 'Semi Bold', size: 32, lineHeight: 40, letterSpacing: 0 },
      { name: 'Heading/H4',      family: 'Inter', style: 'Semi Bold', size: 24, lineHeight: 32, letterSpacing: 0 },
      // Body
      { name: 'Body/Large',      family: 'Inter', style: 'Regular',   size: 18, lineHeight: 28, letterSpacing: 0 },
      { name: 'Body/Medium',     family: 'Inter', style: 'Regular',   size: 16, lineHeight: 24, letterSpacing: 0 },
      { name: 'Body/Small',      family: 'Inter', style: 'Regular',   size: 14, lineHeight: 20, letterSpacing: 0 },
      // Label
      { name: 'Label/Large',     family: 'Inter', style: 'Medium',    size: 14, lineHeight: 20, letterSpacing: 0.1 },
      { name: 'Label/Medium',    family: 'Inter', style: 'Medium',    size: 12, lineHeight: 16, letterSpacing: 0.5 },
      { name: 'Label/Small',     family: 'Inter', style: 'Medium',    size: 11, lineHeight: 16, letterSpacing: 0.5 },
      // Code
      { name: 'Code/Base',       family: 'Roboto Mono', style: 'Regular', size: 14, lineHeight: 20, letterSpacing: 0 },
    ];

    // Load all required fonts first
    const fontSet = new Set(textStyles.map(s => JSON.stringify({ family: s.family, style: s.style })));
    await Promise.all([...fontSet].map(f => figma.loadFontAsync(JSON.parse(f))));

    const created = [];
    for (const { name, family, style, size, lineHeight, letterSpacing } of textStyles) {
      const ts = figma.createTextStyle();
      ts.name = name;
      ts.fontName = { family, style };
      ts.fontSize = size;
      ts.lineHeight = { value: lineHeight, unit: 'PIXELS' };
      ts.letterSpacing = { value: letterSpacing, unit: 'PIXELS' };
      ts.setPluginData('dsb_run_id', RUN_ID);
      ts.setPluginData('dsb_key', `text-style/${name}`);
      created.push({ name, id: ts.id });
    }

    figma.closePlugin(JSON.stringify({ created, count: created.length }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

---

## 8. 冪等性 — 作成前チェックのパターン

作成スクリプトでは、エンティティを作成する前に、すでに存在するかどうかを確認してください。これにより、部分的な失敗の後にスクリプトを再実行しても重複を防げます。

### コレクション作成前のチェック

```javascript
(async () => {
  try {
    const DSB_KEY = 'collection/primitives';
    const RUN_ID = "ds-build-2024-001";

    // Check if already exists
    const existing = await figma.variables.getLocalVariableCollectionsAsync();
    let primColl = existing.find(c => c.getPluginData('dsb_key') === DSB_KEY);

    if (primColl) {
      figma.closePlugin(JSON.stringify({ status: 'already_exists', collectionId: primColl.id, name: primColl.name }));
      return;
    }

    // Create only if not found
    primColl = figma.variables.createVariableCollection("Primitives");
    primColl.renameMode(primColl.modes[0].modeId, "Value");
    primColl.setPluginData('dsb_run_id', RUN_ID);
    primColl.setPluginData('dsb_key', DSB_KEY);

    figma.closePlugin(JSON.stringify({ status: 'created', collectionId: primColl.id }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

### 変数作成前のチェック

```javascript
(async () => {
  try {
    const VARIABLE_KEY = 'primitive/blue/500';
    const RUN_ID = "ds-build-2024-001";

    // Check if already exists by pluginData key
    const allVars = await figma.variables.getLocalVariablesAsync();
    const existing = allVars.find(v => v.getPluginData('dsb_key') === VARIABLE_KEY);

    if (existing) {
      figma.closePlugin(JSON.stringify({ status: 'already_exists', id: existing.id, name: existing.name }));
      return;
    }

    // ... create the variable ...
    figma.closePlugin(JSON.stringify({ status: 'created' }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

### pluginData のタグ付け戦略

作成したすべてのノードに、作成直後にタグを付けてください。`dsb_key` は、冪等性チェックに使う安定した論理識別子です。`dsb_run_id` は、どのビルド実行で作成されたかを示します（クリーンアップに便利です）。

```javascript
node.setPluginData('dsb_run_id', RUN_ID);       // build run ID
node.setPluginData('dsb_phase', 'phase1');       // which phase
node.setPluginData('dsb_key', 'color/bg/primary'); // stable logical key
```

**実行 ID によるクリーンアップ（安全 — タグ付けされたノードのみを対象とし、ユーザー所有のノードは決して対象にしません）：**

```javascript
(async () => {
  try {
    const TARGET_RUN_ID = "ds-build-2024-001"; // run to remove
    const allVars = await figma.variables.getLocalVariablesAsync();
    const removed = [];
    for (const v of allVars) {
      if (v.getPluginData('dsb_run_id') === TARGET_RUN_ID) {
        removed.push(v.name);
        v.remove();
      }
    }
    figma.closePlugin(JSON.stringify({ removed, count: removed.length }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

**名前の接頭辞でクリーンアップしないでください**（例：`color/` で始まるものをすべて削除する）。接頭辞がたまたま同じユーザー作成の変数まで削除されてしまいます。

---

## 9. 検証 — 数、エイリアス、スコープを確認する

Phase 1 の後に次のスクリプトを実行し、Phase 2 に進む前にすべて正しく作成されたことを確認してください。

### コレクション数と変数数の確認

```javascript
(async () => {
  try {
    const collections = await figma.variables.getLocalVariableCollectionsAsync();
    const allVars = await figma.variables.getLocalVariablesAsync();

    const summary = collections.map(c => {
      const vars = allVars.filter(v => v.variableCollectionId === c.id);
      return {
        name: c.name,
        id: c.id,
        modes: c.modes.map(m => m.name),
        variableCount: vars.length,
        missingScopes: vars.filter(v => v.scopes.length === 0 && v.resolvedType !== 'BOOLEAN').length,
        missingCodeSyntax: vars.filter(v => !v.codeSyntax['WEB'] && !v.remote).length,
        sampleVariables: vars.slice(0, 3).map(v => v.name)
      };
    });

    figma.closePlugin(JSON.stringify({
      collectionCount: collections.length,
      totalVariables: allVars.length,
      collections: summary
    }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

解釈：`missingScopes > 0`（プリミティブ型と BOOLEAN 以外の場合）→ スコープ設定に失敗しています。スコープ設定スクリプトを再実行してください。`missingCodeSyntax > 0` → コード構文が設定されていません。コード構文の一括設定スクリプトを実行してください。

注：プリミティブ型の `scopes = []` は正常です（空で非表示）。上記の `missingScopes` は、スコープが空の BOOLEAN 以外の変数を数えます。一覧を確認し、すべてプリミティブ型であることを確認してください。

### エイリアスの解決を確認

```javascript
(async () => {
  try {
    const allVars = await figma.variables.getLocalVariablesAsync();
    const collections = await figma.variables.getLocalVariableCollectionsAsync();

    const brokenAliases = [];
    const aliasedVars = [];

    for (const v of allVars) {
      if (v.remote) continue;
      const coll = collections.find(c => c.id === v.variableCollectionId);
      if (!coll) continue;

      for (const [modeId, val] of Object.entries(v.valuesByMode)) {
        if (val && typeof val === 'object' && val.type === 'VARIABLE_ALIAS') {
          aliasedVars.push({ name: v.name, aliasTargetId: val.id });
          // Verify the target exists
          const target = allVars.find(t => t.id === val.id);
          if (!target) {
            brokenAliases.push({ variable: v.name, modeId, missingTargetId: val.id });
          }
        }
      }
    }

    figma.closePlugin(JSON.stringify({
      totalAliased: aliasedVars.length,
      brokenAliases,
      brokenCount: brokenAliases.length,
      status: brokenAliases.length === 0 ? 'all_aliases_resolve' : 'BROKEN_ALIASES_FOUND'
    }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```
解釈: `brokenCount > 0` は、セマンティック変数が削除済み、または未作成のプリミティブを参照していることを意味します。不足しているプリミティブを作成してから、該当するセマンティック変数のエイリアス作成を再実行します。

### スタイル数を確認

```javascript
(async () => {
  try {
    const [textStyles, effectStyles] = await Promise.all([
      figma.getLocalTextStylesAsync(),
      figma.getLocalEffectStylesAsync()
    ]);

    figma.closePlugin(JSON.stringify({
      textStyles: textStyles.map(s => ({ name: s.name, fontSize: s.fontSize, fontFamily: s.fontName.family })),
      effectStyles: effectStyles.map(s => ({ name: s.name, effectCount: s.effects.length })),
      counts: { text: textStyles.length, effect: effectStyles.length }
    }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

### フェーズ 1 の終了条件チェックリスト

フェーズ 2 に進む前に、以下のすべてを確認します。

- 計画したすべてのコレクションが、正しいモード数で存在する
- プリミティブ変数: `scopes = []`、コード構文が設定されている
- セマンティック変数: 対象スコープが設定され、コード構文が設定され、プリミティブを参照するエイリアスになっている（生の値ではない）
- 壊れたエイリアスの数が 0 である
- 計画したすべてのテキストスタイルが、正しいフォントファミリー、サイズ、太さで存在する
- 計画したすべてのエフェクトスタイルが、正しいシャドウ値で存在する
- ユーザーが明示的に承認していない限り、`ALL_SCOPES` が設定された変数がない