# Plugin API インデックス

> 型定義の全体: `plugin-api-standalone.d.ts`（11,292 行）
> シンボル名で grep すると定義に移動できます。すべての `L#` 行番号はこのファイルを参照します。

---

## figma.\* — PluginAPI (L24)

### 識別情報と状態

| メンバー                        | 型                                                                               |
| ------------------------------- | -------------------------------------------------------------------------------- |
| `apiVersion`                    | `'1.0.0'`                                                                        |
| `editorType`                    | `'figma' \| 'figjam' \| 'dev' \| 'slides' \| 'buzz'`                             |
| `mode`                          | `'default' \| 'textreview' \| 'inspect' \| 'codegen' \| 'linkpreview' \| 'auth'` |
| `fileKey`                       | `string \| undefined`                                                            |
| `root`                          | `DocumentNode`                                                                   |
| `currentPage`                   | `PageNode` — `setCurrentPageAsync` 経由で設定                                    |
| `currentUser`                   | `User \| null`                                                                   |
| `mixed`                         | `unique symbol` — 選択範囲内の値が混在していることを示すセンチネル             |
| `skipInvisibleInstanceChildren` | `boolean`                                                                        |

### ナビゲーションと検索

| メソッド                    | 戻り値                                                  |
| --------------------------- | ------------------------------------------------------- |
| `setCurrentPageAsync(page)` | `Promise<void>` — **必ずこれを使うこと**。同期セッターは例外をスローします |
| `getNodeByIdAsync(id)`      | `Promise<BaseNode \| null>`                             |
| `getNodeById(id)`           | `BaseNode \| null`                                      |
| `getStyleByIdAsync(id)`     | `Promise<BaseStyle \| null>`                            |
| `getStyleById(id)`          | `BaseStyle \| null`                                     |

### ノードの作成

| メソッド                            | 戻り値                      |
| ----------------------------------- | --------------------------- |
| `createFrame()`                     | `FrameNode`                 |
| `createComponent()`                 | `ComponentNode`             |
| `createComponentFromNode(node)`     | `ComponentNode`             |
| `createRectangle()`                 | `RectangleNode`             |
| `createEllipse()`                   | `EllipseNode`               |
| `createLine()`                      | `LineNode`                  |
| `createPolygon()`                   | `PolygonNode`               |
| `createStar()`                      | `StarNode`                  |
| `createVector()`                    | `VectorNode`                |
| `createText()`                      | `TextNode`                  |
| `createSection()`                   | `SectionNode`               |
| `createPage()`                      | `PageNode`                  |
| `createSlice()`                     | `SliceNode`                 |
| `createBooleanOperation()`          | `BooleanOperationNode`      |
| `createTable(rows?, cols?)`         | `TableNode`                 |
| `createImage(data: Uint8Array)`     | `Image`                     |
| `createNodeFromSvg(svg)`            | `FrameNode`                 |
| `createNodeFromJSXAsync(jsx)`       | `Promise<SceneNode>`        |
| `importComponentByKeyAsync(key)`    | `Promise<ComponentNode>`    |
| `importComponentSetByKeyAsync(key)` | `Promise<ComponentSetNode>` |
| `importStyleByKeyAsync(key)`        | `Promise<BaseStyle>`        |

### スタイル（ローカル）

| メソッド                           | 戻り値          |
| ---------------------------------- | --------------- |
| `createPaintStyle()`               | `PaintStyle`    |
| `createTextStyle()`                | `TextStyle`     |
| `createEffectStyle()`              | `EffectStyle`   |
| `createGridStyle()`                | `GridStyle`     |
| `getLocalPaintStyles()` / `Async`  | `PaintStyle[]`  |
| `getLocalTextStyles()` / `Async`   | `TextStyle[]`   |
| `getLocalEffectStyles()` / `Async` | `EffectStyle[]` |
| `getLocalGridStyles()` / `Async`   | `GridStyle[]`   |

