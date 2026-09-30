# フロントエンド JavaScript/TypeScript Web セキュリティ仕様（Vanilla Browser JS/TS、モダンブラウザー）

このドキュメントは、次を支援する**セキュリティ仕様**として作成されています。

1. 新しいフロントエンド JavaScript/TypeScript の**セキュアなデフォルトでのコード生成**（特定のフレームワークを前提としない）。
2. 既存のフロントエンドコードの**セキュリティレビュー／脆弱性調査**（「作業中に問題に気づく」という受動的な確認と、「リポジトリをスキャンして検出事項を報告する」という能動的な確認）。

本書は、**規範的要件**（「MUST/SHOULD/MAY」）と**監査ルール**（危険なパターンの見分け方、検出方法、修正／緩和方法）をまとめたものです。

---

## 0) 安全性、境界、および不正利用防止の制約（必ず従うこと）

* シークレット（秘匿を意図した API キー、秘密鍵、パスワード、OAuth リフレッシュトークン、セッショントークン、Cookie）を要求、出力、ログ記録、ハードコード、またはコミットしてはなりません。
  注記：

  * フロントエンドコードは、エンドユーザーから本質的に確認可能です。秘匿しなければならない値をブラウザーに配信されるコードに含めてはなりません。
  * プロジェクトで「公開」キー（例：公開可能な分析用キー）を使用する場合、それらはシークレットではないものとして扱い、適切な範囲に制限しなければなりません。

* 保護機能を無効化してセキュリティを「修正」してはなりません（例：正当な理由なく `unsafe-inline`／`unsafe-eval` で CSP を弱める、`postMessage` のオリジンチェックを削除する、手軽さのために `innerHTML` に切り替える、任意のリダイレクト／URL を許可する、サニタイズを無効にする）。

* 監査では**根拠に基づく検出事項**を提示しなければなりません。主張を裏付けるファイルパス、コード断片、関連する HTML／CSP／設定値を示してください。

* 不確実性は正直に扱わなければなりません。

  * セキュリティヘッダー（CSP、frame-ancestors など）は、リポジトリ内のコードではなくサーバー／エッジ／CDNで設定されている場合があります。確認できない場合は、「ここでは確認できない。実行時／エッジ設定で確認すること」と報告してください。（また、`<meta http-equiv=...>` は一部のヘッダーを模倣するだけです。meta タグがあるからといって、他のセキュリティヘッダーも存在すると想定しないでください。） ([MDN Web Docs][1])

---

## 1) 作業モード

### 1.1 生成モード（デフォルト）

新しいフロントエンド JS/TS コードの作成または既存コードの変更を依頼された場合：

* 本仕様のすべての **MUST** 要件に従わなければなりません。
* ユーザーが明示的に別の指示をしない限り、すべての **SHOULD** 要件に従うべきです。
* 安全なデフォルト設定のブラウザー API と、独自のセキュリティコード（特に HTML サニタイズ）よりも、十分に実績のあるライブラリーを優先しなければなりません。
* 新たな危険なシンク（`innerHTML` などの DOM XSS 注入シンク、`javascript:` URL への遷移、`eval`／`Function` による動的コード実行、安全でない `postMessage`、安全でないサードパーティスクリプトの読み込みなど）を導入してはなりません。 ([OWASP Cheat Sheet Series][2])

### 1.2 受動的レビュー・モード（編集中は常に有効）

フロントエンドリポジトリ内のどこで作業していても（ユーザーからセキュリティスキャンを依頼されていない場合も含む）：

* 変更対象またはその近辺のコードで、本仕様への違反に「気づかなければ」なりません。
* 問題が見つかったら、簡潔な説明と安全な修正方法を添えて伝えるべきです。

### 1.3 能動的監査モード（明示的なスキャン依頼時）

ユーザーから「スキャン」「監査」「脆弱性を探す」と依頼された場合：

* コードベースを体系的に検索し、本仕様への違反を見つけなければなりません。
* 検出事項を所定の形式（§2.3 を参照）で提示しなければなりません。

推奨する監査順序：

1. HTML エントリーポイント（`index.html`、サーバー側でレンダリングされるテンプレート）、スクリプト／スタイルのインクルード、および CSP の配信方法（ヘッダーか meta か）。 ([W3C][3])
2. DOM XSS シンク（`innerHTML`、`document.write`、`insertAdjacentHTML`、イベントハンドラー属性）とそのデータソース（URL パラメーター／ハッシュ、ストレージ、postMessage、API レスポンス）。 ([OWASP Cheat Sheet Series][2])
3. `window.location*` URL の危険性を含む、ナビゲーション／リダイレクト処理（`javascript:`、リンクのターゲット、URL 許可リスト）。 ([MDN Web Docs][4])
4. オリジン間通信（`postMessage`、iframe の埋め込みパターン、サンドボックス設定）。 ([MDN Web Docs][5])
5. 機密データの保存（localStorage／sessionStorage）と、その信頼性に関する前提。 ([OWASP Cheat Sheet Series][6])
6. サードパーティスクリプト／タグマネージャー／CDN、整合性制御（SRI）、およびポリシー制御（CSP）。 ([OWASP Cheat Sheet Series][7])
7. DOM clobbering の悪用要素、および `window`／`document` の名前付きプロパティへの危険な依存。 ([OWASP Cheat Sheet Series][8])

---

## 2) 定義とレビュー指針

### 2.1 信頼できない入力（信頼できると証明されない限り、攻撃者が制御できるものとして扱う）

例：

