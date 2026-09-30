# jQuery フロントエンドセキュリティ仕様（jQuery 4.0.x、最新のブラウザー）

このドキュメントは、以下を支援する**セキュリティ仕様**として作成されています。

1. 新しい jQuery ベースのフロントエンドコードを対象とする、**デフォルトで安全なコード生成**。
2. 既存の jQuery ベースのコードを対象とする、**セキュリティレビュー／脆弱性の調査**（作業中に問題に気付く受動的な確認と、リポジトリをスキャンして検出事項を報告する能動的な確認）。

この仕様は意図的に、**規範的要件**（「MUST/SHOULD/MAY」）と**監査ルール**（不適切なパターンの見た目、検出方法、修正／緩和方法）をまとめた形式で記述されています。

---

## 0) 安全性、境界、悪用防止の制約（必ず遵守）

* 秘密情報（API キー、パスワード、秘密鍵、セッショントークン、リフレッシュトークン、CSRF トークン、セッション Cookie）を要求、出力、ログ記録、コミットしてはなりません。
* ブラウザーは攻撃者に制御される環境として扱わなければなりません。

  * フロントエンドのチェック（UI の表示制御、「ボタンを無効化」、非表示フィールド、クライアント側の入力検証）を、認可やセキュリティ境界として扱ってはなりません。
  * フロントエンドが「正しく」ても、サーバー側の認可と入力検証が存在しなければなりません。
* 保護機能を無効化してセキュリティを「修正」してはなりません（例：`unsafe-inline` を許可するために CSP を緩和する、動作するという理由で JSONP を有効にする、広範な CORS を追加する、サニタイズを無効化する、セキュリティチェックを抑止する）。
* 監査では、ファイルパス、コードスニペット、関連する設定値を示し、根拠に基づいて検出事項を報告しなければなりません。
* 不確実な点は正直に扱わなければなりません。保護機能がエッジ（CDN/WAF／CSP などのリバースプロキシヘッダー）に存在する可能性がある場合は、「リポジトリ内では確認できない。実行環境／設定を確認すること」と報告してください。

---

## 1) 動作モード

### 1.1 生成モード（デフォルト）

新しい jQuery コードの作成または既存の jQuery コードの変更を依頼された場合：

* この仕様の**すべての MUST 要件**に従わなければなりません。
* ユーザーが明示的に別の指示をしない限り、**すべての SHOULD 要件**に従うべきです。
* 安全なデフォルトのパターンを優先しなければなりません。具体的には、テキスト挿入、DOM ノードの構築、許可リスト、独自のエスケープ処理より実績あるサニタイズライブラリを使用してください。
* 新たなリスクのあるシンク（HTML 文字列の構築、動的なスクリプト読み込み、JSONP、インラインスクリプト／イベントハンドラー属性、安全でない URL の代入、安全でないオブジェクトのマージ）を導入してはなりません。

### 1.2 受動的レビュー モード（編集中は常に有効）

jQuery を使うリポジトリ内のどこで作業していても（ユーザーがセキュリティスキャンを依頼していない場合も含む）：

* この仕様への違反に気付かなければなりません。
* 問題が見つかったら、簡潔な説明と安全な修正方法を添えて伝えるべきです。

### 1.3 能動的監査モード（明示的なスキャン依頼時）

ユーザーから「スキャン」「監査」「脆弱性の調査」を依頼された場合：

* コードベースを体系的に検索し、この仕様への違反を調べなければなりません。
* 構造化された形式（§2.3 を参照）で検出事項を出力しなければなりません。

推奨する監査順序：

1. jQuery の取得元、バージョン、依存関係の健全性（script タグ、ロックファイル、CDN の利用、SRI）。
2. CSP／Trusted Types／セキュリティヘッダーの状態（リポジトリ内、および確認可能な場合は実行環境）。
3. DOM XSS：信頼できない入力元から jQuery のシンク（`.html`、`.append`、`$("<…>")`、`.load` など）へのデータフロー。
4. スクリプト実行シンク：JSONP、`dataType:"script"`、`$.getScript`、動的な `<script>` 挿入。
5. URL／属性の代入（`href`、`src`、`style`、`on*` 属性）。
6. プロトタイプ汚染／安全でないオブジェクトのマージ（`$.extend` のパターン）。
7. AJAX の認証パターン、および Cookie ベースのセッションにおける CSRF。
8. サードパーティ製プラグインと、信頼できないコンテンツの描画経路（コメント、WYSIWYG、Markdown から HTML への変換）。

---

## 2) 定義とレビューの指針

### 2.1 信頼できない入力（安全性が確認できない限り、攻撃者が制御するものとして扱う）

例：

* ユーザーに由来するサーバーからのあらゆるデータ（ユーザープロフィール、コメント、「表示名」、リッチテキスト、ファイル名）。
* サードパーティの API やサービスからのデータ。
* ブラウザーが制御するデータソース：

  * `location.href`、`location.search`、`location.hash`
  * `document.URL`、`document.baseURI`、`document.referrer`
  * `window.name`
  * `localStorage`／`sessionStorage`
  * `postMessage` イベントのデータ（厳密なオリジン検証とスキーマ検証がない場合）
  * 以前に注入された可能性がある DOM コンテンツ（格納型 XSS）

