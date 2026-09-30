# Express（Node.js）Web セキュリティ仕様（Express 5.x / 4.19.2+、Node.js LTS）

このドキュメントは、次を支援する**セキュリティ仕様**として作成されています。

1. 新しい Express アプリやルートを対象とした**セキュア・バイ・デフォルトのコード生成**。
2. 既存の Express コードの**セキュリティレビュー／脆弱性調査**（作業中に問題に気づく受動的な確認と、リポジトリをスキャンして検出事項を報告する能動的な確認）。

本書は意図的に、**規範的な要件**（「MUST/SHOULD/MAY」）と**監査ルール**（問題のあるパターン、その検出方法、修正・緩和方法）をまとめた形式で記述しています。

---

## 0) 安全性、境界、および不正利用防止の制約（必ず従うこと）

* シークレット（API キー、パスワード、秘密鍵、セッションシークレット、Cookie、トークン）を要求、出力、ログ記録、またはコミットしてはなりません。
* 保護機能を無効化してセキュリティを「修正」してはなりません（例：Cookie フラグを弱める、Cookie 認証アプリで CSRF 防御を無効にする、過度に許容的な CORS を有効にする、インターネット上の任意の送信元からのプロキシヘッダーを信頼する、本番環境でデバッグやスタックトレースを有効にする、代替手段なしに TLS を無効にする）。
* 監査では、主張の根拠となるファイルパス、コードスニペット、ミドルウェア／設定値、実行時の前提を示し、**証拠に基づく検出事項**を提示しなければなりません。
* 不確実性を正直に扱ってください。インフラ（リバースプロキシ、ゲートウェイ、WAF、CDN）に保護機能が存在する可能性がある場合は、「アプリコードからは確認できないため、実行時の設定を確認」と報告してください。
* 独自実装の暗号、認証、セッション、CSRF 対策より、検証済みライブラリとプラットフォームの制御機能を優先しなければなりません。Express は、ユーザー入力をアプリケーション側で適切に検証・処理することを明示的に求めています。自動では行いません。([Express][1])

---

## 1) 動作モード

### 1.1 生成モード（既定）

新しい Express コードの作成、または既存コードの変更を依頼された場合：

* 本仕様のすべての **MUST** 要件に従わなければなりません。
* ユーザーが明示的に別の指示をしない限り、すべての **SHOULD** 要件に従うべきです。
* カスタムのセキュリティコードより、安全性を既定とする API と実績のあるライブラリを優先しなければなりません。
* 新たなリスクの高いシンク（シェル実行、動的コード評価、安全でないリダイレクト、ユーザーファイルの HTML としての配信、信頼できない文字列からのテンプレート描画、安全でないファイルシステムパス、SSRF を引き起こす URL フェッチエンドポイントなど）を導入してはなりません。

### 1.2 受動的レビュー・モード（編集中は常に有効）

Express リポジトリ内のどこで作業していても（ユーザーがセキュリティスキャンを依頼していない場合も含む）：

* 本仕様への違反に「気づく」必要があります。
* 問題があれば、簡単な説明と安全な修正方法を添えて、その都度伝えるべきです。

### 1.3 能動的監査モード（明示的なスキャン依頼時）

ユーザーから「スキャン」「監査」「脆弱性を探す」よう依頼された場合：

* 本仕様への違反がないか、コードベースを体系的に検索しなければなりません。
* 検出事項を構造化された形式（§2.3 を参照）で出力しなければなりません。

推奨される監査順序：

1. エントリーポイント（サーバー／アプリの初期化処理）、デプロイ用マニフェスト、Dockerfile、プロセスマネージャーの設定、CI/CD。
2. Express の設定とミドルウェアの順序（helmet、パーサー、認証、セッション、CSRF、CORS）。
3. プロキシの信頼設定（`trust proxy`）と IP／プロトコル／ホストの処理。([Express][2])
4. 認証フロー、セッション、Cookie、パスワードリセットリンク、リダイレクト処理。([Express][1])
5. 状態を変更するルートと CSRF 保護（Cookie 認証アプリの場合）。([OWASP Cheat Sheet Series][3])
6. テンプレート描画と XSS 防御（HTML 生成、CSP、`res.locals`）。([OWASP Cheat Sheet Series][4])
7. ファイル処理（アップロード、ダウンロード、静的ファイル配信）とパストラバーサル。([Express][5])
8. インジェクションの種類（SQL、NoSQL、コマンド実行、安全でないデシリアライズ）。([OWASP Cheat Sheet Series][6])
9. 外部へのリクエスト（SSRF）と Webhook／コールバックの配信。([OWASP Cheat Sheet Series][7])
10. レート制限／ブルートフォース対策／不正利用の制御。([Express][1])
11. 依存関係の衛生管理／ロックファイル／npm audit／脆弱な Express バージョン。([Express][1])

---

## 2) 定義とレビューの指針

### 2.1 信頼できない入力（信頼できると証明されない限り、攻撃者が制御できるものとして扱う）

Express でよくある信頼できない入力は次のとおりです。

* `req.params`（ルートパラメーター）
* `req.query`（クエリ文字列パラメーター。パース方法によって文字列／配列／オブジェクトになり得る）([OWASP Cheat Sheet Series][8])
* `express.json()`、`express.urlencoded()`、`express.text()`、`express.raw()` による `req.body` ([Express][5])
* `req.headers`／`req.get(...)`
* `req.cookies`／`req.signedCookies`（Cookie パーサーミドルウェアを使用している場合）
* アップロードのメタデータやファイル名（例：multer の `file.originalname`、`file.mimetype`）
* 外部システムからのデータ（Webhook、サードパーティ API、メッセージキュー）
* ユーザーに由来する、永続化されたユーザーコンテンツ（DB の行など）

プロキシに関する特記事項：

* `trust proxy` が有効な場合、`req.ip`、`req.hostname`、`req.protocol` などの値は `X-Forwarded-*` ヘッダーから導出されることがあります。プロキシチェーンがこれらのヘッダーを正しく上書きまたは削除していなければ、**攻撃者が制御できる可能性があります**。([Express][2])

### 2.2 状態を変更するリクエスト

データの作成／更新／削除、認証／セッション状態の変更、副作用（購入、メール送信、Webhook 送信）の発生、または特権操作の開始が可能なリクエストは、状態を変更するリクエストです。

### 2.3 必須の監査検出事項フォーマット

見つかった問題ごとに、次を出力してください。

* ルール ID：
* 重大度：Critical / High / Medium / Low
* 場所：ファイルパス + 関数／ルート／ミドルウェア名 + 行番号
* 証拠：該当する正確なコード／設定スニペット
* 影響：何が起こり得るか、誰が悪用できるか
* 修正：安全な変更（最小限の差分を優先）
* 緩和策：すぐに修正するのが難しい場合の多層防御
* 誤検知に関する注記：不確かな場合に確認すべき点

---

## 3) セキュアな基準設定：本番環境の最低限の構成（本番環境では必須）

これは、よくある Express の設定ミスを防ぐための最小限の「本番環境基準」です。

最低限の基準項目：

* `helmet()` を使用して設定する（該当する場合は特に CSP）。フィンガープリント情報を減らすために `x-powered-by` を無効にする。([Express][1])
* カスタムの 404 ハンドラーとエラーハンドラーを用意し、本番環境では内部のスタックトレースを漏えいさせない。([Express][1])
* Cookie／セッションを意図的に使用する。

  * 既定のセッション Cookie 名を使わない
  * Cookie には状況に応じて `Secure`、`HttpOnly`、`SameSite` 属性を設定する
  * Cookie ベースのセッションにシークレットを保存しない（クライアントから読み取り可能）
  * 本番環境でサーバーサイドセッションに MemoryStore を使用しない。([Express][1])
