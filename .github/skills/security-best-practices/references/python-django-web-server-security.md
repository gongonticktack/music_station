# Django（Python）Web セキュリティ仕様（Django 6.0.x、Python 3.x）

このドキュメントは、次の用途を支援する**セキュリティ仕様**として作成されています。

1. 新しい Django コードを**デフォルトで安全に生成**する。
2. 既存の Django コードの**セキュリティレビュー／脆弱性調査**を行う（作業中に問題に気づく「受動的な確認」と、リポジトリをスキャンして指摘事項を報告する「能動的な確認」）。

この仕様は、**規範的な要件**（「MUST／SHOULD／MAY」）と**監査ルール**（危険なパターンの見分け方、検出方法、修正・緩和方法）をまとめたものです。

---

## 0）安全性、境界、悪用防止の制約（必ず遵守）

* シークレット（API キー、パスワード、秘密鍵、セッション Cookie、`SECRET_KEY`、`SECRET_KEY_FALLBACKS`、データベースのパスワード）を要求、出力、記録、コミットしてはなりません。
* 保護機能を無効化してセキュリティ上の問題を「修正」してはなりません（例：`CsrfViewMiddleware` の削除、`@csrf_exempt` の追加、`ALLOWED_HOSTS` を `['*']` に緩和、`SecurityMiddleware` の無効化、テンプレートの自動エスケープの無効化、権限チェックの無効化）。
* 監査では**根拠に基づく指摘**を提示しなければなりません。主張を裏付けるファイルパス、コードスニペット、具体的な設定値を示してください。
* 不確実性を正直に扱ってください。保護機能がインフラ（リバースプロキシ、WAF、CDN、Ingress コントローラー）に存在する可能性がある場合は、「アプリケーションコードでは確認できないため、実行時設定／エッジ設定を確認」と報告してください。
* 修正は Django が意図するセキュリティモデルに適合させなければなりません。可能な限り、独自のセキュリティロジックより Django の組み込み機能（ミドルウェア、認証、フォーム、ORM）を優先してください。Django のデプロイチェックリストとシステムチェックは、意図されたモデルの一部です。([Django Project][1])

---

## 1）動作モード

### 1.1 生成モード（デフォルト）

新しい Django コードの作成、または既存コードの変更を依頼された場合：

* この仕様の**すべての MUST 要件**に従わなければなりません。
* ユーザーが明示的に別の指示をしない限り、すべての **SHOULD 要件**に従うべきです。
* 独自のセキュリティコードより、安全な状態をデフォルトとする Django API と実績のあるライブラリを優先しなければなりません。
* 新たな危険なシンクを導入してはなりません（信頼できない文字列からの動的なテンプレート描画、安全でないリダイレクト、安全でないファイル配信、シェル実行、生 SQL 文字列の整形、信頼できない入力から URL を取得する SSRF の可能性がある処理など）。

### 1.2 受動的レビュー・モード（編集時は常に有効）

Django リポジトリ内のどこで作業する場合も（ユーザーがセキュリティスキャンを依頼していない場合も含む）：

* この仕様への違反に気づかなければなりません。
* 問題が見つかったら、簡潔な説明と安全な修正方法を添えて伝えるべきです。

### 1.3 能動的監査モード（明示的なスキャン依頼時）

ユーザーが「スキャン」「監査」「脆弱性を探す」と依頼した場合：

* 仕様への違反をコードベース全体で体系的に検索しなければなりません。
* 指摘事項を構造化された形式（§2.3 参照）で出力しなければなりません。

推奨する監査順序：

1. デプロイのエントリーポイント（ASGI／WSGI）、Dockerfile、Procfile、systemd ユニット、プラットフォームのマニフェスト。
2. `settings.py` と環境別の設定モジュール。
3. ミドルウェアの順序と有効化されている保護機能。
4. 認証／認可（ログイン、セッション管理、権限、管理画面）。
5. CSRF 対策と状態を変更するエンドポイント。
6. テンプレートと XSS。
7. ファイル処理（アップロード／ダウンロード／静的ファイル／メディア）とパストラバーサル。
8. インジェクションの種類（SQL、コマンド実行、安全でないデシリアライズ）。
9. 外部へのリクエスト（SSRF）。
10. リダイレクト処理（オープンリダイレクト）、CORS、セキュリティヘッダー（CSP、HSTS など）。
11. 依存関係の固定とパッチ適用状況。

---

## 2）定義とレビュー指針

### 2.1 信頼できない入力（信頼できると証明されない限り、攻撃者が制御できるものとして扱う）

例：

* `request.GET`、`request.POST`、`request.FILES`
* `request.body`、JSON ボディ（例：`json.loads(request.body)`）、DRF `request.data`
* URL パスパラメーター（例：`<int:id>`、`<slug:...>`）
* `request.headers`／`request.META`（`HTTP_HOST`、`HTTP_ORIGIN`、`HTTP_REFERER`、`HTTP_X_FORWARDED_*` を含む）
* `request.COOKIES`
* 外部システムからのあらゆるデータ（Webhook、サードパーティ API、メッセージキュー）
* ユーザーに由来する、保存済みのあらゆるコンテンツ（DB の行、キャッシュされたコンテンツ、ファイルのアップロード）

Django は「ユーザーが制御するデータを決して信頼しない」ことを明確に強調し、フォームと検証の使用を推奨しています。([Django Project][2])

### 2.2 状態を変更するリクエスト

データの作成・更新・削除、認証／セッション状態の変更、副作用（購入、メール送信、Webhook 送信）の発生、または特権操作の開始が可能なリクエストは、状態を変更するリクエストです。

### 2.3 必須の監査指摘フォーマット

見つかった問題ごとに、次の項目を出力してください。

* ルール ID：
* 重大度：Critical／High／Medium／Low
* 場所：ファイルパス + 関数／クラス／ビュー名 + 行番号
* 根拠：該当する正確なコード／設定スニペット
* 影響：何が起こり得るか、誰が悪用できるか
* 修正：安全な変更（最小限の差分を優先）
* 緩和策：すぐに修正するのが難しい場合の多層防御
* 誤検知に関する注記：不確かな場合に確認すべき点

---

## 3）安全な基本設定：本番環境の最小構成（本番環境で必須）