* URL 由来のデータ：`location.href`、`location.search`、`location.hash`、`document.baseURI`、`new URLSearchParams(location.search)`、ルーティング用フラグメント。 ([OWASP Cheat Sheet Series][2])
* ユーザーが制御したマークアップを含む可能性のある DOM コンテンツ（コメント、プロフィール、CMS コンテンツ、Markdown から HTML への変換出力など）。特に動的に挿入される場合。 ([OWASP Cheat Sheet Series][2])
* 他のウィンドウ／フレームからの `postMessage` イベントデータ（`event.data`）とメタデータ（`event.origin`）。 ([MDN Web Docs][5])
* ブラウザーストレージ：`localStorage`、`sessionStorage`、IndexedDB（内容は XSS やローカルマシンへのアクセスを通じて攻撃者の影響を受ける可能性があります。「信頼できる」ものとして扱ってはなりません）。 ([OWASP Cheat Sheet Series][6])
* ネットワーク呼び出しから返されたあらゆるデータ（「自分たちの API」からのデータも含む）。保存された攻撃者由来のコンテンツが含まれ、DOM に挿入されたとき初めて危険になる場合があるためです。 ([OWASP Cheat Sheet Series][2])

### 2.2 危険なシンク（DOM XSS／コード実行シンク）

シンクとは、スクリプトを実行したり、攻撃者が制御する文字列を HTML／JS／URL としてセキュリティ上危険な形で解釈したりする可能性のある API／操作です。特に注意すべきシンク：

* HTML の解析／挿入：`innerHTML`、`outerHTML`、`insertAdjacentHTML`、`document.write`、`document.writeln`。 ([OWASP Cheat Sheet Series][2])
* 動的コード実行：`eval`、`new Function`、`setTimeout("...")`、`setInterval("...")`。 ([MDN Web Docs][10])
* `javascript:`／`Location.href` などのセッター経由（および攻撃者が制御する場合はリンクの `window.location` 経由）での、スクリプトを含む URL（例：`href`）への遷移。 ([MDN Web Docs][4])
* 文字列からのイベントハンドラー属性の設定。例：`setAttribute("onclick", "...")`。 ([OWASP Cheat Sheet Series][2])

### 2.3 必須の監査検出事項の形式

見つかった各問題について、次を出力してください。

* ルール ID：
* 深刻度：Critical / High / Medium / Low
* 場所：ファイルパス + 関数／クラス／モジュール + 行番号
* 根拠：該当するコード／設定の正確な抜粋
* 影響：何が起きる可能性があるか、誰が悪用できるか
* 修正：安全な変更（最小限の差分を優先）
* 緩和策：直ちに修正するのが難しい場合の多層防御
* 誤検出に関する注記：不確かな場合に確認すべきこと

---

## 3) 安全な基本設定：本番環境の最低限の構成（本番環境で必須）

これは、よくあるフロントエンド JS/TS のセキュリティ設定ミスを防ぐための最小限の基本設定です。一部はリポジトリ内（HTML／JS）で設定し、一部はサーバー／エッジで設定する場合があります。

### 3.1 Content Security Policy（CSP）の基本設定（SHOULD。高リスクアプリでは MUST）

* 可能であれば、CSP は HTTP レスポンスヘッダーで配信するべきです。
* ヘッダーを設定できない場合（例：静的ホスティングの制約のみがある場合）、HTML の `<meta http-equiv="Content-Security-Policy" ...>` タグによって CSP を配信してもかまいません。 ([MDN Web Docs][1])
* `<meta http-equiv>` を使って CSP を配信する場合、次の制限を理解しなければなりません。

  * ポリシーは meta 要素より後のコンテンツにのみ適用されます（そのため、適用対象とするスクリプト／リソースより十分前に配置する必要があります）。 ([W3C][3])
  * 次のディレクティブは meta で配信するポリシーでは**サポートされず**、無視されます：`report-uri`、`frame-ancestors`、`sandbox`。 ([W3C][3])
  * 「Report-only」CSP は meta 要素では設定できません。 ([W3C][3])

実用的な基本方針：

* スクリプトソースに `unsafe-inline` や `unsafe-eval` を含めないでください（XSS に対する CSP の効果が大きく損なわれます）。 ([MDN Web Docs][10])
* インラインスクリプトが必要な場合は、nonce またはハッシュベースのスクリプトポリシーを優先してください。 ([MDN Web Docs][10])
* 実現可能であれば、Trusted Types の強制を有効にすることを検討してください。 ([MDN Web Docs][11])

### 3.2 サードパーティスクリプトの基本設定（SHOULD）

* サードパーティスクリプトの実行を最小限にし、自社の JS と同等の権限を持つものとして扱うべきです（自社オリジンの権限で実行されます）。 ([OWASP Cheat Sheet Series][7])
* CDN から読み込むサードパーティのスクリプト／スタイルには、Subresource Integrity（SRI）を使用するべきです。 ([MDN Web Docs][12])

### 3.3 ウィンドウ間通信の基本設定（SHOULD）

* `postMessage` 通信は明示的なオリジンに制限し、オリジンとメッセージの形式の両方を検証するべきです。 ([MDN Web Docs][5])

---

## 4) ルール（生成＋監査）

各ルールには、必須の実践事項、安全でないパターン、検出のヒント、および修正方法が含まれます。

### JS-XSS-001: 信頼できない HTML を DOM に挿入しない（`innerHTML` などを避ける）

深刻度：攻撃者が制御する入力がこれらの API に到達すると証明できる場合は Critical。それ以外は Medium


必須事項：

* 入力に信頼できないデータが含まれる可能性がある場合、`innerHTML`、`outerHTML`、`insertAdjacentHTML` を危険なシンクとして扱わなければなりません。 ([OWASP Cheat Sheet Series][2])
* HTML を解析しない安全な DOM API を優先しなければなりません。

  * テキストには `textContent` を使います。 ([OWASP Cheat Sheet Series][2])
  * イベントハンドラー以外の属性には `document.createElement`、`appendChild`、`setAttribute` を使います。 ([OWASP Cheat Sheet Series][2])
* HTML の挿入が本当に必要な場合は、十分にレビューされた HTML サニタイザーでサニタイズするべきです。また、監査済みのコードパスに使用箇所を限定するため、Trusted Types の強制を強く検討してください。 ([MDN Web Docs][11])