### 2.2 jQuery コンテキストにおける高リスクの「シンク」

シンクとは、信頼できない入力が実行可能なコードまたは HTML として解釈される可能性のあるコード経路です。

jQuery の主なシンク分類：

* HTML の挿入／解析：

  * `.html()`、`.append()` および関連メソッドなど、HTML 文字列を受け取る DOM 操作メソッド（CVE に関する注記を参照）。([NVD][1])
  * `$(htmlString)`（引数が HTML マークアップとして解釈される可能性がある場合）。
  * `jQuery.parseHTML(html, …, keepScripts)`、特に `keepScripts=true` の場合。([jQuery API][2])
  * `.load(url)`（HTML を DOM に読み込みます。スクリプト実行に関する特別な動作があります）。([jQuery API][3])
* スクリプト実行／動的なコード読み込み：

  * `$.getScript()`／`$.ajax({ dataType: "script" })`（取得した JavaScript を実行します）。([jQuery API][4])
  * JSONP（`dataType: "jsonp"` または暗黙的な JSONP の動作）（レスポンスとしてリモートの JavaScript を実行します）。([jQuery API][5])
  * `eval`、`new Function`、`setTimeout("…")`、`setInterval("…")`、`$.globalEval`（存在する場合）
* 危険な属性の代入：

  * 信頼できない文字列を `href`、`src`、`srcdoc`、`style`、またはイベントハンドラー属性（`onload`、`onclick` など）に代入すること
  * `javascript:` URL は特に危険であり、使用は推奨されません。([MDN Web Docs][6])

### 2.3 必須の監査検出事項フォーマット

見つかった各問題について、次の項目を出力してください。

* ルール ID：
* 深刻度：Critical / High / Medium / Low
* 場所：ファイルパス + 関数／コンポーネント + 行番号
* 根拠：該当するコード／設定の正確なスニペット
* 影響：何が起こり得るか、誰が悪用できるか
* 修正方法：安全な変更（最小限の差分を優先）
* 緩和策：すぐに修正するのが難しい場合の多層防御
* 誤検知に関する注記：不確実な場合に確認すべき点

---

## 3) セキュアな基本構成：本番環境の最低限の設定（本番環境では必須）

これは、jQuery 関連の一般的なセキュリティ障害を防ぐために必要な、最小限の「本番環境向け基本構成」です。

### 3.1 サポート対象の修正済み jQuery バージョンを使う（必須）

* サポート対象の jQuery メジャーバージョンを使い、常に最新の状態に保たなければなりません。
* 2026-01-27 時点で、jQuery プロジェクトが提供する最新のメジャーリリースは jQuery 4.0.0 です。([blog.jquery.com][7])
* 非常に古いブラウザー（特に IE < 11）をサポートする必要がある場合、jQuery 4 はそれらをサポートしていないため、jQuery 3.x を使い続ける必要があるかもしれません。この場合はリスクの高い状態として扱い、積極的にパッチを適用してください。([blog.jquery.com][7])

### 3.2 jQuery を安全に読み込む（必須）

* jQuery は次のいずれかからのみ読み込まなければなりません。

  * 独自のビルドパイプライン（npm/yarn とロックファイルを使用してバンドル）、または
  * 公式 jQuery CDN／Subresource Integrity（SRI）を有効にした信頼できる CDN。
* CDN から読み込む場合は、SRI（`integrity`）と適切な `crossorigin` 設定を使うべきです。jQuery プロジェクトは、同プロジェクトの CDN で SRI を明示的にサポートし、推奨しています。（[jquery.com][8] から取得）

### 3.3 CSP + Trusted Types（推奨。ポリシーで利用可能／必須の場合は必須）

* XSS の影響を抑える Content Security Policy（CSP）を導入するべきです（特に `script-src` の制限と `unsafe-inline` の回避）。HTTP サーバーで設定しない場合は、`<meta http-equiv="Content-Security-Policy" content="...">` タグで設定できます。([OWASP Cheat Sheet Series][9]) 注：CSP の `script-src` を設定することが最も重要です。その他のディレクティブはそれほど重要ではなく、開発を簡単にするため、一般には省略できます。
* DOM XSS に対する強力な多層防御として、Trusted Types の利用を検討するべきです。([W3C][10])
* CSP ディレクティブ `require-trusted-types-for` を導入する場合、DOM への注入は Trusted Types ポリシーを経由させなければなりません。([MDN Web Docs][11])
* 注：jQuery 4.0 では Trusted Types のサポートが明示的に追加されたため、`require-trusted-types-for` に違反せず、jQuery の操作メソッドで TrustedHTML を使用できます。([blog.jquery.com][7])

### 3.4 セキュリティヘッダーと Cookie の設定（多層防御、推奨）

これらは通常サーバー側で設定されますが、jQuery 関連のミスによる影響範囲を大幅に抑えられます。ただし、対象がフロントエンドの Web アプリケーションのみの場合、これらに対処することはできません。

