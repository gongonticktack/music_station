> [figma-generate-library スキル](../SKILL.md)の一部です。

# 命名規則リファレンス

このリファレンスでは、figma-generate-library ワークフローで使用するすべての命名規則を説明します。変数、コンポーネント、ページ、バリアント、スタイル、区切り、ステータス表示の順に、すべての命名上の判断を網羅します。最後のセクションでは、既存ファイルの規則に合わせる場合と、ここに記載したデフォルトを使う場合について説明します。

---

## 1. 変数の命名

### スラッシュ階層（共通パターン）

Figma の変数にはすべて、スラッシュで区切ったパスを使用します。スラッシュによって Variables パネル内で視覚的にグループ化され、コード内のトークン階層にも直接対応します。

```
{category}/{subcategory}/{role}
```

Simple DS と Material 3 の実例：

```
color/bg/primary
color/bg/secondary
color/text/primary
color/text/muted
color/border/default
color/border/focus
color/feedback/error
color/feedback/success
spacing/xs
spacing/sm
spacing/md
spacing/lg
spacing/xl
spacing/2xl
radius/none
radius/sm
radius/md
radius/lg
radius/full
typography/body/font-size
typography/body/line-height
typography/heading/font-size
typography/heading/font-weight
```

### プリミティブコレクション

プリミティブ変数には生の値を格納し、利用者には公開しません（scope = `[]`）。Simple DS のカラー階調の規則に合わせ、フラットな `{family}/{step}` 形式を使用します。

```
blue/50
blue/100
blue/200
...
blue/900
gray/50
gray/100
...
gray/900
red/500
green/500
```

ステップ番号は対象コードベースの規則に従います。コードベースで `100–900` を使用している場合は、それに合わせます。`50–950` を使用している場合も同様です。コードベースに規則がない場合は、100刻みで `100–900` を使用します。

### セマンティックコレクション

セマンティック変数はプリミティブをエイリアスとして参照します。役割ベースの `{category}/{role}` または `{category}/{subcategory}/{role}` パターンを使用します。

```
color/bg/primary         → alias: primitives/white (light), primitives/gray/900 (dark)
color/bg/secondary       → alias: primitives/gray/100 (light), primitives/gray/800 (dark)
color/text/primary       → alias: primitives/gray/900 (light), primitives/white (dark)
color/text/secondary     → alias: primitives/gray/600 (light), primitives/gray/400 (dark)
color/border/default     → alias: primitives/gray/200 (light), primitives/gray/700 (dark)
```

**規則：** セマンティック変数に生の16進カラー値を格納してはいけません。必ずプリミティブをエイリアスとして参照します。新しいカラー値が必要な場合は、まずプリミティブを作成し、その後セマンティックエイリアスを作成します。

### 大文字・小文字の使い分け

**デフォルト：** 小文字とスラッシュを使用します：`color/bg/primary`、`spacing/2xl`。

**例外を設ける場合：**
- 既存ファイルで PascalCase が使われている場合（例：Material 3 では `Schemes/Primary` を使用）—それに合わせます。
- Variables パネルで読みやすくするためにデザインチームが PascalCase を好む場合は、コード構文を別途定義し、プラットフォームに適した大文字・小文字の形式を使えば問題ありません。
- モード名にはスペースや大文字・小文字の混在を使用できます（例：`SDS Light`、`Mode 1 → Light`）。これらは識別子ではなくラベルです。

**禁止事項：** 変数名の中で camelCase を使わないでください（Figma 名としての `colorBgPrimary` は誤りです。これは Android コード構文でのみ使います）。パスのセグメント内にスペースを入れないでください：`color/bg primary` は誤りで、`color/bg/primary` が正しい形式です。

**重要な違い：** 大文字・小文字の規則は *Figma の変数名* に適用されます。コード構文の名前は、Figma 名の大文字・小文字にかかわらず *プラットフォームの規則* に従います。詳細は §9 を参照してください。

---

## 2. コンポーネントの命名

### メインコンポーネント：PascalCase、接頭辞なし

ライブラリの利用者向けに公開するコンポーネントには、接頭辞を付けず、通常の PascalCase 名を使用します。

```
Button
Input
Checkbox
Toggle
Avatar
Badge
Card
Dialog
Tooltip
Banner
```

公開コンポーネントに名前空間の接頭辞を付けないでください（例：`DS/Button` や `sds-Button` という名前は付けません）。コンポーネント名のスラッシュは Assets パネル内で入れ子のグループを作るため、サブコンポーネントには適していますが、トップレベルの公開コンポーネントには適しません。