安全でないパターン：

* `el.innerHTML = userInput`
* `el.insertAdjacentHTML('beforeend', userInput)`
* `el.outerHTML = userInput`

検出のヒント：

* 次を検索します：`.innerHTML`、`.outerHTML`、`insertAdjacentHTML(`。
* 挿入される文字列の出所を追跡します：URL パラメーター／ハッシュ、postMessage、ストレージ、API レスポンス、DOM 属性。 ([OWASP Cheat Sheet Series][2])

修正：

* プレーンテキストには `textContent` を使います。 ([OWASP Cheat Sheet Series][2])
* 構造化 UI では、DOM ノードを明示的に構築します。
* 「リッチテキスト」が必要な場合：

  * 許可リスト方式のサニタイザーを使ってサニタイズします。
  * 任意の HTML 文字列ではなく、安全な「コンポーネント」を返す方法を優先します。
  * サポートされている場合は Trusted Types の強制を使い、シンクに渡される値が `TrustedHTML` のみとなるようにします。 ([MDN Web Docs][11])

緩和策：

* 厳格な CSP を導入し、Trusted Types の強制（`require-trusted-types-for 'script'`）を検討してください。 ([MDN Web Docs][10])

誤検出に関する注記：

* 文字列が定数であること、または信頼できる定数のみから完全に生成されていることを証明できる場合、安全な可能性があります。それでも、より安全な API を優先してください。

---

### JS-XSS-002: `document.write`／`document.writeln` を避ける（XSS と document clobbering の危険性）

深刻度：攻撃者が制御する入力がこれらの API に到達すると証明できる場合は Critical。それ以外は Medium 

必須事項：

* 本番コードでは `document.write()` と `document.writeln()` を避けなければなりません（これらは XSS の攻撃経路であり、一部のブラウザーが特定の状況で挿入された `<script>` をブロックする場合でも、細工された HTML で悪用される可能性があります）。 ([MDN Web Docs][13])
* レガシーコードでの使用を避けられない場合、信頼できない入力がこれらの API に到達しないようにしなければなりません。また、サポートされている場合は Trusted Types（`TrustedHTML`）を強制するべきです。 ([MDN Web Docs][14])

安全でないパターン：

* `document.write(userInput)`
* `document.writeln(getParam('q'))`

検出のヒント：

* `document.write(`、`document.writeln(` を検索します。 ([OWASP Cheat Sheet Series][2])

修正：

* DOM 操作（`createElement`、`appendChild`）または安全なテキスト挿入（`textContent`）に置き換えます。 ([OWASP Cheat Sheet Series][2])

緩和策：

* 厳格な CSP と Trusted Types の強制により、シンクが残る場合の被害範囲を縮小できます。 ([MDN Web Docs][10])

---

### JS-XSS-003: 文字列からコードを実行しない（`eval`、`new Function`、文字列形式のタイムアウト）

深刻度：攻撃者が制御する入力がこれらの API に到達すると証明できる場合は Critical。それ以外は Medium

必須事項：

* 信頼できないデータを次のものに渡してはなりません。

  * `eval()`
  * `new Function(...)`
  * 文字列引数を使った `setTimeout("...")`／`setInterval("...")` ([MDN Web Docs][10])
* モダンなフロントエンドコードでは、これらの API の使用自体を避け、eval を使わないロジックにリファクタリングするべきです。 ([MDN Web Docs][10])
* 文書化され、レビュー済みの正当な理由と補完的な制御がない限り、`unsafe-eval` を追加して「CSP の破損を修正」してはなりません。 ([MDN Web Docs][10])

安全でないパターン：

* `eval(userInput)`
* `new Function("return " + userInput)()`
* `setTimeout(userInput, 0)`（`userInput` が文字列の場合）

検出のヒント:

* `eval(`、`new Function`、`setTimeout("`、`setInterval("` を検索します。
* 後で使用されるコード文字列の構築も検索します。

修正:

* 動的コードを次の方法に置き換えます。

  * 構造化データと明示的な分岐／ハンドラー
  * JSON には `eval` ではなく JSON パース（`JSON.parse`）を使用します。([OWASP Cheat Sheet Series][2])

緩和策:

* 既定で `eval()` のような API をブロックする CSP を設定し、`unsafe-eval` を避けます。([MDN Web Docs][10])
* 制御されたケースでは Trusted Types の使用を検討できますが、強化レイヤーとして扱い、eval パターンを残す口実にしないでください。([MDN Web Docs][10])

---

### JS-XSS-004: イベントハンドラー属性に文字列を設定しない（例: `setAttribute("onclick", "...")`）

重大度: 高

必須事項:

* 信頼できないデータを使って `setAttribute("on…", string)` または類似のパターンを使用してはなりません。文字列がイベントハンドラーのコンテキストで実行可能なコードに変換されるためです。([OWASP Cheat Sheet Series][2])
* 関数参照を使う `addEventListener` を優先すべきです。

安全でないパターン:

* `el.setAttribute("onclick", userInput)`
* `el.onclick = userControlledString`（文字列の代入）

検出のヒント:

* `.setAttribute("on`、`.onclick =`、`.onmouseover =` などを検索します。
* 右辺（RHS）が URL、ハッシュ、ストレージ、`postMessage` の影響を受けるか追跡します。([OWASP Cheat Sheet Series][2])

修正:

* `addEventListener("click", () => { ... })` に置き換えます。
* 動的ディスパッチが必要な場合は、識別子と関数を対応付ける許可リストを使用します（文字列の eval は使いません）。([OWASP Cheat Sheet Series][2])

---

### JS-URL-001: ナビゲーション前に URL をサニタイズして許可リストで制限する（特に `window.location` / `location.replace`）

重大度: 低（攻撃者が URL を完全に制御できると証明できる場合は高）