これは、よくある Django の設定ミスを防ぐための最小限の「本番環境ベースライン」です。Django は「デプロイチェックリスト」を提供しており、本番設定に対して `manage.py check --deploy` を実行することを推奨しています。([Django Project][1])

### 3.1 設定管理のパターン（SHOULD）

* 環境変数による設定（またはシークレットマネージャー）を使用し、本番設定をコードにハードコードしないようにするべきです。
* 機密性の高い設定（例：`SECRET_KEY`、DB パスワード）を秘密として扱い、ソース管理に含めてはなりません。Django のチェックリストでは、`SECRET_KEY` をハードコードせず、環境変数またはファイルから読み込むことを明示的に推奨しています。([Django Project][1])
* 開発用と本番用の設定モジュールを分け、本番環境では安全なデフォルト値を設定するべきです（重要な設定がない場合はフェイルクローズにする）。([Django Project][1])

### 3.2 最低限のベースライン目標（本番環境）

* 本番環境のエントリーポイントとして `manage.py runserver` を使用してはなりません。本番運用に適した WSGI または ASGI サーバーを使用してください。([Django Project][1])
* 本番環境では `DEBUG = False` を設定しなければなりません。([Django Project][1])
* 強力で秘密性の高い `SECRET_KEY` を設定し、秘密に保たなければなりません。安全にローテーションするために `SECRET_KEY_FALLBACKS` を使用してもかまいません。([Django Project][1])
* `ALLOWED_HOSTS` には想定されるホストを設定しなければなりません（独自にホスト検証を実装する場合を除き、ワイルドカードは使用しないでください）。([Django Project][1])
* 認証が必要な領域では HTTPS を強制しなければなりません（ログイン可能なアプリケーションでは、サイト全体での適用が理想的です）。HTTPS を使用する場合は `CSRF_COOKIE_SECURE=True` と `SESSION_COOKIE_SECURE=True` を設定してください。([Django Project][1])
* 主要な `SecurityMiddleware` ヘッダー／設定を有効にするべきです。HSTS、Referrer-Policy、COOP、nosniff、SSL リダイレクト（プロキシの設定を正しく行うこと）などが含まれます。([Django Project][3])
* ユーザーによるアップロードを信頼できないものとして扱わなければなりません。Web サーバーがアップロードされたコンテンツを実行可能なコンテンツとして解釈しないようにし、`MEDIA_ROOT` を `STATIC_ROOT` と分離してください。([Django Project][1])

---

## 4）ルール（生成 + 監査）

各ルールには、必須の実践事項、安全でないパターン、検出の手掛かり、修正方法が含まれます。

### DJANGO-DEPLOY-001：本番環境で Django の開発サーバーを使用しない

重大度：High（本番環境の場合）

必須事項：

* 本番サーバーとして `manage.py runserver` をデプロイしてはなりません。
* 本番グレードの WSGI または ASGI サーバーの背後で実行しなければなりません。([Django Project][1])

安全でないパターン：

* 本番環境向けのドキュメント／スクリプトで `python manage.py runserver 0.0.0.0:8000` を使用している。
* Docker の `CMD`／エントリーポイントで `runserver` を使用している。
* Kubernetes／Procfile／systemd ユニットで `runserver` を呼び出している。

検出の手掛かり：

* `manage.py runserver`、`runserver 0.0.0.0`、`--insecure` を検索する。
* Docker の `CMD/ENTRYPOINT`、Procfile、systemd ユニットファイル、Helm チャートを確認する。

修正：

* Django のデプロイチェックリストが推奨する本番サーバー（WSGI／ASGI）を使用してください。([Django Project][1])

注：

* ローカル開発では `runserver` を使用しても問題ありません。本番環境のエントリーポイントとして使われている場合に限り、指摘してください。

---

### DJANGO-DEPLOY-002：本番環境では `DEBUG` を無効にしなければならない

重大度：High

必須事項：

* 本番環境では `DEBUG = False` を設定しなければなりません。
* デバッグページ／トレースバックを信頼できないユーザーに公開する仕組みは、重大な情報漏えいリスクとして扱わなければなりません。Django のチェックリストでは、`DEBUG=True` がソースコードの抜粋、ローカル変数、設定などを漏えいさせると明確に警告しています。([Django Project][1])

安全でないパターン：

* 本番設定で `DEBUG = True` を使用している。
* 明示的に上書きされない限り、環境設定が `DEBUG=True` になる。

検出の手掛かり：

* `DEBUG = True`、`DEBUG=os.environ.get(..., True)`、`DJANGO_DEBUG`、`.env` ファイルを検索する。
* 開発環境のデフォルト設定をインポートしている「本番用」設定モジュールを探す。

修正：

* 本番設定で `DEBUG=False` を設定し、環境設定を明示的に行ってください。
* エラー報告にはデバッグページではなく、安全なログ記録／監視を使用してください。([Django Project][1])

---

### DJANGO-CONFIG-001：`SECRET_KEY` は強力かつ秘密性の高い値にし、安全にローテーションする

重大度：High（署名／セッションが有効な本番環境で値が欠落している場合は Critical）

必須事項：

* 本番環境では、十分な長さのランダムな `SECRET_KEY` を設定し、秘密に保たなければなりません。([Django Project][1])
* ソース管理にコミットしたり、表示／ログ出力したりしてはなりません。([Django Project][1])
* 環境変数、ファイル、またはシークレットストアから読み込むべきです（ハードコードしない）。([Django Project][1])
* 署名済みデータをすべて即座に無効化しないよう、`SECRET_KEY_FALLBACKS` を使ってキーをローテーションしてもかまいません。フォールバックから古いキーを適切な時期に削除しなければなりません。([Django Project][1])

安全でないパターン：

* 本番用の `SECRET_KEY = "..."` がリポジトリにハードコードされている。
* `SECRET_KEY` が複数の環境で使い回されている。
* `SECRET_KEY_FALLBACKS` に、有効期限が大幅に過ぎたキーが無期限に残っている。

検出の手掛かり：

* コミット済みファイル内の `SECRET_KEY =`、`SECRET_KEY_FALLBACKS`、`.env`、`print(settings.SECRET_KEY)` を検索する。

修正：