* リクエスト本文のパースに明示的な上限を設定する（`express.json({ limit })`、`express.urlencoded({ limit, parameterLimit, depth })`）。([Express][5])
* `trust proxy` をプロキシ構成に合わせて明示的に設定する。無条件に `true` にしない。([Express][2])
* ログイン／認証エンドポイントにブルートフォース対策とレート制限を設ける。([Express][1])
* 依存関係を定期的に監査・更新する（`npm audit` とアドバイザリへの対応）。([Express][1])

---

## 4) ルール（生成＋監査）

各ルールには、必須の実践事項、安全でないパターン、検出の手がかり、修正方法が含まれます。

### EXPRESS-INPUT-001: すべてのユーザー入力を信頼できないものとして扱い、検証する

重大度：High

必須事項：

* セキュリティ上重要なロジックや危険なシンク（DB クエリ、リダイレクト、ファイルシステム、HTML 出力、シェルコマンド）で使用する前に、信頼できない入力を検証・正規化しなければなりません。使用または引き渡しの前に、入力の型と構造が適切か確認してください。
* 可能な場合は、ブロックリストより許可リスト（安全と分かっているもの）を適用するべきです。
* `req.query`、`req.params`、`req.body` に予期しない型や構造がある場合は、拒否するか安全に処理しなければなりません。

安全でないパターン：

* `req.query`、`req.params`、`req.body` を直接、データベース／クエリビルダー、リダイレクト、ファイルシステムのパス、またはテンプレートに渡す。
* `req.query.foo` が常に文字列だと仮定する（パース方法によって配列／オブジェクトになり得る）。([OWASP Cheat Sheet Series][8])

検出の手がかり：

* 「信頼できない入力からシンクへの」データフローを特定する：リクエスト → シンク（`res.redirect`、SQL の実行、`sendFile`、`child_process`、テンプレート描画、外部フェッチ）。
* 機密性の高い呼び出しで `req.query.*`、`req.body.*`、`req.params.*` が直接使われていないか検索する。

修正：

* ルートの境界でスキーマ検証を追加する（例：zod/joi/express-validator）。
* 型を正規化する（例：ID を整数に変換し、スカラー値が必要な場合は配列を拒否する）。

注記：

* Express の本番環境向けセキュリティガイダンスでは、入力の検証と処理はアプリケーション側の責任であると明記されています。([Express][1])

---

### EXPRESS-REDIRECT-001: オープンリダイレクトを防ぎ、リダイレクト先を検証する

重大度：Medium

必須事項：

* 信頼できない入力（`next`、`return_to`、`url`）から決まるリダイレクト先を検証しなければなりません。
* 同一サイト内の相対パスのみ（推奨）、または厳格なドメイン許可リストのみを認めるべきです。
* 検証に失敗した場合は、安全な既定値にフォールバックしなければなりません。

安全でないパターン：

* 検証せずに `res.redirect(req.query.next)` を使う。
* 信頼できない URL を使って `res.redirect(req.body.url)` または `res.location(...)` を呼び出す。

検出の手がかり：

* `res.redirect(` と `res.location(` を検索し、遷移先の入力元を追跡する。
* `next`、`redirect`、`return`、`url` という名前のクエリパラメーターを探す。

修正：

* 相対パス（`/` で始まるもの）のみを許可し、`//`、バックスラッシュ、エンコードされた同等表現を拒否する。
* ドメインをまたぐリダイレクトが必要な場合は、正確なホスト名を許可リストに登録し、`https` を強制する。

注記：

* Express のドキュメントでは、オープンリダイレクトを危険なユーザー入力の例として挙げ、リダイレクト前にホストを検証する方法を示しています。([Express][1])
* Express を最新の状態に保ってください。一部のバージョンにはオープンリダイレクト関連の CVE があり、アップグレードも緩和策の一部です。([NVD][9])

---

### EXPRESS-HEADERS-001: Helmet（または同等の手段）で重要なセキュリティヘッダーを設定する

重大度：Medium

必須事項：

* 一般的なセキュリティヘッダーを設定するために `helmet()` を使用するべきです。
* ユーザーの影響を受けるコンテンツを表示するページでは、CSP を現実的に設定するべきです（可能な場合は `unsafe-inline` を避ける）。
* `X-Content-Type-Options: nosniff`、クリックジャッキング対策（`X-Frame-Options` または CSP の `frame-ancestors`）、適切なリファラーポリシーを設定するべきです。

注：CSP では `script-src` を設定することが最も重要です。開発を容易にするため、ほかのディレクティブはそれほど重要ではなく、通常は省略できます。

安全でないパターン：

* アプリコードでセキュリティヘッダーを設定しておらず、エッジで設定されている証拠もない。
* ユーザーコンテンツを表示するアプリで CSP が設定されていない。
* クリックジャッキングを意図せず許可する、誤ったフレーミングヘッダーの設定。

検出の手がかり：

* `helmet(` の使用箇所を検索し、CSP が設定されているか、無効化されているか確認する。
* セキュリティヘッダーの設定に使われる `res.setHeader(`／`res.set(` を検索する。
* アプリコードから確認できない場合は nginx／CDN の設定を確認する。それでも確認できなければ「エッジでの確認が必要」と報告する。

修正：

* ミドルウェアの早い段階で `helmet()` を追加し、次を設定する。

  * CSP（`contentSecurityPolicy`）
  * フレーム対策（`frameguard` または CSP の `frame-ancestors`）
  * `X-Content-Type-Options`（`noSniff`）

注記：

* Express の本番環境向けセキュリティのベストプラクティスでは Helmet の使用が推奨され、Helmet が既定で設定するヘッダーも列挙されています。([Express][1])
* ポリシーの調整には OWASP の HTTP ヘッダーガイダンスが参考になります。([OWASP Cheat Sheet Series][10])

---

### EXPRESS-FINGERPRINT-001: `x-powered-by` を無効化し、エラー／404 応答をカスタマイズしてフィンガープリント情報を減らす

重大度：Low（多層防御）

必須事項：

* `app.disable('x-powered-by')` を使って `X-Powered-By` を無効にするべきです。
* 既定の応答からアプリを識別されにくくし、情報漏えいを制御するため、カスタムの 404 ハンドラーとエラーハンドラーを用意するべきです。

安全でないパターン：

* 既定の `X-Powered-By: Express` ヘッダーを有効なままにする。
* 本番環境で、形式から識別できる応答やスタックトレースを含む既定の Express 404／エラー応答を使う。

検出の手がかり：

* `app.disable('x-powered-by')` を検索する。
* ミドルウェアの末尾にカスタム 404（`app.use((req,res)=>...)`）とカスタムエラーハンドラー（`app.use((err,req,res,next)=>...)`）があるか確認する。
* 本番環境での動作に合わせて `NODE_ENV` が正しく設定されているか確認する（EXPRESS-ERROR-001 を参照）。([Express][11])

修正：

* 次を追加する。

  * `app.disable('x-powered-by')`
  * カスタム 404 ハンドラー
  * サーバー側ではログを記録し、クライアント側には一般的なメッセージを返すカスタムエラーハンドラー

注記：
* Expressのドキュメントでは、`x-powered-by`を無効にし、独自のNot Foundハンドラーとエラーハンドラーを追加することが明示的に推奨されています。([Express][1])

---

