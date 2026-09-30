> [figma-generate-library スキル](../SKILL.md)の一部です。

# Discovery Phase リファレンス

このドキュメントでは、デザインシステム構築のフェーズ0で必要となる作業をすべて説明します。トークンを見つけるためのコードベース分析、既存の規約を確認するためのFigmaファイルの調査、購読中のライブラリの検索、計画の作成、書き込み操作を始める前の競合解消が含まれます。

---

## 1. コードベースの分析 — トークンソースの特定

### 検索の優先順位

次の順序でトークンソースを探します。確定的なソースが見つかった時点で検索を終了します。複数の形式が共存する場合もあります。

1. デザイントークンファイル: `*.tokens.json`、`tokens/*.json`、`src/tokens/**`
2. CSS変数ファイル: `variables.css`、`tokens.css`、`theme.css`、`global.css`
3. Tailwind設定: `tailwind.config.js`、`tailwind.config.ts`
4. CSS-in-JSのテーマオブジェクト: `theme.ts`、`createTheme`、`ThemeProvider`
5. プラットフォーム固有: iOSアセットカタログ（`.xcassets`）、Androidの`themes.xml`、`colors.xml`

### CSSカスタムプロパティ（Webで最も一般的）

**検索対象:**

```
:root { ... }
@theme { ... }          ← Tailwind v4
--color-*, --spacing-*, --radius-*, --shadow-*, --font-*
```

**パターン:** `/--[\w-]+:\s*[^;]+/g`

**一般的なファイルの場所:** `src/styles/tokens.css`、`src/styles/variables.css`、`src/theme/*.css`

**抽出と命名の変換:**

| CSS Property | Figma Variable Name | Figma Type | WEB Code Syntax |
|---|---|---|---|
| `--color-bg-primary: #fff` | `color/bg/primary` | COLOR | `var(--color-bg-primary)` |
| `--color-text-secondary: #757575` | `color/text/secondary` | COLOR | `var(--color-text-secondary)` |
| `--spacing-sm: 8px` | `spacing/sm` | FLOAT | `var(--spacing-sm)` |
| `--radius-md: 8px` | `radius/md` | FLOAT | `var(--radius-md)` |
| `--font-body: "Inter"` | `typography/body/font-family` | STRING | `var(--font-body)` |

**命名規則:** カテゴリの境界ではハイフンをスラッシュに置き換えます。最後のパス要素内のハイフンはそのままにします。例: `--color-bg-primary` → `color/bg/primary`、ただし`--color-bg-primary-hover` → `color/bg/primary-hover`。

**元のCSS変数名は必ずコード構文の値として保存してください。** Figma変数名から導出してはいけません。コードベースで`--sds-color-background-brand-default`が使われている場合は、`setVariableCodeSyntax('WEB', '--sds-color-background-brand-default')`にその文字列をそのまま指定します。

### Tailwindの設定

**`tailwind.config.js`または`tailwind.config.ts`で確認する項目:**

```javascript
// theme.extend.colors → Figma color variables
{ primary: { DEFAULT: '#3366FF', light: '#6699FF', dark: '#0033CC' } }
// → color/primary/default, color/primary/light, color/primary/dark

// theme.extend.spacing → Figma FLOAT variables
{ 'xs': '4px', 'sm': '8px', 'md': '16px' }
// → spacing/xs = 4, spacing/sm = 8, spacing/md = 16

// theme.extend.borderRadius → Figma FLOAT variables
{ 'sm': '4px', 'md': '8px', 'lg': '16px' }
// → radius/sm = 4, radius/md = 8, radius/lg = 16
```

Tailwindのユーティリティクラス名（`bg-blue-500`、`p-4`）はトークンではありません。クラス名ではなく設定オブジェクトから値を抽出してください。

### Design Token Community Group（DTCG）形式

**パターン:** `*.tokens.json`または`tokens/*.json`。Style DictionaryやTokens Studioが生成した出力ではなく、ソースファイルを探してください。

```json
{
  "color": {
    "bg": {
      "primary": { "$type": "color", "$value": "#ffffff" },
      "secondary": { "$type": "color", "$value": "#f5f5f5" }
    }
  },
  "spacing": {
    "sm": { "$type": "dimension", "$value": "8px" }
  }
}
```

ネストされたキーは、スラッシュ区切りのFigma名に対応します。例: `color.bg.primary` → `color/bg/primary`。

### CSS-in-JS / テーマオブジェクト

**検索対象:** `createTheme`、`ThemeProvider`、`theme = {}`、styled-components、Emotion、Stitches、vanilla-extract