* シークレットマネージャー／環境変数から読み込んでください。
* ローテーションする場合：

  * 新しい `SECRET_KEY` を設定する。
  * 古いキーを一時的に `SECRET_KEY_FALLBACKS` に保持する。
  * ローテーション期間の終了後に古いキーを削除する。([Django Project][1])

---

### DJANGO-HOST-001：Host ヘッダーを検証する（`ALLOWED_HOSTS` は厳格に設定する）

重大度：Medium

必須事項：

* 本番環境では、想定されるドメイン／ホストを `ALLOWED_HOSTS` に設定しなければなりません。([Django Project][1])
* 独自に堅牢な `Host` 検証を実装する場合を除き、本番環境で `ALLOWED_HOSTS = ['*']` を設定してはなりません（ワイルドカードを使用する場合、CSRF に類する攻撃を防ぐために独自の検証が必要だと Django は警告しています）。([Django Project][1])
* 多層防御として、手前に置く Web サーバーが不明なホストを早い段階で拒否するよう設定するべきです。([Django Project][1])

安全でないパターン：

* 本番環境で `ALLOWED_HOSTS = ['*']` を使用している（または環境変数を展開すると `*` になる）。
* `ALLOWED_HOSTS = []` に `DEBUG=False` を設定している（サイトが動作しない、または設定ミスのあるデプロイで回避策が試みられる）。

検出の手掛かり：

* `ALLOWED_HOSTS` を検索する。
* `ALLOWED_HOSTS` を上書きするプラットフォームの環境設定を確認する。

修正：

* 本番環境向けに `ALLOWED_HOSTS = ['example.com', 'www.example.com', ...]` を設定してください。
* 開発環境向けのホスト設定は分けてください。

注：

* Django は URL の構築に Host ヘッダーを使用します。偽装された Host 値は CSRF、キャッシュポイズニング、メールリンクの改ざんにつながる可能性があります（Django のセキュリティドキュメントでも指摘されています）。([Django Project][2])

---

### DJANGO-HTTPS-001：TLS を使用する場合は Cookie の送信を保護する

重大度：High（認証機能を持つアプリケーションでは Critical）

注：TLS が有効な場合にのみ適用してください。TLS を使わないアプリケーションでは動作しなくなります。

TLS を使用する場合：
* 次を設定しなければなりません。

  * `CSRF_COOKIE_SECURE = True` ([Django Project][1])
  * `SESSION_COOKIE_SECURE = True` ([Django Project][1])
* 次の有効化を検討するべきです。

  * `SECURE_SSL_REDIRECT = True`（プロキシを正しく設定すること）([Django Project][3])
  * `SECURE_HSTS_SECONDS` による HSTS（必要に応じて includeSubDomains／preload を設定）。([Django Project][3])

安全でないパターン：

* HTTP 経由のログインページ、または同じセッション Cookie を使用する HTTP／HTTPS 混在。
* 本番環境で HTTPS を使っているのに、`CSRF_COOKIE_SECURE=False` または `SESSION_COOKIE_SECURE=False` が設定されている。
* HSTS の設定ミス（設定の有効期間中、サイトが利用不能になる可能性がある）。

検出の手掛かり：

* `settings.py` を確認し、`CSRF_COOKIE_SECURE`、`SESSION_COOKIE_SECURE`、`SECURE_SSL_REDIRECT`、`SECURE_HSTS_SECONDS` を調べる。
* HTTP から HTTPS へのリダイレクト動作について、プロキシ／Ingress の設定を確認する。

修正：

* HTTPS リダイレクトと Secure Cookie を有効にしてください。
* HSTS は慎重に追加してください（低い値から始めて検証し、その後増やします）。設定ミスにより、HSTS の有効期間中サイトに問題が生じる可能性があると Django は警告しています。([Django Project][3])

---

### DJANGO-PROXY-001: リバースプロキシの信頼設定を正しく行う（`SECURE_PROXY_SSL_HEADER`）

重大度: 中（TLS プロキシの背後にある場合）

必須:

* TLS を終端するリバースプロキシの背後にある場合、`request.is_secure()` が*外部の*スキームを反映するよう Django を設定しなければなりません。そうしないと、CSRF などのロジックに問題が生じる可能性があります。この設定には `SECURE_PROXY_SSL_HEADER` を使うよう Django が説明しています。([Django Project][3])
* プロキシを管理しており（または保証があり）、受信した偽装ヘッダーを除去する場合に限り、`SECURE_PROXY_SSL_HEADER` を設定しなければなりません。設定ミスがセキュリティを損なう可能性があると Django は明示的に警告し、必要な条件を列挙しています。([Django Project][3])

安全でないパターン:

* プロキシがユーザー提供の `X-Forwarded-Proto` を除去しない環境での `SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")`。
* `SECURE_SSL_REDIRECT=True` の設定後にリダイレクトが無限に繰り返される（多くの場合、プロキシによる HTTPS の判定が誤っています）。([Django Project][3])

検出のヒント:

* `SECURE_PROXY_SSL_HEADER`、`SECURE_SSL_REDIRECT` を検索します。
* 転送ヘッダーが除去されるか、イングレス／プロキシの動作を確認します。

修正:

* プロキシがヘッダーを正しく除去し、設定する場合に限り、`SECURE_PROXY_SSL_HEADER` を設定します（Django が文書化している前提条件に従います）。([Django Project][3])

---

### DJANGO-SESS-001: 本番環境ではセッション Cookie にセキュア属性を設定する

重大度: 中（TLS が有効な場合のみ）

必須（本番環境、HTTPS）:

* `SESSION_COOKIE_SECURE=True` を設定しなければなりません（HTTPS 経由でのみ送信）。([Django Project][3])
* `SESSION_COOKIE_HTTPONLY=True` を維持しなければなりません（Django の既定値は `True` です）。([Django Project][3])
* 正当なクロスサイトフローで `None` が必要な場合を除き、`SESSION_COOKIE_SAMESITE='Lax'` を維持することが望まれます（Django の既定値は `Lax` です）。([Django Project][3])
* クロスサブドメイン Cookie が本当に必要な場合を除き、`SESSION_COOKIE_DOMAIN` の設定は避けることが望まれます（サブドメイン全体に適用される Cookie は攻撃対象領域を広げます）。

安全でないパターン:

* 本番環境の HTTPS での `SESSION_COOKIE_SECURE=False`。