### フォント

| メソッド                    | 備考                             |
| --------------------------- | -------------------------------- |
| `loadFontAsync(fontName)`   | **テキストを編集する前に必ず呼び出すこと** |
| `listAvailableFontsAsync()` | `Promise<Font[]>`                |
| `hasMissingFont`            | `boolean`                        |

### プラグインのライフサイクル

| メソッド                                | 備考                                                          |
| --------------------------------------- | ------------------------------------------------------------ |
| `closePlugin(message?)`                 | **成功時の処理経路では必ず呼び出すこと**                     |
| `closePluginWithFailure(message?)`      | **catch ブロック内で必ず呼び出すこと。エラー時に `closePlugin` は使わないこと** |
| `commitUndo()`                          | スナップショットを Undo 履歴に保存                            |
| `triggerUndo()`                         | 最後のスナップショットに戻す                                  |
| `saveVersionHistoryAsync(title, desc?)` | `Promise<VersionHistoryResult>`                              |
| `notify(message, options?)`             | use_figma では **「not implemented」例外が発生します — 使用しないこと** |
| `openExternal(url)`                     | ブラウザーで URL を開く                                       |

### サブ API（figma のプロパティ）

| プロパティ            | インターフェース         | L#    |
| --------------------- | ------------------------ | ----- |
| `figma.variables`     | `VariablesAPI`           | L2016 |
| `figma.ui`            | `UIAPI`                  | L2604 |
| `figma.util`          | `UtilAPI`                | L2691 |
| `figma.constants`     | `ConstantsAPI`           | L2809 |
| `figma.clientStorage` | `ClientStorageAPI`       | L2531 |
| `figma.viewport`      | `ViewportAPI`            | L3086 |
| `figma.parameters`    | `ParametersAPI`          | L3292 |
| `figma.teamLibrary`   | `TeamLibraryAPI`         | L2372 |
| `figma.annotations`   | `AnnotationsAPI`         | L2187 |
| `figma.codegen`       | `CodegenAPI`             | L2871 |
| `figma.textreview?`   | `TextReviewAPI`          | L3166 |
| `figma.payments?`     | `PaymentsAPI`            | L2420 |
| `figma.buzz`          | `BuzzAPI`                | L2211 |
| `figma.timer?`        | `TimerAPI`（FigJam のみ） | L3053 |

---

## VariablesAPI — figma.variables (L2016)

```
getVariableById(id)                      Variable | null
getVariableByIdAsync(id)                 Promise<Variable | null>
getVariableCollectionById(id)            VariableCollection | null
getVariableCollectionByIdAsync(id)       Promise<VariableCollection | null>
getLocalVariables(type?)                 Variable[]           ← sync works; filter by VariableResolvedDataType
getLocalVariablesAsync(type?)            Promise<Variable[]>
getLocalVariableCollections()            VariableCollection[] ← sync works
getLocalVariableCollectionsAsync()       Promise<VariableCollection[]> ← may not be available; use sync
createVariable(name, collection, type)   Variable
createVariableCollection(name)           VariableCollection
createVariableAlias(variable)            VariableAlias
importVariableByKeyAsync(key)            Promise<Variable>
setBoundVariableForPaint(paint, field, variable)    → returns NEW paint — reassign
setBoundVariableForEffect(effect, field, variable)  → returns NEW effect — reassign
setBoundVariableForLayoutGrid(grid, field, variable)
```

**Variable (L10204):** `name`, `resolvedType`, `codeSyntax`, `scopes`, `hiddenFromPublishing`, `valuesByMode`, `variableCollectionId`

- `setVariableCodeSyntax(platform, value)` — platform: `'WEB' | 'ANDROID' | 'iOS'`
- `setValueForMode(collectionId, modeId, value)`
- `remove()`

**VariableCollection (L10418):** `name`, `modes`, `variableIds`, `defaultModeId`, `hiddenFromPublishing`

