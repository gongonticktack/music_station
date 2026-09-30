# Playwright CLI の操作手順

ラッパースクリプトを使い、こまめにスナップショットを取る。
`PWCLI` が設定済みで、`pwcli` が `"$PWCLI"` のエイリアスであると仮定する。
このリポジトリでは、成果物をまとめるため `output/playwright/<label>/` からコマンドを実行する。

## 標準的な操作サイクル

```bash
pwcli open https://example.com
pwcli snapshot
pwcli click e3
pwcli snapshot
```

## フォームの送信

```bash
pwcli open https://example.com/form --headed
pwcli snapshot
pwcli fill e1 "user@example.com"
pwcli fill e2 "password123"
pwcli click e3
pwcli snapshot
pwcli screenshot
```

## データの抽出

```bash
pwcli open https://example.com
pwcli snapshot
pwcli eval "document.title"
pwcli eval "el => el.textContent" e12
```

## デバッグと確認

問題を再現してから、コンソールメッセージとネットワーク通信を取得する。

```bash
pwcli console warning
pwcli network
```

疑わしい操作の前後をトレースに記録する。

```bash
pwcli tracing-start
# 問題を再現
pwcli tracing-stop
pwcli screenshot
```

## セッション

プロジェクトごとの作業を分離するため、セッションを使う。

```bash
pwcli --session marketing open https://example.com
pwcli --session marketing snapshot
pwcli --session checkout open https://example.com/checkout
```

または、セッションを一度設定する。

```bash
export PLAYWRIGHT_CLI_SESSION=checkout
pwcli open https://example.com/checkout
```

## 設定ファイル

CLI は既定で、現在のディレクトリにある `playwright-cli.json` を読む。別のファイルを指定するには `--config` を使う。

最小構成の例:

```json
{
  "browser": {
    "launchOptions": {
      "headless": false
    },
    "contextOptions": {
      "viewport": { "width": 1280, "height": 720 }
    }
  }
}
```

## トラブルシューティング

- 要素参照で失敗したら、`pwcli snapshot` を再実行してから試す。
- ページの表示がおかしい場合は、`--headed` で開き直し、ウィンドウの大きさを調整する。
- 操作が以前の状態に依存する場合は、名前付きの `--session` を使う。
