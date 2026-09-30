---
name: "screenshot"
description: "ユーザーがデスクトップやシステムのスクリーンショット（画面全体、特定のアプリやウィンドウ、指定した画素領域）を明示的に求めた場合、またはツール固有の撮影機能が使えず OS レベルの撮影が必要な場合に使用する。"
---


# スクリーンショットの撮影

保存先は毎回、次のルールに従う。

1) ユーザーがパスを指定した場合は、そこに保存する。
2) パスを指定せずにスクリーンショットを依頼された場合は、OS の既定の保存先に保存する。
3) Codex 自身の確認用に撮影する場合は、一時ディレクトリに保存する。

## ツールの優先順位

- ツール固有の撮影機能が使える場合は、それを優先する（例: Figma ファイルなら Figma の MCP/スキル、ブラウザーや Electron アプリなら Playwright/agent-browser ツール）。
- 明示的に求められた場合、デスクトップ全体を撮影する場合、またはツール固有の撮影では必要な画像を得られない場合に、このスキルを使う。
- それ以外では、より適切な統合撮影ツールがないデスクトップアプリ用の既定のスキルとして扱う。

## macOS の権限事前確認（繰り返しの確認を減らす）

macOS では、ウィンドウやアプリを撮影する前に事前確認用の補助スクリプトを一度実行する。画面収録の権限を確認し、必要な理由を説明して、まとめて権限を要求する。

補助スクリプトは、サンドボックスでモジュールキャッシュの許可を追加で求められないよう、Swift のモジュールキャッシュを `$TMPDIR/codex-swift-module-cache` に配置する。

```bash
bash <path-to-skill>/scripts/ensure_macos_permissions.sh
```

サンドボックスの承認が何度も求められないよう、可能なら事前確認と撮影を1つのコマンドにまとめる。

```bash
bash <path-to-skill>/scripts/ensure_macos_permissions.sh && \
python3 <path-to-skill>/scripts/take_screenshot.py --app "Codex"
```

Codex の確認用なら、出力を一時ディレクトリに保存する。

```bash
bash <path-to-skill>/scripts/ensure_macos_permissions.sh && \
python3 <path-to-skill>/scripts/take_screenshot.py --app "<App>" --mode temp
```

OS ごとのコマンドを調べ直さず、同梱のスクリプトを使う。

## macOS と Linux（Python の補助スクリプト）

リポジトリのルートから補助スクリプトを実行する。

```bash
python3 <path-to-skill>/scripts/take_screenshot.py
```

よく使う方法:

- 既定の保存先（ユーザーが「スクリーンショットを撮って」と依頼した場合）:

```bash
python3 <path-to-skill>/scripts/take_screenshot.py
```

- 一時ディレクトリ（Codex の画面確認）:

```bash
python3 <path-to-skill>/scripts/take_screenshot.py --mode temp
```

- 指定した保存先（ユーザーがパスやファイル名を指定した場合）:

```bash
python3 <path-to-skill>/scripts/take_screenshot.py --path output/screen.png
```

- アプリ名によるアプリ・ウィンドウの撮影（macOS のみ。部分一致でよく、一致するすべてのウィンドウを撮影）:

```bash
python3 <path-to-skill>/scripts/take_screenshot.py --app "Codex"
```

- アプリ内でタイトルを指定したウィンドウの撮影（macOS のみ）:

```bash
python3 <path-to-skill>/scripts/take_screenshot.py --app "Codex" --window-name "Settings"
```

- 撮影前に一致するウィンドウ ID を列挙する（macOS のみ）:

```bash
python3 <path-to-skill>/scripts/take_screenshot.py --list-windows --app "Codex"
```

- 画素領域（x,y,w,h）:

```bash
python3 <path-to-skill>/scripts/take_screenshot.py --mode temp --region 100,200,800,600
```

- フォーカス中のウィンドウ（最前面のみ撮影。すべてのウィンドウには `--app` を使う）:

```bash
python3 <path-to-skill>/scripts/take_screenshot.py --mode temp --active-window
```

- 指定したウィンドウ ID（macOS では `--list-windows` で ID を調べる）:

```bash
python3 <path-to-skill>/scripts/take_screenshot.py --window-id 12345
```

スクリプトは撮影ごとに1つのパスを表示する。複数のウィンドウやディスプレイが一致した場合は、1行に1つずつ複数のパスを表示し、`-w<windowId>` や `-d<display>` などの接尾辞を付ける。画像表示ツールで各パスを順に確認し、画像の加工は必要な場合または依頼された場合だけ行う。

### 作業例

- 「<App> を見て、何が表示されているか教えて」: 一時ディレクトリに撮影し、表示された各パスを順に確認する。