```typescript
// theme.colors.bg.primary → Figma variable: color/bg/primary
// theme.spacing.sm        → Figma variable: spacing/sm
// Multiple theme objects (lightTheme, darkTheme) → modes in the same collection
```

### iOSのトークンソース

```swift
// Asset catalog colors in .xcassets/Colors.xcassets
// extension Color { static let bgPrimary = Color("bg-primary") }
// Look for traitCollection.userInterfaceStyle for dark mode detection
```

### Androidのトークンソース

```kotlin
// res/values/colors.xml  <color name="primary">#3366FF</color>
// res/values-night/colors.xml  (dark mode overrides)
// MaterialTheme.colorScheme.primary in Compose
// val Primary = Color(0xFF3366FF)
```

### ダークモードの検出

| Platform | Signal |
|---|---|
| Web (CSS) | `@media (prefers-color-scheme: dark)`、`.dark { }`、`[data-theme="dark"]` |
| Web (Tailwind) | 設定内の`darkMode: 'class'`または`darkMode: 'media'` |
| Web (JS) | `darkTheme`と並ぶ独立した`lightTheme`オブジェクト |
| iOS | `Color(uiColor:)`を使った`traitCollection.userInterfaceStyle`、デュアルアピアランスのアセットカタログ |
| Android | `themes.xml`を含む`Theme.*.Night`、Composeの`isSystemInDarkTheme()`、`values-night/`フォルダー |

**Figmaへのマッピング:** ダークモードがある場合、セマンティックカラーコレクションには最低2つのモード（Light/Dark）を設定します。プリミティブコレクションは単一モードのままにします。

### シャドウ／エレベーションの抽出

シャドウはFigma変数にできません。**エフェクトスタイル**として作成します。

```css
/* Look for: box-shadow, --shadow-* */
--shadow-sm: 0 1px 2px rgba(0,0,0,0.05);
--shadow-md: 0 4px 6px -1px rgba(0,0,0,0.10);
--shadow-lg: 0 10px 15px -3px rgba(0,0,0,0.10);
```

CSSの`0 4px 6px -1px rgba(0,0,0,0.1)` → Figma:
```
{ type: "DROP_SHADOW", offset: {x:0, y:4}, radius: 6, spread: -1, color: {r:0, g:0, b:0, a:0.1} }
```

### タイポグラフィの抽出

| Code token | Maps to |
|---|---|
| `font-size: 16px` | FLOAT変数（スコープ`FONT_SIZE`）またはText Styleの`fontSize` |
| `line-height: 1.5` | Text Styleの`lineHeight: {value: 24, unit: "PIXELS"}` |
| `font-weight: 600` | Text Styleの`fontName: {family: "Inter", style: "Semi Bold"}` |
| `letter-spacing: -0.02em` | Text Styleの`letterSpacing: {value: -2, unit: "PERCENT"}` |
| `font-family: "Inter"` | STRING変数（スコープ`FONT_FAMILY`）またはText Styleの`fontName.family` |

複合テキストスタイル（すべてのプロパティをまとめたもの）にはFigma Text Stylesを使います。個別のプロパティには、適切なスコープを設定したFigma変数を使います。

### コンポーネントの抽出

各コンポーネントについて、次の項目を抽出します。

1. **名前** → Figma component set名
2. **Union型のprops** → VARIANTプロパティ
3. **文字列コンテンツのprops** → TEXTプロパティ
4. **Boolean型のprops** → BOOLEANプロパティ（インタラクション状態と組み合わせる場合はVARIANT State）
5. **子／スロットのprops** → INSTANCE_SWAPプロパティ

```typescript
// React example:
interface ButtonProps {
  size: 'sm' | 'md' | 'lg';          // → VARIANT: Size = sm|md|lg
  variant: 'primary' | 'secondary';   // → VARIANT: Style = primary|secondary
  disabled?: boolean;                  // → VARIANT: State (combine: default|hover|pressed|disabled)
  label: string;                       // → TEXT: Label
  icon?: ReactNode;                    // → INSTANCE_SWAP: Icon + BOOLEAN: Show Icon
}
// → Component Set "Button", variant count: 3 sizes × 2 styles × 4 states = 24
```

---

## 2. Figmaファイルの調査

各ビルドの開始時に、次の`use_figma`スニペットを実行してください。いずれも読み取り専用で、ユーザーチェックポイントの前に安全に実行できます。

### すべてのページを一覧表示

