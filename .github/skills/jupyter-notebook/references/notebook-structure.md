# ノートブックの構造

Jupyter ノートブックは、概ね次の構造を持つ JSON 文書。

- `nbformat` and `nbformat_minor`
- `metadata`
- `cells`（Markdown セルとコードセルの一覧）

プログラムから `.ipynb` ファイルを編集する場合:

- テンプレートの `nbformat` と `nbformat_minor` を保つ。
- `cells` の順序を保ち、意図がない限り並べ替えない。
- コードセルの実行回数が不明なら `execution_count` を `null` にする。
- ひな形作成時にはコードセルの `outputs` を空のリストにする。
- Markdown セルでは `cell_type="markdown"` と `metadata={}` を保つ。

ノートブックの JSON を手書きするより、同梱テンプレートや `new_notebook.py`（例: `$CODEX_HOME/skills/jupyter-notebook/scripts/new_notebook.py`）からひな形を作る。