- `addMode(name)` → `modeId`; `removeMode(modeId)`; `renameMode(modeId, name)`

---

## ノードの種類

### 具象シーンノード

| ノード                  | L#     | 主な特徴                                           |
| ----------------------- | ------ | -------------------------------------------------- |
| `DocumentNode`         | L8960  | ルート。`children: PageNode[]`                      |
| `PageNode`             | L9119  | `children`、ローカルスタイル、`backgrounds`         |
| `FrameNode`            | L9311  | `DefaultFrameMixin` — オートレイアウト、クリップ、子要素 |
| `GroupNode`            | L9321  | 子要素のみ。オートレイアウトなし                    |
| `ComponentNode`        | L9678  | Frame と同様 + 公開可能                            |
| `ComponentSetNode`     | L9653  | バリアントセットのコンテナー                       |
| `InstanceNode`         | L9719  | Frame と同様。`mainComponent`、`detach()`           |
| `RectangleNode`        | L9378  | `DefaultShapeMixin` + 角の設定                      |
| `EllipseNode`          | L9410  | + `arcData`                                        |
| `LineNode`             | L9396  |                                                    |
| `PolygonNode`          | L9430  |                                                    |
| `StarNode`             | L9450  |                                                    |
| `VectorNode`           | L9476  | ベクターパス                                       |
| `TextNode`             | L9493  | リッチテキスト、フォント、セグメント                |
| `TextPathNode`         | L9564  | パスに沿ったテキスト                               |
| `BooleanOperationNode` | L9792  | `booleanOperation` プロパティ                      |
| `SliceNode`            | L9368  | エクスポート専用                                   |
| `SectionNode`          | L10754 | グループ化 + 塗り                                  |
| `TableNode`            | L9862  | 子要素は `TableCellNode`                            |

**FigJam のみ:** `StickyNode` L9812、`ConnectorNode` L10121、`ShapeWithTextNode` L9999、`StampNode` L9838、`CodeBlockNode` L10080、`EmbedNode` L10661、`LinkUnfurlNode` L10701、`MediaNode` L10721

**Slides のみ:** `SlideNode` L10784、`SlideRowNode` L10809、`SlideGridNode` L10822

**ユニオン型:**

```
type SceneNode  (L10917) = FrameNode | GroupNode | SliceNode | RectangleNode | LineNode
  | EllipseNode | PolygonNode | StarNode | VectorNode | TextNode | ComponentSetNode
  | ComponentNode | InstanceNode | BooleanOperationNode | SectionNode | ...
type BaseNode   (L10913) = DocumentNode | PageNode | SceneNode
```

---

## Mixin インターフェース