### サブコンポーネント：アンダースコア接頭辞 + スラッシュによる名前空間

ライブラリの利用者向けではない内部サブコンポーネントには、`_` 接頭辞を使用します。これにより、デフォルトで Assets パネルに表示されなくなり、他のデザイナーにも直接使用すべきでないことが伝わります。

```
_Button/Slot           (internal icon slot for Button)
_Input/Indicator       (internal state indicator for Input)
_Badge/Dot             (internal dot sub-component of Badge)
_Parts/Avatar.Status   (UI3 pattern: _Parts/{ParentName}.{SubPart})
_Slider/Handle         (UI3 pattern: _{ParentName}/{SubPart})
```

パターンの規則：
- すべての内部サブコンポーネントに `_` 接頭辞を使用します。例外はありません。
- スラッシュによる名前空間で、サブコンポーネントを親の下にグループ化します：`_Button/IconSlot`。
- 複数の親で共有するサブコンポーネントには、`_Parts/{ComponentName}.{SubPart}` を使用します。

### 非公開のドキュメント用コンポーネント

内部ドキュメント専用（本番利用ではない）のコンポーネントには、`.` 接頭辞を使用します。

```
.ExampleCard
.GuidelineHeader
.DemoFrame
```

これにより、キャンバス上ではアクセス可能な状態を保ちながら、利用者には表示されなくなります。

---

## 3. ページの命名

5つの参考デザインシステムでは、3種類の異なる命名パターンが使われています。1つのパターンを選び、ファイル内のすべてのページで一貫して適用してください。

### パターン1：シンプルな名前（Simple DS、Material 3、Polaris）

最も一般的なパターンです。装飾がなく、すっきりとして読みやすい名前を使います。

```
Cover
---
Foundations
Icons
---
Accordion
Avatars
Buttons
Cards
Dialog
Inputs
Menu
---
Utilities
Component Playground
```

新規作成時、または対象ファイルですでにこのスタイルが使われている場合に、このパターンを使用します。

### パターン2：絵文字接頭辞 + ステータス（UI3 Library）

最も情報量の多いパターンです。ページ名でアセットの種類、デザインの状態、コードの準備状況を示します。

構成：`[Asset Type Emoji] [Optional FPL Label] [Status Circle] Component Name [Code Status Bracket]`

| セグメント | 値 |
|---------|--------|
| アセットの種類 | コンポーネントページには C フラグの絵文字、パターンページには P フラグの絵文字を使用 |
| デザインの状態 | 緑の丸 = 準備完了、黄色の丸 = 作業中、赤の丸 = 使用禁止 |
| コードの状態 | （なし）= コード実装済み、`[beta]` = ベータ、`[future]` = 未実装 |

例：
```
Overview
Status Key
---
FPL COMPONENTS (go/fpl)
[C-flag] FPL [Green] Buttons
[C-flag] FPL [Green] Inputs
[C-flag] FPL [Yellow] Popovers [future]
---
UI3 COMPONENTS
[C-flag] [Green] Comments
---
PATTERNS
[P-flag] [Green] Editor / Layers
---
[Book] Cover
[Headstone] Deprecated
```

ライフサイクルの追跡が必要な大規模な複数チームのデザインシステムを構築する場合、または対象ファイルですでにこのパターンが使われている場合にのみ使用します。

### パターン3：絵文字接頭辞（Shop Minis）

ステータスの丸印を省いた、UI3 パターンの簡易版です。

```
📔 Cover
ℹ️ About
🚀 Getting started
——— THEME ———
Color
Typography
Spacing
——— COMPONENTS ———
Button
Input
Card
```

対象ファイルですでに絵文字接頭辞が使われていて、ライフサイクルの追跡が不要な場合に使用します。

### 共通規則（すべてのパターン）

- **Cover** は常に最初に置きます。
- **区切りページ**は、論理的な各セクションの前後に置きます。
- **基盤／トークンページ**は、常にコンポーネントページより前に置きます。
- **ユーティリティページと内部ページ**は、常に最後に置きます。
- 規則を1つ選び、ファイル内で複数のパターンを混在させないでください。

---

## 4. バリアントの命名

### Property=Value 形式

Figma のコンポーネントセットでは、すべてのコンポーネントバリアントプロパティとその値に `Property=Value` 形式を使用します。

