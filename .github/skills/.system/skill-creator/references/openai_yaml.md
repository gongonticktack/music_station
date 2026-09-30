# openai.yaml のフィールド（完全な例と説明）

`agents/openai.yaml` は、エージェントではなく実行環境が読み取る、製品固有の拡張設定である。ほかの製品固有設定も `agents/` フォルダに配置できる。

## 完全な例

```yaml
interface:
  display_name: "Optional user-facing name"
  short_description: "Optional user-facing description"
  icon_small: "./assets/small-400px.png"
  icon_large: "./assets/large-logo.svg"
  brand_color: "#3B82F6"
  default_prompt: "Optional surrounding prompt to use the skill with"

dependencies:
  tools:
    - type: "mcp"
      value: "github"
      description: "GitHub MCP server"
      transport: "streamable_http"
      url: "https://api.githubcopilot.com/mcp/"
```

## フィールドの説明と制約

最上位の制約:

- 文字列の値はすべて引用符で囲む。
- キーには引用符を付けない。
- `interface.default_prompt`: スキルに応じた、役立つ短い（通常は1文の）開始プロンプトを作る。スキル名を `$skill-name` の形式で明示する必要がある（例: "Use $skill-name-here to draft a concise weekly status update."）。

- `interface.display_name`: UI のスキル一覧やチップに表示する、人向けの名称。
- `interface.short_description`: 一覧で素早く把握できる、人向けの短い UI 説明（25～64文字）。
- `interface.icon_small`: 小さいアイコン素材へのパス（スキルディレクトリからの相対パス）。既定では `./assets/` を使い、スキルの `assets/` フォルダにアイコンを置く。
- `interface.icon_large`: 大きいロゴ素材へのパス（スキルディレクトリからの相対パス）。既定では `./assets/` を使い、スキルの `assets/` フォルダにアイコンを置く。
- `interface.brand_color`: UI のアクセント（バッジなど）に使う16進数の色。
- `interface.default_prompt`: スキルを呼び出すときに挿入する既定のプロンプト文。
- `dependencies.tools[].type`: 依存ツールの分類。現在サポートされるのは `mcp` のみ。
- `dependencies.tools[].value`: ツールまたは依存先の識別子。
- `dependencies.tools[].description`: 依存先についての、人が読める説明。
- `dependencies.tools[].transport`: `type` が `mcp` の場合の接続方式。
- `dependencies.tools[].url`: `type` が `mcp` の場合の MCP サーバー URL。