重要: これは誤検知が多く発生する可能性があります。URL が攻撃者に完全に制御されているかどうか、追加の分析を行ってください。完全に制御されていない場合、せいぜい情報提供レベルです。

注: 任意の URL へリダイレクトできることが重要な機能である場合もあります。それが機能の目的であれば、オリジンを任意に許可するとしても、最低限スキームを検証してください。

必須事項:

* ナビゲーション先への代入はすべて、セキュリティ上重要な操作として扱わなければなりません。

  * `window.location = ...`
  * `location.href = ...`
  * `location.assign(...)`
  * `location.replace(...)` ([MDN Web Docs][4])
* 特に入力が URL パラメーター、ストレージ、メッセージに由来する場合、`javascript:` URL（および一般に、スクリプトを含むその他のアクティブなスキーム）へのナビゲーションを防止しなければなりません。([MDN Web Docs][4]) `http:` と `https:` のみを許可してください。
* 遷移先を検証し、許可リストで制限すべきです。安全な基本方針は次のとおりです。

  * 同一オリジンの相対パスのみを許可する、または
  * 厳格なオリジンとプロトコルの許可リストのみを許可する（通常は `https:`、ローカル開発では必要に応じて `http:`）。([OWASP Cheat Sheet Series][8])

安全でないパターン:

* `location.replace(getParam("next"))`
* `window.location = userSuppliedUrl`
* `redirectTo` が書き換え可能、または攻撃者によって設定可能な場合の `location.assign(window.redirectTo || "/")` ([OWASP Cheat Sheet Series][8])

検出のヒント:

* `window.location`、`location.href`、`location.assign`、`location.replace` を検索します。
* よく使われるリダイレクト用パラメーター `next`、`returnTo`、`redirect`、`url`、`continue` を検索します。
* `javascript:` のリテラルの使用を検索します。([MDN Web Docs][4])

修正:

* `new URL(value, location.origin)` で解析・検証し、次の条件を適用します。

  * `url.protocol` が `{ "https:" }` に含まれること（`http:` を含めるのは、明示的な開発専用コードパスに限ります）。
  * 内部リダイレクトの場合は `url.origin` が `location.origin` と一致すること、外部リダイレクトの場合は厳格な許可リストに含まれること。
  * 必要に応じて、特定のパスプレフィックスのみを許可すること。([MDN Web Docs][4])
* 検証に失敗した場合は、安全な既定の場所（ホーム／ダッシュボード）へ移動します。

緩和策:

* 厳格な CSP と Trusted Types の強制を導入して DOM XSS のシンクによる影響を軽減します。ただし、Trusted Types だけであらゆる安全でないナビゲーションを防げるわけではない点に注意してください。([W3C][15])

誤検知に関する注意:

重要: これは誤検知が多く発生する可能性があります。URL が攻撃者に完全に制御されているかどうか、追加の分析を行ってください。完全に制御されていない場合、せいぜい情報提供レベルです。

* アプリによっては、外部リダイレクト（SSO、決済フロー）を意図的にサポートしています。その場合は、許可リストで制限し、文書化しなければなりません。

---

### JS-URL-002: DOM の URL コンテキスト（`href`、`src` など）に挿入する前に URL をサニタイズする

重大度: 低（攻撃者が URL を完全に制御できると証明できる場合は高）

重要: これは誤検知が多く発生する可能性があります。URL が攻撃者に完全に制御されているかどうか、追加の分析を行ってください。完全に制御されていない場合、せいぜい情報提供レベルです。

必須事項:

* URL を持つ DOM 属性／プロパティの設定は、特に次のものをセキュリティ上重要な操作として扱わなければなりません。

  * `a.href`、`img.src`、`script.src`、`iframe.src`、`form.action`、`link.href`。
* 値が攻撃者の影響を受ける可能性がある場合、スクリプトを含むスキーム（`javascript:` およびその他のアクティブなスキーム）を防止しなければなりません。([MDN Web Docs][4])
* 文字列連結よりも、解析・検証後にプロパティを設定する方法（例: `a.href = url.toString()`）を優先すべきです。

安全でないパターン:

* `link.href = getParam("u")`
* 検証せずに `el.setAttribute("href", userInput)` を使用する
* 信頼できない要素を連結して URL を構築する

検出のヒント:

* `.href =`、`.src =`、`.action =`、`setAttribute("href"`、`setAttribute("src"` を検索します。
* URL 内での `javascript:` / `data:` の使用を検索します。([MDN Web Docs][4])

重要: これは誤検知が多く発生する可能性があります。URL が攻撃者に完全に制御されているかどうか、追加の分析を行ってください。完全に制御されていない場合、せいぜい情報提供レベルです。

修正:

* `new URL(...)` を使って検証します。

  * プロトコルの許可リスト
  * ユーザー指定値を `<script src>` に渡すことは避けます（コード実行として扱います）。([OWASP Cheat Sheet Series][8])

---

### JS-CSP-001: CSP を使用する。meta による配信も許可する

重大度: 中～高（脅威モデルによる。信頼できないコンテンツを扱う場合は高）

注: CSP では `script-src` の設定が最も重要です。その他のディレクティブは重要度が低く、開発を容易にするため、一般に省略できます。

必須事項:

* XSS に対する多層防御の主要な手段として、CSP を導入すべきです。([MDN Web Docs][10])
* ヘッダーを利用できない場合、`<meta http-equiv="Content-Security-Policy" ...>` による CSP の提供が認められます。([MDN Web Docs][1])
* CSP を meta で配信する場合、次の要件を満たさなければなりません。

  * 適用対象とするスクリプト／リソースより前に配置すること。
  * meta ポリシーでサポートされていないディレクティブ（`report-uri`、`frame-ancestors`、`sandbox`）に依存しないこと。([W3C][3])
