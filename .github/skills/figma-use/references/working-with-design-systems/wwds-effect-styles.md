# デザインシステムの操作：エフェクトスタイル

Figma のエフェクトスタイルは、1 つ以上の視覚効果（ドロップシャドウ、インナーシャドウ、ぼかし）に名前を付けて再利用できるようにした定義です。デザインシステムにおけるシャドウまたはエレベーショントークンに最も近いものです。

エフェクトスタイルは変数とは別のものです。シャドウを表す単一の変数型はありません。ただし、エフェクト内の個々の数値プロパティや色プロパティは変数にバインドできます。これにより、シャドウ値をトークンシステムに組み込めます。

## モデル

`EffectStyle` には、基本スタイルフィールド以外に、書き込み可能な主要プロパティが 1 つあります。

| Property      | Type                    | Notes                                                 |
| ------------- | ----------------------- | ----------------------------------------------------- |
| `name`        | `string`                | グループ化にはスラッシュ区切りを使用（例：`"Elevation/200"`） |
| `effects`     | `ReadonlyArray<Effect>` | **読み取り専用配列** — 複製して変更し、再代入する         |
| `description` | `string`                | `BaseStyleMixin` から継承                       |

### エフェクトの種類

`Effect` は判別可能なユニオン型です。よく使われる型は次のとおりです。

| `type`            | 主なプロパティ                                                                                       |
| ----------------- | ---------------------------------------------------------------------------------------------------- |
| `DROP_SHADOW`     | `color: RGBA`, `offset: Vector`, `radius: number`, `spread: number`, `visible: boolean`, `blendMode` |
| `INNER_SHADOW`    | `DROP_SHADOW` と同じ                                                                                |
| `LAYER_BLUR`      | `radius: number`, `visible: boolean`                                                                 |
| `BACKGROUND_BLUR` | `radius: number`, `visible: boolean`                                                                 |

色の値はすべて 0～255 ではなく、0～1 の範囲（`RGBA`）です。

### エフェクトの変数バインディング

エフェクトプロパティは、ノード上で `setBoundVariableForEffect(effect, field, variable)` を使うか、構築時にインラインで指定することで、変数にバインドできます。

`color`、`radius`、`spread`、`offsetX`、`offsetY`

注：`setBoundVariableForEffect` は**新しい**エフェクトオブジェクトを返します。これを受け取り、`effects` 配列に再代入する必要があります。

### ノードへのエフェクトスタイルの適用

スタイルの `id` をノードの `effectStyleId` に割り当てます。すると、ノードの `effects` プロパティにスタイルの値が反映されます。

## よくある注意点

- **`effects` は読み取り専用**：配列をその場で変更することはできません。複製し、複製した配列を変更してから再代入します：`style.effects = [...style.effects, newEffect]`。
- **エフェクトは順番に重なる**：配列内の順序は見た目に影響します。ドロップシャドウは下から上の順に描画されます。
- **色は 0～1 の RGBA**：`{ r: 0, g: 0, b: 0, a: 0.15 }` のように指定します。16 進数でも 0～255 でもありません。
- **`getLocalEffectStyles()` は非推奨**：必ず `getLocalEffectStylesAsync()` を使ってください。
- **スタイルは自動適用されない**：`EffectStyle` を作成しても、その ID をノードに割り当てるまでは、どのノードにも影響しません。

## コードパターン

実行可能なコード例（エフェクトスタイルの一覧表示、作成、適用）については、[effect-style-patterns.md](../effect-style-patterns.md) を参照してください。