```bash
bash <path-to-skill>/scripts/ensure_macos_permissions.sh && \
python3 <path-to-skill>/scripts/take_screenshot.py --app "<App>" --mode temp
```

- 「Figma のデザインと実装が一致しない」: 最初に Figma の MCP/スキルでデザインを撮影し、次にこのスキルで実行中のアプリを撮影して（通常は一時ディレクトリへ保存）、加工前の画像を比較する。

### 複数ディスプレイでの動作

- macOS では複数のモニターが接続されていると、画面全体の撮影時にディスプレイごとに1ファイルを保存する。
- Linux と Windows では、画面全体の撮影に仮想デスクトップを使う（全モニターを1枚に収める）。必要に応じて `--region` で1つのディスプレイだけを切り出す。

### Linux の前提条件とツール選択

補助スクリプトは、次のうち最初に利用可能なツールを自動的に選ぶ。

1) `scrot`
2) `gnome-screenshot`
3) ImageMagick `import`

どれも使えない場合は、いずれかのインストールをユーザーに依頼してから再試行する。

座標で領域を指定するには `scrot` または ImageMagick の `import` が必要。

`--app`、`--window-name`、`--list-windows` は macOS 専用。Linux では `--active-window` を使うか、分かっていれば `--window-id` を指定する。

## Windows（PowerShell の補助スクリプト）

PowerShell の補助スクリプトを実行する。

```powershell
powershell -ExecutionPolicy Bypass -File <path-to-skill>/scripts/take_screenshot.ps1
```

よく使う方法:

- 既定の保存先:

```powershell
powershell -ExecutionPolicy Bypass -File <path-to-skill>/scripts/take_screenshot.ps1
```

- 一時ディレクトリ（Codex の画面確認）:

```powershell
powershell -ExecutionPolicy Bypass -File <path-to-skill>/scripts/take_screenshot.ps1 -Mode temp
```

- 指定したパス:

```powershell
powershell -ExecutionPolicy Bypass -File <path-to-skill>/scripts/take_screenshot.ps1 -Path "C:\Temp\screen.png"
```

- 画素領域（x,y,w,h）:

```powershell
powershell -ExecutionPolicy Bypass -File <path-to-skill>/scripts/take_screenshot.ps1 -Mode temp -Region 100,200,800,600
```

- アクティブなウィンドウ（事前にユーザーにフォーカスを合わせてもらう）:

```powershell
powershell -ExecutionPolicy Bypass -File <path-to-skill>/scripts/take_screenshot.ps1 -Mode temp -ActiveWindow
```

- 指定したウィンドウハンドル（提供された場合のみ）:

```powershell
powershell -ExecutionPolicy Bypass -File <path-to-skill>/scripts/take_screenshot.ps1 -WindowHandle 123456
```

## OS コマンドを直接使う方法（代替手段）

補助スクリプトを実行できない場合に使う。

### macOS

- 画面全体を指定したパスに保存:

```bash
screencapture -x output/screen.png
```

- 画素領域:

```bash
screencapture -x -R100,200,800,600 output/region.png
```

- 指定したウィンドウ ID:

```bash
screencapture -x -l12345 output/window.png
```

- 対話形式での領域選択またはウィンドウ選択:

```bash
screencapture -x -i output/interactive.png
```

### Linux

- 画面全体:

```bash
scrot output/screen.png
```

```bash
gnome-screenshot -f output/screen.png
```

```bash
import -window root output/screen.png
```

- 画素領域:

```bash
scrot -a 100,200,800,600 output/region.png
```

```bash
import -window root -crop 800x600+100+200 output/region.png
```

- アクティブなウィンドウ:

```bash
scrot -u output/window.png
```

```bash
gnome-screenshot -w -f output/window.png
```

## エラーへの対応

- macOS では先に `bash <path-to-skill>/scripts/ensure_macos_permissions.sh` を実行し、画面収録の権限をまとめて要求する。
- サンドボックス内で `screen capture checks are blocked in the sandbox`、`could not create image from display`、または Swift の `ModuleCache` の権限エラーが出た場合は、昇格した権限でコマンドを再実行する。
- macOS でアプリやウィンドウの撮影対象が見つからない場合は、`--list-windows --app "AppName"` を実行して `--window-id` で再試行し、アプリが画面に表示されていることも確認する。
- Linux で領域やウィンドウの撮影に失敗した場合は、`command -v scrot`、`command -v gnome-screenshot`、`command -v import` でツールの有無を確認する。
- サンドボックスで権限エラーが出て OS の既定の場所に保存できない場合は、昇格した権限でコマンドを再実行する。
- 回答には、保存したファイルのパスを必ず記す。