### EXPRESS-COOKIE-001: Cookieにはセキュア属性を設定し、適用範囲を最小限にする

重大度: 中

必須事項:

* 認証／セッション用Cookieには、適切なフラグを設定しなければなりません（MUST）。

  * HTTPS（本番環境）では`Secure`を設定します。重要: TLSが設定されている場合に限り、本番環境で`Secure`を設定してください。HTTPを使うローカル開発環境では、Cookieに`Secure`プロパティを設定しないでください。アプリが本番モードで動作しているかどうかに応じて、条件付きで設定してください。また、HTTPでのテスト時に`Secure` Cookieを無効にできるよう、`SESSION_COOKIE_SECURE`のようなプロパティも含めてください。
  * 認証／セッション用Cookieには`HttpOnly`を設定します。
  * `SameSite`は意図をもって設定します（一般的な初期設定は`Lax`、互換性があれば`Strict`、正当なクロスサイト要件がある場合に限り、`Secure`と併用して`None`）。
* `domain`を広く設定することは避けるべきです（必要な場合を除き、「すべてのサブドメイン」を対象にしないでください）。
* リスクと使いやすさに応じた、有効期限の上限を設定するべきです。

安全でないパターン:

* `HttpOnly`のないセッション／認証用Cookie。
* HTTPSの本番環境で`Secure`のないCookie。
* CSRF対策のない、`SameSite=None`かつCookie認証を使う状態変更エンドポイント。

検出のヒント:

* `res.cookie(`、`Set-Cookie`、`cookie: { ... }`、`express-session`、`cookie-session`を検索します。
* セッションミドルウェアの設定でCookieフラグを確認します。

修正方法:

* セッション／Cookieミドルウェアの設定で、これらの属性を一元的に設定します。

注記:

* Expressの本番環境向けセキュリティガイダンスでは、Cookieのセキュリティオプション（`secure`、`httpOnly`など）が列挙されています。([Express][1])
* `res.cookie()`は最終的にオプションを指定して`Set-Cookie`を設定します。オプションを省略した場合、既定の動作はRFC 6265に従います。([Express][5])
* フラグと有効期間の選択には、OWASPのセッション管理ガイダンスが参考になります。([OWASP Cheat Sheet Series][12])

---

### EXPRESS-SESS-001: 既定のセッションCookie名を使わず、セッションの特定を避ける

重大度: 低（多層防御）

必須事項:

* 既定のセッションCookie名は上書きするべきです（例: `express-session`を使う場合、`connect.sid`のままにしないでください）。
* 互換性上の理由がない限り、汎用的な名前（例: `sessionId`）を使うべきです。

安全でないパターン:

* `name:`を設定せずに`express-session`を使っている（Cookie名が既定値のまま）。
* 同じドメイン上の複数のアプリが、意図せず同じCookie名を共有している。

検出のヒント:

* `express-session`の設定ブロックを検索し、`name:`があるか確認します。

修正方法:

* `express-session`のオプションに`name: 'sessionId'`（または同様の値）を設定します。

注記:

* Expressのドキュメントでは、特定を減らすため、既定のセッションCookie名を使わないことが明示的に推奨されています。([Express][1])

---

### EXPRESS-SESS-002: セッションの保存先とライフサイクルを本番環境に適したものにする

重大度: 高

必須事項:

* 本番環境で`MemoryStore`を使ってはなりません（本番利用を想定して設計されていません）。
* セッションシークレットはソース管理の外部に保管し、安全にローテーションしなければなりません（MUST）。
* セッション固定攻撃のリスクを減らすため、ログイン時や権限変更時にセッションを再生成するべきです。
* クライアントが読み取れるCookieセッションに、機密性の高いシークレットを保存してはなりません（MUST NOT）。

安全でないパターン:

* `app.use(session({ store: new MemoryStore(), ... }))`を使っている、または`store`を指定していない（既定でMemoryStoreが使われます）。
* 例として、`secret: 'keyboard cat'`や`secret: 's3Cur3'`をリポジトリにハードコードしている。
* `cookie-session`を使ってアクセストークン、リフレッシュトークン、個人を特定できる情報（PII）を保存している。

検出のヒント:

* `express-session`を検索し、`MemoryStore`の使用や`store`の指定漏れがないか確認します。
* セッション設定の`secret:`を検索し、ハードコードされていないか確認します。
* `req.session = ...`のパターンを探し、機密データが保存されていないか確認します。

修正方法:

* 本番環境用のセッションストア（Redis、データベースベースのストアなど）を使います。
* シークレットは環境変数またはシークレットマネージャーから読み込みます。
* ログイン時には、権限を安全に再バインドするフローとともに、`req.session.regenerate(...)`または同等の処理を使います。

注記:

* `express-session`では、`MemoryStore`は本番利用を想定して設計されていないと明示的に警告しています。([Express][1])
* `express-session`では、セッション固定攻撃を防ぐためのシークレットのローテーションとセッションの再生成について説明されています。([Express][1])
* Expressによれば、CookieベースのセッションはデータをCookieにシリアライズし、そのデータはクライアントから見えるため、内容は小さく、シークレットを含まないものにしてください。([Express][1])

---

### EXPRESS-CSRF-001: Cookie認証で状態を変更するリクエストにはCSRF対策を必須とする

重大度: 高

- 重要: Cookieを認証に使っていない場合（つまり、認証にAuthenticationヘッダーやその他の受け渡しトークンを使う場合）、CSRFのリスクはありません。

必須事項:

* 認証にCookieを使うすべての状態変更エンドポイント（POST/PUT/PATCH/DELETE）を保護しなければなりません（MUST）。
* 十分に確立されたCSRF緩和策を使うべきです（一般的な基本策はトークンベースの対策です）。
* 多層防御として、Origin/Refererの検証、Fetch Metadataの強制、SameSite Cookie、XHR/fetch用のカスタムヘッダー要件を追加してもかまいません（MAY）。ただし、明示的に設計され、妥当性が説明されていない限り、**これらを完全な代替策として扱ってはなりません**。
* フォームベースのCRSFトークンが現実的でない場合は、少なくともカスタムHTTPヘッダーを必須にしなければなりません（MUST）。これは2番目に強力な方法です。

重要:

* 認証に`Authorization: Bearer ...`ヘッダーを使い（Cookieは使わない）場合、一般に従来型のブラウザーCSRFは該当しません。

安全でないパターン:

* CSRF対策のない、状態を変更するCookie認証エンドポイント。
* 状態変更にGETを使っている（CSRFのリスクを高めます）。
* ユーザーが制御できるフィールドだけを確認する「CSRF対策」。

検出のヒント:

* GET/HEAD以外のメソッドを使うルートをすべて洗い出し、認証にCookieを使っているか特定します。
* CSRFミドルウェアとトークン検証の有無を確認します。
* HTMLフォームだけでなく、JSON APIも確認します。

修正方法:

* Cookie認証のフローにCSRFトークンを実装します。
* 可能であればOrigin/Refererを検証し、SameSiteを適切に設定します。

注記:

* OWASPのCSRFガイダンスとOWASP Node.jsガイダンスは、どちらもWebアプリの標準的な対策として、CSRF対策トークンを推奨しています。([OWASP Cheat Sheet Series][3])

---

### EXPRESS-CORS-001: CORSは明示的に設定し、最小権限にする

重大度: 中（認証情報の設定を誤ると高）

必須事項:

