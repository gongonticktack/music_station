# Codex CLI のパターン

Codex が実行する新しい CLI のコマンド体系を設計するときは、このリファレンスを使ってください。

## 基本的な考え方

CLI は Codex のコマンド層です。サービス、アプリ、API、ログソース、データベースを、Codex がどのリポジトリからでも繰り返し実行できるシェルコマンドに変える役割を担います。

Codex にとって使いやすい CLI は、組み合わせて使える基本操作を提供します。発見、読み取り、解決、ダウンロード、調査、下書き作成、アップロードといった小さなコマンドを組み合わせたほうがよい場合は、「調査をすべて行う」単一のコマンドを避けてください。

## ヘルプはインターフェース

バイナリと漠然としたタスクしか手元にない将来の Codex スレッドのために、`--help` を書いてください。各コマンドには短い説明を付け、フラグには製品や API で使われている名前をそのまま使ってください。

優れたトップレベルのヘルプは、次の問いに答えられるはずです。

- どのコンテナーを発見できるか？
- どのオブジェクトを正確に指定して読み取れるか？
- どの安定した ID を解決できるか？
- どのファイルをダウンロードまたはアップロードできるか？
- どの書き込み操作があるか？
- 生のリクエストを実行するための手段は何か？

## 推奨するコマンドの形

製品で使われる名詞を置き、その後に動詞を続けます。

```bash
tool-name --json doctor
tool-name --json accounts list
tool-name --json projects list
tool-name --json channels resolve --name codex
tool-name --json messages search "exact phrase"
tool-name --json messages context <message-id> --before 3 --after 3
tool-name --json logs download <build-url> --failed --out ./logs
tool-name --json media upload --file ./image.png
tool-name --json drafts create --body-file draft.json
```

API 側で使われる名詞がすでに明確なら、動詞を直接続けても構いません。

```bash
tool-name --json social-sets
tool-name --json drafts list --social-set <id>
tool-name --json request get /v2/me
```

大切なのは一貫性です。製品の用語上必要な場合を除き、多くのスタイルを混在させないでください。

## 成熟した CLI に見られる有用な形

エージェント専用の凝った抽象化より、次のパターンを優先してください。

```bash
# Field-selected structured output: make common reads scriptable.
tool-name issues list --json number,title,url,state
tool-name issues list --json number,title --jq '.[] | select(.state == "open")'

# Human text by default, full API object when requested.
tool-name pods get <name>
tool-name pods get <name> -o json

# Product workflow commands, not just REST nouns.
tool-name logs tail
tool-name webhooks listen --forward-to localhost:4242/webhooks
tool-name webhooks trigger checkout.completed
```

フィルタリングやテンプレート機能は、ユーザーが実際に必要とする場合にだけ実装してください。安定した JSON 出力と対象を絞った読み取りコマンドを基本とします。

## 発見、解決、読み取り、前後の情報

最初に用意するコマンドは、次の順序で設計してください。

1. **発見**: ワークスペース、アカウント、ソーシャルセット、リポジトリ、プロジェクト、チャンネル、キューなど、大きな単位のコンテナーを見つける。
2. **解決**: ユーザー名、チャンネル名、パーマリンク、PR の URL、ビルドの URL、顧客のスラッグなど、人が入力した情報を ID に変換する。
3. **読み取り**: issue、イベント、スレッド、下書き、顧客、ジョブ、実行、メディア項目など、正確に指定したオブジェクトを読む。
4. **前後の情報**: 必要に応じて、近くのメッセージ、親スレッド、前後のログ、監査履歴など、基点となる項目の周辺情報を取得する。

安定した ID がすでにあるのに、Codex に何度も検索を強いないでください。

## テキスト、JSON、ファイル、終了コード

役立つ場合は、人が読めるテキストをデフォルトで出力してください。Codex が結果を解析したりパイプで渡したりする箇所では、必ず `--json` をサポートしてください。

`--json` については、次のようにしてください。

- 標準出力には JSON だけを出力する。
- 進捗と診断情報は標準エラー出力に送る。
- 成功時とエラー時の出力形式を文書化する。
- トークン、Cookie、顧客の機密情報、非公開ヘッダー、無関係なペイロードは伏せる。

ダウンロードとエクスポートについては、次のようにしてください。

- 可能な場合は、ユーザーが `--out` で指定したパスの下にファイルを書き込む。
- JSON 出力では、ファイルパス、容易に取得できるならバイト数、元の URL または ID、次に実行するコマンドを返す。

終了コードについては、次のようにしてください。

- 結果が空の場合も含め、コマンドが成功したらゼロで終了する。
- 認証失敗、無効な入力、ネットワーク障害、解析失敗、API エラー、未完了のアップロードやダウンロードでは、ゼロ以外で終了する。
- 認証情報がない場合でも `doctor --json` を使えるようにする。クラッシュせず、認証情報がないことを報告する。

## ページネーションと取得範囲

デフォルトでは取得範囲を狭くしてください。範囲を広げるための明示的なオプションを追加します。

```bash
tool-name --json messages search "topic" --limit 10
tool-name --json messages search "topic" --limit 50 --all-pages --max-pages 3
tool-name --json drafts list --limit 20 --offset 40
```

`next_cursor`、`next_url`、`offset`、`page_count` など、プロバイダーが実際に使う値を返してください。

## 生のリクエストを実行するための手段

生のリクエスト用コマンドは、問題を解決するための補助手段であり、主要なインターフェースではありません。

使いやすい生のリクエスト用コマンドでも、設定済みの認証、ベース URL、JSON の解析、機密情報のマスキング、ステータスとエラーの処理、`--json` を利用します。

読み取りを簡単にしてください。

```bash
tool-name --json request get /v2/me
```

生の書き込みリクエストは、実際の書き込みとして扱ってください。POST/PUT/PATCH/DELETE を「デバッグ」コマンドの裏に隠さないでください。

## 付属スキルのパターン

付属スキルは CLI の README より短くし、ツールの使い方の流れを教えるものにしてください。

```md
Start with:

tool-name --json doctor
tool-name --json accounts list

For [common job]:

tool-name --json ...
tool-name --json ...

Rules:

- Prefer installed `tool-name` on PATH.
- Use --json when analyzing output.
- Create drafts by default.
- Do not publish/delete/retry/submit unless the user asked.
- Use `request get ...` only when high-level commands are missing.
```

JSON の形式に関する注記は、Codex が次のコマンドを選ぶために必要な場合にだけ含めてください。