```
Size=Small, Style=Primary, State=Default
Size=Medium, Style=Secondary, State=Hover
Size=Large, Style=Ghost, State=Disabled
```

可能な場合は、実際のプロパティ名をコードの prop 名に合わせます。

| Figma のプロパティ | 対応するコードの prop |
|---------------|---------------------|
| `Size` | `size` |
| `Style` / `Variant` | `variant` |
| `State` | 通常は CSS の `:hover`、`:focus`、`:disabled` で制御しますが、一部のシステムでは `state` を使用します |
| `Type` | `type` |
| `Disabled` | `disabled`（boolean） |
| `Icon` | `icon`（boolean またはインスタンスの差し替え） |

### プロパティ値の大文字・小文字

プロパティ値は Figma では **Title Case**（Variants パネルで読みやすくするため）を使用し、コードでは小文字に対応させます。

| Figma の値 | コードの値 |
|-------------|-----------|
| `Small` | `"small"` / `"sm"` |
| `Medium` | `"medium"` / `"md"` |
| `Large` | `"large"` / `"lg"` |
| `Primary` | `"primary"` |
| `Disabled` | `disabled`（boolean prop） |
| `Default` | *(通常は値がない／未設定の場合)* |

### Boolean プロパティ

Figma の boolean コンポーネントプロパティには、値として `true` / `false`（Figma ネイティブの boolean）を使用します。`Yes` / `No` や `On` / `Off` は使用しません。

---

## 5. スタイルの命名（テキストスタイルとエフェクトスタイル）

### テキストスタイル：category/name

```
Display/Large
Display/Medium
Display/Small
Heading/1
Heading/2
Heading/3
Body/Large
Body/Medium
Body/Small
Label/Large
Label/Small
Code/Inline
```

category セグメントはタイポグラフィ上の役割に対応します。可能な場合は、コードベースのタイポグラフィスケールと同じカテゴリ名を使用します。

### エフェクトスタイル（シャドウ）：category/name

```
Shadow/None
Shadow/Subtle
Shadow/Medium
Shadow/Strong
Shadow/Overlay
Elevation/0
Elevation/1
Elevation/2
Elevation/3
Elevation/4
Elevation/5
```

名前付きのセマンティックシャドウには `Shadow/` を使用します。Material Design 形式の番号付きエレベーションレベルには `Elevation/N` を使用します。

---

## 6. 区切りページ

区切りページは、Figma のページパネルに視覚的な区切りを作ることだけを目的とする空のページです。規則は2種類あります。

| 規則 | 例 | 使用例 |
|------------|---------|---------|
| 3つのダッシュ | `---` | Simple DS、UI3、Polaris、Material 3 |
| 装飾付きテキスト | `——— COMPONENTS ———` | Shop Minis |

3つのダッシュを使う規則（`---`）が最も一般的で、新規ファイルのデフォルトです。対象ファイルで装飾付きテキスト形式が使われていない限り、これを使用します。

**区切りを配置する場所：**

```
Cover
---                    ← after cover
Foundations
Icons
---                    ← before components
[component pages]
---                    ← before utilities
Utilities
```

---

## 7. ステータス表示（UI3 絵文字システム）

UI3 Library では、ページ名に色付きの丸い絵文字を使い、デザインの準備状況をひと目で示します。このシステムは任意ですが、大規模チームでは有効です。

| 絵文字 | 意味 | 使用するタイミング |
|-------|---------|-------------|
| 緑の丸 | 準備完了／承認済み | デザインが安定し、レビュー済みで、安全に使用できる |
| 黄色の丸 | 作業中／進行中 | デザインを現在作業中で、変更される可能性がある |
| 赤の丸 | 使用禁止 | 未準備のため参照しない。非推奨になっている可能性もある |

コードの準備状況は、コンポーネント名に角括弧を付けて示します。

| 括弧 | 意味 |
|---------|---------|
| （なし） | コンポーネントはコードに実装済みで、安定している |
| `[beta]` | コンポーネントはコードに実装済みだが、まだ安定していない（準備完了まで約3週間） |
| `[future]` | コードに未実装 |

**ドキュメントの状態（コンポーネントページ内）：**

UI3 形式のシステムを構築する場合、各ドキュメントフレームに次のいずれかのラベルを含むステータスバナーを付けます。

- `APPROVED` — 十分に審査済み
- `READY FOR REVIEW` — 承認待ち
- `WORK IN PROGRESS` — 現在設計中
- `NEEDS UPDATE` — 古くなっており、改訂が必要
- `DO NOT REFERENCE` — 使用すべきでない

