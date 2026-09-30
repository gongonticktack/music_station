# React（JavaScript/TypeScript）Web セキュリティ仕様（React 19.x、TypeScript 5.x）

このドキュメントは、次の用途を支援する**セキュリティ仕様**として作成されています。

1. 新しい React コードの**デフォルトで安全なコード生成**。
2. 既存の React コードに対する**セキュリティレビュー／脆弱性の探索**（作業中に問題に気づく受動的な確認、およびリポジトリをスキャンして問題点を報告する能動的な確認）。

これは意図的に、**規範的な要件**（「MUST/SHOULD/MAY」）と**監査ルール**（不適切なパターンの見分け方、検出方法、修正／緩和方法）をまとめたものです。

---

## 0) 安全性、境界、悪用防止の制約（必ず遵守）

* シークレット（API キー、OAuth クライアントシークレット、秘密鍵、セッション Cookie、JWT、署名鍵）を要求、出力、ログ記録、またはコミットしてはなりません。

  * フロントエンドに関する注意：ブラウザーに配信されるものはすべて、エンドユーザーや攻撃者が確認できます（ソース表示、開発者ツール、プロキシ）。クライアントコードや「バンドル内の環境変数」をシークレットとして扱ってはなりません。([create-react-app.dev][1])
* 保護機能を無効化してセキュリティ上の問題を「修正」してはなりません（例：「動作させる」ために CSP を無効にする、文書化され制約された計画なしに `unsafe-inline`/`unsafe-eval` を追加する、Cookie を使用しているときに CSRF 保護を無効にする、CORS の許可範囲を広げる、サニタイズを省略する、または出荷される「一時的な」回避策を加える）。([OWASP Cheat Sheet Series][2])
* 監査では**証拠に基づく所見**を提示しなければなりません。主張の根拠となるファイルパス、コードスニペット、設定値を示してください。
* 不確実性を正直に扱わなければなりません。インフラ（CDN/WAF/リバースプロキシ）に保護機能が存在する可能性がある場合は、「アプリのコードからは確認できない。実行時のヘッダー／エッジ設定で確認すること」と報告してください。
* 信頼境界を越えるデータ（URL、ストレージ、ネットワーク、postMessage、サードパーティースクリプト）は、そうでないと証明されない限り、攻撃者の影響を受ける可能性があるものとして扱わなければなりません（§2.1 参照）。

---

## 1) 運用モード

### 1.1 生成モード（デフォルト）

新しい React コードの作成または既存コードの変更を依頼された場合：

* この仕様のすべての**MUST**要件に従わなければなりません。
* ユーザーが明示的に別の指示をしない限り、すべての**SHOULD**要件に従うべきです。
* 独自のセキュリティコードより、安全なデフォルト設定の API や実績のあるライブラリを優先しなければなりません。
* 新たなリスクの高いシンク（生 HTML の挿入、`innerHTML` などの直接 DOM シンク、動的コード実行、信頼できないリダイレクト／ナビゲーション、サードパーティースクリプトの挿入、安全でないトークン保存など）を導入してはなりません。([MDN Web Docs][3])

### 1.2 受動的レビュー・モード（編集中は常に有効）

React リポジトリ内のどこで作業していても（ユーザーがセキュリティスキャンを依頼していない場合も含む）：

* 変更対象およびその周辺のコードにおける、この仕様への違反に気づかなければなりません。
* 問題があれば、簡潔な説明と安全な修正方法を添えて、気づいた時点で伝えるべきです。

### 1.3 能動的監査モード（明示的なスキャン依頼時）

ユーザーから「スキャン」「監査」「脆弱性の探索」を依頼された場合：

* この仕様への違反を見つけるため、コードベースを体系的に検索しなければなりません。
* §2.3 に示す構造化形式で所見を出力しなければなりません。

推奨される監査順序：

1. アプリのエントリーポイント、ビルドツール（Vite/Webpack/CRA/Next）、デプロイ設定、CDN／静的ホスティング設定。
2. シークレットと設定の露出（環境変数、実行時設定の注入、ソースマップ）。
3. 信頼できないデータのレンダリング（XSS／DOM XSS）、特に `dangerouslySetInnerHTML`、Markdown／HTML レンダラー、URL 属性。
4. 直接的な DOM 操作と危険な JavaScript 実行（`innerHTML`、`eval`、`new Function`、`document.write` など）。
5. 認証とセッションのパターン（トークン保存、Cookie、CSRF との相互作用、OAuth フロー）。
6. ネットワーク層（axios/fetch ラッパー、動的なベース URL、認証情報付きリクエスト、データ流出のリスク）。
7. ナビゲーションとリダイレクト処理（オープンリダイレクト、`window.location`、`target=_blank`、`window.open`）。
8. サードパーティーのスクリプト／タグ／分析ツールと整合性制御（CSP、SRI）。
9. サービスワーカー／PWA の動作（HTTPS、キャッシュ規則、更新戦略）。
10. セキュリティヘッダーの状態（CSP、クリックジャッキング対策、nosniff、リファラーポリシー）。アプリ側またはエッジ側で確認します。([OWASP Cheat Sheet Series][2])

---

## 2) 定義とレビューの指針

### 2.1 信頼できない入力（攻撃者が制御できるものとして扱う。ただし、そうでないと証明された場合を除く）

例：

* URL 由来のデータ：`window.location`、クエリパラメーター、ハッシュフラグメント、ルートパラメーター。
* ブラウザーストレージ由来のデータ：`localStorage`、`sessionStorage`、`IndexedDB`（アプリが以前に書き込んだデータも含みます。XSS や拡張機能によって改ざんされる可能性があるためです）。([OWASP Cheat Sheet Series][4])
* ウィンドウ間メッセージ由来のデータ：`window.postMessage` のペイロード。([OWASP Cheat Sheet Series][4])
* リモート API、クライアントに中継された Webhook、GraphQL のレスポンス、CMS コンテンツ、機能フラグサービス由来のデータ。
* UI に表示される永続化済みユーザーコンテンツ（プロフィール、コメント、リッチテキスト、Markdown）。
* サードパーティースクリプトやタグマネージャーが生成するデータ（厳格に管理されていると確認できない限り、信頼できないものとして扱う）。([OWASP Cheat Sheet Series][5])

### 2.2 状態変更リクエスト（フロントエンドの観点）

データの作成／更新／削除、認証／セッション状態の変更、副作用（購入、メール送信、Webhook）の実行、または特権操作の開始が可能なリクエストは、状態変更リクエストです。