* CORSが不要な場合は、無効のままにしなければなりません（MUST）。
* CORSが必要な場合:

  * 信頼できるオリジンを許可リストに登録しなければなりません（MUST）。検証せずに任意の`Origin`をそのまま返してはなりません。
  * 広範なオリジン許可と、Cookieを含む認証情報（`Access-Control-Allow-Credentials: true`）を組み合わせてはなりません（MUST NOT）。
  * 必要な範囲にメソッド、ヘッダー、公開するヘッダーを制限するべきです。

安全でないパターン:

* `Access-Control-Allow-Credentials: true`と`Access-Control-Allow-Origin: *`の併用。
* 許可リストによる検証をせず、すべてのリクエストの`Origin`をそのまま返している。
* クロスオリジンアクセスが一部でしか必要ないのに、許容範囲の広いCORSミドルウェアを全体に適用している。

検出のヒント:

* `cors(`、`Access-Control-Allow-Origin`、`Access-Control-Allow-Credentials`を検索します。
* クロスオリジンに公開されているエンドポイントで、認証にCookieを使っているか確認します。

修正方法:

* 厳格なオリジン許可リストを実装し、認証情報を含むリクエストを意図したオリジンに限って許可します。
* CORS設定を全体に適用する代わりに、ルートグループごとに分けることを検討します。

注記:

* OWASPのHTTPヘッダーガイダンスでは、ブラウザーの動作に影響するヘッダーを含め、レスポンスヘッダーがセキュリティに及ぼす影響を扱っています。ヘッダー設定を見直す際の参考にしてください。([OWASP Cheat Sheet Series][10])

---

### EXPRESS-PROXY-001: リバースプロキシの信頼設定（`trust proxy`）を正しく行う

重大度: 中（IPベースの認証を使う場合は高）

必須事項:

* リバースプロキシ／LBの背後にある場合、実際のプロキシチェーンに合わせて`app.set('trust proxy', ...)`を設定しなければなりません（MUST）。
* プロキシの動作とヘッダー書き換えを完全に管理している場合を除き、`trust proxy = true`を無条件に設定してはなりません（MUST NOT）。
* 最後に信頼されるプロキシが`X-Forwarded-For`、`X-Forwarded-Host`、`X-Forwarded-Proto`を上書きまたは削除し、クライアントが偽装できないようにしなければなりません（MUST）。

安全でないパターン:

* インターネットに直接公開されたアプリや、未知のプロキシの背後にあるアプリで`app.set('trust proxy', true)`を設定している。
* 適切なプロキシ信頼設定をせずに、セキュリティ上の判断で`req.ip`、`req.protocol`、`req.hostname`を使っている。
* 偽装可能な転送ヘッダーを使い、`req.ip`をキーにレート制限している。

検出のヒント:

* `app.set('trust proxy'`を検索します。
* ヘッダーの書き換え動作について、インフラのドキュメント（nginx/LB）を確認します。
* `req.ip`、`req.ips`、`req.protocol`、`req.hostname`を使うセキュリティロジックを特定します。

修正方法:

* ネットワークに合わせて、`trust proxy`にホップ数、明示的なIP／サブネットのリスト、またはカスタム関数を設定します。
* プロキシが転送ヘッダーを上書きするようにします。

注記:

* Expressは、`trust proxy`が`true`の場合、クライアントIPが`X-Forwarded-For`から決まり、プロキシが転送ヘッダーを上書きしなければ、クライアントが任意の値を指定できると明示的に警告しています。また、信頼プロキシの有効化により、転送ヘッダーから導出される`req.hostname`と`req.protocol`にも影響が及ぶと説明しています。([Express][2])

---

### EXPRESS-BODY-001: リクエストボディのサイズと解析制限を適切に設定する

重大度: 低

必須事項:

* 次の項目には明示的なボディサイズ制限を設定するべきです。

  * `express.json({ limit })`
  * `express.urlencoded({ limit, parameterLimit, depth })`
* 必要なパーサーだけを有効にするべきです。すべてのルートで大きなボディを既定で解析しないでください。
* リバースプロキシ／ゲートウェイ側でも、追加の制限を設けるべきです。

安全でないパターン:

* 明示的なボディ制限がない（任意に大きなJSON／urlencodedデータを受け付ける）。
* ボディが必要なのは一部のルートだけなのに、パーサーを全体に適用している。
* 正当な理由もなく`parameterLimit`が非常に大きい（DoSの可能性）。

検出のヒント:

* `express.json(`を検索し、`limit`が設定されているか（または意図的に制限を設けていないか）確認します。
* `express.urlencoded(`を検索し、`limit`、`parameterLimit`、`depth`を確認します。
* アップロード／Webhookエンドポイントに特別な解析要件がないか確認します。

修正方法:

* 保守的な既定値でパーサーを設定し、必要な場合はルートグループごとに上書きします。

注記:

* Expressは`express.json`のオプション（既定値が100kbの`limit`を含む）を説明し、`req.body`は信頼できないため検証が必要だと明示しています。([Express][5])
* Expressは`limit`、`parameterLimit`、`depth`を含む`express.urlencoded`のオプションを説明しています。([Express][5])
* OWASP Node.jsガイダンスも、リクエストサイズ制限を設定するよう推奨しています。([OWASP Cheat Sheet Series][8])

---

### EXPRESS-INPUT-002: HTTPパラメーターポリューションと`req.query`の型の混同を防ぐ

重大度: 中

必須事項:

* クエリの解析方法によっては、`req.query`の値が複数の値を持つ場合（配列／オブジェクト）があるものとして扱わなければなりません（MUST）。
* セキュリティ上重要なフィールド（例: `role`、`isAdmin`、`redirect`、`amount`、`userId`）で複数の値が曖昧さを生む場合は、拒否するべきです。
* パラメーターポリューションが懸念される場合は、明示的な解析や専用のミドルウェアを検討するべきです。

安全でないパターン:

* 型を確認せずに`if (req.query.admin) { ... }`を使っている（配列／オブジェクトが真偽値に強制変換され、trueになる場合があります）。
* `req.query`をそのままORM／NoSQLのクエリーオブジェクトに渡している。

検出のヒント:

* 型を強制せずに`req.query.*`を使う、セキュリティ上重要な比較を検索します。
* クエリパラメーターが文字列であることを前提にしたコードを探します。

修正方法:

* 値の形を検証します。特定のパラメーターは文字列のみを許可し、配列／オブジェクトを拒否します。
* 該当する場合は、クエリ解析設定（simpleとextended）を統一し、その設定を文書化します。

注記:

* OWASP Node.jsチートシートでは、Expressのクエリ解析が文字列、配列、オブジェクトを生成することを明示し、HTTPパラメーターポリューションの防止を推奨しています。([OWASP Cheat Sheet Series][8])

---

### EXPRESS-XSS-001: HTMLレスポンスとテンプレートでの反射型／格納型XSSを防ぐ

重大度: 高

必須事項:

* HTML出力内の信頼できないコンテンツをエスケープしなければなりません（MUST）。テンプレートは既定で自動エスケープするようにし、無効化しないでください。
* エスケープ／サニタイズせずに、信頼できない文字列をHTMLに挿入してはなりません（MUST NOT）。
* ユーザーが制御するコンテンツを描画するアプリでは、CSP（Helmet経由）を設定するべきです。
* テンプレートで使うユーザー入力は、検証／エスケープ済みでない限り、`res.locals`に含めないようにするべきです。

安全でないパターン:
* `res.send("<div>" + req.query.q + "</div>")`
* 信頼できない HTML を「安全」なテンプレートフラグ／フィルター経由で渡す。
* 信頼できない文字列を `res.locals` に書き込み、エスケープせずにレンダリングする。

検出の手掛かり:

* ユーザー入力を含む文字列を使った `res.send(` を検索する。
* テンプレートの「safe」フラグ（エンジン固有）を検索し、データの出所を追跡する。
* `res.locals` への代入を検索し、信頼できないデータが含まれる可能性を確認する。

修正:

* 自動エスケープ機能のあるテンプレートエンジンを使い、検証済みのデータのみを渡す。
* HTML を含める必要があるリッチテキストには、信頼できるサニタイザーと許可リストポリシーを使う。
* 現実的なディレクティブを指定した CSP を追加する。

注記:

* Express の API ドキュメントでは、`res.locals` に「ユーザーが制御する入力を含めるべきではない」と明示的に警告しており、CSRF トークンなどをテンプレートに公開するためによく使われると説明している。([Express][5])
* OWASP の XSS 防止ガイダンスには、標準的な出力エンコーディングとポリシーの推奨事項が記載されている。([OWASP Cheat Sheet Series][4])
* Helmet は CSP などのヘッダーを介して、一部の XSS 攻撃を緩和できる。([Express][1])

---

### EXPRESS-TEMPLATE-001: 信頼できないテンプレートやテンプレートパスをレンダリングしない（SSTI / LFI のリスク）

深刻度: Critical（テンプレート文字列／パスがユーザーまたは攻撃者に制御されていると証明できる場合）

必須事項:

* 信頼できない入力の影響を受ける内容、テンプレートパス、または名前を持つテンプレートをレンダリングしてはならない。
* ユーザーが制御するファイルシステム上の場所からテンプレートを読み込んではならない。
* 「メールテンプレート編集機能」、「テーマエンジン」、「CMS のようなテンプレート保存機能」は、サンドボックス化と分離が必要な高リスク設計として扱うべきである。

安全でないパターン:

* `view` が許可リストにない状態での `res.render(req.query.view, data)`。
* ユーザー入力を含む文字列からテンプレートをレンダリングする（エンジン固有）。
* アップロード用ディレクトリからテンプレートを読み込む。

検出の手掛かり:

* 最初の引数が許可リストによる制限なしにリクエスト／DB に由来する `res.render(` を検索する。
* ユーザーコンテンツを渡しているテンプレートコンパイル API（エンジン固有）を検索する。

修正:

* 許可リストに登録したテンプレート名と、固定されたテンプレートディレクトリを使う。
* ユーザー定義テンプレートが必要な場合は、厳格なサンドボックス化を実装し、実行環境を分離する。

注記:

* Express のテンプレートシステムの挙動は選択したエンジンによって異なる。ユーザー入力がテンプレートの選択またはソースに影響する場合は、安全でないものと見なす。

---

### EXPRESS-FILES-001: パストラバーサルと安全でないファイル配信を防ぐ（sendFile/download）

深刻度: High

必須事項:

* ユーザーが制御するファイルシステムパスを `res.sendFile()` / `res.download()` / ファイルシステム API に直接渡してはならない。
* ディレクトリ内のユーザー選択ファイルを配信するときは、固定した `root` と厳格なオプション（例: ドットファイルの拒否）を指定して `res.sendFile` を使うべきである。
* ユーザー固有のファイルを配信する前に、必ず認可チェックを行う。

安全でないパターン:

* `root` による制限なしでの `res.sendFile(req.query.path)` または `res.download(req.params.file)`。
* `..` セグメント、エンコードされたパストラバーサル、または絶対パスを受け付けるファイル配信ルート。

検出の手掛かり:

* `res.sendFile(` を検索し、`path` 引数の出所を追跡する。
* `res.download(` を検索し、`path` 引数の出所を追跡する。
* リクエストに由来するパスに対する `fs.readFile` / `createReadStream` を探す。

修正:

* クライアントから生のパスを受け取るのではなく、サーバー側（DB）に保存した識別子とパスの対応表を使う。
* 適切な場合は `root: <trusted_base_dir>` と `dotfiles: 'deny'` を指定し、ファイル名の部分を厳格に検証する。

注記:

* Express の `res.sendFile` ドキュメントでは、安全な配信設定の一部として `root` オプションと `dotfiles: 'deny'` を使う例が示されている。([Express][5])
* `res.download` はファイルを添付ファイルとして転送するが、基になる `path` を制御／検証する必要がある。([Express][5])

---

### EXPRESS-STATIC-001: `express.static` / serve-static を強化し、信頼できないアップロードをアクティブコンテンツとして配信しない

深刻度: Medium（ファイル拡張子に堅牢な制限がない状態で、信頼できないユーザーファイルを配信している場合）

必須事項:

* ユーザーのアップロードファイルを、明示的に意図されサンドボックス化されている場合を除き、公開静的ディレクトリからアクティブコンテンツ（特に HTML/JS/SVG）として配信してはならない。コンテンツが非アクティブ（png、jpg などの画像）であると確実な場合は、安全な可能性がある。配信前に画像ファイルの拡張子が許可リストに含まれていることを検証するとよい。
* 静的ファイル配信は、次のように設定するべきである:

  * ドットファイルを拒否／無視する
  * 不要な場合は意図しないディレクトリインデックスを避ける
  * 変更されないアセットには適切なキャッシュ制御を適用する

安全でないパターン:

* ユーザーが任意のファイルをアップロードできる状態での `app.use(express.static('uploads'))`。
* アップロードされた HTML または SVG を、アプリと同じオリジンからインラインで配信する。

検出の手掛かり:

* `express.static(` を検索し、配信対象のディレクトリを特定する。
* 配信対象のディレクトリとアップロードファイルの保存場所を照合する。
* 静的ミドルウェアの `dotfiles` および `index` オプションを確認する。

修正:

* アップロードファイルは静的 Web ルートの外に保存し、適切な場合は安全な `Content-Type` と `Content-Disposition: attachment` を設定する制御されたルート経由で配信する。
* `express.static(root, { dotfiles: 'deny'|'ignore', index: false (if desired) })` を設定する。

注記:

* Express のドキュメントには、`dotfiles` の挙動や `index` を含む `express.static` のオプションが記載されている。([Express][5])

---

### EXPRESS-UPLOAD-001: ファイルアップロードを検証し、安全に保存・配信する

深刻度: Low - Medium

必須事項:

* アップロードサイズ制限をアプリケーション層とエッジ層で設けるべきである。
* ファイル形式は、許可リストとコンテンツチェックを使って検証しなければならない（ファイル名の拡張子だけに頼らない）。
* 可能な場合は、アップロードファイルを実行可能なルートや静的配信ルートの外に保存しなければならない。
* サーバー側でファイル名（ランダムな ID）を生成するべきであり、元のファイル名を信頼してはならない。
* 明示的に意図されている場合を除き、アクティブである可能性のある形式は安全に（ダウンロード添付として）配信しなければならない。

安全でないパターン:

* 任意のファイル形式を受け入れ、インラインで再配信する。
* `file.originalname` を保存先パスとして使う。
* サイズ／形式の検証がない。

検出の手掛かり:

* multer/busboy/formidable の使用箇所を調べ、`limits` の設定を確認する。
* アップロードファイルの書き込み先と配信方法を確認する。
* アップロードファイルが `public/` または `express.static` のルート配下に置かれていないか確認する。

修正:

* OWASP のアップロードガイダンスに従い、許可リストによる検証、安全な保存、安全な配信を実装する。

注記:

* OWASP のファイルアップロードガイダンスには、許可リスト、コンテンツ検証、保存、安全な配信のパターンが記載されている。([OWASP Cheat Sheet Series][13])

---