* 一般的なセキュリティヘッダー（CSP、`X-Content-Type-Options: nosniff`、`frame-ancestors`／`X-Frame-Options` によるクリックジャッキング対策、`Referrer-Policy`）を設定するべきです。([OWASP Cheat Sheet Series][12])
* 脅威モデルで「XSS = アカウント乗っ取り」を明示的に許容していない限り、JavaScript からアクセスできる場所（`localStorage` など）への長期間有効な秘密情報／トークンの保存は避けるべきです。これは jQuery 固有の問題ではありませんが、jQuery を多用した DOM 操作は DOM XSS の再発リスクを高めます。攻撃者が得られる利得を減らしてください。

---

## 4) ルール（生成＋監査）

各ルールには、必須の実践事項、安全でないパターン、検出の手がかり、修正方法が含まれます。

### JQ-SUPPLY-001: jQuery にパッチを適用し、既知の脆弱なバージョンを使わない

深刻度：Medium（インターネットに公開されたアプリで、既知の脆弱なバージョンの場合は High）

注：アップグレードの前に、ユーザーの同意を得て、バージョンを据え置く理由があるか確認してください。アップグレードによって予期しない形でアプリケーションが壊れることがあります。アップグレードは実行せずに、報告して推奨してください。

必須事項：

* 修正済みバージョンが存在する場合、影響の大きい既知の脆弱性を持つ jQuery バージョンを使ってはなりません。
* 次のバージョンより新しいものにアップグレードしなければなりません。

  * CVE-2019-11358（3.4.0 より前の jQuery におけるプロトタイプ汚染）。([NVD][13])
  * CVE-2020-11022／CVE-2020-11023（信頼できない HTML を扱う際の DOM 操作メソッドにおける XSS リスク。3.5.0 で修正済み）。([NVD][1])

安全でないパターン：

* 古い jQuery を参照する script タグまたはパッケージマニフェスト（例：`jquery-1.*`、`jquery-2.*`、`jquery-3.3.*`、`jquery-3.4.*`、`jquery-3.4.1` など）。
* アップグレードの手段がない古い圧縮版 jQuery を含むベンダーディレクトリ。

検出の手がかり：

* HTML／テンプレートで `jquery-` を検索し、バージョン文字列を解析する。
* `package.json`、`package-lock.json`、`yarn.lock`、`pnpm-lock.yaml` を確認する。
* `vendor/`、`public/`、`static/`、`assets/`、`wwwroot/` にある `jquery*.js` を確認する。

修正方法：

* 最新の jQuery にアップグレードする（最新の安定メジャーバージョンを優先。2026-01-27 時点では 4.0.0 が最新）。([blog.jquery.com][7])
* アップグレードに制約がある場合は、少なくとも CVE の修正バージョンを超えるものにアップグレードし、代替の保護策（強力な CSP、厳格なサニタイズ、JSONP などのリスクのある API の削除、信頼できないオブジェクトに対する deep-extend の削除）を追加する。

注記：

* 製品要件により古いバージョンが必要な場合は、「代替の保護策が必要な受容済みリスク」として報告してください。

---

### JQ-SUPPLY-002: サードパーティスクリプトの読み込みでは integrity と信頼できるオリジンを使用する（推奨）

深刻度：High

必須事項：

* jQuery とプラグインは、信頼できるオリジンからのみ読み込まなければなりません。
* CDN から読み込む場合は、SRI（`integrity`）と適切な `crossorigin` の設定を使うべきです。([jquery.com][8])

安全でないパターン：

* `integrity` のない `<script src="https://…/jquery.min.js"></script>`。
* 明示的な信頼判断をせずに、無作為なサードパーティ CDN から jQuery を読み込むこと。

検出の手がかり：

* HTML 内の `<script src=` をスキャンし、`integrity=` と `crossorigin=` の有無を確認する。
* 信頼できない URL を使った動的なスクリプト挿入を特定する（JQ-EXEC-001 を参照）。

修正方法：

* npm + ロックファイルを使ったバンドルを優先する。
* CDN を使う場合は、公式の script タグをコピーする（jQuery CDN は SRI をサポートしています）。([jquery.com][8])

注：正しい SRI タグを取得できない場合は、この手順を省略し、ユーザーに伝えてください。誤った値を使うとアプリが動作しなくなります。その場合は削除してユーザーに知らせてください。

---

### JQ-XSS-001: 信頼できないデータを jQuery の DOM 操作メソッドで HTML として挿入してはならない

深刻度：High（攻撃者が制御するコンテンツがこれらのシンクに到達する場合）

必須事項：

* HTML 文字列の挿入はすべて、コード実行につながる境界として扱わなければなりません。
* 信頼できないテキストには、安全な代替手段を使わなければなりません。

  * `.text(untrusted)`（HTML ではなくテキストとして扱う）。([jQuery API][14])
  * フォームフィールドには `.val(untrusted)` を使う。([jQuery API][15])
  * HTML 文字列を連結する代わりに、要素を作成し、テキスト／属性を安全に設定する。

安全でないパターン（例）：

* `$(selector).html(untrusted)`
* `$(selector).append(untrusted)`
* `$(selector).before(untrusted)` / `.after(untrusted)` / `.replaceWith(untrusted)` / `.wrap(untrusted)`（および類似のもの）
* マークアップの組み立て: `"<div>" + untrusted + "</div>"` を jQuery に渡す

検出の手がかり:

* 次を Grep で検索する: `.html(`, `.append(`, `.prepend(`, `.before(`, `.after(`, `.replaceWith(`, `.wrap(`, `.wrapAll(`, `.wrapInner(`
* §2.1 のソースからこれらの呼び出しへ至るデータフローを追跡する。