フロントエンド固有の注意：

* 状態変更は多くの場合、`fetch/axios` 呼び出しまたはフォーム送信によって発生します。Cookie ベースの認証を使用している場合、これらの呼び出しは CSRF の対象となる可能性があります（§4 REACT-CSRF-001）。([OWASP Cheat Sheet Series][6])

### 2.3 必須の監査所見フォーマット

見つかった問題ごとに、次を出力してください。

* ルール ID：
* 重大度：Critical / High / Medium / Low
* 場所：ファイルパス + コンポーネント／関数 + 行番号
* 証拠：該当するコード／設定の正確なスニペット
* 影響：何が起きる可能性があるか、誰が悪用できるか
* 修正：安全な変更（差分は最小限にする）
* 緩和策：即時の修正が難しい場合の多層防御
* 誤検知に関する注記：不確かな場合に確認すべきこと

---

## 3) セキュアなベースライン：本番環境の最小構成（本番環境では必須）

これは、React フロントエンドでよくある設定ミスを防ぐための、最小限の「本番環境ベースライン」です。

### 3.1 本番ビルドと設定の衛生管理（必須）

* 本番ビルドを配信しなければなりません（最小化済みで、開発専用のオーバーレイ／ツールがなく、適切なモードフラグが設定されていること）。
* ビルド時の設定に、配信される JS/HTML/CSS にシークレットが埋め込まれないようにしなければなりません。ビルド時の「環境変数」はシークレットではなく、公開情報として扱ってください。([create-react-app.dev][1])
* ソースマップは機微な運用成果物として扱うべきです。

  * 公開しないか、意図した場所（例：認証の背後、またはエラー報告プロバイダー）に限って公開してください。コード構造や内部 URL が明らかになる可能性があるためです。

### 3.2 ブラウザーが強制する保護機能（SHOULD。ただし、最新のアプリではベースラインとして期待される）

* XSS に対する多層防御として CSP を導入し、React のビルドと互換性を保つべきです（厳密に必要で文書化されている場合を除き、`unsafe-inline` と `unsafe-eval` は避けてください）。([OWASP Cheat Sheet Series][2])
* CDN から読み込むサードパーティーのスクリプト／スタイルには Subresource Integrity（SRI）を使用するか、自前でホスティングするべきです。([MDN Web Docs][7])
* 明示的に埋め込みを必要とする製品要件がない限り、`frame-ancestors`（CSP）および／または `X-Frame-Options` によるクリックジャッキング対策を有効にするべきです。([MDN Web Docs][8])

### 3.3 高リスク機能のベースライン（使用する場合は必須）

* ユーザーが提供した HTML／Markdown／リッチテキストをレンダリングする場合：

  * 挿入前にサニタイズし、生の DOM シンクを避けなければなりません。([OWASP Cheat Sheet Series][9])
* サービスワーカー／PWA を使用する場合：

  * HTTPS 経由で配信し、安全なキャッシュ／更新戦略を実装しなければなりません（サービスワーカーは強力なリクエスト／レスポンスのプロキシです）。([MDN Web Docs][10])

---

## 4) ルール（生成および監査）

各ルールには、必要な実践方法、安全でないパターン、検出の手がかり、修正方法が記載されています。

### REACT-CONFIG-001: クライアントバンドルにシークレットを埋め込まない（環境変数は公開情報）

重大度：シークレットが露出した場合は Critical

必須事項：

* React コード、`public/` アセット、またはクライアントで使用するビルド時環境変数にシークレットを含めてはなりません。
* 実行時に React アプリから利用できる値は、攻撃者が取り出せるものとして扱わなければなりません。

安全でないパターン：

* シークレットにビルド時環境変数を使用する：

  * 秘密鍵や認証情報を含む `process.env.REACT_APP_*`。
  * シークレットを含む `import.meta.env.VITE_*`。
* JS/TS 内にハードコードされたシークレット、コミット済みの `.env`、または全ユーザーに配信される `public/config.json` 内のシークレット。

検出の手がかり：

* 次を検索します。

  * `REACT_APP_`、`VITE_`、`NEXT_PUBLIC_`、`process.env.`、`import.meta.env.`
  * `apiKey`、`secret`、`token`、`private`、`password`、`client_secret`
* 実行時設定 JSON がないか、`public/` を調べます。

修正：

* シークレットをサーバー側（API、BFF、サーバーレス関数）に移します。
* ブラウザーからサードパーティー API を呼び出す必要がある場合は、バックエンドを使って有効期間が短く、スコープが限定されたトークンを発行します。

注記：

* CRA はシークレットを保存しないよう明示的に警告しており、環境変数はビルドに埋め込まれ、ファイルを調べる人なら誰でも確認できると説明しています。([create-react-app.dev][1])
* Vite は、クライアントコードに公開された変数はクライアントバンドルに含まれ、機微な情報を含めるべきではないと明示しています。([vitejs][11])

---

### REACT-XSS-001: 信頼できないコンテンツに `dangerouslySetInnerHTML` を使用しない（サニタイズするか、使用を避ける）

重大度：攻撃者が制御する HTML がそこに到達すると証明できる場合に限り High

必須事項：

* 絶対に必要な場合を除き、`dangerouslySetInnerHTML` を避けなければなりません。
* 使用が避けられない場合：

  * 実績のあるサニタイザー（例：DOMPurify）と許可リストを基本とする設定を使って、信頼できない HTML をサニタイズしなければなりません。
  * サニタイズ処理を一元化し、厳格にレビューしなければなりません。
  * CSP を追加し、Trusted Types の導入を検討するべきです（REACT-TT-001 参照）。

安全でないパターン：

* `userHtml` が API／URL／ストレージ由来の `<div dangerouslySetInnerHTML={{ __html: userHtml }} />`。
* 正規表現、その場しのぎの除去処理、不完全な許可リストによる「サニタイズ」。

検出の手がかり：

* Grep：`dangerouslySetInnerHTML`、`__html:`
* HTML 文字列の出所（API/CMS/URL/localStorage）を追跡します。

修正：

* 安全なレンダリングに置き換えます。

  * HTML 文字列ではなく、構造化データを React 要素／コンポーネントとしてレンダリングします。
  * リッチテキストが必要な場合は、DOMPurify（または同等のもの）でサニタイズしてから、サニタイズ済みの出力をレンダリングします。
* CSP を追加し、可能な限り危険なシンクを削除します。

注記：

