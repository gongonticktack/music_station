# Playwright CLI コマンド一覧

CLI がグローバルにインストールされていない場合は、ラッパースクリプトを使う。

```bash
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export PWCLI="$CODEX_HOME/skills/playwright/scripts/playwright_cli.sh"
"$PWCLI" --help
```

ユーザー単位のスキルは `$CODEX_HOME/skills` にインストールされる（既定値: `~/.codex/skills`）。

必要に応じて、使いやすいエイリアスを設定する。

```bash
alias pwcli="$PWCLI"
```

## 基本操作

```bash
pwcli open https://example.com
pwcli close
pwcli snapshot
pwcli click e3
pwcli dblclick e7
pwcli type "search terms"
pwcli press Enter
pwcli fill e5 "user@example.com"
pwcli drag e2 e8
pwcli hover e4
pwcli select e9 "option-value"
pwcli upload ./document.pdf
pwcli check e12
pwcli uncheck e12
pwcli eval "document.title"
pwcli eval "el => el.textContent" e5
pwcli dialog-accept
pwcli dialog-accept "confirmation text"
pwcli dialog-dismiss
pwcli resize 1920 1080
```

## ページ移動

```bash
pwcli go-back
pwcli go-forward
pwcli reload
```

## キーボード

```bash
pwcli press Enter
pwcli press ArrowDown
pwcli keydown Shift
pwcli keyup Shift
```

## マウス

```bash
pwcli mousemove 150 300
pwcli mousedown
pwcli mousedown right
pwcli mouseup
pwcli mouseup right
pwcli mousewheel 0 100
```

## ファイルへの保存

```bash
pwcli screenshot
pwcli screenshot e5
pwcli pdf
```

## タブ

```bash
pwcli tab-list
pwcli tab-new
pwcli tab-new https://example.com/page
pwcli tab-close
pwcli tab-close 2
pwcli tab-select 0
```

## 開発者ツール

```bash
pwcli console
pwcli console warning
pwcli network
pwcli run-code "await page.waitForTimeout(1000)"
pwcli tracing-start
pwcli tracing-stop
```

## セッション

作業を分離するには、名前付きセッションを使う。

```bash
pwcli --session todo open https://demo.playwright.dev/todomvc
pwcli --session todo snapshot
```

または、環境変数を一度設定する。

```bash
export PLAYWRIGHT_CLI_SESSION=todo
pwcli open https://demo.playwright.dev/todomvc
```