修正:

* `.text()` / `.val()` またはノード構築に置き換える:

  * `const $el = $("<span>").text(untrusted); container.append($el);`
* 出力に限定的なマークアップを含める必要がある場合は、JQ-XSS-002（サニタイズ）を参照。

注意:

* 古い jQuery バージョンでは、サニタイズを試みても追加のエッジケースがありました。3.5.0 以降で修正済みです。それでも「文字列のサニタイズ」だけに依存せず、構造化した生成方法または実績のあるサニタイザーを優先してください。([GitHub][16])

---

### JQ-XSS-002: ユーザー制御の HTML を描画する必要がある場合は、実績のある HTML サニタイザーで必ずサニタイズする

重大度: 中（攻撃者がリッチ HTML を制御でき、サニタイザーが脆弱または設定不備の場合は高）

必須事項:

* 正規表現を使って独自の HTML サニタイザーを「自作」してはならない。
* ユーザー制御の HTML を表示する必要がある場合（例: リッチテキストのコメント）、十分に保守されている HTML サニタイザーと制限的な許可リストを使って必ずサニタイズする。

  * DOMPurify は一般的な選択肢です。保守的な設定を使い、最新の状態を保ってください。([GitHub][17])
  * 利用可能な場合は、ブラウザーの HTML Sanitizer API も検討してよい（注: 利用できるブラウザーは限られます）。([MDN Web Docs][18])
* 多層防御のため、サニタイズと CSP を組み合わせ、可能であれば Trusted Types も併用することが望ましい。([OWASP Cheat Sheet Series][9])

安全でないパターン:

* 正規表現で「`<script>` を除去」または「`<` をエスケープ」し、その後 `.html()` で挿入する方法。
* DOMPurify（または同様のもの）で許可するタグや属性の範囲が広すぎる設定、またはレビューされていない設定。

検出の手がかり:

* 「sanitize」ヘルパー関数、`<` / `>` パターンを置換する正規表現、または「すべてのタグを許可」する設定を検索する。
* ユーザー生成の「リッチテキスト」や「カスタム HTML」を描画する機能を特定する。
* サニタイザーの結果が `.html()` または同等のシンクに挿入されているか確認する。

修正:

* 厳格な許可リストを持つサニタイザーを導入する。
* 「サニタイズしてから挿入する」処理を、レビュー済みの単一モジュールに集約する。
* 代表的な悪意ある入力を網羅する回帰テストを追加する（ペイロードをログやテレメトリーに保存しない）。

誤検知に関する注意:

* コンテンツが確実に信頼できる場合（例: 自分が配布するコンパイル済みテンプレート）は、信頼境界と、攻撃者に制御されない理由を文書化する。

---

### JQ-XSS-003: `$(untrustedString)` と `jQuery.parseHTML` で攻撃者が制御するマークアップを処理してはならない

重大度: 高（攻撃者が制御できる場合）

必須事項:

* HTML として解釈される可能性がある場合、攻撃者が制御する文字列を `$()` に渡してはならない。
* `jQuery.parseHTML(html, …, keepScripts)` は高リスクのプリミティブとして扱うこと。信頼できない入力には、必ず keepScripts を `false` にする。([jQuery API][2])

安全でないパターン:

* `const $node = $(untrusted);`
* `$.parseHTML(untrusted, /* context */, true)`（スクリプトが保持される）

検出の手がかり:

* 引数が静的セレクターでも静的マークアップでもない `$(` 呼び出しを検索する。
* `$.parseHTML(` を検索し、`keepScripts` 引数を確認する。

修正:

* タグ名を定数にした DOM 生成と、信頼できない値に対する `.text()` を使う。
* HTML の解析が必要な場合は、先にサニタイズし（JQ-XSS-002）、スクリプトを無効にする。

---

### JQ-XSS-004: `.load()` は HTML およびスクリプトの挿入箇所として扱わなければならない

重大度: 中（URL またはコンテンツを攻撃者が制御できる場合は高）

必須事項:

* 攻撃者が制御する URL または HTML フラグメントを `.load()` に使用してはならない。
* jQuery の `.load()` におけるスクリプトの挙動を理解すること:

  * URL にセレクターがない場合、スクリプトが削除される前にコンテンツが `.html()` に渡されるため、スクリプトが実行される可能性があります。([jQuery API][3])
* データの取得には `fetch()` / XHR を優先し、その後、安全な DOM 生成で描画するか、明示的にサニタイズすることが望ましい。

安全でないパターン:

* `$("#target").load(untrustedUrl)`
* `$("#target").load("/path?param=" + untrusted)`

検出の手がかり:

* JS/TS ファイル全体で `.load(` を検索する。
* URL にセレクターが付加されているかを特定する（挙動が異なります）。([jQuery API][3])
* URL がユーザー入力の影響を受けるか追跡する。

修正:

* `.load()` を次の方法に置き換える:

  * `fetch()` で JSON を取得し、`.text()` / ノード構築で描画する、または
  * `fetch()` で HTML を取得してサニタイズした後に挿入する。
* `.load()` を残す必要がある場合は、URL が定数または厳格な許可リストに限定され、返されるコンテンツが信頼できることを確認する。