### EXPRESS-INJECT-001: SQL インジェクションを防ぐ（パラメーター化クエリ／ORM を使用）

深刻度: High

必須事項:

* パラメーター化クエリ、または内部でパラメーター化を行う ORM／クエリビルダーを使わなければならない。
* 信頼できない入力を使った文字列連結／テンプレートリテラルで SQL を組み立ててはならない。

安全でないパターン:

* ``db.query(`SELECT * FROM users WHERE id = ${req.query.id}`)``
* `"SELECT ... WHERE name = '" + req.body.name + "'"`

検出の手掛かり:

* JS/TS 内の `SELECT`、`INSERT`、`UPDATE`、`DELETE` 文字列を grep で検索する。
* 信頼できない入力が `.query(...)`、`.execute(...)`、または生 SQL API に渡されていないか追跡する。

修正:

* パラメーター化クエリ（プレースホルダー）または ORM のクエリ API に置き換える。
* クエリを実行する前に、型（例: 整数 ID）を検証する。

注記:

* OWASP の SQL インジェクション防止ガイダンスでは、パラメーター化クエリが強く推奨されている。([OWASP Cheat Sheet Series][6])

---

### EXPRESS-INJECT-002: NoSQL インジェクション／演算子インジェクションを防ぐ（Mongo 系）

深刻度: High（アプリケーションに依存）

必須事項:

* 信頼できない入力から構築するクエリオブジェクトでは、型とスキーマを検証しなければならない。
* ユーザー入力をクエリオブジェクトにマージする場合は、演算子インジェクション（例: `$ne`、`$gt`、`$where`）を防がなければならない。
* 適切な場合は、防御用ライブラリ／ミドルウェアの使用を検討するべきである。

安全でないパターン:

* 攻撃者が制御するリクエスト本文を使った `collection.find(req.body)`。
* スキーマ検証なしに `req.query` / `req.body` を Mongo クエリにマージする。

検出の手掛かり:

* 引数がリクエスト由来の `find(`、`findOne(`、`aggregate(` 呼び出しを検索する。
* `{ ...req.query }` や `Object.assign(query, req.body)` のようなパターンを確認する。

修正:

* 入力境界でスキーマを検証し、検証済みフィールドのみからクエリオブジェクトを明示的に構築する。

注記:

* OWASP の Node.js チートシートでは、入力検証について説明し、NoSQL の文脈でサニタイズによく使われる Node エコシステムのモジュールに触れている。([OWASP Cheat Sheet Series][8])

---

### EXPRESS-CMD-001: OS コマンドインジェクションを防ぐ（child_process）

深刻度: Critical to High（露出状況による）。ユーザーまたは攻撃者が制御できることを証明すること。

必須事項:

* 信頼できない入力を使ったシェルコマンドの実行を避けなければならない。
* サブプロセスが必要な場合:

  * 攻撃者の影響を受ける文字列を使った `exec()` / `execSync()` を避けなければならない。
  * 攻撃者の影響を受けるデータとともに `shell: true` を使ってはならない。
  * 引数配列と厳格な許可リストを使う `spawn()` を使うべきである。実行ファイル名はハードコードするか許可リストで制限し、ユーザー指定のコマンド名を使わない。
  * フラグインジェクションを避けるため、サブコマンドが対応している場合はユーザー制御値を `--` の後に置くべきである。

安全でないパターン:

* `exec(req.query.cmd)`
* `exec(`convert ${userPath} ...`)`
* `spawn('sh', ['-c', userString])`
* `spawn(userString, ['foo'])`

検出の手掛かり:

* `child_process`、`exec(`、`execSync(`、`spawn(`、`fork(` を検索する。
* リクエスト／DB のデータがコマンドの組み立てに使われていないか追跡する。

修正:

* 可能であれば、サブプロセスの代わりに機能を javascript で実装するか、ライブラリを使う。
* 避けられない場合は、コマンドをハードコードし、パラメーターを厳格な許可リストで制限する。

注記:

* OWASP の OS コマンドインジェクション防御ガイダンスには、シェルを避ける方法や許可リストのパターンが記載されている。([OWASP Cheat Sheet Series][14])

---

### EXPRESS-SSRF-001: 外部 HTTP 通信でサーバーサイドリクエストフォージェリ（SSRF）を防ぐ

深刻度: Medium（クラウド／LAN 環境では High）

注: これは主に、クラウド／LAN 環境にデプロイされるアプリ、または同じマシン上に他の HTTP サービスがあるアプリに該当する。Webhook のように、この機能が不可避な場合もある。

必須事項:

* 到達可能なプライベート HTTP エンドポイントが他に存在する場合、ユーザー指定 URL への外部リクエストは高リスクとして扱わなければならない。
* ユーザーの影響を受ける URL を取得する場合は、宛先を検証し制限する（ホスト／ドメインの許可リスト）べきである。
* 次へのアクセスをブロックするべきである:

  * localhost / プライベート IP 範囲 / リンクローカル
  * クラウドメタデータエンドポイント
* URL 取得機能では `http` / `https` のみを許可しなければならない（`file:`、`javascript:` などのスキームを避けるため）。
* タイムアウトを設定し、リダイレクトを制限するべきである。

安全でないパターン:

* `fetch(req.query.url)`
* 任意の URL を受け付ける「URL プレビュー」／「URL からインポート」エンドポイント。

検出の手掛かり:

* URL がユーザー／DB に由来する `fetch(`、`axios(`、`got(`、`request(`、`node-fetch` の使用箇所を検索する。
* Webhook テスター、プレビュー機能、画像取得機能を確認する。

修正:

* スキーム許可リスト、ホスト許可リスト、DNS／IP 解決チェック、タイムアウト、リダイレクトポリシーを適用する。
* インフラレベルでのネットワーク送信制御を検討する。

注記:

* OWASP の SSRF 防止ガイダンスには、標準的な対策とよくある落とし穴が記載されている。([OWASP Cheat Sheet Series][7])

---

### EXPRESS-ERROR-001: 本番環境でエラー処理から機密情報を漏らさない

深刻度: Low

必須事項:

* ミドルウェアの最後に、集中管理されたエラーハンドラー（`app.use((err, req, res, next) => ...)`）を定義するべきである。
* 本番環境でスタックトレース、内部エラーメッセージ、またはシークレットをクライアントに返してはならない。
* 適切に秘匿処理を行ったうえで、サーバー側にエラーを記録するべきである。
* 詳細が漏れるデフォルト動作を避けるため、本番環境向けの設定でアプリを実行するべきである。
* 本番環境のエラーメッセージに、シークレット、環境変数、セッション、Cookie などの機密情報を記録したり返したりしてはならない。

安全でないパターン:

* クライアントに `err.stack` を返す。
* 本番環境で開発専用のエラーミドルウェアを使う。
* `NODE_ENV` が development のままで、詳細なエラーレスポンスが返される。

検出の手掛かり:

* 最終段のエラーハンドリングミドルウェアがあることを確認する。
* `res.status(500).send(err)` などを検索する。
* 本番環境の環境変数と起動スクリプトを確認する。

修正:

* 汎用的なメッセージを返し、詳細を内部で記録する、本番環境向けの安全なエラーハンドラーを追加する。
* 本番環境向けの動作になるよう、環境を設定する。

注記：

* Expressの本番環境向けセキュリティガイダンスでは、独自のエラー処理を推奨している。([Express][1])
* Expressのエラー処理ドキュメントでは、既定のエラーハンドラーの動作と、本番モードが公開される情報に与える影響について説明している。([Express][11])

---

