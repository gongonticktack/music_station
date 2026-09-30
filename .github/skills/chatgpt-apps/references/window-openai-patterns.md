# Window.openai のパターン

ChatGPT 専用のウィジェット機能が必要なタスク、`app` ラッパーを使う古いサンプルを移行するタスク、または React ウィジェットでホストのグローバル変数を安全に読み取る必要がある場合に、このリファレンスを読み込んでください。

## 基本ルール

- ウィジェットの基本動作は MCP Apps ブリッジ上に構築してください: `ui/*` 通知、`tools/call`、`ui/message`、`ui/update-model-context`。
- `window.openai` は、タスクで ChatGPT 専用のランタイム機能が特に役立つ場合に限って使用してください。
- `window.openai` は追加機能として扱ってください。可能な場合、アプリには MCP Apps 標準に基づく一貫した基本経路も用意してください。

## `window.openai` の標準 API

### 状態とデータ

- `window.openai.toolInput`: ホストから渡されたツール引数
- `window.openai.toolOutput`: 現在の `structuredContent`
- `window.openai.toolResponseMetadata`: 現在の `_meta` ペイロード（ウィジェット専用）
- `window.openai.widgetState`: 永続化されたウィジェットローカルのスナップショット
- `window.openai.setWidgetState(state)`: 意味のある UI 変更の後に、ウィジェットローカルのスナップショットを永続化する

### ランタイム API

- `window.openai.callTool(name, args)`: ウィジェットから別の MCP ツールを呼び出す
- `window.openai.sendFollowUpMessage({ prompt, scrollToBottom? })`: ウィジェットが作成したフォローアップメッセージを ChatGPT に投稿するよう依頼する
- `window.openai.openExternal({ href, redirectUrl? })`: ChatGPT の検証済みフローを通じて外部 URL を開く
- `window.openai.requestDisplayMode({ mode })`: `inline`、`pip`、`fullscreen` をリクエストする
- `window.openai.requestModal({ params, template? })`: ホスト管理のモーダルを開く
- `window.openai.requestClose()`: ウィジェットを閉じるよう ChatGPT に依頼する
- `window.openai.uploadFile(file, options?)`: ウィジェットからファイルをアップロードする
- `window.openai.selectFiles()`: ChatGPT のファイルライブラリ選択画面を開き、アプリで使用を許可されたファイルを返す
- `window.openai.getFileDownloadUrl({ fileId })`: 一時的なダウンロード URL を解決する
- `window.openai.notifyIntrinsicHeight(...)`: 動的な高さの変化を通知する
- `window.openai.setOpenInAppUrl({ href })`: 全画面表示からアプリへ移動するときの遷移先を上書きする

### コンテキスト情報

- `window.openai.theme`
- `window.openai.displayMode`
- `window.openai.maxHeight`
- `window.openai.safeArea`
- `window.openai.view`
- `window.openai.userAgent`
- `window.openai.locale`

## リポジトリのラッパーサンプルからの対応付け

- `app.callServerTool({ name, arguments })`:
  ChatGPT の互換レイヤーを意図的に使う場合は、`window.openai.callTool(name, args)` を使用してください。
  移植可能な MCP Apps 経路を使う場合は、ブリッジ経由で `tools/call` を使用してください。
- `app.sendMessage(...)`:
  移植可能なブリッジメッセージングには `ui/message` を使用してください。
  タスクが ChatGPT 専用である場合は、`window.openai.sendFollowUpMessage({ prompt })` が最も近いサポート対象の方法です。
- `app.updateModelContext(...)`:
  ブリッジ経由で `ui/update-model-context` を使用してください。
  これは標準ブリッジの一部であり、`window.openai` の機能ではありません。
- `app.openLink({ url })`:
  ChatGPT の外部ナビゲーションフローを意図的に使う場合は、`window.openai.openExternal({ href: url })` を使用してください。
- `app.requestDisplayMode({ mode })`:
  `window.openai.requestDisplayMode({ mode })` を使用してください。
- `app.getHostContext()`:
  ドキュメントに記載されたグローバル変数（`theme`、`displayMode`、`locale`、`maxHeight`、`safeArea`、`userAgent`）を直接読み取ってください。
- `app.getHostCapabilities()` / `app.getHostVersion()`:
  これらはラッパーレベルの便利な API です。
  これらを主要な公開 API として紹介するのではなく、機能検出（`if (window.openai?.requestModal)`）とドキュメントに記載されたグローバル変数を優先してください。

## ファイルのパターン

- ユーザーがウィジェット内で新しいローカルファイルを追加する場合は、`window.openai.uploadFile(file)` を使用してください。
- アップロードしたファイルをユーザーの ChatGPT ファイルライブラリにも保存する場合は、`window.openai.uploadFile(file, { library: true })` を使用してください。
- 再アップロードではなく、ChatGPT ファイルライブラリにすでにあるファイルをユーザーが再利用できるようにする場合は、`window.openai.selectFiles()` を使用してください。
- ファイルのプレビューまたはファイルパラメーターのペイロードでの転送に一時 URL が必要な場合は、`window.openai.getFileDownloadUrl({ fileId })` を使用してください。
- ウィジェット内でこれらのヘルパーを機能検出し（`if (window.openai?.selectFiles)`）、ChatGPT 専用のヘルパーを利用できない場合に備えて、代替のアップロードフローを用意してください。

## React ヘルパーの抽出

- リポジトリの `src/use-openai-global.ts` は、コンポーネント内に `window.openai` の直接参照を散在させず、ホストのグローバル変数の変更を購読するための良いベースラインです。
- リポジトリの `src/use-widget-state.ts` は、React の状態を `window.openai.setWidgetState(...)` に反映するための良いベースラインです。
- リポジトリの `src/use-widget-props.ts` は、型付きの `toolOutput` をローカルのフォールバック付きで読み取るための良いベースラインです。
- これらのヘルパーは任意です。シンプルな vanilla ウィジェットで十分な場合に、React の抽象化を無理に導入しないでください。
