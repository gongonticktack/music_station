---
name: "jupyter-notebook"
description: "実験、探索、チュートリアル用の Jupyter ノートブック（`.ipynb`）の作成、ひな形の生成、編集を求められたときに使う。同梱のテンプレートを優先し、補助スクリプト `new_notebook.py` で整った開始用ノートブックを生成する。"
---


# Jupyter Notebook スキル

主に次の2種類の、整理され再現可能な Jupyter ノートブックを作る。

- 実験と探索的分析
- チュートリアルと教育向けの手順解説

構成を揃えて JSON の誤りを減らすため、同梱テンプレートと補助スクリプトを優先する。

## 使用する場面
- 新しい `.ipynb` ノートブックを一から作る。
- 未整理のメモやスクリプトを構造化されたノートブックに変える。
- 既存のノートブックを、再現しやすく読み流しやすい構成に改善する。
- 他の人が読んだり再実行したりする実験やチュートリアルを作る。

## 選択基準
- 探索、分析、仮説検証が目的なら `experiment` を選ぶ。
- 指導、段階的な説明、特定の読者向けなら `tutorial` を選ぶ。
- 既存のノートブックを編集する場合は、意図を保ちつつ構成を改善するリファクタリングとして扱う。

## スキルのパス（最初に1回設定）

```bash
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export JUPYTER_NOTEBOOK_CLI="$CODEX_HOME/skills/jupyter-notebook/scripts/new_notebook.py"
```

ユーザー範囲のスキルは `$CODEX_HOME/skills` にインストールされる（既定: `~/.codex/skills`）。

## 作業手順
1. 目的を確定する。
ノートブックの種類を `experiment` または `tutorial` として特定する。
目標、読者、完了条件を把握する。

2. テンプレートからひな形を作る。
ノートブックの JSON を手書きせず、補助スクリプトを使う。

```bash
uv run --python 3.12 python "$JUPYTER_NOTEBOOK_CLI" \
  --kind experiment \
  --title "Compare prompt variants" \
  --out output/jupyter-notebook/compare-prompt-variants.ipynb
```

```bash
uv run --python 3.12 python "$JUPYTER_NOTEBOOK_CLI" \
  --kind tutorial \
  --title "Intro to embeddings" \
  --out output/jupyter-notebook/intro-to-embeddings.ipynb
```

3. 実行可能な小さな段階でノートブックを埋める。
各コードセルは1つの作業に集中させる。
目的と予想される結果を説明する短い Markdown セルを加える。
短い要約で足りる場合は、大量で読みにくい出力を避ける。

4. 適切なパターンを適用する。
実験では `references/experiment-patterns.md` に従う。
チュートリアルでは `references/tutorial-patterns.md` に従う。

5. 既存のノートブックは安全に編集する。
構造を保ち、上から下への説明の流れが改善する場合を除き、セルの順序を変えない。
全面的な書き換えより、対象を絞った編集を優先する。
生の JSON を編集する必要がある場合は、先に `references/notebook-structure.md` を読む。

6. 結果を検証する。
環境が許すならノートブックを上から下まで実行する。
実行できない場合は明示し、ローカルでの検証方法を示す。
`references/quality-checklist.md` の最終チェックリストを使う。

## テンプレートと補助スクリプト
- テンプレートは `assets/experiment-template.ipynb` と `assets/tutorial-template.ipynb` にある。
- 補助スクリプトはテンプレートを読み、タイトルセルを更新してノートブックを書き出す。

スクリプトのパス:
- `$JUPYTER_NOTEBOOK_CLI`（インストール時の既定値: `$CODEX_HOME/skills/jupyter-notebook/scripts/new_notebook.py`）

## 一時ファイルと出力の規則
- 中間ファイルは `tmp/jupyter-notebook/` に置き、完了後に削除する。
- このリポジトリでは最終成果物を `output/jupyter-notebook/` に書く。
- 安定した分かりやすいファイル名を使う（例: `ablation-temperature.ipynb`）。

## 依存関係（必要な場合にのみインストール）
依存関係の管理には `uv` を優先する。

ローカルでノートブックを実行する場合に使える任意の Python パッケージ:

```bash
uv pip install jupyterlab ipykernel
```

同梱のひな形作成スクリプトは Python 標準ライブラリのみを使い、追加の依存関係は不要。

## 環境
必須の環境変数はない。

## 参考資料
- `references/experiment-patterns.md`: 実験の構成と目安。
- `references/tutorial-patterns.md`: チュートリアルの構成と教える順序。
- `references/notebook-structure.md`: ノートブックの JSON 構造と安全な編集の規則。
- `references/quality-checklist.md`: 最終検証のチェックリスト。