重要な注意: TLS が設定されている場合に限り、本番環境で `Secure` を設定してください。HTTP を使うローカル開発環境では、Cookie に `Secure` プロパティを設定しないでください。アプリが本番モードで実行されているかどうかに応じて、条件付きで設定してください。また、HTTP でテストするときに `Secure` Cookie を無効化できる `SESSION_COOKIE_SECURE` のようなプロパティも含めてください。

* `SESSION_COOKIE_HTTPONLY=False`。
* Cookie 認証を使う状態変更エンドポイントと `SESSION_COOKIE_SAMESITE=None` の組み合わせ（CSRF のリスクが高まります）。

検出のヒント:

* `SESSION_COOKIE_` の設定、`response.set_cookie(..., httponly=..., secure=..., samesite=...)` を検索します。

修正:

* 本番環境の設定で、上記を明示的に設定します。
* 認証フローとの互換性を検証します。([Django Project][3])

---

### DJANGO-SESS-002: CSRF Cookie の設定は意図的に行う（HttpOnly にはトレードオフがある）

重大度: 中

必須:

* HTTPS/TLS を使用する場合、`CSRF_COOKIE_SECURE=True` を設定することが望まれます。([Django Project][3])
* クロスサイト要件がない限り、`CSRF_COOKIE_SAMESITE='Lax'` を維持することが望まれます。Django の既定値は `Lax` です。([Django Project][3])
* フロントエンドで CSRF Cookie を読み取る必要がない場合、`CSRF_COOKIE_HTTPONLY=True` を設定してもかまいません（既定値は `False` です）。有効にする場合、JS は代わりに DOM から CSRF トークンを読み取る必要があります（Django が説明しています）。([Django Project][3])

安全でないパターン:

* 本番環境の HTTPS/TLS での `CSRF_COOKIE_SECURE=False`。
* `CSRF_COOKIE_HTTPONLY=True` を設定しながら、JS で「csrftoken Cookie を読み取る」方式に依存すること（AJAX の CSRF 対策が機能しなくなります）。
* 明確な理由のない `CSRF_COOKIE_SAMESITE=None`。

検出のヒント:

* `CSRF_COOKIE_` の設定を検索します。
* JS 内で `csrftoken` を取得するための `document.cookie` の使用を検索します。

修正:

* Django の説明に従い、Cookie 設定を CSRF トークンの取得方法（Cookie または DOM）に合わせます。([Django Project][4])

---

### DJANGO-CSRF-001: Cookie 認証を使う状態変更リクエストは CSRF 対策を必ず行う

重大度: 高

必須:

* `django.middleware.csrf.CsrfViewMiddleware` を有効のままにしなければなりません（既定で有効です）。([Django Project][4])
* 内部向け POST フォームには `{% csrf_token %}` を含めなければなりません。外部 URL に POST するフォームには含めてはなりません（トークンが漏えいすると Django は警告しています）。([Django Project][4])
* 認証に Cookie を使うすべての状態変更エンドポイント（POST/PUT/PATCH/DELETE）を保護しなければなりません。
* AJAX/SPA の呼び出しでは、文書化されているとおり、`X-CSRFToken` ヘッダー（または設定されたヘッダー名）で CSRF トークンを送信しなければなりません。([Django Project][4])
* `@csrf_exempt` の使用には十分注意し、絶対に必要な場合に限らなければなりません。使用する場合は、適切な代替制御（例: Webhook のリクエスト署名）で CSRF 対策を置き換えなければなりません。Django は `csrf_exempt` について明示的に警告しています。([Django Project][2])

安全でないパターン:

* `MIDDLEWARE` 内での `CsrfViewMiddleware` の欠落。
* 汎用の認証済みビューでの `@csrf_exempt`。
* セッション認証を使い、CSRF トークンのない POST/PUT/PATCH/DELETE エンドポイント。
* 状態変更操作に GET を使うこと（CSRF リスクが増幅します）。

検出のヒント:

* `settings.py` `MIDDLEWARE` を調べて、`CsrfViewMiddleware` とその順序を確認します（CSRF 対策が済んでいることを前提とするミドルウェアより前に置くべきだと Django は説明しています）。([Django Project][4])
* `csrf_exempt`、`csrf_protect`、`ensure_csrf_cookie` を検索します。
* GET 以外のメソッドを使う URL パターンを列挙し、CSRF 対策の適用範囲を確認します。

修正:

* `CsrfViewMiddleware` を再び有効にし、フォームに CSRF トークンを追加し、AJAX のヘッダー処理を追加します。
* キャッシュデコレーターについて: CSRF トークンが必要なビューをキャッシュする場合、CSRF Cookie/Vary ヘッダーのないレスポンスがキャッシュされないよう、Django の説明に従って `@csrf_protect` を適用します。([Django Project][4])

注:

* HTTPS でデプロイすると、Django の CSRF ミドルウェアは同一オリジンであることを確認するために Referer ヘッダーも検査します（Django のセキュリティ文書で説明されています）。([Django Project][2])

---

### DJANGO-XSS-001: テンプレートと HTML 生成で反射型／格納型 XSS を防ぐ

重大度: 高

必須:

* HTML テンプレートでは Django のテンプレート自動エスケープ（既定で安全）に依存しなければなりません。Django のセキュリティ文書によると、Django テンプレートは危険な文字をエスケープしますが、制限もあります。([Django Project][2])
* 信頼できるコンテンツまたは安全にサニタイズされたコンテンツでない限り、自動エスケープを広範囲に無効化（`{% autoescape off %}`）してはなりません。([Django Project][5])
* 信頼できないコンテンツを安全なものとして扱ってはなりません。

  * ユーザーデータに対する `mark_safe(...)` は避けてください。
  * ユーザーが制御するコンテンツに対する `|safe` は避けてください。
* HTML コンテキスト上の落とし穴（例: 引用符で囲まれていない属性）に注意しなければなりません。Django は、引用符で囲まれていない属性のコンテキストではエスケープだけでは保護されない例を明示しています。([Django Project][2])
* エスケープ漏れの危険がある手動連結ではなく、安全な HTML 構築ヘルパー（例: `format_html`）を優先することが望まれます。([Django Project][6])

安全でないパターン:

* `{% autoescape off %}{{ user_input }}{% endautoescape %}`
* `{{ user_input|safe }}`
* `mark_safe(request.GET["q"])`
* 引用符で囲まれていない属性へのインジェクション: `<style class={{ var }}>...`（Django 独自の例）。([Django Project][2])

検出のヒント:

* テンプレート内の `|safe`、`autoescape off`、`safeseq` を検索します。
* Python 内の `mark_safe`、`SafeString`、またはリクエスト／DB の値を使った直接的な HTML 連結を検索します。
* `user_value` に HTML が含まれる `HttpResponse(user_value)` を返すコードを確認します。

修正:

* 安全でないマーク付けを削除します。厳密に必要な場合に限ってサニタイズします（許可リスト方式の HTML サニタイザーを使用します）。
* 属性を引用符で囲み、信頼できない値を危険なコンテキストに置かないようにします。
* 多層防御として CSP を追加します（DJANGO-CSP-001 を参照）。([Django Project][2])

---

### DJANGO-TEMPLATE-001: 信頼できないテンプレートソース文字列を決してレンダリングしない

重大度: 高〜致命的（状況と公開範囲による）

必須:

* テンプレートソース文字列が信頼できない入力（リクエスト、ユーザーコンテンツ、信頼できないユーザーが編集できる DB 行）の影響を受けるテンプレートをレンダリングしてはなりません。
* 「文字列からテンプレートを生成する」パターンは、Django テンプレートが一部の他のエンジンより制約されている場合でも危険なものとして扱わなければなりません。コンテキストからのデータ漏えい、エスケープの回避、XSS やコンテンツインジェクションを引き起こす可能性があります。

安全でないパターン:

* `Template(request.GET["tmpl"]).render(Context(...))`
* ユーザーのテンプレートを DB に保存し、通常の権限／コンテキストでレンダリングすること。

検出のヒント:

* 定数でない文字列を使う `django.template.Template(`、`Engine.from_string`、`.render(Context(` を検索します。
* テンプレート文字列の出所（管理画面、DB、アップロード、リクエスト）をたどります。

修正:

* 実行を伴わない書式設定（例: `string.Template`、明示的なプレースホルダー）または厳格な許可リスト方式のレンダリングに置き換えます。
* ユーザー定義テンプレートに対応する必要がある場合は、厳重に隔離します（サービス／テナントコンテキストの分離、厳格な許可リストを用意し、回避が起こり得ると想定します）。

---

### DJANGO-SQL-001: SQL インジェクションを防ぐ（ORM またはパラメーター化された生 SQL を使う）

重大度: 高

必須:

* 通常の DB アクセスには Django ORM/queryset を使わなければなりません。通常の使い方では queryset はパラメーター化され、SQL インジェクションから保護されると Django は説明しています。([Django Project][2])
* 生 SQL には十分注意しなければなりません。`raw()`、`cursor.execute()`、`extra()`、`RawSQL` を使う場合、パラメーター（例: `params=`）を別に渡し、信頼できない入力を SQL に文字列補間してはなりません。Django の生 SQL 文書では、ユーザー制御のパラメーターを `params` でエスケープするよう警告しています。([Django Project][7])
* SQL テンプレート内でプレースホルダーを引用符で囲んではなりません。引用符で囲まれた `%s` プレースホルダーは安全でないと Django の文書で明示的に警告されています。([Django Project][8])
* 必要な場合を除き、`extra()` と `RawSQL` は避けることが望まれます。Django のセキュリティ文書も注意を促しています。([Django Project][2])

安全でないパターン:

* `cursor.execute(f"SELECT ... WHERE id={request.GET['id']}")`
* `Model.objects.raw("... %s" % user_input)`（文字列の書式設定）
* `extra(where=[f"headline='{q}'"])`
* 引用符で囲まれたプレースホルダー: `WHERE othercol = '%s'`（安全でないと明示的に文書化されています）。([Django Project][8])

検出のヒント:

* `.raw(`、`.extra(`、`RawSQL(`、`connection.cursor()`、`.execute(` を検索します。
* Python の文字列内で SQL キーワード（`SELECT`、`UPDATE`、`DELETE`、`INSERT`）を検索します。
* 信頼できない入力がこれらの呼び出し箇所に渡る経路を追跡します。

修正:

* ORM クエリを優先します。
* 生 SQL が避けられない場合は、パラメーター（`params`、DB-API のパラメーターバインディング）を使い、プレースホルダーを引用符で囲まないでください。([Django Project][7])

---

### DJANGO-CMD-001: OS コマンドインジェクションを防ぐ

重大度: 致命的〜高（公開範囲による）

必須:

* 攻撃者が影響を与えられる入力を使ってシステムコマンドを実行することを避けなければなりません。
* subprocess が必要な場合:

  * 引数はリストとして渡さなければなりません（シェル文字列は不可）。
  * 攻撃者が影響を与えられるコンテンツを含む `shell=True` を使ってはなりません。
  * 変数部分には厳格な許可リストを使うことが望まれます。
* シェルを呼び出すより、純粋な Python ライブラリを優先することが望まれます。

安全でないパターン:

* `os.system(request.GET["cmd"])`
* `path` がユーザー制御である場合の `subprocess.run(f"convert {path}", shell=True)`。

検出のヒント:

* `os.system`、`subprocess`、`Popen`、`shell=True` を検索します。
* リクエスト／DB の入力がこれらの呼び出しに渡る経路を追跡します。

修正:

* ライブラリ API に置き換えます。避けられない場合は、実行ファイルをハードコードし、検証済みパラメーターを許可リストで制限します。

---

### DJANGO-UPLOAD-001: ファイルアップロードを検証し、安全に保存して配信する

重大度: 高

必須:

* すべてのユーザーアップロードを信頼できないものとして扱わなければなりません。「メディアファイルはユーザーによってアップロードされます。信頼できないものです！」と Django は明示的に警告しています。([Django Project][1])
* Web サーバーがユーザーアップロードを実行可能コードとして決して解釈しないようにしなければなりません（例: アップロードされた `.php` や HTML を、実行したりアクティブコンテンツとしてインライン表示したりしない）。([Django Project][1])
* サイズ制限を適用しなければなりません（少なくとも Web サーバー側で設定します。DoS を防ぐため、サーバーでアップロードサイズを制限するよう Django のセキュリティ文書は推奨しています）。([Django Project][2])
* 拡張子だけに頼らず、許可リストとコンテンツ検査を使ってファイル形式を検証することが望まれます。* アップロードファイルは、アプリケーションコードのディレクトリおよび静的ファイルのルートの外部に保存するべきです。
* 同一オリジンによる影響を抑えるため、アップロードファイルを別のトップレベルドメインまたは第2レベルドメインから配信することを検討するべきです。Djangoのセキュリティドキュメントは別ドメインを推奨しており、一部の保護ではサブドメインでは不十分な場合があると述べています。([Django Project][2])
* ポリグロット形式のアップロードによるリスクを認識しなければなりません。Djangoのドキュメントには、有効なPNGヘッダーを使ってHTMLを「画像として」アップロードできる事例が記載されています（また、WebサーバーによってはHTMLとして配信される可能性があります）。([Django Project][2])

安全でないパターン:

* `text/html` を使ってアップロードファイルをインライン表示する、または実行可能な可能性のある形式のダウンロードを強制しない。
* 拡張子だけに基づくアップロード許可リスト。
* 静的ファイルのルートやコードのルート内にアップロードファイルを保存する。

検出の手がかり:

* `request.FILES`、`FileField`、`ImageField`、アップロード用フォームやビューを検索します。
* アップロードファイルの配信パスと、Nginx/Apacheの設定（メディアハンドラー）を調べます。
* `MEDIA_URL`、`MEDIA_ROOT`、静的ファイルの設定を確認します。

修正:

* Webサーバーを設定して、アップロードファイルを実行されない不活性なバイト列として配信し、リスクの高い種類については `Content-Disposition: attachment` を強制することを検討します。
* 必要に応じて、ユーザーコンテンツには別ドメインを使用します。([Django Project][2])

---

### DJANGO-PATH-001: パストラバーサルと安全でないファイル配信を防ぐ（静的ファイルとメディアの分離）

深刻度: 高

必須事項:

* ファイルの読み取り、書き込み、配信にユーザー入力をファイルシステムのパスとして扱ってはなりません。
* `MEDIA_ROOT` と `STATIC_ROOT` を別々に保たなければなりません。Djangoの設定ドキュメントでは、セキュリティ上の問題を避けるため、異なる値にする必要があると明示的に警告しています。([Django Project][3])
* 任意の相対パスをユーザーから受け取るのではなく、サーバー側の識別子をキーとするDjangoのストレージAPIを優先するべきです。

安全でないパターン:

* `open(os.path.join(MEDIA_ROOT, request.GET["path"]))`
* `?file=../../...` 形式のパラメーターを受け取るダウンロードエンドポイント。
* 設定が不適切な `MEDIA_ROOT == STATIC_ROOT`。

検出の手がかり:

* リクエスト値とともに使われている `open(`、`Path(`、`os.path.join(` を検索します。
* 設定内の `MEDIA_ROOT`、`STATIC_ROOT` を確認します。([Django Project][3])

修正:

* 既知のファイルに対応付けたサーバー側IDを使います。
* 静的ファイルとメディアを分離し、Webサーバーがメディアを信頼できないものとして扱うようにします。([Django Project][3])

---

### DJANGO-REDIRECT-001: オープンリダイレクトを防ぐ（`next`、`return_to`、`redirect`）

深刻度: 中（認証フローと組み合わさる場合は高）

必須事項:

* 信頼できない入力（例: `next`、`return_to`）から得たリダイレクト先を検証しなければなりません。
* 同一サイト内の相対パス、または許可リストに登録したホストやスキームに制限するべきです。
* 独自の解析処理ではなく、Djangoの安全なURLヘルパー（例: `django.utils.http.url_has_allowed_host_and_scheme`）を使うべきです。

安全でないパターン:

* 検証なしの `return redirect(request.GET.get("next"))`。
* 単純な文字列チェックで実装されたリダイレクト許可リスト。

検出の手がかり:

* `redirect(` を検索し、リダイレクト先の由来を追跡します。
* `next`、`return_to`、`redirect`、`url` という名前のパラメーターを検索します。

修正:

* 許可リストで検証し、検証に失敗した場合は安全な内部パスを既定値にします。
* `ALLOWED_HOSTS` によるホスト検証を厳格に保ちます（DJANGO-HOST-001を参照）。([Django Project][3])

---

### DJANGO-HEADERS-001: 必須のセキュリティヘッダーを有効にする（SecurityMiddlewareとクリックジャッキング対策）

深刻度: 中〜高

必須事項:

* 本番環境では `django.middleware.security.SecurityMiddleware` を使い、適切に設定するべきです。対象は次のとおりです。

  * `X-Content-Type-Options: nosniff`（Django設定 `SECURE_CONTENT_TYPE_NOSNIFF`、既定値 `True`）。([Django Project][3])
  * `Referrer-Policy`（Django設定 `SECURE_REFERRER_POLICY`、既定値 `'same-origin'`）。([Django Project][3])
  * COOP（Django設定 `SECURE_CROSS_ORIGIN_OPENER_POLICY`、既定値 `'same-origin'`）。([Django Project][3])
  * 必要に応じたHTTPSリダイレクトとHSTS（DJANGO-HTTPS-001を参照）。([Django Project][3])
* X-Frame-Optionsミドルウェアでクリックジャッキング対策を有効にするべきです。Djangoのセキュリティドキュメントは、第三者サイトによるフレーム埋め込みが不要なサイトでは、これを強く推奨しています。([Django Project][2])

安全でないパターン:

* SecurityMiddlewareがない。
* フレーム埋め込みの明確な要件がないのに、クリックジャッキング対策がない（または全体で無効になっている）。
* 機密性の高いエンドポイントに対する、範囲が広すぎるフレーム埋め込み許可。

検出の手がかり:

* `MIDDLEWARE` を調べ、SecurityMiddlewareとXFrameOptionsMiddlewareがあるか確認します。
* ビュー単位でフレーム埋め込みやCSRF保護を無効にしていないか検索します。

修正:

* ミドルウェアを追加または有効化し、設定を意図的に行います。([Django Project][3])

注記:

* 一部のヘッダーはエッジ（CDN/リバースプロキシ）で設定される場合があります。アプリケーションコード内で確認できない場合は、「エッジで確認」として指摘してください。

---

### DJANGO-CSP-001: 多層防御としてContent Security Policy（CSP）を導入する