* 明示的に必要とされ、レビュー済みでない限り、CSP の問題に対する「手っ取り早い修正」として `unsafe-inline` を追加してはなりません（CSP の目的の多くが損なわれます）。([MDN Web Docs][10])
* 明示的に必要とされ、レビュー済みでない限り、`unsafe-eval` を追加してはなりません（悪用されやすい eval 系 API が許可されます）。([MDN Web Docs][10])

安全でないパターン:

* 信頼できないコンテンツを描画するアプリで、CSP がどこにも存在しない（リポジトリの HTML またはサーバー／エッジのいずれにもない）。
* 強い根拠なく、CSP に `script-src 'unsafe-inline'` および／または `script-src 'unsafe-eval'` が含まれている。([MDN Web Docs][10])
* meta で配信する CSP に `frame-ancestors` が含まれている（meta では無視されます）。([W3C][3])

検出のヒント:

* HTML 内の `<meta http-equiv="Content-Security-Policy"` を検索します。
* サーバー／エッジの設定で `Content-Security-Policy` ヘッダーを検索します。
* CSP が meta にしかない場合、適用対象とする `<script>` タグより前に記述されているか確認します。([W3C][3])

修正:

* サーバー／エッジで CSP をヘッダー配信する方法を優先します。
* meta に制約される場合は、強固な許可リスト型 CSP を維持し、制約事項を文書化します。クリックジャッキング対策（例: `frame-ancestors`）は meta ではなく、サーバー／エッジで実装します。([W3C][3])

---

### JS-CSP-002: 厳格な CSP（nonce／hash）を優先し、コード内のインライン／eval パターンを避ける

重大度: 中

注: CSP では `script-src` の設定が最も重要です。その他のディレクティブは重要度が低く、開発を容易にするため、一般に省略できます。

必須事項:

* 厳格な CSP のもとで動作するよう、フロントエンドコードを設計すべきです。

  * インラインスクリプトとインラインイベントハンドラーを避ける。
  * eval 系 API を避ける（JS-XSS-003 を参照）。
  * 必要なスクリプトは nonce または hash で許可する。([MDN Web Docs][10])

安全でないパターン:

* 大量のインラインスクリプトブロックや、インラインの `onclick="..."` ハンドラー。
* `unsafe-eval` を必要とするライブラリ。

検出のヒント:

* インラインコードを含む `<script>` ブロック、`onclick="`、`onload="` などを検索します。
* `unsafe-inline` または `unsafe-eval` を含む CSP ディレクティブを検索します。([MDN Web Docs][10])

修正:

* インラインスクリプトを外部 JS ファイル（同一オリジン）に移します。
* やむを得ないインラインブロックには nonce／hash を使用します。([MDN Web Docs][10])

---

### JS-TT-001: DOM XSS の攻撃対象領域を減らすため Trusted Types を使用する（対応している場合）

重大度: 低

必須事項:

* 多くの DOM XSS シンクで生の文字列が拒否されるよう、CSP の `require-trusted-types-for 'script'` による Trusted Types の強制を検討すべきです。([MDN Web Docs][11])
* Trusted Types を使う場合、作成可能なポリシーを制限するために CSP の `trusted-types` ディレクティブも使用すべきです（ポリシーの乱立を抑え、監査性を高めます）。([MDN Web Docs][16])
* Trusted Types のポリシーコードは小さく保ち、十分にレビューし、シンク向けの信頼済み値を生成する唯一の経路として使用しなければなりません。([W3C][15])

安全でないパターン:

* 「Trusted Types を有効化」しているが、ポリシーが入力をそのまま返す（サニタイズ／検証がない）。
* コードベース全体に、制限されていない場当たり的なポリシーが多数作成されている。
* Trusted Types だけで、あらゆる安全でないナビゲーションや XSS のすべての種類を防げるという誤解（DOM インジェクションシンクを対象とするものであり、汎用サンドボックスではありません）。([W3C][15])

検出のヒント:

* CSP ディレクティブ `require-trusted-types-for` と `trusted-types` を検索します。
* コード内の `trustedTypes.createPolicy(` を検索し、ポリシーの実装を確認します。([MDN Web Docs][11])

修正:

* 十分にレビューした少数のポリシーを追加します（例: サニタイズを行う `createHTML`）。
* `trusted-types <policyName...>` で許可するポリシーを制限します。
* 適切な箇所では、シンクが `TrustedHTML` / `TrustedScriptURL` を要求するよう移行します。([MDN Web Docs][11])

---

### JS-MSG-001: `postMessage` では厳格なオリジン検証と明示的な targetOrigin を使用する

重大度: 中（`postMessage` 経由で危険な動作を引き起こせる場合は高）

必須事項:

* メッセージ送信時は、リダイレクト後やウィンドウのオリジン変更後に予期しないオリジンへデータが送信されないよう、明示的な `targetOrigin` を設定しなければなりません（`*` は不可）。([MDN Web Docs][5])
* メッセージ受信時は、次の要件を満たさなければなりません。

  * `event.origin` を、想定されるオリジンの許可リストと完全一致で検証します（部分一致は不可）。([OWASP Cheat Sheet Series][6])
  * 該当する場合は、`event.source`（想定されるウィンドウ参照）も検証することを検討します。([MDN Web Docs][5])
  * `event.data` の構造（スキーマ／形状）を検証し、純粋なデータとして扱います（コードとして評価したり、`innerHTML` で DOM に挿入したりしてはなりません）。([OWASP Cheat Sheet Series][6])

安全でないパターン:

* `otherWindow.postMessage(payload, "*")`
* `origin` の確認なしに `window.addEventListener("message", (e) => { doSomething(e.data) })` を使用する
* `if (e.origin.includes("trusted.com"))`（部分一致による確認）
* `el.innerHTML = e.data` ([OWASP Cheat Sheet Series][6])

検出のヒント:

* `postMessage(`、`addEventListener("message"`、`onmessage =` を検索します。
* すべてのハンドラーで `event.origin` が明示的に許可リストと照合されているか監査します。([OWASP Cheat Sheet Series][6])

修正:

* 許可リストを定義します。

  * `const ALLOWED = new Set(["https://app.example.com", "https://accounts.example.com"]);`
  注: 開発を容易にするため、現在のページのオリジン `window.location.origin` を安全な既定のオリジンとして使用できます。
* 受信時:

  * `if (!ALLOWED.has(event.origin)) return;`
  * 厳格なスキーマで `event.data` を検証し、不明なフィールドや余分なフィールドは拒否します。
* 送信時:

  * `targetOrigin` には、期待されるオリジン文字列を正確に指定する。([OWASP Cheat Sheet Series][6])

緩和策:

* 厳格な CSP と組み合わせ、メッセージ処理経路では DOM シンクを避ける。([MDN Web Docs][10])

---

### JS-STORAGE-001: Web Storage は秘密情報を安全に保管できる場所ではない（攻撃者に操作される可能性がある）

深刻度: 低

必須事項:

* 漏えいが問題になる機密情報やセッション識別子を `localStorage`（または `sessionStorage`）に保存してはならない。XSS が 1 件あるだけで、ストレージ内のすべての情報が持ち出される可能性がある。([OWASP Cheat Sheet Series][6])
* ストレージから読み取った値は、信頼できない入力として扱わなければならない（攻撃者は XSS を介して悪意ある値をストレージに読み込ませることができる）。([OWASP Cheat Sheet Series][6])
* セッション識別子には、サーバーが設定する `HttpOnly` Cookie を優先すべきである（JS から `HttpOnly` を設定できないため、JS からアクセス可能なストレージへのセッション ID の保存は避ける）。([OWASP Cheat Sheet Series][6])
* ストレージの分離に依存する無関係な複数のアプリを同じオリジンでホストすることは避けるべきである（ストレージはオリジン単位で共有される）。([OWASP Cheat Sheet Series][6])

安全でないパターン:

* `localStorage.setItem("access_token", token)`
* `localStorage.setItem("session", sessionId)`
* 「同一オリジンだから信頼できる」と考えて `localStorage` を信用する。

検出のヒント:

* `localStorage.getItem`、`localStorage.setItem`、`sessionStorage.*` を検索する。
* `token`、`jwt`、`session`、`auth`、`refresh` という名前のストレージキーに注意する。([OWASP Cheat Sheet Series][6])

修正:

* サーバー管理のセッション、または安全に配信・ローテーションされる短命トークンを使用し、XSS 対策（CSP/Trusted Types）を慎重に講じて、JS に公開する情報を最小限にする。
* 機密性のない状態のためにストレージを使う必要がある場合は、認証関連の情報を保存せず、使用前に検証・エスケープする。

---

### JS-SUPPLY-001: サードパーティ JavaScript はサプライチェーン上の大きなリスクである。使用を最小限に抑え、管理する

深刻度: 低

必須事項:

* サードパーティ JS は権限の面でファーストパーティ JS と同等として扱わなければならない（自サイトのオリジンで任意のコードを実行し、DOM データにアクセスできる）。([OWASP Cheat Sheet Series][7])
* サードパーティスクリプトは最小限にし、次の方法を優先すべきである:

  * 自サイトでホストする／スクリプトをミラーする。
  * 厳格な CSP の許可リストを使う。
  * CDN から配信するスクリプトには SRI を適用する。
  * 想定外の変更がないか継続的に監視する。([OWASP Cheat Sheet Series][7])

安全でないパターン:

* レビューせずに、多数のベンダーから任意のリモートスクリプトを読み込む。
* 完全性を確認する仕組みがないまま、スクリプトを動的に挿入できるタグマネージャーを使う。
* CSP で広範なワイルドカード（例: `script-src *`）からのスクリプトを許可する。([MDN Web Docs][10])

検出のヒント:

* HTML 内の `<script src="https://...">` と `tag manager` のスニペットを検索する。
* CSP の `script-src` ソースにワイルドカードや広すぎるドメインがないか検索する。
* 動的なスクリプト挿入を検索する: `document.createElement("script")`、`script.src = ...`、`appendChild(script)`。([OWASP Cheat Sheet Series][8])

修正:

* 不要なサードパーティタグを削除する。
* 可能な場合はスクリプトを自サイトでホストするか、ミラーする。
* CSP の `script-src` を、信頼するソースの最小限の集合に制限する。
* CDN スクリプト／スタイルに SRI を追加する。([OWASP Cheat Sheet Series][7])

---

### JS-SRI-001: サードパーティのスクリプト／スタイルには Subresource Integrity (SRI) を使う

深刻度: 低

必須事項:

* ブラウザーが、期待される暗号学的ハッシュと一致する場合にのみサードパーティリソースを読み込むよう、SRI を使うべきである。([MDN Web Docs][12])
* 元のリソースが変更された場合は、SRI ハッシュを更新しなければならない（バージョンを固定し、「latest」URL は避ける）。

安全でないパターン:

* `integrity` のない `<script src="https://cdn.example.com/lib.js"></script>`。
* `latest` を指定したり、バージョンを固定せずにサードパーティリソースを読み込んだりする。

検出のヒント:

* `integrity=` のない `<script src="https://` と `<link rel="stylesheet" href="https://` を検索する。
* `integrity` が存在し、強度の高いハッシュ（通常は sha256/384/512）が使われているか確認する。([MDN Web Docs][12])

修正:

* `integrity="sha384-..."`（または適切な値）を追加し、必要に応じて適切な CORS モードを設定する。
* 重要なライブラリは、自サイトでのホスティングを優先する。

---

### FS-DOMC-001: DOM clobbering を防ぐ（`window`/`document` の名前付きプロパティに依存しない）

深刻度: 中〜高（スクリプトの読み込みや `javascript:` によるナビゲーションを可能にする場合は致命的になりうる）