* React は、`dangerouslySetInnerHTML` が危険であり、誤用すると XSS を引き起こす可能性があると明示的に警告しています。([React][12])
* OWASP は、React の `dangerouslySetInnerHTML` をサニタイズせずに使うことを、フレームワークの「エスケープハッチ」に関するよくある落とし穴として明示的に挙げています。([OWASP Cheat Sheet Series][9])
* DOMPurify は、自身を HTML/SVG/MathML 用の XSS サニタイザーと説明しています。([GitHub][13])

---

### REACT-XSS-002: React のデフォルトのエスケープ動作に依存し、これを回避しない

重大度：回避された場合は High

必須事項：

* 信頼できない文字列は通常の JSX 補間（`{value}`）と React の props を使ってレンダリングしなければなりません。これらはデフォルトでエスケープされます。
* 信頼できないデータから HTML 文字列を組み立て、何らかの方法で DOM に挿入してはなりません。
* 「エスケープハッチ」はすべて高リスクとして扱い、レビューを必須とするべきです。

安全でないパターン：

* 信頼できないテキストを HTML に変換して挿入する：

  * `element.innerHTML = userValue`
  * `document.write(userValue)`
  * `insertAdjacentHTML(..., userValue)`

検出の手がかり：

* DOM シンクを検索します：`innerHTML`、`outerHTML`、`insertAdjacentHTML`、`document.write`、`DOMParser`、`createContextualFragment`。

修正：

* React（JSX）を通じてテキストコンテンツをレンダリングし、エスケープさせます。
* HTML がどうしても必要な場合は、サニタイズしたうえで REACT-XSS-001 と REACT-TT-001 を適用します。

注記：

* React のドキュメント（JSX）では、React DOM は埋め込まれた値をレンダリング前にエスケープし、インジェクション攻撃の防止に役立てると説明されています。([React][14])

---

### REACT-DOM-001: React コードで DOM XSS インジェクションシンクを避ける（安全な代替手段を使う）

重大度：High

必須事項：

* 厳格に制御されている場合を除き、React のレンダリング外であっても、直接的な DOM インジェクションシンクを避けなければなりません。
* DOM シンクが必要な場合：

  * 入力が信頼できる／検証済み／サニタイズ済みであることを保証しなければなりません。
  * Trusted Types（REACT-TT-001）を適用するべきです。

安全でないパターン：

* `someEl.innerHTML = untrusted`
* `document.write(untrusted)`* `new DOMParser().parseFromString(untrusted, 'text/html')` の後に挿入

検出の手がかり:

* Grep の検索対象: `innerHTML`, `outerHTML`, `document.write`, `DOMParser`, `Range().createContextualFragment`, `insertAdjacentHTML`

修正:

* 次を優先してください:

  * テキストの挿入には `textContent`。
  * 手動の DOM 操作ではなく、React のレンダリング。
  * HTML の解析が必要な場合は、信頼できるサニタイザー。

注記:

* Trusted Types のドキュメントでは、`Element.innerHTML` や `document.write()` のような HTML シンクはインジェクションシンクと定義されており、攻撃者が制御する入力を渡すとスクリプトを実行する可能性があります。([MDN Web Docs][3])
* OWASP の HTML5 ガイダンスでは、信頼できないデータを割り当てる際に `innerHTML` ではなく `textContent` を使うことを推奨しています。([OWASP Cheat Sheet Series][4])

---

### REACT-URL-001: `href`、`src`、ナビゲーション、リダイレクトに使う信頼できない URL を検証し、制限する

重大度: 高（攻撃者が制御できると証明できる場合に限る）

必須事項:

* 信頼できない入力に由来する URL はすべて危険なものとして扱わなければなりません。
* スキームと（該当する場合は）ホストを許可リストで制限しなければなりません:

  * 通常、アプリ内ナビゲーションでは `https:`（localhost／開発環境では `http:` も可）と相対 URL のみを許可します。
  * 専門的な検証と明確な用途がない限り、`javascript:` と危険な `data:` の使用を明示的にブロックしなければなりません。
* 絶対 URL より同一サイト内の相対パス（例: `/settings`）を優先すべきです。
* 「returnTo/next/redirect」パラメーターを検証しなければなりません（REACT-REDIRECT-001 を参照）。

安全でないパターン:

* `<img src={userProvidedUrl}>...`（トラッキング／データ流出に使われる可能性があり、スクリプト／iframe に使う場合も危険）
* `window.location = next`
* 検証せず、`next` がクエリパラメーターに由来する `navigate(next)`

検出の手がかり:

* 次を検索します:

  * `href={`, `src={`, `window.location`, `location.href`, `window.open`, `navigate(`, `redirectTo`, `returnTo`, `next=`
* 値が URL／クエリ／ストレージ／API に由来するかを追跡します。

修正:

* 共通の `safeUrl()` ユーティリティを実装します:

  * `new URL(value, base)` で解析する
  * スキームとホストの許可リストを適用する（または同一オリジンを強制する）
  * リダイレクトでは、相対パス（`/` で始まるもの）か、厳格な許可リストに含まれる絶対オリジンのみを許可する
* 検証に失敗した場合は安全な既定値にフォールバックします。

注記:

* OWASP は React の `dangerouslySetInnerHTML` によるリスクを明示し、また、React は専門的な検証なしに `javascript:` や `data:` の URL を安全に処理できないと述べています。([OWASP Cheat Sheet Series][9])

---

### REACT-MARKUP-001: Markdown／リッチテキストのレンダリングは安全に設定する

重大度: 中

必須事項:

* ユーザーや CMS に由来する場合、Markdown／リッチテキストは攻撃者が制御できるものと想定しなければなりません。
* サニタイズされていない限り、生の HTML をレンダリングしないようにしなければなりません。
* 次のような Markdown レンダラーを優先すべきです:

  * 既定で生の HTML を許可しない
  * または、生の HTML を許可しないよう設定できる
  * または、レンダリング前に HTML 出力をサニタイズする

安全でないパターン:

* 「生の HTML をそのまま通す」設定が有効な Markdown レンダリング（HTML を許可するオプション／プラグインなど）。
* ユーザー提供の SVG／MathML／HTML をサニタイズせずインラインでレンダリングする。

検出の手がかり:

* 一般的なライブラリと危険なオプションを検索します:

  * `marked`, `markdown-it`, `react-markdown`, `rehype-raw`, `sanitize: false`, `allowDangerousHtml` など。
* 「Markdown 出力」とともに使われている `dangerouslySetInnerHTML` を探します。

修正:

* 生の HTML をそのまま通す設定を無効にします。
* 実績のあるサニタイザー（例: DOMPurify）で出力をサニタイズしてからレンダリングします。

注記:

* OWASP の XSS ガイダンスでは、フレームワークの安全機構を回避する場合、出力エンコーディングや HTML のサニタイズが必要だと強調しています。([OWASP Cheat Sheet Series][9])

---

### REACT-TT-001: 可能な場合は Trusted Types（CSP と併用）で DOM XSS シンクを強化する

重大度: 低

必須事項:

* まず Trusted Types をレポート専用モードで有効にし、違反に対処した後で強制モードに切り替えることを検討すべきです。
* Trusted Types ポリシーを一元管理し、レビューが必要な高リスクコードとして扱うべきです。
* 信頼できない文字列を単に「そのまま通す」寛容なポリシーを作成してはなりません。

安全でないパターン:

* HTML シンクに対し、サニタイズせず生の文字列を返す Trusted Types ポリシー。
* コードベース内にポリシーが散在している（監査が困難）。

検出の手がかり:

* 次を検索します:

  * `trustedTypes.createPolicy`
  * CSP ディレクティブ: `require-trusted-types-for`, `trusted-types`
* 残存する DOM シンクも検索します（REACT-DOM-001）。

修正:

* 範囲を厳密に限定した少数のポリシーを実装します:

  * HTML ポリシーではサニタイザー（DOMPurify など）を使用する。
  * スクリプト URL ポリシーでは厳格な許可リストを使用する。
* レポート専用モードで実行し、違反を修正してから強制します。

注記:

* MDN は Trusted Types について、インジェクションシンクに渡す前に入力が変換（通常はサニタイズ）されるようにする仕組みと説明し、HTML シンク（`innerHTML`、`document.write`）および JS URL シンク（`script.src`）を挙げています。([MDN Web Docs][3])
* W3C の Trusted Types 仕様では、レビュー済みポリシーが作成した型付き値にシンクを限定することで、DOM XSS のリスクを低減するものと位置付けています。([W3C][15])

---

### REACT-CSP-001: 多層防御として CSP を導入し、維持する（特に信頼できないコンテンツをレンダリングする場合）

重大度: 中〜高

必須事項:

* 本番環境では CSP を導入すべきです。信頼できないコンテンツをレンダリングするアプリやサードパーティスクリプトを統合するアプリでは、必ず導入しなければなりません。
* 可能な限り `unsafe-inline` と `unsafe-eval` を避けるべきです。
* 必要に応じてインラインスクリプトに CSP nonce／hash を使用し、現実的なポリシーを維持すべきです。
* 適切な場合、CSP を使って SRI を必須化／促進すべきです。

安全でないパターン:

* アプリのシェル（SPA のエントリー HTML）に CSP がまったくない。
* 正当な理由なく `unsafe-inline`／`unsafe-eval` に広く依存する CSP。
* `script-src *`、または許可範囲が広すぎるソース。

検出の手がかり:

* CSP の設定箇所を確認します:

  * サーバー／CDN の設定、`index.html` のレスポンスヘッダー、またはフレームワーク設定。
* リポジトリ内に見当たらない場合は、「エッジ側で確認」と記録します。

修正:

* HTTP レスポンスヘッダーで CSP を追加します（推奨）。
* まずレポート専用で開始して破損を抑え、その後強制します。

注記:

* OWASP は CSP を XSS に対する「多層防御」と説明し、静的サイトでも SRI の強制に役立つと述べていますが、唯一の防御策にすべきではありません。([OWASP Cheat Sheet Series][2])

---

### REACT-SRI-001: サードパーティのスクリプトとスタイルには Subresource Integrity（SRI）を使う（または自前でホストする）

重大度: 低

必須事項:

* サードパーティの JS は、自分のオリジンで任意のコードを実行するのと同等として扱わなければなりません。
* CDN またはサードパーティから読み込む場合:

  * 該当する場合は SRI（`integrity=...`）と `crossorigin` を使うべきです。
  * バージョンを正確に固定すべきです（「latest」URL は避ける）。
  * 重要なコードは自前でホストすることを優先すべきです。

安全でないパターン:

* integrity のない `<script src="https://cdn.example.com/lib/latest.js"></script>`。
* 管理体制なしに任意のスクリプトを動的に読み込むタグマネージャー。

検出の手がかり:
* `public/index.html`、テンプレート、または SSR ラッパー内を検索します:

  * `<script src=`, `<link rel="stylesheet" href=`
  * タグマネージャーのスニペット（GTM、Segment など）
* 実行時 JS で動的に読み込まれるスクリプトを特定します。

修正:

* 安定したサードパーティアセットには SRI ハッシュを追加するか、自前でホストします。
* タグマネージャーに管理統制を適用します（REACT-3P-001 を参照）。

注記:

* MDN は SRI を、暗号学的ハッシュを照合して、（CDN などから）取得したリソースが改ざんされていないことをブラウザーが検証できるセキュリティ機能と説明しています。([MDN Web Docs][7])
* OWASP の CSP ガイダンスでは、CSP によって SRI を強制でき、静的サイトでも有用だと述べています。([OWASP Cheat Sheet Series][2])

---

### REACT-3P-001: サードパーティ JavaScript とタグマネージャーを最小限に抑え、管理する

重大度: 高

必須事項:

* サードパーティスクリプトを最小限に抑え、それぞれをサプライチェーン上のリスクとして扱わなければなりません。
* 自分のオリジンでどのサードパーティ JS が実行されるのか、その理由も含めて正確に把握しなければなりません。
* 次の管理策を導入すべきです:

  * バージョンをレビューして固定する（または社内にミラーする）。
  * データアクセスを制限する（データレイヤー方式）。
  * SRI と CSP を使い、可能なら信頼できない UI を iframe 内でサンドボックス化することを検討する。

安全でないパターン:

* レビューされていない分析／広告スクリプトが DOM、Cookie、ストレージ、ユーザーデータに全面的にアクセスできる状態で実行される。
* エンジニアリング部門以外の担当者が変更管理なしに変更できるタグマネージャー。

検出の手がかり:

* HTML／JS 内で一般的なベンダーのスニペットを検索します:

  * GTM、Segment、Hotjar、FullStory など。
* スクリプトの動的な挿入を探します:

  * `document.createElement('script')`, `.src = ...`, `.appendChild(script)`

修正:

* 必要なベンダーだけに絞ります。
* 可能な場合:

  * スクリプトを自前でホストするか、ミラーする。
  * SRI を使う。
  * 管理されたデータレイヤーでデータの露出を制限する。