深刻度: 中（信頼できないコンテンツをレンダリングするアプリでは高） 

注記: CSPではscript-srcの設定が最も重要です。それ以外のディレクティブは重要度が低く、開発を容易にするため、一般に省略できます。

必須事項:

* XSSやコンテンツインジェクションの脅威を軽減するため、CSPを導入するべきです。DjangoのセキュリティドキュメントはCSPを推奨しており、Django 6.0で導入された新機能であると述べています。([Django Project][2])
* CSPの限界を理解しなければなりません。

  * CSPの適用対象からルートを除外しないでください。同一オリジンポリシーにより、保護されていないページが保護されたページを損なう可能性があるとDjangoは警告しています。([Django Project][2])
* 安全に調整するため、まずは `SECURE_CSP_REPORT_ONLY` から始めてもかまいません（Djangoはレポートのみのモードに対応しています）。([Django Project][3])

安全でないパターン:

* ユーザーが制御するコンテンツをレンダリングするアプリにCSPがない。
* CSPから「ほんの数ページ」を除外している（全体の保護が弱まります）。特に、何らかのインジェクション経路があるページは要注意です。([Django Project][2])
* 正当な理由なく、広く `unsafe-inline` を許可するなど、過度に寛容なディレクティブをCSPで使用している。

検出の手がかり:

* `SECURE_CSP`、`SECURE_CSP_REPORT_ONLY`、CSPミドルウェアの設定を検索します。
* リバースプロキシ/CDNの設定でCSPヘッダーを調べます。

修正:

* 現実的なCSPを実装します。可能であれば、まずレポートのみのモードで運用し、その後に強制モードへ移行します。([Django Project][3])

---

### DJANGO-AUTH-001: パスワードの保存にはDjangoの安全なハッシャーを使い、パスワードポリシーを設定する

深刻度: 高

必須事項:

* Django組み込みのパスワードハッシュ化を使わなければなりません（平文または元に戻せる暗号化パスワードを保存してはなりません）。
* 最新のハッシャーを優先し、既定値を最新の状態に保つべきです。Djangoのドキュメントでは `PASSWORD_HASHERS` が説明されており、最新の選択肢（Argon2、bcrypt、scrypt、PBKDF2の各種方式）が含まれています。([Django Project][3])
* 本番環境のパスワードポリシーとして `AUTH_PASSWORD_VALIDATORS` を設定するべきです（既定値は空です）。([Django Project][3])

安全でないパターン:

* 独自のパスワード保存またはハッシュ化。
* DBフィールドに保存された平文パスワード。
* 消費者向けアプリでパスワード検証を行っていない。

検出の手がかり:

* 手動のハッシュ化と比較しながら、`.set_password(` の使用状況を検索します。
* 設定内の `PASSWORD_HASHERS` と `AUTH_PASSWORD_VALIDATORS` を調べます。([Django Project][3])

修正:

* Djangoの認証ユーザーモデルAPIを使います。
* 製品のリスクプロファイルに適したパスワードバリデーターを有効にします。([Django Project][3])

---

### DJANGO-AUTHZ-001: 認可を明示的かつ一貫して行う

深刻度: 高

必須事項:

* 特権を要する操作（閲覧、変更、管理者相当の操作）ごとに、認可チェックを必ず実施しなければなりません。
* サーバー側の権限チェックなしに、UI上の制限（例: ボタンを隠す）だけに依存してはなりません。
* 該当する場合は、Djangoの権限やグループ、およびオブジェクト単位の認可パターンを使うべきです。

安全でないパターン:

* 「ログイン済みなら操作してよい」と想定しているビュー。
* 更新・削除エンドポイントに認可チェックがない。

検出の手がかり:

* 状態を変更するビューを列挙し、所有権や権限を検証しているか確認します。
* オブジェクト単位のアクセスを確認せず、`is_authenticated` のみ、または `is_staff` のみを使っていないか確認します。

修正:

* 明示的な権限チェックと、認可されていないアクセスを確認するテストを追加します。

---

### DJANGO-ADMIN-001: Django管理サイトを価値の高い攻撃対象として扱う

深刻度: 高

必須事項:

* 管理サイトを強力な認証とHTTPSのみの通信で保護しなければなりません（DJANGO-HTTPS-001を参照）。([Django Project][1])
* 可能な場合は、管理サイトへの露出を制限するべきです（ネットワーク許可リスト、VPN、SSO、追加の認証制御など）。
* インストール済みの管理サイト拡張機能とサードパーティアプリについて、XSS/CSRFのリスクを監査するべきです。

安全でないパターン:

* 認証が弱いまま、管理サイトをインターネットに公開している。
* 管理サイトをHTTPで配信している。

検出の手がかり:

* `urlpatterns` から `admin.site.urls` を検索します。
* デプロイ設定でIP許可リストや認証ゲートウェイを確認します。

修正:

* ネットワーク制御を追加し、HTTPSを強制します。

---

### DJANGO-LOG-001: ログやエラー報告から秘密情報が漏れないようにする

深刻度: 中〜高

必須事項:

* `SECRET_KEY`、セッションCookie、認証ヘッダー、パスワードリセットトークンなどの秘密情報をログに記録してはなりません。
* 本番環境のログ設定を慎重に行わなければなりません。Djangoのデプロイチェックリストでは、本番環境への移行前にログを見直すよう明示的に求めています。([Django Project][1])
* 例外に機密性の高いコンテキストが含まれて表示されないよう、本番環境では `DEBUG=False` を確実に設定しなければなりません。([Django Project][1])

安全でないパターン:

* 本番環境でリクエストの全ヘッダーやCookieをログに記録する。
* 設定辞書の内容を出力する。
* デバッグ用エラーページ。

検出の手がかり:

* `LOGGING` の設定を調べ、リクエストのヘッダーやCookieをログに記録するミドルウェアを検索します。
* `print(settings` / `logging.info(request.META)` のパターンを検索します。

修正:

* 機密情報をマスキングし、秘密情報ではなくIDを記録します。
* 構造化ログと安全なエラー監視ツールを使います。([Django Project][1])

---

### DJANGO-SUPPLY-001: 依存関係とパッチを適切に管理する（Djangoおよびセキュリティ上重要な依存関係）