---

### JQ-EXEC-001: 動的なスクリプト実行およびスクリプト取得を信頼できない入力から到達可能にしてはならない

重大度: 高

必須事項:

* 信頼できない URL、またはユーザーの影響を受ける URL からスクリプトを取得して実行してはならない。
* 次をコード実行プリミティブとして扱うこと:

  * `$.getScript(url)` は取得したスクリプトをグローバルコンテキストで実行する。([jQuery API][4])
  * `$.ajax({ dataType: "script" })` およびレスポンスを実行するその他のスクリプト型リクエスト。
* 強く、レビュー済みの正当な理由がない限り、これらのパターンを削除することが望ましい。

安全でないパターン:

* `$.getScript(untrustedUrl)`
* `$.ajax({ url: untrustedUrl, dataType: "script" })`
* `src` が信頼できない入力に由来する、動的な `<script src=...>` の挿入。

検出の手がかり:

* `getScript(`, `dataType: "script"`, `globalEval`, `eval`, `new Function` を検索する。
* URL を受け付ける「プラグインローダー」や「テーマローダー」機能を探す。

修正:

* スクリプトをビルド時にバンドルする。
* 実行時の読み込みが必要な場合は、許可リストに登録され、バージョンが固定され、整合性が検証されたアセットに制限する（可能であれば、実行時のコード読み込み自体も避ける）。

---

### JQ-AJAX-001: エンドポイントが完全に信頼できる場合を除き JSONP を無効にし、信頼できる場合でも使用を避ける

重大度: 中（攻撃者が URL/エンドポイントに影響できる場合は高）

必須事項:

* 信頼できないエンドポイントには JSONP を使用してはならない。JavaScript のレスポンスが実行されるためです。
* `$.ajax` を使う場合、完全には信頼できない対象に対して JSONP を明示的に無効にすること。jQuery の公式ドキュメントは、対象を信頼できない場合、「セキュリティ上の理由から」`jsonp: false` を設定するよう推奨しています。([jQuery API][5])
* JSON（`dataType: "json"`）を使った CORS と、サーバー側での明示的なオリジン許可リストを優先することが望ましい。

安全でないパターン:

* `dataType: "jsonp"`
* `callback=?` を含む URL、または JSONP の挙動を引き起こすパターン。callback 引数は歴史的に XSS の攻撃経路です。
* `dataType` を固定せず、JSONP も無効にしていない `$.get(untrustedUrl)`（オプションや jQuery の挙動に応じてリスクが異なります）

検出の手がかり:

* `jsonp`, `dataType: "jsonp"`, `callback=?` を検索する。
* URL がハードコードも許可リスト化もされていないクロスドメイン AJAX を検索する。

修正:

* サーバー側で CORS を設定し、HTTPS 経由で JSON を使用する。
* 次を設定する:

  * `dataType: "json"`
  * `jsonp: false`（URL の解釈が曖昧な場合に多層防御として設定）([jQuery API][5])

---

### JQ-AJAX-002: Cookie 認証を使う状態変更 AJAX リクエストは CSRF 対策を必須とする

重大度: 高

注: これは Cookie ベースの認証を使用する場合にのみ該当します。リクエストが Authorization ヘッダーを使用する場合、CSRF の可能性はありません。

必須事項:

* 認証に Cookie を使う場合、状態変更リクエスト（POST/PUT/PATCH/DELETE）を CSRF から必ず保護する。
* サーバーで検証される CSRF トークンを使うことが望ましい。AJAX 呼び出しでは、トークンは通常カスタムヘッダーで送信されます。([OWASP Cheat Sheet Series][19])
* 「AJAX リクエストだから」という理由だけで CSRF 対策になると見なしてはならない。

安全でないパターン:

* Cookie 認証で、CSRF トークン/ヘッダーなしに `$.post("/transfer", {...})` または `$.ajax({ method: "POST", ... })` を使う。
* `X-Requested-With` の確認だけを行う「CSRF 対策」（これは多層防御にすぎず、主要な対策ではありません）。

検出の手がかり:

* 状態変更を行う AJAX 呼び出しを列挙し、CSRF トークンが含まれているか確認する。
* サーバーがどのように CSRF 検証を行う想定かを特定する（meta tag、cookie-to-header の二重送信、同期トークンなど）。

修正:

* 例として `$.ajaxSetup({ headers: { "X-CSRF-Token": token } })` のように、一元化した箇所で CSRF トークンを含め、サーバーが検証することを確認する。
* トークンの要件と検証について OWASP の CSRF ガイダンスに従う。([OWASP Cheat Sheet Series][19])

誤検知に関する注意:

* 認証が Cookie ベースでない場合（例: Authorization ヘッダーのベアラートークン）、CSRF のリスクは異なります。実際の認証方式を確認する。

---

### JQ-ATTR-001: 検証または許可リストなしに、信頼できない値を危険な属性へ書き込んではならない

重大度: 低（onclick などのイベントでは高）

必須事項:

* `href`, `src`, `action` などに書き込む URL を必ず検証または許可リスト化する。
* 危険なスキームを必ずブロックする。コードを実行できるため、`javascript:` URL は推奨されません。([MDN Web Docs][6])
* 文字列からイベントハンドラー属性（`onclick`, `onerror` など）を設定してはならない。
* 信頼できない文字列を `style` 属性に書き込むことは避け、事前定義された CSS クラスの切り替えを優先することが望ましい。