| Mixin                        | L#    | 提供する機能                                                                                  |
| ---------------------------- | ----- | ----------------------------------------------------------------------------------------------- |
| `BaseNodeMixin`              | L5284 | `id`、`name`、`type`、`parent`、`remove()`、プラグインデータ                                  |
| `SceneNodeMixin`             | L5561 | `visible`、`locked`、`opacity`、変数バインディング                                              |
| `ChildrenMixin`              | L5773 | `children`、`appendChild()`、`insertChild()`、`findAll()`、`findOne()`、`findAllWithCriteria()` |
| `LayoutMixin`                | L6135 | `x`、`y`、`width`、`height`、`rotation`、`resize()`、`rescale()`                              |
| `AutoLayoutMixin`            | L6436 | `layoutMode`、軸方向の整列、パディング、`itemSpacing`、`layoutSizingHorizontal/Vertical`         || `AutoLayoutChildrenMixin`    | L7064 | `layoutAlign`, `layoutGrow`, sizing — **`appendChild()`の後に設定すること**                             |
| `GridLayoutMixin`            | L6939 | CSS Gridのトラック、間隔、テンプレート                                                                  |
| `GridChildrenMixin`          | L7127 | グリッド内の子要素の配置                                                                          |
| `GeometryMixin`              | L7485 | `fills`、`strokes`、`strokeWeight`、`strokeAlign`                                               |
| `MinimalFillsMixin`          | L7328 | `fills`のみ                                                                                    |
| `MinimalStrokesMixin`        | L7246 | `strokes`、`strokeWeight`                                                                       |
| `BlendMixin`                 | L6339 | `opacity`、`blendMode`、`isMask`、`effects`                                                     |
| `CornerMixin`                | L7537 | `cornerRadius`、`cornerSmoothing`                                                               |
| `RectangleCornerMixin`       | L7560 | 各コーナーの半径                                                                                |
| `ExportMixin`                | L7577 | `exportSettings`、`exportAsync()`                                                               |
| `ReactionMixin`              | L7704 | `reactions`（プロトタイピング）                                                                       |
| `PublishableMixin`           | L7875 | `description`、`key`、`getPublishStatusAsync()`                                                 |
| `VariantMixin`               | L8182 | `variantProperties`                                                                             |
| `ComponentPropertiesMixin`   | L8229 | `componentProperties`、`addComponentProperty()`                                                 |
| `PluginDataMixin`            | L5443 | `getPluginData()`、`setPluginData()`、`getSharedPluginData()`                                   |
| `FramePrototypingMixin`      | L7651 | `overflowDirection`、`numberOfFixedChildren`                                                    |
| `BaseFrameMixin`             | L7939 | ChildrenMixin + LayoutMixin + AutoLayoutMixin + GeometryMixin + …                               |
| `DefaultFrameMixin`          | L7997 | BaseFrameMixin + FramePrototypingMixin + ReactionMixin                                          |
| `DefaultShapeMixin`          | L7928 | BlendMixin + GeometryMixin + LayoutMixin + ExportMixin + ReactionMixin                          |
| `ExplicitVariableModesMixin` | L9084 | `setExplicitVariableModeForCollection()`                                                        |

---

## ペイントと塗り

| Type            | L#    | Notes                                                                             |
| --------------- | ----- | --------------------------------------------------------------------------------- |
| `SolidPaint`    | L4302 | `type:'SOLID'`、`color: RGB`、`opacity`、`visible`、`blendMode`                   |
| `GradientPaint` | L4357 | `type: 'GRADIENT_LINEAR\|RADIAL\|ANGULAR\|DIAMOND'`、`gradientStops: ColorStop[]` |
| `ImagePaint`    | L4377 | `type:'IMAGE'`、`imageHash`、`scaleMode`                                          |
| `VideoPaint`    | L4413 | `type:'VIDEO'`                                                                    |
| `PatternPaint`  | L4449 | `type:'PATTERN'`                                                                  |
| `type Paint`    | L4481 | 5種類すべてのユニオン型                                                                 |
| `ColorStop`     | L4271 | `{ position: number, color: RGBA }`                                               |
| `ImageFilters`  | L4290 | 露出、コントラスト、彩度など                                              |

> **重要**: 塗りと線は**読み取り専用の配列**です。複製して変更し、再代入してください。

---

## エフェクト

| Type                               | L#    |
| ---------------------------------- | ----- |
| `DropShadowEffect`                 | L3966 |
| `InnerShadowEffect`                | L4009 |
| `BlurEffect` (Normal/Progressive)  | L4048 |
| `NoiseEffect` (Mono/Duo/Multitone) | L4105 |
| `TextureEffect`                    | L4180 |
| `GlassEffect`                      | L4209 |
| `type Effect`                      | L4250 |

---

## タイポグラフィ