注記:

* OWASP は、サードパーティ JS のサーバー侵害によって悪意ある JS が注入される可能性を指摘し、任意コード実行や機密情報の第三者への漏えいなどのリスクを挙げています。([OWASP Cheat Sheet Series][5])

---

### REACT-AUTH-001: XSS に耐えられるようトークンとセッションを扱う（Web Storage への機密情報の保存を避ける）

重大度: 中

必須事項:

* XSS により窃取される可能性があるため、セッション識別子や長寿命トークンを `localStorage`（および一般に Web Storage）へ保存するのは避けるべきです。
* トークンをクライアント側に置く必要がある場合:

  * 有効期間を短くし、更新の仕組みを備えたメモリ内ストレージを優先すべきです。
  * トークンのスコープを限定してローテーションしなければなりません。永続ストレージ内の長寿命ベアラートークンは避けてください。
* 可能であれば、セッショントークンには HTTPOnly Cookie を優先すべきです（CSRF 対策が必要です。REACT-CSRF-001 を参照）。

安全でないパターン:

* 認証トークンに `localStorage.setItem('token', ...)`／`sessionStorage.setItem('token', ...)` を使用する。
* 更新トークンを `localStorage` に永続保存する。
* Web Storage のデータを信頼できるものとして扱う。

検出の手がかり:

* 次を Grep します: `localStorage.`, `sessionStorage.`, `setItem(`, `getItem(`, `token`, `jwt`, `refresh`
* 認証コードで、トークンを永続保存する「ログイン状態を保持」機能を検索します。

修正:

* HTTPOnly Cookie（サーバー側の変更）と CSRF 対策へ移行するか、有効期間の短いメモリ内トークンを使います。
* トークンのスコープと有効期間を縮小します。

注記:

* OWASP の HTML5 ガイダンスでは、機密情報やセッション識別子を local storage に保存しないことを推奨し、XSS が 1 件あるだけですべての Web Storage データを盗まれる可能性があると警告しています。([OWASP Cheat Sheet Series][4])
* OAuth ブラウザーベースアプリのガイダンスでは、localStorage などの永続的なブラウザーストレージに保存されたトークンは、悪意ある JS（例: XSS）からアクセスされる可能性があると説明しています。([IETF Datatracker][16])

---

### REACT-CSRF-001: Cookie 認証を使う状態変更リクエストは、必ず CSRF 対策を行う

重大度: 高

注: アプリケーションが Cookie ベースの認証を使用していない場合（たとえば Authentication ヘッダーを使っている場合）、CSRF は問題になりません。

必須事項:

* アプリが認証に Cookie を使用する場合:

  * 状態変更リクエスト（POST／PUT／PATCH／DELETE）を CSRF から保護しなければなりません。
  * CSRF トークン方式（同期トークンまたは二重送信 Cookie）など、バックエンドに適した堅牢なパターンを使うべきです。
  * SameSite Cookie は多層防御として使い、唯一の防御策にすべきではありません。

安全でないパターン:

* CSRF トークン／ヘッダーのない `fetch('/api/transfer', { method: 'POST', credentials: 'include' })` で、Cookie のみに依存する。
* 状態を変更する操作に GET を使う。

検出の手がかり:

* 状態変更を行うネットワークリクエストを列挙し、次を確認します:

  * `credentials: 'include'` または `withCredentials: true` を使っているか。
  * CSRF トークンのヘッダー（例: `X-CSRF-Token`）が含まれているか。
* 「csrf」ユーティリティを検索します。見当たらない場合は疑わしいものとして扱います。

修正:

* CSRF トークンのフローを追加します:

  * 安全なエンドポイントからトークンを取得し、状態変更リクエストに付与する。
  * サーバー側で検証する。
* 多層防御として SameSite Cookie と Origin／Referer の検証を維持します。

注記:

* OWASP の CSRF ガイダンスでは、SameSite の動作（Lax／Strict／None）を多層防御の手法として説明し、Lax がユーザビリティとセキュリティのバランスを取りやすい理由を述べていますが、完全な CSRF 対策の代替にはなりません。([OWASP Cheat Sheet Series][6])

---

### REACT-AUTHZ-001: フロントエンドだけの認可に依存しない

重大度: 高（主たる防御として使われている場合に限る）

必須事項:

* フロントエンドの認可チェックはすべて UX のためだけのものとして扱わなければなりません。* 保護されたリソースや操作については、サーバー側で必ず認可を強制すること。

安全でないパターン:

* UI上では「保護」されているように見えても、サーバー側のチェックなしでAPIから呼び出せる操作。
* サーバー側で強制されていないクライアント側チェック（`if (user.isAdmin) { showAdminPanel(); }` など）。

検出のヒント:

* 機密性の高い操作をUIで制限している箇所を探し、サーバーのエンドポイントでも認可が強制されていることを確認する。
* フロントエンドのみの監査では、「クライアント側のチェックはセキュリティ対策ではない。バックエンドを確認すること」と報告する。

修正:

* サーバー側の認可チェックを追加または確認する。
* フロントエンドでの制限は利便性のためにのみ使用する。

注記:

* これは一般的なWebアプリのセキュリティ要件であり、Reactだけではサーバーのリソースを保護できない。

---

### REACT-NET-001: 動的な外向きリクエストによるデータ流出と認証情報の漏えいを防ぐ

深刻度: 中〜高

必須事項:

* 攻撃者が制御するオリジンに対して、認証済みリクエストを送信してはならない。
* ユーザー入力によってリクエスト先（スキーム／ホスト／ポート）が決まることを避けるべきである。
* 次の要件を満たすネットワーククライアント（fetch/axios）を一元化すべきである:

  * 固定の `baseURL`（または厳格な許可リスト）、
  * リダイレクトの厳格な処理、
  * `credentials` の明示的な使用。

安全でないパターン:

* `fetch(userProvidedUrl, { credentials: 'include' })`
* `axios.create({ baseURL: userProvidedBase })`
* 機密性の高いヘッダーを付けて任意のドメインにアクセスする、クライアント側の「URL取得／プレビュー」機能。

検出のヒント:

* `fetch(` / `axios(` を検索し、第1引数または `baseURL` が次の値に由来していないか確認する:

  * クエリパラメーター、localStorage、APIレスポンス、postMessage
* `credentials: 'include'`、`withCredentials: true` を検索する。

修正:

* 接続先に許可リストを適用する。明示的に必要でない限り、クロスオリジンリクエストを禁止する。
* 許可リストにない接続先へのリクエストでは、認証情報／Authorizationヘッダーを取り除く。

注記:

* ブラウザーが一部のクロスオリジン動作を制限していても、信頼できないエンドポイントへのトークン／ヘッダー漏えいは、依然としてよくある問題である。

---

### REACT-REDIRECT-001: オープンリダイレクトと信頼できないナビゲーションを防ぐ

深刻度: 中

必須事項:

* 信頼できない入力（`next`、`returnTo`、`redirect`）に由来するリダイレクト先／ナビゲーション先を検証しなければならない。
* 同一サイト内の相対パスのみを許可するか、絶対URLには信頼できるオリジンの厳格な許可リストのみを使うべきである。

安全でないパターン:

* `window.location.href = new URLSearchParams(location.search).get('next')`
* `next` がクエリパラメーターに由来する `navigate(next)`。

検出のヒント:

* 次を検索する: `next`、`returnTo`、`redirect`、`window.location`、`navigate(`
* リダイレクト先の由来を追跡する。

修正:

* 相対パス（`/^\/[^\s]*$/`）または許可リストにあるオリジンのみを許可する。
* 無効な場合は安全な既定値（例: `/`）にフォールバックする。

注記:

* オープンリダイレクトはフィッシングによく利用され、SSO/OAuthフローを損なうおそれがある。

---

### REACT-SW-001: サービスワーカーは高い権限を持つため、HTTPSと安全なキャッシュ／更新ルールを必須とする

深刻度: 中

必須事項:

* サービスワーカーはHTTPS経由で配信し（`localhost` の開発環境を除く）、セキュアコンテキストでのみデプロイしなければならない。
* 明示的に設計し、脅威モデリングを行った場合を除き、認証済みAPIの機密性の高いレスポンスをキャッシュしてはならない。
* 安全な更新方法（再読み込みの確認、バージョン付きキャッシュ、有効化時の古いキャッシュの削除）を実装すべきである。

安全でないパターン:

* 認証が必要なアプリにサービスワーカーを登録し、無差別に「すべて」をキャッシュする。
* PIIやユーザー固有のコンテンツを含む長期間有効なキャッシュが、アカウント間で共有される。

検出のヒント:

* 次を検索する:

  * `navigator.serviceWorker.register`
  * `workbox`、`precacheAndRoute`、カスタムの `fetch` ハンドラー
* キャッシュのパターン（`caches.open`、`cache.put`、`respondWith`）を調べる。

修正:

* オフライン対応を設計している場合を除き、キャッシュ対象を静的アセット（JS/CSS/画像）のみに制限する。
* ユーザー固有データをキャッシュする必要がある場合、キャッシュキーをユーザーごとに分ける。
* 明確な更新方法を用意する。

注記:

* MDNによると、サービスワーカーはセキュリティ上の理由からHTTPSを必要とし、リクエスト／レスポンスのプロキシとして動作する。([MDN Web Docs][10])
* 「セキュアコンテキスト」は、MITM攻撃者が強力なAPIにアクセスするのを防ぐための仕組みであり、サービスワーカーはそのような強力な機能の一例である。([MDN Web Docs][18])

---

### REACT-HEADERS-001: Reactアプリのシェル（アプリまたはエッジ）に必須のセキュリティヘッダーが設定されていることを確認する

深刻度: 中

必須事項（オリジンから配信される一般的なSPAの場合）:

* 次を設定すべきである:

  * CSP（`Content-Security-Policy`）
  * `X-Content-Type-Options: nosniff`
  * クリックジャッキング対策（CSP内の `frame-ancestors` および／または `X-Frame-Options`）
  * `Referrer-Policy`
  * 必要に応じて `Permissions-Policy`
* リポジトリ内に設定がなくても、どこか（CDN／エッジ／サーバー）で必ず設定する。

安全でないパターン:

* セキュリティヘッダーがどこにも（アプリにもエッジにも）設定されていない。
* 信頼できないコンテンツをレンダリングするアプリや、サードパーティのスクリプトを使用するアプリでCSPが設定されていない。

検出のヒント:

* リポジトリ内のサーバー／CDN設定（nginx、Cloudflare、Vercel設定など）を確認する。
* 設定がなければ、「実行時／エッジで確認」と指摘する。

修正:

* エッジでヘッダーを一元的に設定する。
* 現実的なCSPを保ち、段階的に適用する（report-onlyから強制適用へ）。

注記:

* MDNのクリックジャッキング対策ガイダンスでは、`X-Frame-Options` やCSPの `frame-ancestors` を含む防御策を説明している。([MDN Web Docs][8])
* OWASPのCSPガイダンスでは、レスポンスヘッダーによる配信を説明し、ヘッダーを推奨される方式としている。([OWASP Cheat Sheet Series][2])

---

### REACT-POSTMSG-001: `postMessage` ではオリジンを検証し、ペイロードを信頼できないデータとして扱う

深刻度: 中〜高（メッセージで可能な操作による）

必須事項:

* 厳格な理由がない限り、メッセージ送信時に正確な `targetOrigin` を指定しなければならない（`*` は使用しない）。
* 受信時に `event.origin` を検証し、メッセージの形式も検証しなければならない。
* メッセージデータをコードとして評価したり、HTMLとしてDOMに挿入したりしてはならない。

安全でないパターン:

* 不明な送信先への `window.postMessage(data, '*')`。
* 次のものを受信する:

  * `window.addEventListener('message', (e) => { eval(e.data) })`
  * `element.innerHTML = e.data`

検出のヒント:

* 次を検索する: `postMessage(`、`addEventListener('message'`
* オリジンのチェックと安全な取り扱いを確認する。

修正:

* 厳格なオリジン許可リストとスキーマ検証（例: zod）を追加する。
* メッセージペイロードはデータとしてのみ扱い、Reactを使って安全に表示する。

注記:

* OWASPのHTML5ガイダンスでは、`postMessage` に期待するオリジンを指定すること、送信元のオリジンを確認すること、データを検証すること、メッセージ内容に対してeval/innerHTMLを使わないことを推奨している。([OWASP Cheat Sheet Series][4])

---

### REACT-FILE-001: ファイルのアップロードとプレビューでクライアント側のアクティブコンテンツ脆弱性を生じさせない

深刻度: 中（保存型XSSが可能な場合は高）

必須事項:

* ユーザーがアップロードしたファイルとプレビューは、悪意のある可能性があるものとして扱わなければならない。
* サニタイズ済みで、かつ明示的に必要な場合を除き、アップロードされたHTML／SVGなどのアクティブコンテンツをインライン表示してはならない。
* UXのためにクライアント側でファイル形式を検証すべきだが、セキュリティについては必ずサーバー側の検証に依存する。

安全でないパターン:

* ユーザーがアップロードしたHTMLをコンテンツとして表示する。
* サニタイズせずに、信頼できないSVG／HTMLを `dangerouslySetInnerHTML` または `<iframe srcdoc=...>` でインライン表示する。

検出のヒント:

* アップロード用コンポーネントとプレビュー処理を検索する:

  * `input type="file"`、`FileReader`、`URL.createObjectURL`、`<iframe>`、`<object>`、`<embed>`。
* アップロードされたコンテンツが後でどこに表示されるか追跡する。

修正:

* 受け付ける形式を制限し、必要に応じてサニタイズし、リスクの高い形式にはダウンロード／添付ファイルとしての配信を優先する。
* サーバーで実際のポリシー（形式チェック、ファイル名の変更、スキャン、Webルート外への保存）を強制する。

注記:

* OWASPのファイルアップロードガイダンスでは、拡張子の許可リスト化、ファイル形式の検証、ファイル名の生成、サイズ制限、Webルート外への保存、およびファイルを誰でも取得できる場合の「クライアント側アクティブコンテンツ（XSS、CSRFなど）」の考慮を推奨している。([OWASP Cheat Sheet Series][19])

---

### REACT-SUPPLY-001: 依存関係とサプライチェーンの衛生管理（フロントエンドとビルドツール）

深刻度: 低

必須事項:

* ロックファイルを使用し、CIで再現可能なインストールを強制しなければならない。
* 次の依存関係について、定期的に監査し、アドバイザリに迅速に対応すべきである:

  * React、react-dom、ルーターライブラリ、ビルドツール（Vite/Webpack）、サニタイザー、認証ライブラリなど。
* インストール時スクリプト攻撃やタイポスクワッティングのリスクを減らすべきである。

監査の重点項目:

* CIでは `npm ci`（またはYarnのfrozen lockfile／pnpmの同等機能）を使い、依存関係のずれを防ぐ。
* 脆弱性スキャン（`npm audit`、GitHub Dependabot/alertsなど）を使用する。

安全でないパターン:

* ロックファイルがない、またはCIでロックファイルが無視されている。
* CIで `npm install` を実行し、再現不可能なビルドを生成する。
* リスクの高い依存関係が固定されていない、またはレビューされていない。レビューなしで突然メジャーバージョンを更新する。
* サードパーティパッケージのインストールスクリプトを無条件に実行する。

検出のヒント:

* ロックファイル（`package-lock.json`、`yarn.lock`、`pnpm-lock.yaml`）を確認する。
* CIスクリプトで `npm install` と `npm ci` のどちらを使っているか確認する。
* `postinstall` スクリプトと不審なビルド手順を検索する。

修正:

* ロックファイルを使用し、CIでその適用を強制する（例: `npm ci`）。
* 定期的に監査を実施し、責任を持ってバージョンを固定／更新する。
* 可能であればインストールスクリプトを制限する。

注記:

* npmのドキュメントによると、`npm audit` は既知の脆弱性レポートを受け取るためにプロジェクトの依存関係ツリーをレジストリに送信する機能であり、（任意で）`npm audit fix` を通じて修正を適用できる。ただし、一部の脆弱性は手動での確認が必要とされている。([npm Docs][20])
* npmのドキュメントによると、`npm ci` は自動化／CI環境向けの機能で、既存のロックファイルを必要とし、`package.json` とロックファイルが一致しない場合は失敗する。([npm Docs][21])
* OWASPのNPMセキュリティガイダンスでは、ロックファイルの適用を推奨し、不整合時に中止するための `npm ci` / `yarn install --frozen-lockfile` を明示的に取り上げている。また、インストール時スクリプトのリスクと、攻撃対象領域を減らすために `--ignore-scripts` を使う選択肢も強調している。([OWASP Cheat Sheet Series][22])

---

## 5) 実践的なスキャンのヒューリスティック（「探し方」）

実際にスキャンする際は、次の検出力の高いパターンを使用する:

* 生HTML／XSSの回避手段:

  * `dangerouslySetInnerHTML`、`__html:`
  * MarkdownのHTMLパススルーフラグ: `rehype-raw`、`allowDangerousHtml`、`sanitize: false`
* DOM XSSのシンク:

  * `innerHTML`、`outerHTML`、`insertAdjacentHTML`、`document.write`、`DOMParser`、`createContextualFragment`
* 危険なJavaScript実行:

  * `eval(`、`new Function(`、`setTimeout("`、`setInterval("`
* 信頼できないURLの注入／ナビゲーション:

  * 信頼できない値を伴う `href={` / `src={`
  * `window.location`、`location.href`、`window.open`、`navigate(`
  * クエリパラメーター: `next`、`returnTo`、`redirect`
* トークン／セッションのリスク:

  * `token`、`jwt`、`refresh` を伴う `localStorage.setItem`、`sessionStorage.setItem`、`getItem(`
* Cookie／CSRFの関連:

  * CSRFヘッダーのない状態変更リクエストにおける `credentials: 'include'`、`withCredentials: true`
* サードパーティスクリプト:

  * `public/index.html` 内の `<script src=...>`
  * タグマネージャーのスニペットと動的なスクリプト挿入
* サービスワーカー:

  * `navigator.serviceWorker.register`、Workboxの使用、カスタムの `fetch` ハンドラー
* postMessage:

  * `*` を伴う `postMessage(`、`event.origin` チェックの欠如
* サプライチェーン:

  * ロックファイルの欠如、CIでの `npm install` の使用、監査工程の欠如、リスクの高いpostinstallスクリプト

必ず次の点を確認する:

* データの由来（信頼できないか、信頼できるか）
* シンクの種類（Reactの回避手段、DOMシンク、ナビゲーション、ストレージ）
* 保護策の有無（サニタイズ、許可リスト、CSP／Trusted Types、CSRFトークン、ヘッダー、ガバナンス）

---

## 6) 出典（2026-01-26にアクセス）

Reactの一次ドキュメント:

* React 19安定版の発表 — `https://react.dev/blog/2024/12/05/react-19` ([React][23])
* React DOMドキュメント: `dangerouslySetInnerHTML` の警告 — `https://react.dev/reference/react-dom/components/common#dangerouslysetting-the-inner-html` ([React][12])
* React（レガシー）のJSXエスケープに関する記述 — `https://legacy.reactjs.org/docs/introducing-jsx.html` ([React][14])