深刻度: 中（既知の脆弱なバージョンを使用している場合は高）

必須事項:

* Djangoおよびセキュリティ上重要な依存関係のバージョンを固定し、定期的に更新するべきです。
* Djangoのセキュリティリリースには速やかに対応しなければなりません。

検出の手がかり:

* `requirements.txt`、ロックファイル、ビルドイメージを確認します。
* Djangoのバージョンを特定し、サポート対象の最新リリースと比較します（Djangoのダウンロードページには、現在の安定版とサポート対象のブランチが掲載されています）。([Django Project][9])

修正:

* パッチ適用済みのバージョンにアップグレードし、過去に脆弱だったクラスに対する回帰テストを追加します。

---

## 5) 実践的なスキャンのヒューリスティクス（「探し方」）

実際にスキャンする際は、次の検出精度の高いパターンを使います。

* デプロイ/開発用サーバー:

  * `manage.py runserver`、`runserver 0.0.0.0`、`--insecure` ([Django Project][1])
* デバッグ/設定:

  * `DEBUG = True` ([Django Project][1])
  * `SECRET_KEY =`、`SECRET_KEY_FALLBACKS` ([Django Project][1])
* ホスト検証:

  * `ALLOWED_HOSTS = ['*']` ([Django Project][3])
* HTTPSとプロキシ:

  * `SECURE_SSL_REDIRECT`、`SECURE_HSTS_SECONDS`、`SECURE_PROXY_SSL_HEADER` ([Django Project][3])
* Cookie/セッション:

  * `SESSION_COOKIE_SECURE`、`SESSION_COOKIE_HTTPONLY`、`SESSION_COOKIE_SAMESITE` ([Django Project][3])
  * `CSRF_COOKIE_SECURE`、`CSRF_COOKIE_HTTPONLY`、`CSRF_COOKIE_SAMESITE` ([Django Project][3])
* CSRFのバイパス:

  * `csrf_exempt`、`CsrfViewMiddleware` がない箇所、`{% csrf_token %}` のないPOSTフォーム ([Django Project][4])
* XSS:

  * `|safe`、`autoescape off`、`mark_safe(`、HTML文字列の連結 ([Django Project][5])
* SQLインジェクション:

  * `.raw(`、`.extra(`、`RawSQL(`、SQL文字列の書式化とともに使われる `cursor.execute(` ([Django Project][7])
* ユーザーアップロード/メディア:

  * `request.FILES`、`MEDIA_ROOT`、`MEDIA_URL`、メディアのインライン配信、`MEDIA_ROOT == STATIC_ROOT` ([Django Project][1])
* リダイレクト:

  * `redirect(request.GET.get("next"))` のパターン、許可リスト検証の欠如
* セキュリティヘッダーとCSP:

  * `SecurityMiddleware` がない、X-Frame-Optionsによる保護がない、適切な場合に `SECURE_CSP` が導入されていない ([Django Project][2])

必ず次の点を確認します。

* データの由来（信頼できるか、信頼できないか）
* 使用先の種類（テンプレート/SQL/サブプロセス/ファイル/リダイレクト/HTTP）
* 保護制御（ミドルウェア、検証、許可リスト、認可チェック）の有無
* セキュリティヘッダーや制御がアプリ内とエッジのどちらで設定されているか

---

## 6) 出典（2026-01-27にアクセス）

Djangoの一次資料:

```text
- Django Downloads (current stable & supported branches): https://www.djangoproject.com/download/
- Django 6.0 Release Notes: https://docs.djangoproject.com/en/6.0/releases/6.0/
- Django: Deployment checklist (incl. check --deploy, runserver warning, HTTPS/cookies guidance): https://docs.djangoproject.com/en/6.0/howto/deployment/checklist/
- Django: Settings reference (SecurityMiddleware settings, cookies, SECRET_KEY_FALLBACKS, CSP settings): https://docs.djangoproject.com/en/6.0/ref/settings/
- Django: Security in Django (XSS/CSRF/SQLi/clickjacking/HTTPS/host header validation/uploads/CSP): https://docs.djangoproject.com/en/6.0/topics/security/
- Django: CSRF how-to (middleware, csrf_token usage, AJAX header patterns, csrf_exempt cautions): https://docs.djangoproject.com/en/6.0/howto/csrf/
- Django: Performing raw SQL queries (parameterization guidance): https://docs.djangoproject.com/en/6.0/topics/db/sql/
- Django: QuerySet API reference (extra() cautions; “do not quote placeholders” guidance): https://docs.djangoproject.com/en/6.0/ref/models/querysets/
- Django: Template built-ins (autoescape tag): https://docs.djangoproject.com/en/6.0/ref/templates/builtins/
- Django: Template language reference (turning off autoescape & risks): https://docs.djangoproject.com/en/6.0/ref/templates/language/
- Django: Utilities reference (e.g., format_html): https://docs.djangoproject.com/en/6.0/ref/utils/
```
OWASP:

```text
- OWASP Cheat Sheet Series: Django Security Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Django_Security_Cheat_Sheet.html
```

[1]: https://docs.djangoproject.com/en/6.0/howto/deployment/checklist/ "https://docs.djangoproject.com/en/6.0/howto/deployment/checklist/"
[2]: https://docs.djangoproject.com/en/6.0/topics/security/ "Django のセキュリティ | Django ドキュメント | Django"
[3]: https://docs.djangoproject.com/en/6.0/ref/settings/ "設定 | Django ドキュメント | Django"
[4]: https://docs.djangoproject.com/en/6.0/howto/csrf/ "Django の CSRF 保護の使い方 | Django ドキュメント | Django"
[5]: https://docs.djangoproject.com/en/6.0/ref/templates/builtins/ "https://docs.djangoproject.com/en/6.0/ref/templates/builtins/"
[6]: https://docs.djangoproject.com/en/6.0/ref/utils/ "https://docs.djangoproject.com/en/6.0/ref/utils/"
[7]: https://docs.djangoproject.com/en/6.0/topics/db/sql/ "https://docs.djangoproject.com/en/6.0/topics/db/sql/"
[8]: https://docs.djangoproject.com/en/6.0/ref/models/querysets/ "https://docs.djangoproject.com/en/6.0/ref/models/querysets/"
[9]: https://www.djangoproject.com/download/ "Django をダウンロード | Django"