| Type                | L#    | Notes                                                                                  |
| ------------------- | ----- | -------------------------------------------------------------------------------------- |
| `FontName`          | L3697 | `{ family: string, style: string }`                                                    |
| `TextNode`          | L9493 | `characters`、`textAlignHorizontal`、`fontSize`、`fontName`、`getStyledTextSegments()` |
| `StyledTextSegment` | L4882 | 範囲ごとのテキストプロパティ                                                              |
| `LetterSpacing`     | L4826 | `{ value, unit: 'PIXELS'\|'PERCENT' }`                                                 |
| `LineHeight`        | L4830 | `{ value, unit } \| { unit: 'AUTO' }`                                                  |
| `TextCase`          | L3701 | `'ORIGINAL'\|'UPPER'\|'LOWER'\|'TITLE'\|'SMALL_CAPS'`                                  |
| `TextDecoration`    | L3702 | `'NONE'\|'UNDERLINE'\|'STRIKETHROUGH'`                                                 |
| `OpenTypeFeature`   | L3728 | 合字、数字など                                                              |

---

## 変数とバインディング

| Type                          | L#     | Notes                                                         |
| ----------------------------- | ------ | ------------------------------------------------------------- |
| `Variable`                    | L10204 | 変数の基本オブジェクト                                          |
| `VariableCollection`          | L10418 | 変数とモードのコレクション                               |
| `VariableAlias`               | L10172 | 別の変数への参照                                 |
| `VariableValue`               | L10176 | `boolean \| string \| number \| RGB \| RGBA \| VariableAlias` |
| `VariableResolvedDataType`    | L10171 | `'BOOLEAN' \| 'COLOR' \| 'FLOAT' \| 'STRING'`                 |
| `VariableDataType`            | L5023  | `'VARIABLE_ALIAS' \| 'EXPRESSION'`を含む                   |
| `VariableScope`               | L10177 | 変数を適用できる場所                                 |
| `CodeSyntaxPlatform`          | L10203 | `'WEB' \| 'ANDROID' \| 'iOS'`                                 |
| `VariableBindableNodeField`   | L5712  | 変数バインディングを受け付けるノードフィールド                      |
| `VariableBindableTextField`   | L5739  | テキスト固有のバインド可能フィールド                                 |
| `VariableBindablePaintField`  | L5748  | `'color'`                                                     |
| `VariableBindableEffectField` | L5751  | `'color'\|'radius'\|'spread'\|'offsetX'\|'offsetY'`           |

---

## スタイル

| Interface        | L#     | Notes                                                  |
| ---------------- | ------ | ------------------------------------------------------ |
| `BaseStyleMixin` | L10977 | `name`、`id`、`key`、`type`、`description`、`remove()` |
| `PaintStyle`     | L11002 | `type:'PAINT'`、`paints: Paint[]`                      |
| `TextStyle`      | L11018 | `type:'TEXT'`、フォントプロパティ                         |
| `EffectStyle`    | L11087 | `type:'EFFECT'`、`effects: Effect[]`                   |
| `GridStyle`      | L11103 | `type:'GRID'`、`layoutGrids`                           |
| `type BaseStyle` | L11119 | 4種類すべてのユニオン型                                      |
| `type StyleType` | L10955 | `'PAINT' \| 'TEXT' \| 'EFFECT' \| 'GRID'`              |

---

## プリミティブとジオメトリ

| Type             | L#    | Shape                                         |
| ---------------- | ----- | --------------------------------------------- |
| `Vector`         | L3667 | `{ x: number, y: number }`                    |
| `Rect`           | L3671 | `{ x, y, width, height }`                     |
| `RGB`            | L3680 | `{ r, g, b }` — **0–1の範囲。0–255ではありません**      |
| `RGBA`           | L3688 | `{ r, g, b, a }` — **0–1の範囲**              |
| `Transform`      | L3666 | `[[a,b,tx],[c,d,ty]]` 2×3アフィン行列       |
| `ArcData`        | L3958 | `{ startingAngle, endingAngle, innerRadius }` |
| `Constraints`    | L4264 | `{ horizontal, vertical }: ConstraintType`    |
| `ConstraintType` | L4260 | `'MIN'\|'CENTER'\|'MAX'\|'STRETCH'\|'SCALE'`  |
| `VectorPath`     | L4792 | `{ windingRule, data: string }`               |
| `VectorNetwork`  | L4775 | 頂点 + セグメント + 領域                 |
| `Guide`          | L4482 | `{ axis, offset }`                            |