### EXPRESS-AUTH-001: 認可エンドポイントに対するブルートフォース攻撃を防ぐ

重大度: 中

注: これはアプリケーションに大きく依存します。ユーザーに知らせることは有益ですが、複雑な追加設定なしに修正するのは困難です。ユーザーに情報を伝え、解決策の実装を依頼された場合は、考えられる解決策を案内してください。

必須事項:

* ログイン／認証エンドポイントをブルートフォース攻撃から保護することが望ましい。
* 次の条件でレート制限することが望ましい。

  1. ユーザー名とIPの組み合わせごとの連続した失敗回数
  2. 一定時間内におけるIPごとの失敗回数

安全でないパターン:

* ログイン試行が無制限。

検出のヒント:

* すべての認証エンドポイントを特定し、レート制限／スロットリングの有無を確認する。
* `rate-limiter-flexible`、`express-rate-limit`、またはゲートウェイポリシーを検索する。

修正方法:

* アプリ側またはエッジ側でレート制限／スロットリングを実装する。この方法のツールとして、Expressのドキュメントでは`rate-limiter-flexible`を挙げている。([Express][1])

注記：

* OWASP Node.jsチートシートも、ブルートフォース攻撃に対する予防策を推奨している。([OWASP Cheat Sheet Series][8])

---

### EXPRESS-DEPS-001: 依存関係とパッチの適切な管理（Express + Node + 重要なミドルウェア）

重大度: 中／低

注: `npm audit`は、実際には問題にならない、重要度の低い「脆弱性」を多数報告することがよくあります。Expressやその他の極めて重要なパッケージにのみ注目し、開発ツールやバンドラーなどに記載されたものは無視してください。

ユーザーの同意なしにパッケージをアップグレードしないでください。既存のコードが予期しない形で壊れる可能性があります。代わりに、古くなったパッケージについてユーザーに知らせてください。

必須事項:

* Expressはサポート中のバージョン系列を使用しなければならない（サポート終了済みのメジャーバージョンは避ける）。
* CIや保守作業で`npm audit`を使用してもよい。
* ロックファイルで依存関係のバージョンを固定し、メジャーアップデートを慎重に確認することが望ましい。

安全でないパターン:

* サポート終了済みのExpressバージョン（例: 非常に古いメジャーバージョン系列）を実行している。
* `npm audit`の検出結果をトリアージせずに放置している。
* バージョン範囲が固定されておらず、安全でないバージョンへ自動的にアップグレードされる。

検出のヒント:

* `package.json`とロックファイルで、`express`およびその他の重要なミドルウェアのバージョンを確認する。
* CIパイプラインに`npm audit`／SCAのステップがあるか調べる。

修正方法:

* Expressを最新の安定版にアップグレードし、パッチを適用する。
* 依存関係の自動スキャンとアップグレードのプロセスを導入する。

注記：

* Expressの本番環境向けセキュリティガイダンスでは、依存関係の脆弱性がアプリを侵害する可能性を強調し、`npm audit`を推奨している。([Express][1])
* 既知のオープンリダイレクト関連のCVEを含め、Expressのバージョンに影響するセキュリティ問題を追跡する。([NVD][9])

---

### EXPRESS-DOS-001: DoS対策を設定する（タイムアウト、制限、リバースプロキシ）

重大度: 低

注: 提供されたアプリケーションの情報だけでは、リバースプロキシの背後でアプリケーションが動作しているか判断しにくい場合があります。ユーザーに知らせたり、導入を推奨したりしてもかまいませんが、ユーザーから依頼されない限り設定を試みないでください。これはデプロイ環境に大きく依存します。

必須事項:

* 実現可能な場合は、キャッシュ、負荷分散、フィルタリング制御を提供するためにリバースプロキシを使用することが望ましい。
* Slowlorisや類似のDoS攻撃パターンへの露出を減らすため、サーバー／プロキシのタイムアウトや接続数制限を設定してもよい。
* 不正な接続によってプロセスがクラッシュしないよう、サーバー／ソケットのエラーを処理しなければならない。（Expressは例外を処理するが、例外的なケースもある。）

安全でないパターン:

* 公開Nodeサーバーの前にリバースプロキシがなく、あらゆる設定が既定値のまま。
* サーバー／ソケットオブジェクトにエラーハンドラーがない。
* タイムアウトが極端に長く、リクエストボディのサイズが無制限。

検出のヒント:

* サーバーの作成箇所（`http.createServer`、`https.createServer`）と、タイムアウトが設定されているかを調べる。
* プロキシ／ゲートウェイの設定で、タイムアウトと最大ボディサイズを確認する。

修正方法:

* リバースプロキシとタイムアウトの設定方法を説明し、リクエストサイズ制限を設定する。
* 堅牢なエラー処理ミドルウェアを追加する。

注記：

* Node.jsのセキュリティガイダンスでは、HTTP DoSについて、リバースプロキシの使用とサーバーのタイムアウトを適切に設定することを解説している。([Node.js][15])

---

### EXPRESS-NODE-INSPECT-001: 本番環境でNode inspectorを公開しない

重大度: 重大

注: この検出結果が本当に本番環境の実行経路に該当することを確認してください。ローカルデバッグにのみ使われている可能性があります。

必須事項:

* 本番環境でNodeを`--inspect`付きで実行してはならない（特にループバック以外にバインドする場合）。
* `NODE_OPTIONS`や起動スクリプトで、本番環境のinspectorが有効化されていないことを確認しなければならない。
* ファイアウォールで保護し、デバッグはローカルでのみ行うことが望ましい。

安全でないパターン:

* 本番環境で`node --inspect=0.0.0.0:9229 app.js`を実行している。
* コンテナ／PM2／systemdの設定でinspectorが有効になっている。

検出のヒント:

* Dockerfile、Procfile、systemdユニット、PM2設定、npmスクリプトで`--inspect`を検索する。
* `NODE_OPTIONS`を確認する。

修正方法:

* 本番環境の起動コマンドからinspectorフラグを削除し、ローカル開発に限定する。

注記：

* Nodeのセキュリティガイダンスでは、inspectorの公開リスク（DNSリバインディングなど）を説明し、本番環境でinspectorを実行しないよう推奨している。([Node.js][15])

---

### EXPRESS-NODE-HTTP-001: 本番環境で安全でないHTTP解析を有効にしない

重大度: 高

注: この検出結果が本当に本番環境の実行経路に該当することを確認してください。ローカル開発にのみ使われている可能性があります。

必須事項:

* 本番環境でNodeの`insecureHTTPParser`を使用してはならない。
* リクエストスマグリングのリスクを減らすため、曖昧なリクエストを正規化するフロントエンドプロキシの設定を提案してもよい。

安全でないパターン:

* `{ insecureHTTPParser: true }`を指定してHTTPサーバーを作成している。

検出のヒント:

* サーバー作成コードで`insecureHTTPParser`を検索する。

修正方法:

* 安全でない解析を削除し、仕様に準拠した解析を利用するとともに、エッジ側でリクエストを正規化する。

注記：

* Nodeのセキュリティガイダンスでは、`insecureHTTPParser`を使用しないよう明示的に推奨している。([Node.js][15])

---

## 5) 実践的なスキャンのヒューリスティック（「探し方」）

Expressのリポジトリを実際にスキャンする際、次のパターンは有力な手掛かりになります。

* TLS／通信:

  * リバースプロキシへの言及なしに`app.listen(80`を使用している、`helmet`がない、Cookieに`secure`がない ([Express][1])（注: これはWebに公開されたアプリケーションにのみ該当します。内部アプリではTLSが使われていない可能性があります。）