安全でないパターン:

* `$("a").attr("href", untrustedUrl)`
* `$("img").attr("src", untrustedUrl)`
* `$(el).attr("style", untrustedCss)`
* `$(el).attr("onclick", untrustedJs)`

検出の手がかり:

* `.attr("href"`, `.attr("src"`, `.attr("style"`, `.prop("href"`, `.prop("src"` を検索する。
* 入力が URL パラメーター、サーバー JSON、DOM、またはストレージに由来するか追跡する。

修正:

* `new URL(value, location.origin)` で URL を解析・検証し、必要に応じてプロトコル（`https:` など）とホスト名を許可リスト化する。
* ナビゲーション先には、完全な URL よりも、自分で組み立てた相対パスを優先する。
* `style` 文字列を、事前定義したクラス名を使う `addClass/removeClass` に置き換える。

---

### JQ-SELECTOR-001: ユーザー制御のセレクターフラグメントは `jQuery.escapeSelector` でエスケープする

重大度: 中（セキュリティ上重要な UI で誤った要素が選択されると、高になる可能性があります）

必須事項:

* 特殊な CSS 文字を含む可能性のある ID/クラスで選択する必要がある場合は、`jQuery.escapeSelector()`（jQuery 3.0 以降で利用可能）を使うことが望ましい。([jQuery API][20])
* 攻撃者が制御する文字列をセレクター式にそのまま連結してはならない。

安全でないパターン:

* `$("#" + untrustedId)`
* `$("[data-id='" + untrusted + "']")`（特に、厳密な引用符付けやエスケープがない場合）

検出の手がかり:

* `$(` セレクター内で使われる `"#" +`、`". " +`、またはテンプレート文字列を検索する。
* 「ユーザー指定 ID による選択」を探す。

修正:

* `$("#" + $.escapeSelector(untrustedId))` ([jQuery API][20])
* ユーザー由来のセレクターより、安定した内部 ID を優先する。

注意:

* これは多くの場合「堅牢性」の問題ですが、誤った要素の選択によって UI が別のデータを表示・変更したり、セキュリティ関連の確認を省略したりする場合は、セキュリティ上重要な問題になり得ます。

---

### JQ-PROTOTYPE-001: 信頼できないオブジェクトをディープマージせず、プロトタイプ汚染を防ぐ

重大度: 中

必須事項:

* 危険なキーをフィルタリングせずに、攻撃者が制御するオブジェクトをアプリケーションオブジェクトへディープマージ（`$.extend(true, …)`）してはならない。
* CVE-2019-11358 のプロトタイプ汚染の挙動を避けるため、jQuery が 3.4.0 以降であることを必ず確認する。([NVD][13])

安全でないパターン:

* `$.extend(true, target, untrustedObj)`
* `untrustedObj` が URL/JSON/ストレージに由来する場合の `$.extend(true, {}, defaults, untrustedObj)`

検出の手がかり:

* `$.extend(true` を検索し、マージされるオブジェクトのソースを確認する。
* 信頼できない JSON を使う「オプションのマージ」/「設定の適用」パターンを検索する。

修正:

* 次の方法を優先する:

  * 許可リスト化したキーだけを使う浅いマージ、または
  * `__proto__`, `prototype`, `constructor` と、それらのネストした出現を明示的に拒否する安全なマージヘルパー。
* jQuery にパッチを適用した状態を保つ。

---

### JQ-CSP-001: DOM XSS の導入と悪用を困難にするため、CSP と Trusted Types を使うことが望ましい

重大度: 中

必須事項:

* XSS に対する多層防御として CSP を導入することが望ましい。([OWASP Cheat Sheet Series][9])
* Trusted Types（`require-trusted-types-for`）を有効にする場合、DOM への挿入が Trusted Types ポリシーを経由することを必ず確認する。([MDN Web Docs][11])
* jQuery 4 を使う場合は、その Trusted Types 対応（TrustedHTML 入力）を活用することが望ましい。([blog.jquery.com][7])

安全でないパターン:
* 補完策の計画がないまま CSP（`script-src 'unsafe-inline'` / `'unsafe-eval'`）を弱めて jQuery の機能を「修正」する。
* ユーザーコンテンツを表示したり、DOM を頻繁に操作したりするアプリケーションで CSP が設定されていない。

検出の手掛かり:

* CSP ヘッダーを探す（サーバー設定、フレームワークのミドルウェア、meta タグ）。
* リポジトリ内で確認できない場合は、「エッジ／実行時に確認」として指摘する。

修正:

* CSP を段階的に導入する。まずインラインスクリプトとインラインイベントハンドラーをなくし、その後 `script-src` を厳格化する。
* 対応可能で、実現性がある場合は Trusted Types を導入する。

---

## 5) 実践的なスキャンのヒューリスティクス（「探し方」）

スキャンを行う際は、次の検出精度の高いパターンを使う:

* jQuery のバージョン／取得元:

  * `jquery-*.js` または `vendor/` 内の `static/`
  * 古いバージョンに固定された `package.json` の `jquery` 依存関係
  * `integrity` / `crossorigin` のない CDN の script タグ ([jquery.com][8])
