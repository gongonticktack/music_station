# Image API クイックリファレンス

このファイルは代替 CLI モード専用。ユーザーが組み込みの `image_gen` ツールではなく `scripts/image_gen.py` の使用を明示的に求めた場合にのみ使用する。

以下のパラメータは Image API と同梱の代替 CLI の機能を説明するものであり、組み込みの `image_gen` ツールに通常渡せる引数だと考えないこと。

## 対象範囲

- この代替 CLI は GPT Image モデル（`gpt-image-1.5`、`gpt-image-1`、`gpt-image-1-mini`）向けである。
- 組み込みの `image_gen` ツールと代替 CLI では、利用できる設定が異なる。

## エンドポイント

- 生成: `POST /v1/images/generations`（`client.images.generate(...)`）
- 編集: `POST /v1/images/edits`（`client.images.edit(...)`）

## GPT Image モデルの主なパラメータ

- `prompt`: テキストプロンプト
- `model`: 画像モデル
- `n`: 画像数（1～10）
- `size`: `1024x1024`、`1536x1024`、`1024x1536`、または `auto`
- `quality`: `low`、`medium`、`high`、または `auto`
- `background`: 生成結果の透明性（`transparent`、`opaque`、または `auto`）。プロンプトに記す場面の背景とは異なる。
- `output_format`: `png`（既定）、`jpeg`、`webp`
- `output_compression`: 0～100（jpeg/webp のみ）
- `moderation`: `auto`（既定）または `low`

## 編集専用のパラメータ

- `image`: 1枚以上の入力画像。GPT Image モデルでは最大16枚指定できる。
- `mask`: 任意のマスク画像
- `input_fidelity`: `low`（既定）または `high`

`input_fidelity` に関するモデル別の補足:

- `gpt-image-1` と `gpt-image-1-mini` はすべての入力画像を保持するが、最初の画像の質感と細部をより豊かに再現する。
- `gpt-image-1.5` は最初の5枚の入力画像を、より高い忠実度で保持する。

## 出力

- 各画像の `b64_json` を含む `data[]` の一覧
- 同梱の `scripts/image_gen.py` CLI は `b64_json` をデコードして出力ファイルに保存する。

## 制限と補足

- 入力画像とマスクは50MB未満でなければならない。
- 既存画像の変更を求められた場合は、編集エンドポイントを使用する。
- マスク処理はプロンプトに従うため、正確な形状は保証されない。
- 大きい画像サイズと高品質の設定は、所要時間とコストを増やす。
- 高い `input_fidelity` は入力トークンの使用量を大きく増やす可能性がある。
- 選択した GPT Image モデルが特定のオプションに対応していないために失敗した場合は、そのオプションを外して手動で再試行する。

## 重要な境界

- `quality`、`input_fidelity`、明示的なマスク、`background`、`output_format` などのパラメータは、代替経路専用の実行設定である。
- 組み込みの `image_gen` ツールに渡せる引数だと考えないこと。