---

## プロトタイピング

| Type                  | L#    | Notes                                                     |
| --------------------- | ----- | --------------------------------------------------------- |
| `Reaction`            | L5015 | トリガー + アクションの組み合わせ                                     |
| `Trigger`             | L5146 | リアクションを開始するもの                               |
| `Action`              | L5064 | 実行される内容                                              |
| `Transition`          | L5145 | `SimpleTransition \| DirectionalTransition`               |
| `Easing`              | L5182 | イージング曲線の定義                                   |
| `Navigation`          | L5178 | `'NAVIGATE'\|'SWAP'\|'OVERLAY'\|'SCROLL_TO'\|'CHANGE_TO'` |
| `OverflowDirection`   | L5215 | `'NONE'\|'HORIZONTAL'\|'VERTICAL'\|'BOTH'`                |
| `OverlayPositionType` | L5219 | オーバーレイの配置                                         |

---

## イベントと変更

| Type                  | L#    | Notes                                                           |
| --------------------- | ----- | --------------------------------------------------------------- |
| `ArgFreeEventType`    | L11   | `'selectionchange'\|'currentpagechange'\|'close'\|timer events` |
| `RunEvent`            | L3321 | パラメーター付きのプラグイン実行                                      |
| `DropEvent`           | L3339 | ドラッグ＆ドロップ                                                   |
| `DocumentChangeEvent` | L3359 | ドキュメントのあらゆる変更                                             |
| `NodeChangeEvent`     | L3626 | ノードプロパティの変更                                           |
| `NodeChangeProperty`  | L3499 | 監視可能なすべてのプロパティ名                                    |
| `StyleChangeEvent`    | L3365 | スタイルの作成・削除・更新                                      |
| `DocumentChange`      | L3489 | `CreateChange \| DeleteChange \| PropertyChange`                |
| `TextReviewEvent`     | L3657 | テキストレビューのモード                                                |

---

## エクスポート

| Type                        | L#    | Notes                                         |
| --------------------------- | ----- | --------------------------------------------- |
| `ExportSettingsImage`       | L4561 | PNG/JPG/WEBP/BMP                              |
| `ExportSettingsSVG`         | L4634 |                                               |
| `ExportSettingsPDF`         | L4653 |                                               |
| `ExportSettingsREST`        | L4667 |                                               |
| `ExportSettingsConstraints` | L4554 | `{ type: 'SCALE'\|'WIDTH'\|'HEIGHT', value }` |

---

## 主要なサブAPIの領域

**ClientStorageAPI (L2531):** `getAsync(key)`、`setAsync(key, value)`、`keysAsync()`、`deleteAsync(key)`

**ViewportAPI (L3086):** `center: Vector`, `zoom: number`, `scrollAndZoomIntoView(nodes)`, `bounds: Rect`

**UtilAPI (L2691):** `solidPaint(hex, opacity?)`, `rgba(r,g,b,a?)`, `rgb(r,g,b)`, `colorToHex(color)`, `loadImageAsync(url)`, `clone(val)`

**TeamLibraryAPI (L2372):** `getAvailableLibraryVariableCollectionsAsync()`, `importVariableByKeyAsync(key)`

**Image (L11120):** `hash`, `getBytesAsync()`, `getSizeAsync()`

---

## 全シンボル（フラット一覧 — .d.ts ファイル内で grep してください）

シンボルを検索するには: `grep -n "^interface Foo\|^type Foo\|^declare type Foo" plugin-api-standalone.d.ts`