* HTML の挿入先（DOM XSS）:

  * `.html(`、`.append(`、`.prepend(`、`.before(`、`.after(`、`.replaceWith(`、`.wrap(`
  * 引数が HTML／テンプレート文字列である可能性のある `$(`
  * `$.parseHTML(`、特に `keepScripts=true` の場合 ([jQuery API][2])
  * `.load(`（およびセレクターが追記されているか。スクリプトの挙動が異なる）([jQuery API][3])
* スクリプト実行／動的コード:

  * `$.getScript(`、`dataType: "script"` ([jQuery API][4])
  * `dataType: "jsonp"` または `jsonp:` の使用、`callback=?` パターン ([jQuery API][5])
  * `eval`、`new Function`、`setTimeout("…")`、`$.globalEval`
* 危険な属性への書き込み:

  * `.attr("href", …)`、`.attr("src", …)`、`.attr("style", …)`
  * `javascript:` のようなスキームの代入、または不審な URL の組み立て ([MDN Web Docs][6])
* セレクターの組み立て:

  * `$("#" + user)` など。`$.escapeSelector` で修正する ([jQuery API][20])
* プロトタイプ汚染:

  * `$.extend(true, …, userObj)`。jQuery が 3.4.0 以上であることを確認し、危険なキーを除外する ([NVD][13])
* AJAX の CSRF 対策:

  * Cookie を使う一方で CSRF トークン／ヘッダーがない `$.post(` / `$.ajax({ method: ... })` ([OWASP Cheat Sheet Series][19])
* 多層防御:

  * 設定に CSP／セキュリティヘッダーがない（または確認できないため、実行時の検証が必要）([OWASP Cheat Sheet Series][12])

必ず次の点を確認する:

* データの出所（信頼できないものか、信頼できるものか）
* 挿入先の種類（HTML の挿入／スクリプト実行／属性／セレクター／オブジェクトのマージ）
* 保護策の有無（サニタイザー、許可リスト、CSP、Trusted Types、CSRF 検証）

---

## 6) 参考資料（2026-01-27 閲覧）

jQuery プロジェクトの公式ドキュメントとリリースノート:

* jQuery 4.0.0 リリースノート（Trusted Types／CSP の変更、バージョン情報）: `https://blog.jquery.com/2026/01/17/jquery-4-0-0/`. ([blog.jquery.com][7])
* jQuery のダウンロード（最新バージョン情報、CDN と SRI の案内）: `https://jquery.com/download/`. ([jquery.com][8])
* jQuery API: `.html()`: `https://api.jquery.com/html/`. ([jQuery API][21])
* jQuery API: `.text()`: `https://api.jquery.com/text/`. ([jQuery API][14])
* jQuery API: `.append()`: `https://api.jquery.com/append/`. ([jQuery API][22])
* jQuery API: `.load()`（スクリプトの実行動作）: `https://api.jquery.com/load/`. ([jQuery API][3])
* jQuery API: `jQuery.parseHTML(…, keepScripts)`: `https://api.jquery.com/jQuery.parseHTML/`. ([jQuery API][2])
* jQuery API: `$.ajax()`（`jsonp: false` のセキュリティに関する注記）: `https://api.jquery.com/jQuery.ajax/`. ([jQuery API][5])
* jQuery API: `$.getScript()`（スクリプトを実行）: `https://api.jquery.com/jQuery.getScript/`. ([jQuery API][4])
* jQuery API: `jQuery.escapeSelector()`: `https://api.jquery.com/jQuery.escapeSelector/`. ([jQuery API][20])

jQuery の脆弱性／勧告:

* NVD CVE-2019-11358（プロトタイプ汚染、jQuery < 3.4.0）: `https://nvd.nist.gov/vuln/detail/CVE-2019-11358`. ([NVD][13])
* NVD CVE-2020-11022（DOM 操作メソッドの XSS リスク、3.5.0 で修正）: `https://nvd.nist.gov/vuln/detail/CVE-2020-11022`. ([NVD][1])
* NVD CVE-2020-11023（`<option>` に関連する XSS リスク、3.5.0 で修正）: `https://nvd.nist.gov/vuln/detail/CVE-2020-11023`. ([NVD][23])
* GitHub Security Advisory GHSA-gxr4-xjj5-5px2（jQuery の htmlPrefilter における XSS、3.5.0 で修正）: `https://github.com/jquery/jquery/security/advisories/GHSA-gxr4-xjj5-5px2`. ([GitHub][16])

OWASP Cheat Sheet Series（jQuery の使用に関係する Web アプリケーションセキュリティの基礎）:

* XSS 対策: `https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html`. ([OWASP Cheat Sheet Series][24])
* DOM ベースの XSS 対策: `https://cheatsheetseries.owasp.org/cheatsheets/DOM_based_XSS_Prevention_Cheat_Sheet.html`. ([OWASP Cheat Sheet Series][25])
* CSRF 対策: `https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html`. ([OWASP Cheat Sheet Series][19])
* HTTP セキュリティヘッダー: `https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html`. ([OWASP Cheat Sheet Series][12])
* コンテンツセキュリティポリシーのチートシート: `https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html`. ([OWASP Cheat Sheet Series][9])

