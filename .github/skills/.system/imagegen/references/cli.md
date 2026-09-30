# CLI リファレンス（`scripts/image_gen.py`）

このファイルは、フォールバックの CLI モード専用です。ユーザーが組み込みの `image_gen` ツールではなく `scripts/image_gen.py` を使うよう明示的に求めた場合にのみ読んでください。

`generate-batch` は、このフォールバック経路で使う CLI サブコマンドです。スキルの最上位モードではありません。

## この CLI でできること
- `generate`：プロンプトから新しい画像を生成する
- `edit`：既存の画像を 1 枚以上編集する
- `generate-batch`：JSONL ファイルから多数の生成ジョブを実行する

実際の API 呼び出しには、**ネットワークアクセス**と `OPENAI_API_KEY` が必要です。`--dry-run` には必要ありません。

## クイックスタート（どのリポジトリからでも実行可能）
スキルの CLI を指す固定のパスを設定します（`CODEX_HOME` の既定値は `~/.codex`）。

```
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export IMAGE_GEN="$CODEX_HOME/skills/.system/imagegen/scripts/image_gen.py"
```

使用する環境のパッケージマネージャーで、依存パッケージをその環境にインストールしてください。uv で管理されている環境では、引き続き `uv pip install ...` を推奨します。

## クイックスタート

ドライラン（API 呼び出しなし。ネットワークも `openai` パッケージも不要）：

```bash
python "$IMAGE_GEN" generate \
  --prompt "Test" \
  --out output/imagegen/test.png \
  --dry-run
```

補足：
- 単発のドライランでは、API に送るペイロードと算出された出力先パスが表示されます。
- リポジトリ内の最終成果物は `output/imagegen/` に置いてください。

生成（`OPENAI_API_KEY` とネットワークが必要）：

```bash
python "$IMAGE_GEN" generate \
  --prompt "A cozy alpine cabin at dawn" \
  --size 1024x1024 \
  --out output/imagegen/alpine-cabin.png
```

編集：

```bash
python "$IMAGE_GEN" edit \
  --image input.png \
  --prompt "Replace only the background with a warm sunset" \
  --out output/imagegen/sunset-edit.png
```

## 注意事項
- 正しい環境を有効にしてから、同梱の CLI を直接使用してください（`python "$IMAGE_GEN" ...`）。
- ユーザーがカスタムラッパーを明示的に求めない限り、単発の実行用スクリプト（例：`gen_images.py`）を作成しないでください。
- `scripts/image_gen.py` は**決して変更しないでください**。不足している機能がある場合は、ほかの作業をする前にユーザーに確認してください。

## 既定値
- モデル：`gpt-image-1.5`
- この CLI がサポートするモデルファミリー：GPT Image モデル（`gpt-image-*`）
- サイズ：`1024x1024`
- 品質：`auto`
- 出力形式：`png`
- 単発実行時の既定の出力先：`output/imagegen/output.png`
- 背景：`--background` を設定しない限り指定なし

## 品質、入力画像の忠実度、マスク（CLI フォールバックのみ）
これらは CLI で明示的に指定する設定です。組み込みの `image_gen` ツールの引数ではありません。

- `--quality` は `generate`、`edit`、`generate-batch` で使用できます：`low|medium|high|auto`
- `--input-fidelity` は**編集専用**で、指定できる値は `low|high` です
- `--mask` は**編集専用**です

例：

```bash
python "$IMAGE_GEN" edit \
  --image input.png \
  --prompt "Change only the background" \
  --quality high \
  --input-fidelity high \
  --out output/imagegen/background-edit.png
```

マスクに関する補足：
- 複数画像を編集する場合は、`--image` を繰り返し指定してください。指定順には意味があるため、プロンプトでは各画像を番号と役割で説明してください。
- CLI で指定できる `--mask` は 1 つだけです。
- 可能な場合は PNG マスクを使用してください。スクリプトのマスク処理はベストエフォートであり、ファイルの確認と警告を超える完全な事前検証は行いません。
- 意図しない変化を減らすため、編集用プロンプトでも変更してはいけない条件（`change only the background; keep the subject unchanged`）を繰り返し指定してください。

## 出力の扱い
- 一時的な JSONL 入力や作業用ファイルには `tmp/imagegen/` を使用してください。
- 最終的な出力には `output/imagegen/` を使用してください。
- 出力先ファイルがすでに存在する場合、`--force` を指定しない限り再実行は失敗します。
- `--out-dir` を指定すると、単発実行時のファイル名は `image_1.<ext>`、`image_2.<ext>` などになります。
- 縮小版のコピーには、変更しない限り既定の接尾辞 `-web` が付きます。

## よく使う例

補助フィールドを指定して生成する：

```bash
python "$IMAGE_GEN" generate \
  --prompt "A minimal hero image of a ceramic coffee mug" \
  --use-case "product-mockup" \
  --style "clean product photography" \
  --composition "wide product shot with usable negative space for page copy" \
  --constraints "no logos, no text" \
  --out output/imagegen/mug-hero.png
```

生成すると同時に、Web で素早く読み込める縮小版のコピーも保存する：

```bash
python "$IMAGE_GEN" generate \
  --prompt "A cozy alpine cabin at dawn" \
  --size 1024x1024 \
  --downscale-max-dim 1024 \
  --out output/imagegen/alpine-cabin.png
```

複数のプロンプトを並行して生成する（非同期バッチ）：

```bash
mkdir -p tmp/imagegen output/imagegen/batch
cat > tmp/imagegen/prompts.jsonl << 'EOF'
{"prompt":"Cavernous hangar interior with a compact shuttle parked near the center","use_case":"stylized-concept","composition":"wide-angle, low-angle","lighting":"volumetric light rays through drifting fog","constraints":"no logos or trademarks; no watermark","size":"1536x1024"}
{"prompt":"Gray wolf in profile in a snowy forest","use_case":"photorealistic-natural","composition":"eye-level","constraints":"no logos or trademarks; no watermark","size":"1024x1024"}
EOF

python "$IMAGE_GEN" generate-batch \
  --input tmp/imagegen/prompts.jsonl \
  --out-dir output/imagegen/batch \
  --concurrency 5

rm -f tmp/imagegen/prompts.jsonl
```

補足：
- `generate-batch` には `--out-dir` が必要です。
- generate-batch には --out-dir が必要です。
- 並列実行数は `--concurrency` で制御します（既定値は `5`）。
- JSONL ではジョブごとの設定変更が可能です（例：`size`、`quality`、`background`、`output_format`、`output_compression`、`moderation`、`n`、`model`、`out`、プロンプトの補助フィールド）。
- `--n` は単一のプロンプトから複数のバリエーションを生成します。`generate-batch` は異なるプロンプトを多数処理するためのものです。
- バッチモードでは、ジョブごとの `out` は `--out-dir` の下に置くファイル名として扱われます。

## CLI に関する補足
- 対応サイズ：`1024x1024`、`1536x1024`、`1024x1536`、`auto`。
- 背景を透明にするには、`output_format` を `png` または `webp` にする必要があります。
- `--prompt-file`、`--output-compression`、`--moderation`、`--max-attempts`、`--fail-fast`、`--force`、`--no-augment` に対応しています。
- この CLI は GPT Image モデル向けです。以前の GPT Image 以外の画像モデルの動作がここにも当てはまると考えないでください。

## 関連項目
- フォールバックの CLI モード向け API パラメーター早見表：`references/image-api.md`
- 両方の最上位モードで共通のプロンプト例：`references/sample-prompts.md`
- フォールバックの CLI モード向けネットワーク／サンドボックスに関する補足：`references/codex-network.md`
