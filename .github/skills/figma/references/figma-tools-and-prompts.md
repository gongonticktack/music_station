# Figma MCP ツールと依頼文の例

Figma MCP の各ツールの用途と、出力を使用中の技術構成に合わせるための依頼文を簡潔にまとめる。

## 主なツール
- `get_design_context`（Figma Design、Figma Make）: 中心となるツール。構造化されたデザイン情報と、既定では React + Tailwind のコードを返す。選択範囲に基づく依頼はデスクトップで機能する。リモートサーバーはフレームやレイヤーのリンクからノード ID を抽出する。
- `get_variable_defs`（Figma Design）: 選択範囲で使われる変数やスタイル（色、余白、書体）を列挙する。トークンとの整合に役立つ。
- `get_metadata`（Figma Design）: レイヤーの ID、名前、種類、位置、サイズの概要を簡潔な XML で返す。大きなノードで `get_design_context` を再実行する前に使い、応答の切り詰めを避ける。
- `get_screenshot`（Figma Design、FigJam）: 視覚的な再現性を確認するため、選択範囲のスクリーンショットを返す。
- `get_figjam`（FigJam）: アーキテクチャや作業フローなどの FigJam 図について、XML とスクリーンショットを返す。
- `create_design_system_rules`（ファイルの文脈なし）: 使用中の技術構成に合わせ、デザインからコードへの変換の規則ファイルを生成する。エージェントが読める場所に保存する。
- `get_code_connect_map`（Figma Design）: Figma ノード ID とコードのコンポーネントの対応（`codeConnectSrc`、`codeConnectName`）を返す。既存コンポーネントの再利用に使う。
- `add_code_connect_map`（Figma Design）: Figma ノードとコードのコンポーネントの対応を追加・更新し、再利用を促す。
- `get_strategy_for_mapping`（アルファ版、ローカルのみ）: Figma の問いに答えながら、ノードをコードのコンポーネントに結び付ける方法を決めるツール。
- `send_get_strategy_response`（アルファ版、ローカルのみ）: `get_strategy_for_mapping` の後に回答を送る。
- `whoami`（リモートのみ）: 認証された Figma ユーザーの情報（メール、プラン、シート種別）を返す。

## 依頼文の例（デザイン情報）
- フレームワークを変える: 「Figma の選択範囲を Vue で生成して」「通常の HTML + CSS で」「iOS 向けに」。
- 自分のコンポーネントを使う: 「`src/components/ui` のコンポーネントを使って Figma の選択範囲を生成して」。
- 組み合わせる: 「`src/ui` のコンポーネントを使い、Tailwind でスタイルを付けて Figma の選択範囲を生成して」。
- 注意: リモートサーバーで選択範囲に基づいて依頼するにはフレームやレイヤーのリンクが必要。サーバーは URL からノード ID を抽出する。

## 依頼文の例（変数とスタイル）
- 「Figma の選択範囲で使われる変数を取得して」
- 「Figma の選択範囲では、どの色と余白の変数が使われている？」
- 「Figma の選択範囲で使われる変数名と値を列挙して」

## 依頼文の例（Code Connect）
- 「この選択範囲の Code Connect の対応を見せて」
- 「このノードを `src/components/ui/Button.tsx` の `Button` に対応付けて」

## 推奨手順の確認
`get_design_context` →（大きなノードでは必要に応じて `get_metadata`）→ `get_screenshot` の順に進め、生成された出力を適用するときは `SKILL.md` のプロジェクトの規則に従う。