このシステムは、ライフサイクルの追跡に実質的な価値がある大規模な複数チームのシステムにのみ推奨されます。小規模なシステムでは、絵文字によるステータス表示を省略し、シンプルなページ名を使用してください。

---

## 8. 既存の規則に合わせる場合とデフォルトを使う場合

**名前を付ける前に、必ず既存の状態を確認してください。** ページや変数を作成する前に `get_metadata` または `inspectFileStructure` を実行し、既存の規則を確認します。

### 既存ファイルに合わせる場合：

- ファイル内のページで、一貫した命名パターン（絵文字接頭辞、区切りスタイル、大文字・小文字の使い分け）がすでに使われている。
- ファイル内の変数コレクションですでに命名方式が確立されている。
- デザインチームが作業を始め、意図的な決定が反映されている。
- 既存のコンポーネント名で特定のパターン（PascalCase、kebab-case、名前空間の接頭辞）が使われている。

### このドキュメントのデフォルトを使う場合：

- 既存コンテンツのない新しい Figma ファイルを作成する。
- 既存の規則に一貫性がない（複数のスタイルが混在しており、合わせるべき規則がない）。
- ユーザーがベストプラクティスに沿った新しいデザインシステムを明示的に求めている。

### コードと Figma が一致しない場合：

コードベースでは `button-primary` が使われているのに、Figma に `Button` という名前のコンポーネントがある場合は、Figma のコンポーネント名を変更しないでください。代わりに、次のようにします。
- Figma の名前は `Button`（PascalCase の、人が読みやすい名前）のままにします。
- 変数のコード構文には、コードベースにある CSS トークン名を正確に設定します。
- Code Connect のソースパスには実際のコードファイルを指定し、コードコンポーネントの名前を正確に使います。

**ルール：** Figma の名前はデザイナー向けです。コード構文と Code Connect のソースパスには、コード内の識別子を正確に指定します。この2つの識別体系は並行して運用されます。

---

## 9. Figma の変数名とコード名 — 全体像

これは、特に誤解されやすい領域の1つです。Figma の名前とコード名が**意図的に異なる規則に従う**のは、それぞれ対象とする利用者と環境が異なるためです。

### 異なる理由

| | Figma の変数名 | コード構文（WEB） |
|---|---|---|
| **対象者** | Variables パネルを使うデザイナー | CSS/Swift/Kotlin を使う開発者 |
| **区切り文字** | `/`（スラッシュ）— Figma UI で視覚的なグループ化を作成 | `-`（ハイフン）— CSS カスタムプロパティの構文で必須 |
| **大文字・小文字** | 小文字（表示名には PascalCase も可 — 下記参照） | CSS は kebab-case、JS/Android は camelCase |
| **階層の深さ** | 2～4階層 | CSS はフラット、JS はドット記法 |
| **名前空間** | 暗黙的（コレクションによる） | 明示的なプレフィックス（`--p-`、`--md-`、`--cds-`） |

### 変換

```
Figma variable name              Code syntax (WEB)
──────────────────               ─────────────────
color/bg/primary          →      var(--color-bg-primary)
spacing/xs                →      var(--spacing-xs)
radius/md                 →      var(--radius-md)
typography/body/font-size →      var(--typography-body-font-size)

Pattern: replace "/" with "-", wrap in var(--)

**CRITICAL: The `var()` wrapper is REQUIRED for WEB code syntax.** Figma expects the full CSS function syntax — not just the property name. If you set `--color-bg-primary` (without `var()`), Dev Mode will show raw hex values instead of the variable reference. Always set `var(--color-bg-primary)`.
```

```
Figma variable name              Code syntax (ANDROID)
──────────────────               ─────────────────────
color/bg/primary          →      colorBgPrimary
spacing/xs                →      spacingXs
radius/md                 →      radiusMd

Pattern: replace "/" with "", capitalize each word after first
```

```
Figma variable name              Code syntax (iOS)
──────────────────               ─────────────────
color/bg/primary          →      Color.bgPrimary
spacing/xs                →      Spacing.xs
radius/md                 →      Radius.md

Pattern: first segment becomes class name, remainder becomes property (camelCase)
```

### 5つの参照ファイルにある実例

