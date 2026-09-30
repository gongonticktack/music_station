---
name: "playwright"
description: "`playwright-cli` または同梱のラッパースクリプトを使い、ターミナルから実際のブラウザーを自動操作する必要がある場合に使用する（移動、フォーム入力、スナップショット、スクリーンショット、データ抽出、UI 操作のデバッグ）。"
---


# Playwright CLI スキル

`playwright-cli` を使い、ターミナルから実際のブラウザーを操作する。CLI がグローバルにインストールされていなくても使えるよう、同梱のラッパースクリプトを優先する。
このスキルは CLI を使った自動操作を基本とする。ユーザーがテストファイルを明示的に求めた場合を除き、`@playwright/test` に切り替えない。

## 前提条件の確認（必須）

コマンドを提案する前に、ラッパーが依存する `npx` を使えるか確認する。

```bash
command -v npx >/dev/null 2>&1
```

使えない場合は作業を止め、`npx` を提供する Node.js/npm のインストールをユーザーに依頼する。次の手順をそのまま示す。

```bash
# Node/npm のインストールを確認
node --version
npm --version

# 未インストールなら Node.js/npm を導入してから実行:
npm install -g @playwright/cli@latest
playwright-cli --help
```

`npx` が使えるようになったら、ラッパースクリプトで進める。`playwright-cli` のグローバルインストールは任意。

## スキルのパス（一度だけ設定）

```bash
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export PWCLI="$CODEX_HOME/skills/playwright/scripts/playwright_cli.sh"
```

ユーザー単位のスキルは `$CODEX_HOME/skills` にインストールされる（既定値: `~/.codex/skills`）。

## クイックスタート

ラッパースクリプトを使用する。

```bash
"$PWCLI" open https://playwright.dev --headed
"$PWCLI" snapshot
"$PWCLI" click e15
"$PWCLI" type "Playwright"
"$PWCLI" press Enter
"$PWCLI" screenshot
```

ユーザーがグローバルインストールを希望する場合は、次の方法も使える。

```bash
npm install -g @playwright/cli@latest
playwright-cli --help
```

## 基本手順

1. ページを開く。
2. スナップショットを取り、安定した要素参照を得る。
3. 最新のスナップショットにある参照を使って操作する。
4. ページ移動や大きな DOM 変更の後は、スナップショットを取り直す。
5. 有用な場合は、スクリーンショット、PDF、トレースを保存する。

最小限の操作サイクル:

```bash
"$PWCLI" open https://example.com
"$PWCLI" snapshot
"$PWCLI" click e3
"$PWCLI" snapshot
```

## スナップショットを取り直すタイミング

次の操作の後に取り直す。

- ページ移動
- UI を大きく変える要素のクリック
- モーダルやメニューの開閉
- タブの切り替え

要素参照は古くなることがある。参照が見つからずコマンドが失敗した場合は、スナップショットを取り直す。

## 推奨する操作例

### フォームの入力と送信

```bash
"$PWCLI" open https://example.com/form
"$PWCLI" snapshot
"$PWCLI" fill e1 "user@example.com"
"$PWCLI" fill e2 "password123"
"$PWCLI" click e3
"$PWCLI" snapshot
```

### トレースを使った UI 操作のデバッグ

```bash
"$PWCLI" open https://example.com --headed
"$PWCLI" tracing-start
# ...操作...
"$PWCLI" tracing-stop
```

### 複数タブの操作

```bash
"$PWCLI" tab-new https://example.com
"$PWCLI" tab-list
"$PWCLI" tab-select 0
"$PWCLI" snapshot
```

## ラッパースクリプト

ラッパースクリプトは `npx --package @playwright/cli playwright-cli` を使うため、グローバルインストールなしで CLI を実行できる。

```bash
"$PWCLI" --help
```

リポジトリでグローバルインストールを標準としている場合を除き、ラッパーを優先する。

## 参考資料

必要なものだけを開く。

- CLI コマンド一覧: `references/cli.md`
- 実用的な操作手順とトラブルシューティング: `references/workflows.md`

## 注意事項

- `e12` のような要素 ID を参照する前に、必ずスナップショットを取る。
- 参照が古くなったようなら取り直す。
- 必要な場合を除き、`eval` や `run-code` より明示的なコマンドを優先する。
- 新しいスナップショットがない場合は、`eX` のような仮の参照を使って理由を述べる。`run-code` で参照を回避しない。
- 画面での確認が役立つ場合は `--headed` を使う。
- このリポジトリで成果物を保存する場合は `output/playwright/` を使い、ルート直下に新たな成果物フォルダを作らない。
- Playwright のテスト仕様より、CLI コマンドと操作手順を基本とする。