必須事項:

* 同じ `id`/`name` を持つ HTML 要素の挿入によって上書きされうる、暗黙的なグローバル変数や `window.someName` / `document.someName` の参照に依存してはならない。([OWASP Cheat Sheet Series][8])
* `let x = window.redirectTo || "/safe"; location.assign(x);` のようなパターンは避けなければならない。`redirectTo` が、攻撃者の制御する `href`（`javascript:` を含む）を持つ `<a>` 要素に上書きされる可能性があるためである。([OWASP Cheat Sheet Series][8])
* 名前付きプロパティへのアクセスではなく、明示的な変数宣言、ローカルスコープ、明示的な DOM 検索（`getElementById`）を使うべきである。([OWASP Cheat Sheet Series][8])
* アプリがユーザー制御のマークアップを挿入する場合（サニタイズ済みであっても）、サニタイズ方法で `id`/`name` の衝突が考慮されるようにすべきである。([OWASP Cheat Sheet Series][8])

安全でないパターン:

* セキュリティ上重要な URL に使われる `const cfg = window.config || {};`。
* `const redirect = window.redirectTo || "/"; location.assign(redirect);` ([OWASP Cheat Sheet Series][8])
* 厳密な検証をせず、`window.*` の設定値からスクリプトを読み込む。

検出のヒント:

* `window.` と `document.` が設定値の格納場所として使われている箇所を検索する（特に `||` によるフォールバックパターン）。
* `location.assign/replace` に、`window`/`document` のプロパティ由来の変数が渡されている箇所を検索する。
* `.src` にローカル変数以外の値が設定される動的スクリプト生成（`createElement('script')`）を検索する。([OWASP Cheat Sheet Series][8])

修正:

* 設定値は（`window`/`document` ではなく）モジュールスコープの定数に格納し、明示的に渡す。
* URL のような設定値は、プロトコル／オリジンの許可リストで検証する（FEJS-URL-001 を参照）。([OWASP Cheat Sheet Series][8])
* サニタイズ、CSP、および（限定的なケースでは）重要なオブジェクトの凍結による強化を検討する。ただし、これらは多層防御として扱い、安全なコーディングパターンの代わりにしてはならない。([OWASP Cheat Sheet Series][8])

---

## 5) 実践的なスキャンのヒューリスティクス（「探し出す」方法）

積極的にスキャンする際は、次の検出力の高いパターンを使う:

* DOM XSS シンク:

  * `.innerHTML`、`.outerHTML`、`insertAdjacentHTML(`
  * `document.write(`、`document.writeln(` ([OWASP Cheat Sheet Series][2])

* 危険なナビゲーション／URL シンク:

  * `window.location`、`location.href`、`location.assign`、`location.replace`
  * `javascript:` リテラル（および `data:text/html` のようなその他の疑わしいスキーム）([MDN Web Docs][4])

* 文字列からのコード実行:

  * `eval(`、`new Function`、`setTimeout("`、`setInterval("` ([MDN Web Docs][10])

* イベントハンドラーへの文字列注入:

  * 文字列を使った `.setAttribute("on`、`.onclick =`、`.onload =` ([OWASP Cheat Sheet Series][2])

* `postMessage`:

  * `targetOrigin` に `"*"` を指定した `postMessage(`
  * `event.origin` の厳格な許可リストチェックを行わない `addEventListener("message"` ([MDN Web Docs][5])

* ストレージ:

  * `localStorage.setItem(` / `getItem(`、`sessionStorage.*`
  * `token`、`jwt`、`session`、`auth`、`refresh` を含むキー ([OWASP Cheat Sheet Series][6])

* CSP と関連項目:

  * `Content-Security-Policy` ヘッダーの設定（サーバー／エッジ）
  * `<meta http-equiv="Content-Security-Policy" ...>`
  * `unsafe-inline` または `unsafe-eval` を含む CSP
  * `require-trusted-types-for` / `trusted-types` ディレクティブ ([MDN Web Docs][1])

* サードパーティスクリプト:

  * `integrity=` のない `<script src="https://...">`
  * タグマネージャーのスニペットと、動的にスクリプトを挿入するコード経路 ([MDN Web Docs][12])


* DOM clobbering のガジェット:

  * `window.<name> || ...` および `document.<name> || ...` のパターン
  * 設定値の取得元として `window`/`document` のプロパティをセキュリティ上重要な用途に使うこと ([OWASP Cheat Sheet Series][8])

必ず次の点を確認する:

* データの出所（信頼できないものか、信頼できるものか）。
* シンクの種類（HTML 解析、ナビゲーション、コード実行、メッセージ処理、ストレージ）。
* 保護対策の有無（CSP、Trusted Types、サニタイザー、厳格な許可リスト、スキーマ検証）。

---

## 6) 参考資料（2026-01-27 にアクセス）

主要な標準仕様／プラットフォーム文書:

* W3C Content Security Policy Level 2（HTML の `<meta>` による配信制限、meta CSP で未サポートのディレクティブ）: `https://www.w3.org/TR/CSP2/` ([W3C][3])
* MDN: CSP ガイド（厳格な CSP、nonce/hash、`unsafe-inline`/`unsafe-eval`、eval のブロック）: `https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CSP` ([MDN Web Docs][10])
* MDN: `<meta http-equiv>`（meta による CSP と、meta ベースのセキュリティヘッダーに関する警告）: `https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/meta/http-equiv` ([MDN Web Docs][1])
* MDN: `frame-ancestors`（および `<meta>` ではサポートされていない旨の注記）: `https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/frame-ancestors` ([MDN Web Docs][18])

DOM XSS と危険なシンク:

* OWASP: DOM Based XSS Prevention Cheat Sheet（危険なシンクと、`textContent` のような安全なパターン）: `https://cheatsheetseries.owasp.org/cheatsheets/DOM_based_XSS_Prevention_Cheat_Sheet.html` ([OWASP Cheat Sheet Series][2])
* MDN: `innerHTML`（セキュリティ上の考慮事項）: `https://developer.mozilla.org/en-US/docs/Web/API/Element/innerHTML` ([MDN Web Docs][19])
* MDN: `insertAdjacentHTML`（セキュリティ上の考慮事項）: `https://developer.mozilla.org/en-US/docs/Web/API/Element/insertAdjacentHTML` ([MDN Web Docs][20])
* MDN: `document.write()` / `document.writeln()`（セキュリティ上の考慮事項）: `https://developer.mozilla.org/en-US/docs/Web/API/Document/write` および `https://developer.mozilla.org/en-US/docs/Web/API/Document/writeln` ([MDN Web Docs][13])

URL スキームの危険性:

* MDN: `javascript:` URL（ナビゲーション時の実行、非推奨、`window.location` への参照）: `https://developer.mozilla.org/en-US/docs/Web/URI/Reference/Schemes/javascript` ([MDN Web Docs][4])

Trusted Types:

* W3C: Trusted Types 仕様（DOM XSS シンクには `Element.innerHTML` と `Location.href` の setter が含まれること、目的と制限）: `https://www.w3.org/TR/trusted-types/` ([W3C][15])
* MDN: `require-trusted-types-for` ディレクティブ: `https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/require-trusted-types-for` ([MDN Web Docs][11])
* MDN: `trusted-types` ディレクティブ: `https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/trusted-types` ([MDN Web Docs][16])

ウィンドウ間のメッセージング:

* MDN: `window.postMessage`（セキュリティガイダンス: `targetOrigin` を指定し、オリジンを検証する）: `https://developer.mozilla.org/en-US/docs/Web/API/Window/postMessage` ([MDN Web Docs][5])
* OWASP: HTML5 Security Cheat Sheet（Web Messaging のガイダンス: オリジンの明示、厳格なチェック、`innerHTML` を使わない）: `https://cheatsheetseries.owasp.org/cheatsheets/HTML5_Security_Cheat_Sheet.html` ([OWASP Cheat Sheet Series][6])

サードパーティスクリプトと完全性:

* OWASP: Third Party JavaScript Management Cheat Sheet（SRI／ミラーリングを含むリスクと緩和策）: `https://cheatsheetseries.owasp.org/cheatsheets/Third_Party_Javascript_Management_Cheat_Sheet.html` ([OWASP Cheat Sheet Series][7])
* MDN: Subresource Integrity の概要: `https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Subresource_Integrity` ([MDN Web Docs][12])
* W3C: Subresource Integrity 仕様: `https://www.w3.org/TR/sri-2/` ([W3C][21])

DOM clobbering:

* OWASP: DOM Clobbering Prevention Cheat Sheet（名前付きプロパティへのアクセスのリスク、`location.assign` と `javascript:` を使った攻撃例）: `https://cheatsheetseries.owasp.org/cheatsheets/DOM_Clobbering_Prevention_Cheat_Sheet.html` ([OWASP Cheat Sheet Series][8])

[1]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/meta/http-equiv "https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/meta/http-equiv"
[2]: https://cheatsheetseries.owasp.org/cheatsheets/DOM_based_XSS_Prevention_Cheat_Sheet.html "https://cheatsheetseries.owasp.org/cheatsheets/DOM_based_XSS_Prevention_Cheat_Sheet.html"
[3]: https://www.w3.org/TR/CSP2/ "Content Security Policy Level 2"
[4]: https://developer.mozilla.org/en-US/docs/Web/URI/Reference/Schemes/javascript "javascript: URLs - URIs | MDN"[5]: https://developer.mozilla.org/en-US/docs/Web/API/Window/postMessage "https://developer.mozilla.org/en-US/docs/Web/API/Window/postMessage"
[6]: https://cheatsheetseries.owasp.org/cheatsheets/HTML5_Security_Cheat_Sheet.html "https://cheatsheetseries.owasp.org/cheatsheets/HTML5_Security_Cheat_Sheet.html"
[7]: https://cheatsheetseries.owasp.org/cheatsheets/Third_Party_Javascript_Management_Cheat_Sheet.html "https://cheatsheetseries.owasp.org/cheatsheets/Third_Party_Javascript_Management_Cheat_Sheet.html"
[8]: https://cheatsheetseries.owasp.org/cheatsheets/DOM_Clobbering_Prevention_Cheat_Sheet.html "https://cheatsheetseries.owasp.org/cheatsheets/DOM_Clobbering_Prevention_Cheat_Sheet.html"
[9]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Attributes/rel/noopener "https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Attributes/rel/noopener"
[10]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CSP "https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CSP"
[11]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/require-trusted-types-for "https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/require-trusted-types-for"
[12]: https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Subresource_Integrity "https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Subresource_Integrity"
[13]: https://developer.mozilla.org/en-US/docs/Web/API/Document/write "https://developer.mozilla.org/en-US/docs/Web/API/Document/write"
[14]: https://developer.mozilla.org/en-US/docs/Web/API/Document/writeln "https://developer.mozilla.org/en-US/docs/Web/API/Document/writeln"
[15]: https://www.w3.org/TR/trusted-types/ "https://www.w3.org/TR/trusted-types/"
[16]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/trusted-types "https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/trusted-types"
[18]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/frame-ancestors "https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/frame-ancestors"
[19]: https://developer.mozilla.org/en-US/docs/Web/API/Element/innerHTML "https://developer.mozilla.org/en-US/docs/Web/API/Element/innerHTML"
[20]: https://developer.mozilla.org/en-US/docs/Web/API/Element/insertAdjacentHTML "https://developer.mozilla.org/en-US/docs/Web/API/Element/insertAdjacentHTML"
[21]: https://www.w3.org/TR/sri-2/ "https://www.w3.org/TR/sri-2/"