* プロキシの信頼設定:

  * `app.set('trust proxy', true)`、`req.ip`／`req.protocol`／`req.hostname`を使用するロジック ([Express][2])
* セキュリティヘッダー／フィンガープリント:

  * `helmet(`がない、`app.disable('x-powered-by')`がない ([Express][1])
* Cookie／セッション:

  * `express-session`の指定がない`store`（MemoryStoreのリスク）、ハードコードされた`secret:`、`cookie: { secure/httpOnly/sameSite }`の指定がない ([Express][1])
  * 大きなオブジェクトや秘密情報を保存する`cookie-session` ([Express][1])
* ボディ解析の制限:

  * `express.json()`／`express.urlencoded()`／`limit`を指定せずに`parameterLimit`または`depth`を使用している ([Express][5])
* CSRF:

  * Cookie認証を使うPOST／PUT／PATCH／DELETEルートで、CSRFトークンやオリジンチェックがない ([OWASP Cheat Sheet Series][3])
* オープンリダイレクト:

  * `res.redirect(req.query.next)`など ([Express][1])
* XSS／HTML出力:

  * ユーザー入力を使ってHTMLを組み立てる`res.send(`、テンプレートの「安全」フラグ、`res.locals`内の信頼できない値 ([Express][5])
* ファイル処理:

  * パスがリクエストに由来する`res.sendFile(`／`res.download(`、`express.static('uploads')` ([Express][5])
* インジェクション:

  * SQL文字列やテンプレートリテラルをDB呼び出しに渡している ([OWASP Cheat Sheet Series][6])
  * `child_process.exec`／`execSync`／`shell: true` ([OWASP Cheat Sheet Series][14])
* SSRF:

  * ユーザー指定URLへの外向き`fetch/axios/got` ([OWASP Cheat Sheet Series][7])
* ブルートフォース／不正利用:

  * スロットリングのない認証エンドポイント、レート制限ミドルウェアがない ([Express][1])
* サプライチェーン:

  * 古いExpressバージョン、ロックファイルがない、`npm audit`のワークフローがない ([Express][1])
* Nodeランタイムの危険要因:

  * 本番スクリプトでの`--inspect`、`insecureHTTPParser`の使用 ([Node.js][15])

必ず次の点を確認する:

* データの由来（信頼できないか、信頼できるか）
* データの送信先の種類（HTML／テンプレート、SQL／NoSQL、サブプロセス、ファイルシステム、リダイレクト、外向きHTTP）
* 保護策の有無（検証、許可リスト、ミドルウェア、プロキシ設定、ヘッダーポリシー）
* 保護策がエッジ側にあるか、アプリケーションコード内にあるか

---

## 6) 参照資料（2026-01-27アクセス）

Expressの一次資料:

* Express: 本番環境向けベストプラクティス — セキュリティ: `https://expressjs.com/en/advanced/best-practice-security.html` ([Express][1])
* Express: プロキシの背後での実行（`trust proxy`）: `https://expressjs.com/en/guide/behind-proxies.html` ([Express][2])
* Express 5.x APIリファレンス（パーサー、static、sendFile、redirect、Cookie）: `https://expressjs.com/en/5x/api.html` ([Express][5])
* Express: エラー処理: `https://expressjs.com/en/guide/error-handling.html` ([Express][11])

セッションミドルウェアのドキュメント:

* express-sessionドキュメント（Cookieフラグ、secretのローテーション、セッション固定攻撃の軽減、MemoryStoreの警告）: `https://expressjs.com/en/resources/middleware/session.html` ([Express][1])

Node.jsおよびnpmの公式リファレンス:

* Node.js — セキュリティのベストプラクティス（DoS、プロキシのガイダンス、inspectorのリスク、リクエストスマグリングに関する注意事項）: `https://nodejs.org/en/learn/getting-started/security-best-practices` ([Node.js][15])
* npmドキュメント — `npm audit`: `https://docs.npmjs.com/cli/v9/commands/npm-audit/` ([npm Docs][16])

OWASPチートシートシリーズ:

* セッション管理: `https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html` ([OWASP Cheat Sheet Series][12])
* CSRF対策: `https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html` ([OWASP Cheat Sheet Series][3])
* XSS対策: `https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html` ([OWASP Cheat Sheet Series][4])
* 入力検証: `https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html` ([OWASP Cheat Sheet Series][17])
* SQLインジェクション対策: `https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html` ([OWASP Cheat Sheet Series][6])
* OSコマンドインジェクション対策: `https://cheatsheetseries.owasp.org/cheatsheets/OS_Command_Injection_Defense_Cheat_Sheet.html` ([OWASP Cheat Sheet Series][14])
* SSRF対策: `https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html` ([OWASP Cheat Sheet Series][7])
* ファイルアップロード: `https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html` ([OWASP Cheat Sheet Series][13])
* 未検証のリダイレクト: `https://cheatsheetseries.owasp.org/cheatsheets/Unvalidated_Redirects_and_Forwards_Cheat_Sheet.html` ([OWASP Cheat Sheet Series][18])
* HTTPヘッダー: `https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html` ([OWASP Cheat Sheet Series][10])

バージョン情報／勧告:

* Expressパッケージのバージョン（npm）: `https://www.npmjs.com/package/express`
* Expressのオープンリダイレクトに関する勧告（CVE）: `https://nvd.nist.gov/vuln/detail/CVE-2024-29041` ([NVD][9])

[1]: https://expressjs.com/en/advanced/best-practice-security.html "本番環境におけるExpressのセキュリティベストプラクティス"
[2]: https://expressjs.com/en/guide/behind-proxies.html "プロキシの背後でのExpress"
[3]: https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html "クロスサイトリクエストフォージェリ対策 - OWASPチートシートシリーズ"
[4]: https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html "クロスサイトスクリプティング対策 - OWASPチートシートシリーズ"
[5]: https://expressjs.com/en/5x/api.html "Express 5.x - APIリファレンス"
[6]: https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html "SQLインジェクション対策 - OWASPチートシートシリーズ"
[7]: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html "サーバーサイドリクエストフォージェリ対策 - OWASPチートシートシリーズ"[8]: https://cheatsheetseries.owasp.org/cheatsheets/Nodejs_Security_Cheat_Sheet.html "Node.js セキュリティ - OWASP チートシートシリーズ"
[9]: https://nvd.nist.gov/vuln/detail/cve-2024-29041?utm_source=chatgpt.com "CVE-2024-29041 詳細 - NVD"
[10]: https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html "HTTP ヘッダー - OWASP チートシートシリーズ"
[11]: https://expressjs.com/en/guide/error-handling.html "Express のエラー処理"
[12]: https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html "セッション管理 - OWASP チートシートシリーズ"
[13]: https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html "ファイルアップロード - OWASP チートシートシリーズ"
[14]: https://cheatsheetseries.owasp.org/cheatsheets/OS_Command_Injection_Defense_Cheat_Sheet.html "OS コマンドインジェクション対策 - OWASP チートシートシリーズ"
[15]: https://nodejs.org/en/learn/getting-started/security-best-practices "Node.js — セキュリティのベストプラクティス"
[16]: https://docs.npmjs.com/cli/v9/commands/npm-audit/ "npm-audit | npm ドキュメント"
[17]: https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html "入力検証 - OWASP チートシートシリーズ"
[18]: https://cheatsheetseries.owasp.org/cheatsheets/Unvalidated_Redirects_and_Forwards_Cheat_Sheet.html "未検証のリダイレクトとフォワード - OWASP チートシートシリーズ"