OWASP Cheat Sheet Series:

* クロスサイトスクリプティングの防止（フレームワークのエスケープ回避機能、React `dangerouslySetInnerHTML`、URL 検証に関する注意事項）— `https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html` ([OWASP チートシートシリーズ][9])
* コンテンツセキュリティポリシー — `https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html` ([OWASP チートシートシリーズ][2])
* クロスサイトリクエストフォージェリの防止 — `https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html` ([OWASP チートシートシリーズ][6])
* HTML5 セキュリティ（Web Storage、postMessage、タブナビング、サンドボックス化されたフレーム）— `https://cheatsheetseries.owasp.org/cheatsheets/HTML5_Security_Cheat_Sheet.html` ([OWASP チートシートシリーズ][4])
* サードパーティ JavaScript の管理 — `https://cheatsheetseries.owasp.org/cheatsheets/Third_Party_Javascript_Management_Cheat_Sheet.html` ([OWASP チートシートシリーズ][5])
* ファイルアップロード — `https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html` ([OWASP チートシートシリーズ][19])
* NPM セキュリティのベストプラクティス — `https://cheatsheetseries.owasp.org/cheatsheets/NPM_Security_Cheat_Sheet.html` ([OWASP チートシートシリーズ][22])

ブラウザー／プラットフォームに関する参考資料（MDN、W3C）：

* Trusted Types API — `https://developer.mozilla.org/en-US/docs/Web/API/Trusted_Types_API` ([MDN Web Docs][3])
* W3C Trusted Types 仕様 — `https://www.w3.org/TR/trusted-types/` ([W3C][15])
* サブリソース完全性 — `https://developer.mozilla.org/en-US/docs/Web/Security/Subresource_Integrity` ([MDN Web Docs][7])
* クリックジャッキング対策の概要 — `https://developer.mozilla.org/en-US/docs/Web/Security/Attacks/Clickjacking` ([MDN Web Docs][8])
* Service Worker の使用（HTTPS の要件、プロキシのような動作）— `https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API/Using_Service_Workers` ([MDN Web Docs][10])
* セキュアコンテキスト（強力な API は HTTPS に制限される）— `https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Secure_Contexts` ([MDN Web Docs][18])
* リンクの `rel` 値（noopener/noreferrer）— `https://developer.mozilla.org/en-US/docs/Web/HTML/Attributes/rel` ([MDN Web Docs][17])

ビルドツール／環境変数の公開に関する参考資料：

* Create React App の環境変数に関する警告 — `https://create-react-app.dev/docs/adding-custom-environment-variables/` ([create-react-app.dev][1])
* Vite の環境変数に関するセキュリティ上の注意 — `https://vite.dev/guide/env-and-mode` ([vitejs][11])

認証／トークンの保存に関するガイダンス：

* ブラウザーベースアプリ向け OAuth 2.0（トークンの保存に関する説明）— `https://datatracker.ietf.org/doc/html/draft-ietf-oauth-browser-based-apps` ([IETF Datatracker][16])

依存関係管理ツールに関する参考資料：

* npm audit のドキュメント — `https://docs.npmjs.com/cli/v10/commands/npm-audit/` ([npm Docs][20])
* npm ci のドキュメント — `https://docs.npmjs.com/cli/v10/commands/npm-ci/` ([npm Docs][21])

サニタイザーに関する参考資料：

* DOMPurify — `https://github.com/cure53/DOMPurify` ([GitHub][13])

[1]: https://create-react-app.dev/docs/adding-custom-environment-variables/ "カスタム環境変数の追加 | Create React App"
[2]: https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html "コンテンツセキュリティポリシー - OWASP チートシートシリーズ"
[3]: https://developer.mozilla.org/en-US/docs/Web/API/Trusted_Types_API "Trusted Types API - Web API | MDN"
[4]: https://cheatsheetseries.owasp.org/cheatsheets/HTML5_Security_Cheat_Sheet.html "HTML5 セキュリティ - OWASP チートシートシリーズ"
[5]: https://cheatsheetseries.owasp.org/cheatsheets/Third_Party_Javascript_Management_Cheat_Sheet.html "サードパーティ JavaScript の管理 - OWASP チートシートシリーズ"
[6]: https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html "クロスサイトリクエストフォージェリの防止 - OWASP チートシートシリーズ"
[7]: https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Subresource_Integrity "サブリソース完全性 - セキュリティ | MDN"
[8]: https://developer.mozilla.org/en-US/docs/Web/Security/Attacks/Clickjacking "クリックジャッキング - セキュリティ | MDN"
[9]: https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html "クロスサイトスクリプティングの防止 - OWASP チートシートシリーズ"
[10]: https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API/Using_Service_Workers "Service Worker の使用 - Web API | MDN"
[11]: https://vite.dev/guide/env-and-mode "環境変数とモード | Vite"
[12]: https://react.dev/reference/react-dom/components/common "共通コンポーネント（例：<div>）– React"
[13]: https://github.com/cure53/DOMPurify "GitHub - cure53/DOMPurify: DOMPurify - HTML、MathML、SVG 向けの DOM 専用で超高速かつ非常に柔軟な XSS サニタイザー。安全なデフォルト設定で動作し、多くの設定項目やフックも利用できます。デモ："
[14]: https://legacy.reactjs.org/docs/introducing-jsx.html "JSX の紹介 – React"
[15]: https://www.w3.org/TR/trusted-types/ "Trusted Types"
[16]: https://datatracker.ietf.org/doc/html/draft-ietf-oauth-browser-based-apps "
            
                draft-ietf-oauth-browser-based-apps-26
            
        "
[17]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Attributes/rel "HTML 属性: rel - HTML | MDN"
[18]: https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Secure_Contexts "セキュアコンテキスト - セキュリティ | MDN"
[19]: https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html "ファイルアップロード - OWASP チートシートシリーズ"
[20]: https://docs.npmjs.com/cli/v10/commands/npm-audit "npm-audit | npm ドキュメント"
[21]: https://docs.npmjs.com/cli/v10/commands/npm-ci "npm-ci | npm ドキュメント"
[22]: https://cheatsheetseries.owasp.org/cheatsheets/NPM_Security_Cheat_Sheet.html "NPM セキュリティ - OWASP チートシートシリーズ"
[23]: https://react.dev/blog/2024/12/05/react-19 "React v19 – React"