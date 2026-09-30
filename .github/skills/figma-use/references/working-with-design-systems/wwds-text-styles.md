# デザインシステムを扱う: テキストスタイル

Figmaのテキストスタイルは、名前を付けて再利用できるタイポグラフィ定義です。デザイントークンライブラリにおけるタイプスケールに最も近いものです。テキストスタイルには、フォントファミリー、サイズ、ウェイト、行の高さ、文字間隔などのタイポグラフィ属性がひとまとめにされ、名前付きの単一の要素としてテキストノードに適用できます。

テキストスタイルは変数とは別のものです。タイポグラフィを単一の変数にまとめることはできません。複合型の変数は存在しないためです。ただし、テキストスタイルの個々のプロパティは変数にバインドできます（例: `fontSize`をサイズ変数に、`fontFamily`を文字列変数にバインドする）。これにより、スタイルをトークンシステムに組み込めます。

## モデル

`TextStyle`には、次の書き込み可能なプロパティがあります。

| プロパティ           | 型             | 備考                                                                        |
| ------------------ | ---------------- | ---------------------------------------------------------------------------- |
| `name`             | `string`         | グループ化にはスラッシュ区切りを使用（例: `"Heading/XL"`）                           |
| `fontSize`         | `number`         | ピクセル単位                                                                    |
| `fontName`         | `FontName`       | `{ family: string, style: string }` — **設定する前にフォントを読み込む必要があります** |
| `letterSpacing`    | `LetterSpacing`  | `{ value: number, unit: 'PIXELS' \| 'PERCENT' }`                             |
| `lineHeight`       | `LineHeight`     | `{ value: number, unit: 'PIXELS' \| 'PERCENT' }`または`{ unit: 'AUTO' }`       |
| `textCase`         | `TextCase`       | `'ORIGINAL' \| 'UPPER' \| 'LOWER' \| 'TITLE' \| 'SMALL_CAPS'`                |
| `textDecoration`   | `TextDecoration` | `'NONE' \| 'UNDERLINE' \| 'STRIKETHROUGH'`                                   |
| `paragraphSpacing` | `number`         |                                                                              |
| `paragraphIndent`  | `number`         |                                                                              |
| `description`      | `string`         | `BaseStyleMixin`から継承                                              |

### lineHeightとletterSpacingの形式

これらのプロパティには、数値だけではなくオブジェクトを指定する必要があります。

```js
// WRONG — bare number throws
style.lineHeight = 1.5;
style.letterSpacing = 0;

// CORRECT
style.lineHeight = { unit: "AUTO" }; // auto line height
style.lineHeight = { value: 24, unit: "PIXELS" }; // fixed pixel height
style.lineHeight = { value: 150, unit: "PERCENT" }; // 150% line height

style.letterSpacing = { value: 0, unit: "PIXELS" }; // zero tracking
style.letterSpacing = { value: -2, unit: "PIXELS" }; // tight tracking
style.letterSpacing = { value: 5, unit: "PERCENT" }; // percent-based tracking
```

`lineHeight`を読み取るときは、必ず最初に`unit`を確認してください。`{ unit: 'AUTO' }`には`value`キーがありません。

### テキストスタイルの変数バインディング

次のフィールドは、`style.setBoundVariable(field, variable)`で変数にバインドできます。

`fontFamily`, `fontSize`, `fontStyle`, `fontWeight`, `letterSpacing`, `lineHeight`, `paragraphSpacing`, `paragraphIndent`

バインドを解除するには、`style.setBoundVariable(field, null)`を使います。

**重要: ヘッドレスの`setBoundVariable`モードでは、`TextStyle`で`use_figma`を使用できません。**

この機能は、対話型のプラグインコンテキスト（UIプラグイン、Figmaエディター）でのみ利用できます。`use_figma`（MCP、アシスタントのヘッドレスランタイム）経由で実行している場合、`ts.setBoundVariable(...)`を呼び出すと`"not a function"`がスローされます。この場合は、代わりに値を直接設定してください。

```js
// In use_figma (headless) — variable binding not available
const ts = figma.createTextStyle();
ts.fontSize = 24; // set directly; cannot bind to a variable

// In a real interactive plugin — variable binding works
const ts = figma.createTextStyle();
ts.setBoundVariable("fontSize", fontSizeVariable);
```

テキストスタイルで変数のライブバインディングが必要な場合は、次の方法をおすすめします。

1. `use_figma`で値を直接指定してテキストスタイルを作成する
2. Figmaでファイルを開き、スタイルパネルから対話的に変数をバインドする、または
3. Figmaエディター内で動作する対話型プラグインを使う（ヘッドレスではないもの）

### ノードへのテキストスタイルの適用

`TextStyle`を取得したら、その`TextNode`をノードの`id`プロパティに割り当てて、`textStyleId`に適用します。非同期セッターの`setTextStyleIdAsync(id)`も使えます。ノードの`textStyleId`を設定するためにフォントを読み込む必要はありません。必要なのは、テキスト内容やフォントプロパティを直接編集する場合だけです。

## よくある注意点

- **`fontName`を設定する前にフォントを読み込む必要があります**: テキストスタイルのフォントを作成または変更する前に、`await figma.loadFontAsync({ family, style })`を呼び出してください。
- **フォントスタイル名はファイルによって異なります**: `"SemiBold"`や`"Semi Bold"`のようなフォントスタイル名は、フォントプロバイダーやFigmaファイルによって異なります。推測するのではなく、`loadFontAsync`を呼び出してエラーを捕捉し、正しいスタイル文字列を確認してください。
- **ヘッドレスでは`setBoundVariable`を使用できません**: `TextStyle.setBoundVariable()`／ヘッドレスモードでは、`"not a function"`を呼び出すと`use_figma`がスローされます。値を直接設定し、必要であれば対話的にバインドしてください。
- **スタイルは自動的には適用されません**: `TextStyle`を作成しても、そのIDをテキストノードに割り当てるまでは、どのノードにも影響しません。
- **`getLocalTextStyles()`は非推奨です**: 必ず`getLocalTextStylesAsync()`を使ってください。
- **名前は一意ではありません**: 同じ名前のテキストスタイルが複数存在することがあります。既知のスタイルを検索する場合は、名前だけでなくIDまたは`key`で照合してください。
- **スラッシュによるグループ化は見た目上のものです**: `"Heading/XL"`と`"HeadingXL"`は別の名前です。スラッシュはUI上の表示を補助するだけです。
- **`lineHeight`と`letterSpacing`にはオブジェクトを指定する必要があります**: `style.lineHeight = 1.5`を実行するとエラーになります。必ず`{ value, unit }`形式または`{ unit: 'AUTO' }`を使ってください。

## コードパターン

一覧表示、作成、フォントの確認、タイプスケール、スタイルの適用に関する実行可能なコード例は、[text-style-patterns.md](../text-style-patterns.md)を参照してください。