ブラウザー／プラットフォームの参考資料（SRI、CSP、Trusted Types、危険な URL スキーム）:

* MDN: Subresource Integrity (SRI): `https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Subresource_Integrity`. ([MDN Web Docs][26])
* W3C: SRI 仕様: `https://www.w3.org/TR/sri-2/`. ([W3C][27])
* MDN: CSP ガイド: `https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CSP`. ([MDN Web Docs][28])
* MDN: `require-trusted-types-for` ディレクティブ: `https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/require-trusted-types-for`. ([MDN Web Docs][11])
* MDN: Trusted Types API: `https://developer.mozilla.org/en-US/docs/Web/API/Trusted_Types_API`. ([MDN Web Docs][29])
* W3C: Trusted Types 仕様: `https://www.w3.org/TR/trusted-types/`. ([W3C][10])
* MDN: `javascript:` URL スキームに関する警告: `https://developer.mozilla.org/en-US/docs/Web/URI/Reference/Schemes/javascript`. ([MDN Web Docs][6])
* DOMPurify プロジェクトのドキュメント: `https://github.com/cure53/DOMPurify`. ([GitHub][17])

[1]: https://nvd.nist.gov/vuln/detail/cve-2020-11022?utm_source=chatgpt.com "CVE-2020-11022 詳細 - NVD"
[2]: https://api.jquery.com/jQuery.parseHTML/?utm_source=chatgpt.com "jQuery.parseHTML()"
[3]: https://api.jquery.com/load/?utm_source=chatgpt.com ".load() | jQuery API ドキュメント"
[4]: https://api.jquery.com/jQuery.getScript/?utm_source=chatgpt.com "jQuery.getScript()"
[5]: https://api.jquery.com/jQuery.ajax/?utm_source=chatgpt.com "jQuery.ajax()"
[6]: https://developer.mozilla.org/en-US/docs/Web/URI/Reference/Schemes/javascript?utm_source=chatgpt.com "javascript: URL - URI - MDN Web Docs"
[7]: https://blog.jquery.com/2026/01/17/jquery-4-0-0/ "jQuery 4.0.0 | 公式 jQuery ブログ"
[8]: https://jquery.com/download/ "jQuery のダウンロード | jQuery"
[9]: https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html?utm_source=chatgpt.com "コンテンツセキュリティポリシー - OWASP Cheat Sheet Series"
[10]: https://www.w3.org/TR/trusted-types/?utm_source=chatgpt.com "Trusted Types"
[11]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/require-trusted-types-for?utm_source=chatgpt.com "Content-Security-Policy: require-trusted-types-for ディレクティブ"
[12]: https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html?utm_source=chatgpt.com "HTTP セキュリティレスポンスヘッダーのチートシート"
[13]: https://nvd.nist.gov/vuln/detail/cve-2019-11358?utm_source=chatgpt.com "CVE-2019-11358 詳細 - NVD"
[14]: https://api.jquery.com/text/?utm_source=chatgpt.com ".text() | jQuery API ドキュメント"
[15]: https://api.jquery.com/val/?utm_source=chatgpt.com ".val() | jQuery API ドキュメント"
[16]: https://github.com/jquery/jquery/security/advisories/GHSA-gxr4-xjj5-5px2 "jQuery.htmlPrefilter および関連メソッドの潜在的な XSS 脆弱性 · 勧告 · jquery/jquery · GitHub"
[17]: https://github.com/cure53/DOMPurify?utm_source=chatgpt.com "DOMPurify - DOM 専用で非常に高速、柔軟な XSS ..."
[18]: https://developer.mozilla.org/en-US/docs/Web/API/HTML_Sanitizer_API?utm_source=chatgpt.com "HTML Sanitizer API - MDN Web Docs"
[19]: https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html?utm_source=chatgpt.com "クロスサイトリクエストフォージェリ対策チートシート"
[20]: https://api.jquery.com/jQuery.escapeSelector/?utm_source=chatgpt.com "jQuery.escapeSelector()"
[21]: https://api.jquery.com/html/?utm_source=chatgpt.com ".html() | jQuery API ドキュメント"
[22]: https://api.jquery.com/append/?utm_source=chatgpt.com ".append() | jQuery API ドキュメント"
[23]: https://nvd.nist.gov/vuln/detail/cve-2020-11023?utm_source=chatgpt.com "CVE-2020-11023 詳細 - NVD"
[24]: https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html?utm_source=chatgpt.com "クロスサイトスクリプティング対策 - OWASP Cheat Sheet Series"
[25]: https://cheatsheetseries.owasp.org/cheatsheets/DOM_based_XSS_Prevention_Cheat_Sheet.html?utm_source=chatgpt.com "DOM ベースの XSS 対策チートシート"
[26]: https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Subresource_Integrity?utm_source=chatgpt.com "Subresource Integrity - セキュリティ - MDN Web Docs"
[27]: https://www.w3.org/TR/sri-2/?utm_source=chatgpt.com "Subresource Integrity"
[28]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CSP?utm_source=chatgpt.com "コンテンツセキュリティポリシー (CSP) - HTTP - MDN Web Docs"
[29]: https://developer.mozilla.org/en-US/docs/Web/API/Trusted_Types_API?utm_source=chatgpt.com "Trusted Types API - MDN Web Docs"