```javascript
(async () => {
  try {
    const pages = figma.root.children.map((p, i) => ({
      index: i,
      name: p.name,
      id: p.id,
      childCount: p.children.length
    }));
    figma.closePlugin(JSON.stringify({ pages }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

読み取り結果の解釈: 命名規則の参考としてページ名を記録します（PascalCaseか、文のような大文字小文字の使い分けか）。区切りページ（`---`）の数を数え、既存のコンポーネントページと基盤ページを特定します。

### モードを含めて変数コレクションを一覧表示

```javascript
(async () => {
  try {
    const collections = await figma.variables.getLocalVariableCollectionsAsync();
    const result = collections.map(c => ({
      id: c.id,
      name: c.name,
      modes: c.modes,                    // [{modeId, name}, ...]
      variableCount: c.variableIds.length,
      defaultModeId: c.defaultModeId
    }));
    figma.closePlugin(JSON.stringify({ collections: result }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

読み取り結果の解釈: プリミティブとセマンティックの既存の分割を特定し、モード名（"Light/Dark"か、"SDS Light/SDS Dark"か）を確認し、スコープを把握するために変数の数を数えます。

### コレクション内の変数を一覧表示（名前、型、スコープ、サンプル値を含む）

```javascript
(async () => {
  try {
    const collections = await figma.variables.getLocalVariableCollectionsAsync();
    const targetName = "Color"; // change to the collection you want to inspect
    const coll = collections.find(c => c.name === targetName);
    if (!coll) { figma.closePlugin(JSON.stringify({ error: `Collection "${targetName}" not found` })); return; }

    const allVars = await figma.variables.getLocalVariablesAsync();
    const vars = allVars.filter(v => v.variableCollectionId === coll.id);

    const result = vars.map(v => ({
      id: v.id,
      name: v.name,
      resolvedType: v.resolvedType,
      scopes: v.scopes,
      codeSyntax: v.codeSyntax,
      // First mode value only, for a sample
      sampleValue: v.valuesByMode[coll.defaultModeId]
    }));

    figma.closePlugin(JSON.stringify({ collection: coll.name, variableCount: result.length, variables: result }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

読み取り結果の解釈: 変数が`ALL_SCOPES`を使っていないかを確認し（問題あり）、命名規則（スラッシュ区切りの階層か）を確認し、コード構文が設定されているかを確認し、エイリアスの連鎖を特定します。

### プロパティを含めてコンポーネントセットを一覧表示

```javascript
(async () => {
  try {
    await figma.setCurrentPageAsync(figma.currentPage); // ensures page context
    const componentSets = figma.currentPage.findAll(n => n.type === 'COMPONENT_SET');
    const result = componentSets.map(cs => ({
      id: cs.id,
      name: cs.name,
      variantCount: cs.children.length,
      properties: Object.entries(cs.componentPropertyDefinitions).map(([key, def]) => ({
        name: key,
        type: def.type,
        variantOptions: def.variantOptions || null,
        defaultValue: def.defaultValue
      }))
    }));
    figma.closePlugin(JSON.stringify({ componentSets: result, count: result.length }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

注: すべてのページを検索するには、`figma.root.children`を反復し、各ページで`setCurrentPageAsync`を実行します。

### すべてのスタイルを一覧表示

```javascript
(async () => {
  try {
    const [textStyles, effectStyles, paintStyles] = await Promise.all([
      figma.getLocalTextStylesAsync(),
      figma.getLocalEffectStylesAsync(),
      figma.getLocalPaintStylesAsync()
    ]);

    figma.closePlugin(JSON.stringify({
      textStyles: textStyles.map(s => ({ id: s.id, name: s.name, fontSize: s.fontSize, fontName: s.fontName })),
      effectStyles: effectStyles.map(s => ({ id: s.id, name: s.name, effectCount: s.effects.length })),
      paintStyles: paintStyles.map(s => ({ id: s.id, name: s.name })),
      counts: { text: textStyles.length, effect: effectStyles.length, paint: paintStyles.length }
    }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```

### 既存コンポーネントの命名規則を確認

```javascript
(async () => {
  try {
    // Replace with the node ID of an existing component to analyze
    const node = await figma.getNodeByIdAsync("YOUR_NODE_ID");
    if (!node) { figma.closePlugin(JSON.stringify({ error: "Node not found" })); return; }

    // Check fills for variable bindings
    const fillInfo = [];
    if ('fills' in node && Array.isArray(node.fills)) {
      for (const fill of node.fills) {
        if (fill.type === 'SOLID' && fill.boundVariables?.color) {
          fillInfo.push({ type: 'variable_alias', id: fill.boundVariables.color.id });
        } else if (fill.type === 'SOLID') {
          fillInfo.push({ type: 'hardcoded', r: fill.color.r, g: fill.color.g, b: fill.color.b });
        }
      }
    }

    figma.closePlugin(JSON.stringify({
      name: node.name,
      type: node.type,
      fills: fillInfo,
      pluginData: node.getPluginData('dsb_key') || null
    }));
  } catch(e) { figma.closePluginWithFailure(e.toString()); }
})();
```
---

## 3. search_design_system の使用

### 検索対象

`search_design_system` は、指定したファイルの**サブスクライブ済みデザインライブラリ**を対象に、3種類の検索を並行して実行します。

1. **コンポーネント** — 公開済みライブラリコンポーネント。レコメンデーションエンジンで名前や説明を検索します（関連度順で、完全一致ではありません）。
2. **変数** — サブスクライブ済みライブラリ全体のデザイントークン（色、間隔など）
3. **スタイル** — ペイントスタイル、テキストスタイル、エフェクトスタイル

検索対象となるのは、そのファイルがサブスクライブしているライブラリだけです。結果が空の場合、ファイルがデザインシステムライブラリをサブスクライブしていない可能性があります。

### 入力

```
search_design_system({
  query: "button",              // required — text query
  fileKey: "abc123",            // required — your file key
  includeComponents: true,      // default true
  includeVariables: true,       // default true
  includeStyles: true           // default true
})
```

### 戻り値

```json
{
  "components": [
    {
      "name": "Button",
      "libraryName": "Design System",
      "assetType": "component_set",
      "componentKey": "abc123def",
      "description": "Primary action button"
    }
  ],
  "variables": [
    {
      "name": "colors/primary/500",
      "variableType": "COLOR",
      "variableSetKey": "set1key",
      "key": "var1key",
      "scopes": ["FILL_COLOR"],
      "variableCollectionName": "Colors"
    }
  ],
  "styles": [
    {
      "name": "Heading/H1",
      "styleType": "TEXT",
      "key": "style1key"
    }
  ]
}
```

### 結果の解釈

**コンポーネント:** `componentKey` を使うと、`use_figma` でコンポーネントをインポートできます。
```javascript
const component = await figma.importComponentByKeyAsync("abc123def");
// or for component sets:
const componentSet = await figma.importComponentSetByKeyAsync("abc123def");
```

**変数:** `variableSetKey` はコレクションキー、`key` は変数キーです。これらを使って、どのような命名規則が使われているか、またエイリアスとして利用できるトークンが何かを把握します。

**スタイル:** `key` は `figma.importStyleByKeyAsync(key)` で現在のファイルにインポートする際に使用できます。

### 検索するタイミング

- **フェーズ 0、ステップ 0c**: 計画を立てる前に、広く検索します（`query: "button"`、`query: "color"`、`query: "spacing"`）。これにより、再利用の基準を確認できます。
- **各コンポーネントの作成直前**: `use_figma` の作成コードを書く前に、そのコンポーネント名で検索します。

**再利用の判断:**

| 条件 | 判断 |
|---|---|
| バリアント API が一致し、同じトークンモデルのコンポーネントが見つかった | インポートして再利用 |
| コンポーネントは見つかったが、バリアントのプロパティが異なる、または値がハードコードされている | 再構築 |
| 見た目は一致するが、API に互換性がないコンポーネントが見つかった | ラップする: 新しいラッパーコンポーネント内にインスタンスとしてネストする |

---

## 4. 計画の作成

コードベースの分析と Figma の確認後、対応表を作成してユーザーに提示します。

### トークン → 変数の対応表

コード内で見つかった各トークンについて、次を記録します。

| Code Token | CSS Name | Raw Value | Figma Collection | Figma Variable Name | Figma Type | Mode(s) |
|---|---|---|---|---|---|---|
| `theme.colors.blue[500]` | `--color-blue-500` | `#3B82F6` | Primitives | `blue/500` | COLOR | Value |
| `theme.colors.bg.primary` | `--color-bg-primary` | (light: blue/50, dark: gray/900) | Color | `color/bg/primary` | COLOR | Light, Dark |
| `theme.spacing.sm` | `--spacing-sm` | `8px` | Spacing | `spacing/sm` | FLOAT | Value |
| `theme.radii.md` | `--radius-md` | `8px` | Spacing | `radius/md` | FLOAT | Value |
| `theme.shadows.md` | `--shadow-md` | `0 4px 6px rgba(0,0,0,0.1)` | — | — | Effect Style | — |

### コンポーネント → コンポーネントセットの対応表

| Code Component | Props → Variant Axes | Variant Count | Figma Page | Reuse? |
|---|---|---|---|---|
| `Button` | size (sm/md/lg) × variant (primary/secondary) × state (default/hover/disabled) | 18 | Buttons | Search first |
| `Avatar` | size (sm/md/lg) × type (image/initials/icon) | 9 | Avatars | Search first |

### 差分の特定

コードで見つかったものと、Figma にすでに存在するものを比較します。

- **新規:** コードにはあるが Figma にはないトークンやコンポーネント → 作成
- **既存:** 一致する名前のトークンやコンポーネントが Figma にある → スコープとコード構文を確認し、スキップまたは更新
- **競合:** 同じ名前で値が異なる → ユーザーに確認する（セクション 5 を参照）
- **Figma のみ:** Figma にはあるがコードにはない → ユーザーに知らせ、通常はスキップ

### ユーザーに提示する確認メッセージのテンプレート

続行前にこのメッセージを提示します。ユーザーの明示的な承認なしに、フェーズ 1 を開始してはいけません。

```
調査結果と作成計画を示します:

コードベースの分析
  色: 基本トークン {N} 件（{families}）、意味的トークン {M} 件（{light/dark if applicable}）
  余白: トークン {N} 件（{range}）
  書体: テキストスタイル {N} 件、個別の尺度トークン {M} 件
  影: {N} 段階 → Effect Styles に変換
  コンポーネント: {list of component names}

既存の FIGMA ファイル
  コレクション: 既存 {N} 件
  変数: 既存 {M} 件
  スタイル: テキスト {K} 件、エフェクト {L} 件、ペイント {J} 件
  コンポーネント: {list}

計画
  新しいコレクション: {list with mode counts}
  新しい変数: 約 {N} 件（{breakdown by collection}）
  新しいスタイル: テキスト {N} 件、エフェクト {M} 件
  新しいコンポーネント: {list}
  各コンポーネントの前に検索するライブラリ: {list}

判断が必要な不足点と競合
  ⚠ {conflict description} — コードは X、Figma は Y です。どちらを採用しますか？

作成しないもの（理由）
  - {item}: 同じ慣習に従うものが Figma に既にある
  - {item}: Figma 変数に対応していない（例: z-index、アニメーションのタイミング）

進めてもよいですか？
```

---

## 5. 競合の解決 — コードと Figma が一致しない場合

同じトークンやコンポーネントがコードと Figma の両方に存在し、値、名前、構造が異なる場合は、**必ずユーザーに確認します**。黙ってどちらかを選んではいけません。

### 判断の枠組み

| Scenario | Ask the user |
|---|---|
| Same CSS name, different hex value (e.g., `--color-accent` is `#3366FF` in code but `#5B7FFF` in Figma) | "コードでは `#3366FF` ですが、Figma の `color/accent/default` には現在 `#5B7FFF` が設定されています。どちらが正しいですか？" |
| Same component name, different variant axes (code has `size: sm/md/lg`, Figma has `Size: Small/Large`) | "コードではサイズが 3 種類 (sm/md/lg) ですが、Figma には 2 種類 (Small/Large) あります。Medium を追加しますか、それともコードに合わせて名前を変更しますか？" |
| Code has a semantic token with no primitive layer; Figma already has a fully-layered system | "コードベースではフラットな単一レイヤーのトークンモデルを使っています。Figma ファイルではプリミティブとセマンティックを分けています。Figma の構成とコードの構成のどちらに合わせますか？" |
| Figma variable exists but has `ALL_SCOPES` (incorrect per best practice) | "`color/bg/primary` はすでにありますが、スコープに `ALL_SCOPES` が設定されています。`FRAME_FILL, SHAPE_FILL` に変更することをお勧めします。スコープを更新してもよいですか？" |
| Code uses camelCase (`backgroundColor`), Figma uses slash-separated (`color/bg/default`) | "コードベースでは camelCase の命名を使っています。Figma ファイルではスラッシュ区切りの階層を使っています。新しい変数にはスラッシュ区切り (Figma 標準) を使い、コード構文を通じて対応づけますか？" |

### コードを優先

次の項目では、コードを信頼できる情報源として扱います。
- 16 進値（コードが本番環境で使われている値）
- トークン名（CSS 変数名がコード構文になる）
- モードの値（ライト/ダークの分割はコードに由来する）

### Figma を優先

次の項目では、Figma を信頼できる情報源として扱います。
- コレクションの構成（適切に構成されたシステムがすでにある場合は、置き換えずに拡張する）
- 変数の命名階層（デザイナーがすでに特定の名前でシステムを使っている場合）
- ページ構成（既存のページ整理パターンに合わせる）

### どちらとも決められない場合: 調整

どちらが正しいとも明確に言えない場合は、解決案を提示して尋ねます。
> 「[option] を提案します。これならコードのトークン名と Figma の命名規則の両方を維持できます。この方法でよいですか？」