| ファイル | Figma の変数名 | WEB コード構文 | ANDROID コード構文 |
|------|--------------------|-----------------|--------------------|
| Simple DS | `color/bg/primary` | `var(--color-bg-primary)` | `colorBgPrimary` |
| Simple DS | `spacing/sm` | `var(--spacing-sm)` | `spacingSm` |
| Material 3 | `Schemes/Primary` | `var(--md-sys-color-primary)` | `colorPrimary` |
| Material 3 | `Corner/Extra-small` | `var(--md-sys-shape-corner-extra-small)` | `shapeCornerExtraSmall` |
| Polaris | `color/bg/surface` | `var(--p-color-bg-surface)` | — |

**Material 3 から得られる重要な観察：** Figma の名前 `Schemes/Primary` は、スペースを含む PascalCase ですが、WEB コード構文は `var(--md-sys-color-primary)` で、ベンダープレフィックス `md-sys-` が付いた完全な kebab-case です。Figma の名前とコード構文はほとんど似ていません。これは意図的なもので、成熟したデザインシステムではよく見られます。

### Figma の大文字・小文字：小文字が標準、表示名には PascalCase も有効

小文字を使う指針は標準的な設定であり、絶対的なルールではありません。実際のファイルを見ると、次のような例があります。

| ファイル | Figma での表記 | コード出力での表記 | 理由 |
|------|-----------|------------------|-----|
| Simple DS | `color/bg/primary`（小文字） | `var(--color-bg-primary)` | 直接対応 — シンプル |
| Material 3 | `Schemes/Primary`（PascalCase） | `var(--md-sys-color-primary)` | Variables パネルでは PascalCase の方が読みやすい。コード名は別途定義 |
| Polaris | `color/bg/surface`（小文字） | `var(--p-color-bg-surface)` | ベンダープレフィックス付きの直接対応 |

**ルール：** Figma の名前を CSS 名にそのまま対応させる場合は、小文字を使います。デザインシステムで技術的なコード名とは異なる、人が読みやすい変数名を使う場合は、PascalCase（または既存ファイルの表記）を使います。

### コードベースで CSS カスタムプロパティを使っていない場合

JavaScript を中心とするシステム（Chakra、Ant Design、MUI）の中には、CSS `var(--...)` をまったく使わないものもあります。それらのトークンは JS のテーマオブジェクトに格納されています。

```
Chakra:    colors.gray[500]         →  JS: theme.colors.gray[500]
Ant:       colorPrimary             →  JS: token.colorPrimary
MUI:       palette.primary.main     →  JS: theme.palette.primary.main
```

この場合は、CSS 変数ではなく JS のプロパティパスを WEB コード構文に設定します。
```javascript
// For a JS-object-based system like Chakra:
v.setVariableCodeSyntax('WEB', 'colors.gray.500');

// For Ant Design:
v.setVariableCodeSyntax('WEB', 'colorPrimary');
```

### 階層の深さ：コードベースに合わせる

スラッシュの階層数は、コードベースのネストの深さに合わせます。

| コードベースのパターン | Figma の階層 | 例 |
|-----------------|------------|---------|
| `--primary`（フラット） | 1～2階層 | `color/primary` |
| `--color-bg-surface`（3要素） | 3階層 | `color/bg/surface` |
| `--md-sys-color-primary`（ベンダー名 + 3要素） | 3階層（ベンダープレフィックスはコード構文にのみ含める） | `color/primary` |
| `theme.palette.primary.main`（4要素） | 3～4階層 | `color/palette/primary/main` |

**重要：** ベンダープレフィックス（`--p-`、`--md-sys-`、`--cds-`）は、Figma の変数名ではなく、**コード構文**に含めます。Figma の名前 `color/bg/surface` とコード構文 `var(--p-color-bg-surface)` を組み合わせるのが正しいパターンです。

### 発見時に行うこと

フェーズ 0 の調査では、対応関係の両側を明示的に記録します。

```
コードベースで見つかった各トークンについて:
  CSS 変数:       --sds-color-background-brand-default
  Figma 名:       color/bg/brand/default        （スラッシュ階層、ベンダープレフィックスなし）
  WEB 構文:       var(--sds-color-background-brand-default)  （正確な CSS 名）
  ANDROID 構文:   sdsColorBackgroundBrandDefault  （camelCase）
  iOS 構文:       Color.backgroundBrandDefault    （ドット記法）
```

この対応関係を状態台帳に保存します。フェーズ 1 で `setVariableCodeSyntax` を呼び出す際に使ってください。元の CSS 変数名が分かっている場合、Figma の名前からコード構文を導き出してはいけません。必ず元の名前を使ってください。