```
PluginAPI               VariablesAPI            AnnotationsAPI          TeamLibraryAPI
UIAPI                   UtilAPI                 ViewportAPI             ClientStorageAPI
ConstantsAPI            CodegenAPI              PaymentsAPI             TextReviewAPI
ParametersAPI           TimerAPI                BuzzAPI                 DevResourcesAPI

DocumentNode            PageNode                FrameNode               GroupNode
ComponentNode           ComponentSetNode        InstanceNode            RectangleNode
EllipseNode             LineNode                PolygonNode             StarNode
VectorNode              TextNode                TextPathNode            BooleanOperationNode
SliceNode               SectionNode             TableNode               TableCellNode
StickyNode              ConnectorNode           ShapeWithTextNode       StampNode
CodeBlockNode           EmbedNode               LinkUnfurlNode          MediaNode
WidgetNode              SlideNode               SlideRowNode            SlideGridNode
TransformGroupNode      HighlightNode           WashiTapeNode

BaseNodeMixin           SceneNodeMixin          ChildrenMixin           LayoutMixin
AutoLayoutMixin         AutoLayoutChildrenMixin GridLayoutMixin         GridChildrenMixin
GeometryMixin           MinimalFillsMixin       MinimalStrokesMixin     BlendMixin
MinimalBlendMixin       CornerMixin             RectangleCornerMixin    ExportMixin
ReactionMixin           PublishableMixin        VariantMixin            ComponentPropertiesMixin
PluginDataMixin         DevResourcesMixin       DevStatusMixin          StickableMixin
ConstraintMixin         DimensionAndPositionMixin AspectRatioLockMixin  FramePrototypingMixin
BaseFrameMixin          DefaultFrameMixin       DefaultShapeMixin       OpaqueNodeMixin
VectorLikeMixin         ComplexStrokesMixin     IndividualStrokesMixin  ContainerMixin
AnnotationsMixin        MeasurementsMixin       ExplicitVariableModesMixin

Variable                VariableCollection      VariableAlias           ExtendedVariableCollection
LibraryVariableCollection LibraryVariable
VariableValue           VariableResolvedDataType VariableDataType       VariableScope
CodeSyntaxPlatform      VariableBindableNodeField VariableBindableTextField
VariableBindablePaintField VariableBindableEffectField VariableBindableLayoutGridField

SolidPaint              GradientPaint           ImagePaint              VideoPaint
PatternPaint            Paint                   ColorStop               ImageFilters
DropShadowEffect        InnerShadowEffect       BlurEffect              NoiseEffect
TextureEffect           GlassEffect             Effect
LayoutGrid              RowsColsLayoutGrid      GridLayoutGrid

PaintStyle              TextStyle               EffectStyle             GridStyle
BaseStyle               BaseStyleMixin          StyleType

FontName                Font                    LetterSpacing           LineHeight
TextCase                TextDecoration          TextDecorationStyle     FontStyle
OpenTypeFeature         StyledTextSegment       LeadingTrim

Vector                  Rect                    RGB                     RGBA
Transform               ArcData                 Constraints             ConstraintType
VectorPath              VectorNetwork           VectorVertex            VectorSegment
VectorRegion            Guide                   BlendMode               MaskType

Reaction                Trigger                 Action                  Transition
Easing                  Navigation              OverflowDirection       OverlayPositionType
OverlayBackground       PublishStatus

ArgFreeEventType        RunEvent                DropEvent               DocumentChangeEvent
NodeChangeEvent         NodeChangeProperty      StyleChangeEvent        DocumentChange
TextReviewEvent         SlidesViewChangeEvent   CanvasViewChangeEvent

ExportSettingsImage     ExportSettingsSVG       ExportSettingsPDF       ExportSettingsREST
ExportSettingsConstraints

User                    ActiveUser              BaseUser                Image
Video                   VersionHistoryResult    FindAllCriteria
```
