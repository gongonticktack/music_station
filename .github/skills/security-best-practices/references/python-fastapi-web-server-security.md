# FastAPI（Python）Web セキュリティ仕様（FastAPI 0.128.x、Python 3.x）([PyPI][1])

このドキュメントは、次を支援する**セキュリティ仕様**として作成されています。

1. 新しい FastAPI コードを**デフォルトで安全に生成する**こと。
2. 既存の FastAPI コードの**セキュリティレビュー／脆弱性調査**（作業中に受動的に「問題に気づく」こと、および能動的に「リポジトリをスキャンして調査結果を報告する」こと）。

これは意図的に、**規範的な要件**（「MUST/SHOULD/MAY」）と**監査ルール**（悪いパターンの例、それを検出する方法、修正または緩和する方法）をまとめた文書として記述されています。

FastAPI は一般に ASGI サーバー（例：Uvicorn）とともにデプロイされ、Starlette と Pydantic の上に構築されているため、この仕様ではセキュリティに影響する範囲でそれらのレイヤーも扱います。([PyPI][1])

---

## 0) 安全性、境界、悪用防止の制約（必ず遵守）

* シークレット（API キー、パスワード、秘密鍵、セッション Cookie、署名鍵、認証情報を含むデータベース URL）を要求、出力、ログ記録、またはコミットしてはなりません。
* 保護機能を無効にすることでセキュリティを「修正」してはなりません（例：認証を弱める、CORS を緩くする、署名チェックを省略する、検証を無効にする、TLS 検証をオフにする、認証情報を含む `allow_origins=["*"]` を追加する）。
* 監査では、**根拠に基づく調査結果**を提示しなければなりません。主張の根拠となるファイルパス、コードスニペット、設定値を示してください。
* 不確実性は正直に扱ってください。保護機能がインフラストラクチャ（リバースプロキシ、WAF、CDN、サービスメッシュ）に存在する可能性がある場合は、「アプリケーションコードからは確認できない。実行時／設定で確認すること」と報告してください。
* ブラウザーの制御機能を正しく扱ってください。

  * CORS は認証の仕組みではなく、ブラウザーにのみ影響します。
  * CSRF 対策が適用されるのは、ブラウザーが認証情報（Cookie）を自動的に付与する場合です。ヘッダートークンのみを使う API では通常関係ありません。([OWASP Cheat Sheet Series][2])

---

## 1) 動作モード

### 1.1 生成モード（デフォルト）

新しい FastAPI コードの作成、または既存コードの変更を依頼された場合：

* この仕様の**すべての MUST 要件**に従わなければなりません。
* ユーザーが明示的に別の指示をしない限り、**すべての SHOULD 要件**に従うべきです。
* 独自のセキュリティコードより、安全なデフォルトの API と実績のあるライブラリを優先しなければなりません。
* 新たなリスクの高い処理箇所（シェル実行、安全でないデシリアライズ、動的な eval、信頼できないテンプレートのレンダリング、安全でないファイル配信、安全でないリダイレクト、任意の外部取得）を追加してはなりません。

### 1.2 受動的レビュー・モード（編集中は常に有効）

FastAPI リポジトリ内のどこで作業している場合でも（ユーザーがセキュリティスキャンを依頼していない場合も含む）：

* 変更対象およびその周辺コードで、この仕様への違反に気づかなければなりません。
* 問題が見つかったら、簡潔な説明と安全な修正方法を添えて指摘するべきです。

### 1.3 能動的監査モード（明示的なスキャン依頼時）

ユーザーから「スキャン」「監査」「脆弱性を探す」と依頼された場合：

* この仕様への違反がないか、コードベースを体系的に検索しなければなりません。
* 調査結果を構造化された形式（§2.3 参照）で出力しなければなりません。

推奨する監査順序：

1. アプリケーションのエントリーポイント／デプロイスクリプト／Dockerfile／Procfile／Helm／Terraform。
2. ASGI サーバーの設定（Uvicorn/Gunicorn）、プロキシ設定、debug／reload 設定。
3. FastAPI アプリケーションの設定（ドキュメントの公開、ミドルウェア、信頼するホスト、CORS）。
4. 認証／認可の設計（依存関係、JWT／セッションの処理、パスワードの保存）。
5. Cookie／セッションの利用と CSRF（Cookie を使用している場合）。
6. 入力検証と出力の整形（Pydantic モデル、過剰なデータ露出）。
7. テンプレートのレンダリングと XSS／SSTI（HTML を配信する場合）。
8. ファイル処理（アップロードとダウンロード）、StaticFiles、Range サポート。
9. インジェクションの種類（SQL、コマンド実行、安全でないデシリアライズ）。
10. 外部へのリクエスト（SSRF）、リダイレクト処理、WebSocket のセキュリティ。

---

## 2) 定義とレビュー指針

### 2.1 信頼できない入力（信頼できると証明されない限り、攻撃者が制御できるものとして扱う）

例：

* クエリパラメーター／パスパラメーター
* JSON ボディ（ネストされたフィールドを含む）
* ヘッダー（`Host`、`Origin`、`X-Forwarded-*` を含む）
* Cookie（セッション Cookie を含む）
* ファイルアップロード（multipart パート）
* WebSocket のメッセージ、クエリパラメーター、ハンドシェイク中のヘッダー ([Starlette][3])
* 外部システムからのあらゆるデータ（Webhook、サードパーティ API、メッセージキュー）
* ユーザーに由来する、永続化されたユーザーコンテンツ（DB の行など）

### 2.2 状態を変更するリクエスト

データの作成／更新／削除、認証／セッション状態の変更、副作用（購入、メール送信、Webhook 送信）の発生、または特権操作の開始が可能なリクエストは、状態を変更するリクエストです。

### 2.3 必須の監査結果フォーマット

見つかった各問題について、次を出力してください。

* ルール ID：
* 重大度：Critical / High / Medium / Low
* 場所：ファイルパス＋関数／ルート名＋行番号
* 根拠：該当するコード／設定の正確なスニペット
* 影響：何が起こり得るか、誰が悪用できるか
* 修正：安全な変更（最小限の差分を優先）
* 緩和策：即時の修正が難しい場合の多層防御
* 誤検知に関する注記：不確実な場合に確認すべき点

---

## 3) 安全なベースライン：本番環境の最低限の設定（本番環境では必須）

これは、FastAPI／ASGI でよくある設定ミスを防ぐための、最小限の「本番ベースライン」です。

ベースラインの目標：

* 本番環境で、debug のトレースバックや自動リロードを無効にする。([PyPI][4])
* ワーカー、タイムアウト、リソース制御を設定した本番用 ASGI サーバーで実行する。([PyPI][4])
* Host ヘッダーの検証を有効にする（TrustedHostMiddleware または同等の機能）。([PyPI][5])
* 明示的に必要でない限り CORS を無効にする。有効にする場合は厳格に設定し、最小権限にする。([OWASP Cheat Sheet Series][6])
* 依存関係を通じて一貫して認証を適用する（「このルートの認証を忘れた」という事態を避ける）。([FastAPI][7])
* Cookie／セッションを使用する場合、Cookie フラグを安全に設定し、CSRF 対策を講じる。([OWASP Cheat Sheet Series][8])
* リクエストサイズと multipart の上限をエッジで設定し、必要に応じてアプリケーションでも検証する（メモリ／CPU の DoS を緩和するため）。([advisories.gitlab.com][9])
* 特に Starlette／python-multipart の依存パッケージに速やかにパッチを適用する（過去に複数の DoS およびパストラバーサルの勧告がある）。([advisories.gitlab.com][10])

---

## 4) ルール（生成＋監査）

各ルールには、必須の実践事項、安全でないパターン、検出の手掛かり、修正方法が含まれます。

### FASTAPI-DEPLOY-001: 本番環境で自動リロード／開発専用サーバーモードを使用しない

重大度：High（本番環境の場合）

必須事項：

* 自動リロード／監視モード（例：Uvicorn の reload）で本番環境を実行してはなりません。
* 本番用のプロセスモデル（例：適切な場合は複数ワーカー）と安定したサーバー設定で実行しなければなりません。([PyPI][4])

安全でないパターン：

* 本番環境のエントリーポイントにある `uvicorn ... --reload`（または同等の「reload=True」設定）。
* 本番環境で `--reload` を使って実行する Docker／Procfile／systemd のコマンド。

検出の手掛かり：

* `--reload`、`reload=True`、`watchfiles`、`fastapi dev`、「development」の実行スクリプトを検索します。
* Docker CMD／ENTRYPOINT、Procfile、systemd ユニット、シェルスクリプトを確認します。

修正：

* 本番環境では reload を削除し、安定した設定と明示的なワーカー構成で Uvicorn／Gunicorn を実行します。([PyPI][4])

注：

* ローカル開発では reload を使用してかまいません。本番環境のエントリーポイントとして明確に使われている場合にのみ指摘します。

---

### FASTAPI-DEPLOY-002: 本番環境では debug モードを無効にすること

重大度：Critical

必須事項：

* 本番環境で debug のトレースバックを有効にしてはなりません（FastAPI／Starlette の debug モードは機密性の高い内部情報を露出させ、攻撃を成立させやすくする可能性があります）。([PyPI][5])
* クライアントに詳細なスタックトレースを返す設定は、機密性の高いものとして扱わなければなりません。

安全でないパターン：

* `app = FastAPI(debug=True)`（または Starlette の `debug=True`）、あるいは本番環境で debug を有効にする同等の環境設定。([PyPI][5])
* エンドユーザーにトレースバックを見せるサーバー／ログ設定。

検出の手掛かり：

* `debug=True`、`DEBUG = True`、debug に割り当てられる環境フラグを検索します。
* 例外ミドルウェアとエラーハンドラーの設定を確認します。

修正：

* debug はローカル開発／テストでのみ有効にします。
* クライアントには一般的なエラーレスポンスを返し、詳細は内部でログに記録します。

---

### FASTAPI-OPENAPI-001: 本番環境では OpenAPI と対話型ドキュメントを無効にするか、保護すること

重大度：Medium（機密性の高い／内部向けアプリでは High の場合あり）

必須事項：

* 明示的な業務上の必要がない限り、一般公開サービスでは本番環境の `/docs`、`/redoc`、`/openapi.json` を無効にするべきです。
* 有効にする場合は、保護しなければなりません（例：認証、ネットワークの許可リスト、内部専用のルーティング）。
* 「隠すことで安全になる」と考えてはなりません。ドキュメントの公開は情報漏えいの影響を増幅させるものとして扱ってください。

安全でないパターン：

* 内部／管理用 API の `/docs` と `/openapi.json` に、誰でもアクセスできる。
* 本番環境の同じホスト名上で、アクセス制御なしにドキュメントを有効にしている。

検出の手掛かり：

* `FastAPI(docs_url=..., redoc_url=..., openapi_url=...)` またはデフォルト設定を確認します。
* リバースプロキシのルーティングと許可リストを確認します。

修正：

* 本番環境ではドキュメントのエンドポイントを無効にする（`docs_url=None`、`redoc_url=None`、`openapi_url=None`）か、エッジでアクセスを制限します。

---

### FASTAPI-AUTH-001: 認証を明示し、依存関係を通じて一貫して適用すること

重大度：High

必須事項：

* 保護対象のエンドポイントで認証を「忘れる」ことがないよう、認証は依存関係（またはルーター単位の依存関係）として実装しなければなりません。
* 特権ルーター／エンドポイントではデフォルトで拒否し、本当に公開するルートだけを明示しなければなりません。
* ルーター境界で認証の適用を一元化するべきです（例：認証済みエンドポイント用の保護された `APIRouter`）。([FastAPI][7])

安全でないパターン：

* ハンドラー内に場当たり的な認証チェックが分散している（見落としやすい）。
* 明確なポリシーがないまま、保護されたエンドポイントと保護されていないエンドポイントが混在している。

検出の手掛かり：

* ルーターとエンドポイントを特定し、保護対象に `Depends(...)`／`Security(...)` が含まれているか確認します。
* 依存関係の代わりにハンドラー内で使われている `if user is None: raise ...` のようなパターンを検索します。

修正：

* 認証を依存関係に移し、`Depends()`／`Security()` を使ってルーター／エンドポイントに一貫して適用します。([FastAPI][7])

---

### FASTAPI-AUTH-002: 標準的な認証情報の受け渡し方法を使い、URL にシークレットを含めない

重大度：High

必須事項：

* トークン認証にはクエリパラメーターではなく、`Authorization: Bearer <token>` ヘッダーを使うべきです。([FastAPI][11])
* 避けられる場合、シークレット（トークン、長期間有効なシークレットを含むリセットリンク、API キー）をクエリ文字列に含めてはなりません。

安全でないパターン：

* 主な認証手段として `?token=...`、`?api_key=...`、`?auth=...` を使っている。
* 長期間有効なアクセストークンを URL に埋め込んでいる（ログ、リファラー、キャッシュを通じて漏えいする）。

検出の手掛かり：

* `token`、`api_key`、`key`、`secret`、`password` のようなパラメーター名を検索します。
* 正当な理由なく、クエリ API キーを使うセキュリティスキームを確認します。

修正：

* トークンを Authorization ヘッダーに移し、有効期間を短縮するかローテーションし、機密値には POST ボディを使います。

---

### FASTAPI-AUTH-003: パスワードは強固にハッシュ化して保存し、平文では決して保存しない

重大度：Critical

必須事項：

* パスワードは、強度が高く計算コストの大きいパスワードハッシュ方式（例：Argon2id、bcrypt）を使って保存しなければなりません。
* パスワードを平文で保存してはなりません。また、可逆暗号化を主な保護手段として使ってはなりません。
* ハッシュ化と検証には、実績のあるライブラリを使うべきです（独自実装をしないでください）。

安全でないパターン：

* パスワードを平文でデータベースに保存している。
* 適切なパスワードハッシュ KDF を使わず、高速なハッシュ（例：SHA256）を使用している。
* API レスポンスでパスワードハッシュを返している。

検出の手掛かり：

* 永続化される `password=` フィールドを検索し、パスワードに対する `hashlib.md5/sha1/sha256` の使用箇所を確認します。
* レスポンスモデルにパスワード／ハッシュのフィールドがないか調べます。

修正：

* 適切なパスワードハッシュライブラリに移行し、ログイン時に再ハッシュして更新する経路を追加します。

---

### FASTAPI-AUTH-004: JWT を厳格に検証し、JWT にシークレットを含めない

重大度：High

必須事項：

* JWT の署名を検証し、許可するアルゴリズムを限定しなければなりません。
* システムに応じて標準クレームを検証しなければなりません（最低でも `exp`。複数サービスまたは複数テナントの場合は、通常 `iss`／`aud` も検証します）。
* JWT の内容はクライアントが読めるものとして扱い、JWT のペイロードにシークレットを含めてはなりません。([FastAPI][12])

安全でないパターン：* `jwt.decode(..., options={"verify_signature": False})` または同等のもの。
* `alg=none` を受け入れること／アルゴリズム混同。
* JWT ペイロードに機密情報（API キー、パスワード）を保存すること。

検出のヒント:

* `jwt.decode`、`python-jose`、`PyJWT`、`verify_signature` を検索する。
* exp の検証漏れや有効期限が長すぎないか確認する。

修正:

* 厳格な検証（署名、許可されたアルゴリズム、exp、および必要な発行者／対象者の制約）を適用する。
* クライアントに公開しても問題のない識別子／クレームだけを保存する。([FastAPI][12])

---

### FASTAPI-AUTHZ-001: オブジェクト単位およびプロパティ単位で認可を必ず適用する

重大度: 高

必須事項:

* ユーザーが制御する識別子（パス／クエリ／本文内の ID）でリソースにアクセスする場合は、必ずオブジェクトレベルの認可を行う。
* 「過剰なデータ露出」（例: 管理者専用フィールド）を防ぐため、必ずプロパティレベルの認可とレスポンスの整形を行う。([OWASP Foundation][13])

安全でないパターン:

* `GET /users/{id}` が、呼び出し元にその `id` へのアクセス権があるか確認せずにユーザーレコードを返す。
* レスポンスモデルに内部フィールド（ロール、権限、請求データ、パスワードハッシュ）が含まれている。

検出のヒント:

* ID を受け取るエンドポイントを列挙し、認可チェックが行われているか追跡する。
* 公開用と内部用のレスポンスモデルを比較し、フィールドを確認する。

修正:

* オブジェクトレベルのチェック（所有権、ACL、テナント境界）を追加する。
* 許可されたフィールドのみを含む専用のレスポンスモデルを使用する。

---

### FASTAPI-SESS-001: Cookie ベースのセッションと TLS を使用する場合、本番環境では Cookie 属性を必ず安全に設定する

重大度: 高（TLS が有効な場合のみ）

必須事項（本番環境、HTTPS）:

* セッション Cookie は HTTPS 経由でのみ送信されるよう（secure）必ず設定する。重要: TLS が設定されている本番環境でのみ `Secure` を設定する。HTTP を使うローカル開発環境では、Cookie の `Secure` プロパティを設定しないこと。アプリが本番モードで実行されているかに応じて条件付きで設定すること。また、HTTP 経由のテスト時に `Secure` Cookie を無効化できる `SESSION_COOKIE_SECURE` のようなプロパティも含めること。
* セッション Cookie には HttpOnly を必ず設定する（JavaScript からアクセスできないようにする）。
* `SameSite=Lax` を使用すること（UX が許容する場合は `Strict`）。クロスサイト Cookie が必要な場合は、CSRF への影響を文書化し、補完的な対策を追加する。([OWASP Cheat Sheet Series][8])
* Starlette の `SessionMiddleware` を使用する場合、本番環境では `https_only=True` を必ず設定し、適切な `same_site` を選択する。([PyPI][5])

安全でないパターン:

* Secure/HttpOnly が設定されていないセッション Cookie。
* CSRF 対策なしで、認証済みの状態変更エンドポイントに `SameSite=None` Cookie を使用する。

検出のヒント:

* `SessionMiddleware(` を検索し、`https_only`、`same_site` などのパラメーターを確認する。
* `set_cookie(` の使用箇所と Cookie フラグを検索する。

修正:

* Cookie の安全属性を設定し、権限の高いセッションには短い有効期間を優先する。([OWASP Cheat Sheet Series][8])

---

### FASTAPI-SESS-002: 署名付きセッション Cookie に機密情報を保存しない

重大度: 高

必須事項:

* Cookie ベースのセッションデータはクライアントから読み取り可能である（署名付き ≠ 暗号化済み）と想定し、サーバー側で暗号化しない限り、秘密情報／個人情報を保存しない。
* Cookie には不透明な識別子（例: セッション ID）または機密性のない状態のみを保存し、機密性のあるセッション状態はサーバー側に保存する。([OWASP Cheat Sheet Series][8])

安全でないパターン:

* アクセストークン、リフレッシュトークン、または個人情報を Cookie セッションのペイロードに直接保存する。
* 「署名付き Cookie」を機密情報の保管場所として扱う。

検出のヒント:

* `request.session[...] =` または `session[...] =` 相当のパターンを検索し、何が保存されているかを特定する。
* `SessionMiddleware` またはその他の Cookie セッション機構の使用を特定する。

修正:

* 機密情報をサーバー側ストレージに移し、Cookie の内容を最小限にする。

---

### FASTAPI-CSRF-001: Cookie 認証による状態変更リクエストには必ず CSRF 対策を施す

重大度: 高

注: これは Cookie ベースの認証を使用する場合にのみ適用される。Authorization ヘッダーなどのヘッダーまたはトークンベースの認証を使用するアプリケーションでは、通常 CSRF は問題にならない。

必須事項:

* 認証に Cookie を使用するすべての状態変更エンドポイント（POST/PUT/PATCH/DELETE）を必ず保護する。
* 独自実装ではなく、実績のある CSRF 対策（同期トークンパターン、または十分にレビューされたミドルウェア）を使用すること。([OWASP Cheat Sheet Series][2])
* 多層防御として Origin/Referer チェック、SameSite Cookie、Fetch Metadata を追加してもよいが、Cookie 認証アプリではトークンが主たる防御策となる。([OWASP Cheat Sheet Series][2])
* 重要: 認証に Cookie を使用しない場合（認証が `Authorization` ヘッダー経由の場合）、通常 CSRF は該当しない。([FastAPI][11])

安全でないパターン:

* CSRF 検証のない、状態を変更する Cookie 認証エンドポイント。
* 状態変更操作に GET を使用すること（CSRF リスクを高める）。

検出のヒント:

* GET 以外のメソッドを使うルートを列挙し、認証に Cookie が使われているか特定する。
* CSRF トークンの生成／検証やミドルウェアを探す。

修正:

* Cookie 認証を使用する場合は、状態変更操作に CSRF トークンを追加して検証する。([OWASP Cheat Sheet Series][2])

---

### FASTAPI-VALID-001: リクエストの解析と検証は必ずスキーマ駆動にし、一括割り当てを防止する

重大度: 中（特に DB に書き込む API）

必須事項:

* リクエスト本文に任意の `dict`/`Any` を受け入れるのではなく、Pydantic モデルを使用すること。
* 適切な場合は、予期しないフィールドを拒否するようモデルを設定すること（「一括割り当て」型の不具合を防ぐ）。
* 識別子（ID、メールアドレス、URL）は、アクセス制御や副作用に使用する前に必ず検証し、正規化する。([OWASP Cheat Sheet Series][14])

安全でないパターン:

* `payload = await request.json()` の後に `Model(**payload)` を行う、または許可リストなしで `payload` を使って DB に直接書き込む。
* 書き込みエンドポイントで未知のフィールドを黙って受け入れるモデル。

検出のヒント:

* `await request.json()`、`request.body()`、`dict` 型の本文、`Any` 型の本文を検索する。
* フィルタリングされていない入力を使って `db.update(**payload)` または `Model(**payload)` を行うエンドポイントを探す。

修正:

* 許可するフィールドを明示した Pydantic モデルを使用し、書き込みエンドポイントでは余分なフィールドを拒否する。([OWASP Cheat Sheet Series][14])

---

### FASTAPI-RESP-001: レスポンスモデルと明示的なシリアライズで過剰なデータ露出を防止する

重大度: 中

必須事項:

* 含めるフィールドのみを含むレスポンスモデルを必ず定義する（特にユーザー、認証関連、請求関連のオブジェクト）。
* 機密フィールドの漏えいを避けるため、「作成入力」「DB／内部用」「公開出力」には別々のモデルを使用すること。([FastAPI][15])

安全でないパターン:

* 内部カラムを含む ORM オブジェクトや辞書を返す。
* 「DB モデル」をレスポンスモデルとして再利用する（`password_hash`、`is_admin` などを含む）。

検出のヒント:

* `user` が ORM インスタンスであるときに `return user` するエンドポイントを探す。
* 機密リソースを返すエンドポイントで `response_model` が省略されていないか確認する。

修正:

* 明示的なレスポンスモデルを追加し、機密フィールドを除外した「公開用」スキーマを作成する。([FastAPI][15])

---

### FASTAPI-XSS-001: HTML レスポンスとテンプレートで反射型／格納型 XSS を防止する

重大度: 高（サービスが HTML を提供する場合）

必須事項:

* HTML では、自動エスケープを有効にしたテンプレート機能を必ず使用する。
* 信頼できないコンテンツを安全なものとして扱ってはならない（ユーザー制御データを「生 HTML」として安全でない形でレンダリングしない）。
* ユーザーコンテンツを含む HTML を提供する場合は、CSP を導入すること。([OWASP Cheat Sheet Series][16])

安全でないパターン:

* エスケープ／サニタイズせずにユーザーコンテンツを HTML に直接レンダリングする。
* 自動エスケープを無効にする、またはサニタイズなしで「生 HTML」機能を使用する。

検出のヒント:

* テンプレートのレンダリングと、HTML を組み立てる文字列連結を検索する。
* テンプレート内の「安全でない」フィルター／構文や、引用符で囲まれていない属性を確認する。

修正:

* 自動エスケープを有効のままにする。ユーザー HTML がどうしても必要な場合のみ、信頼できるサニタイザーでサニタイズし、CSP を追加する。([OWASP Cheat Sheet Series][16])

注:

* 純粋な JSON API では、通常 XSS はクライアント／アプリ側の問題だが、エラーページやドキュメントページが HTML をレンダリングする場合がある。

---

### FASTAPI-SSTI-001: 信頼できないテンプレートを決してレンダリングしない（サーバーサイド・テンプレート・インジェクション）

重大度: 重大

必須事項:

* ユーザーが制御するテンプレート構文を含むテンプレートを決してレンダリングしてはならない。
* 「文字列からのテンプレート」レンダリングが、信頼できない入力の影響を受ける場合は危険なものとして扱う。
* 信頼できないテンプレートがどうしても必要な場合（まれで高リスク）:

  * サンドボックス化されたテンプレート方式を必ず使用し、機能を制限する。
  * サンドボックスの脱出が起こり得ると想定し、隔離と厳格な許可リストを追加する。([OWASP Foundation][17])

安全でないパターン:

* 通常の Jinja 環境で、ユーザー入力や DB から読み込んだテンプレートをレンダリングする。
* ユーザー制御の文字列を使ってテンプレートを動的に組み立てる。

検出のヒント:

* Jinja の `Environment.from_string`、`Template(...)`、または類似のものを検索する。
* テンプレート文字列の出所（リクエスト、DB、アップロード、管理画面）を追跡する。

修正:

* 実行機能のないテンプレート方式（単純な文字列置換）に置き換える。
* 本当に必要な場合は、Jinja のサンドボックス環境と強力な隔離を使用する。([jinja.palletsprojects.com][18])

---

### FASTAPI-HEADERS-001: 重要なセキュリティヘッダーを設定する（アプリ内またはエッジで）

重大度: 中

必須事項（一般的な API／Web アプリ）:

* 次を設定すること:

  * `X-Content-Type-Options: nosniff`
  * HTML を提供する場合はクリックジャッキング対策（`X-Frame-Options` および／または CSP `frame-ancestors`）
  * 必要に応じて `Referrer-Policy` および `Permissions-Policy`

注:

* ヘッダーはプロキシ／CDN で設定されている場合がある。アプリのコード上で確認できない場合は、「エッジで確認」として記録する。([OWASP Cheat Sheet Series][6])

安全でないパターン:

* HTML を提供するアプリや機密性の高い API で、アプリにもエッジにもセキュリティヘッダーがない。

検出のヒント:

* ヘッダーを設定するミドルウェアを検索し、リバースプロキシの設定を確認する。

修正:

* ミドルウェアまたはリバースプロキシ／CDN でヘッダーを一元的に設定する。

---

### FASTAPI-CORS-001: CORS は明示的かつ最小権限で設定する

重大度: 中（認証情報を含む設定が誤っている場合は高）

必須事項:

* CORS が不要な場合は、必ず無効のままにする。
* CORS が必要な場合:

  * 信頼できるオリジンを必ず許可リストに登録する（任意のオリジンをそのまま反映しない）。
  * 認証情報を含むリクエストとワイルドカードのオリジンを組み合わせてはならない（安全ではなく、準拠したミドルウェアでは一般に拒否される）。([OWASP Cheat Sheet Series][6])
  * 許可するメソッドとヘッダーを制限すること。

安全でないパターン:

* `allow_origins=["*"]` と `allow_credentials=True` を併用する。
* 検証せずに `Origin` を反映する。
* `allow_origin_regex=".*"` を広範に使用する。

検出のヒント:

* `CORSMiddleware` の設定を検索する。
* `allow_origins=["*"]`、`allow_credentials=True`、`allow_origin_regex` を探す。

修正:

* 明示的なオリジン許可リストと最小限のメソッド／ヘッダーを使用し、必要な場合を除き認証情報を無効にする。([OWASP Cheat Sheet Series][6])

---

### FASTAPI-HOST-001: 本番環境では Host ヘッダーを必ず検証する

重大度: 低

必須事項:

* 受け入れる Host 値を制限するため、`TrustedHostMiddleware`（またはエッジでの同等機能）を使用すること。([PyPI][5])
* 検証せずに、セキュリティ上重要な判断で `Host` ヘッダーを信頼してはならない。

安全でないパターン:

* リクエストの Host からパスワード再設定リンクやコールバック URL などの外部 URL を生成する際に、Host を検証しない。
* 許容的なプロキシの背後にあるアプリで、任意の Host ヘッダーを許可する。

検出のヒント:

* `TrustedHostMiddleware` の使用箇所を検索する。
* `request.url`、`request.base_url`、または Host 由来の値を使って外部 URL を構築するロジックを検索する。

修正:

* 本番環境では厳格な許可済み Host の一覧を設定し、可能であればエッジでも適用する。

---

### FASTAPI-PROXY-001: リバースプロキシの信頼設定を正しく構成する

重大度: 高（プロキシの背後にある場合）

必須事項:

* リバースプロキシの背後にある場合は、転送ヘッダーの信頼設定を必ず正しく構成する。
* 公開インターネットから届く `X-Forwarded-*` ヘッダーを盲目的に信頼してはならない。
* Uvicorn のプロキシヘッダー対応を使用する場合、転送ヘッダーを提供できる IP を必ず制限する。([PyPI][4])

安全でないパターン：

* 信頼するプロキシの IP を制限せずに、プロキシヘッダーを広く有効にする。
* 適切な信頼境界を設けず、転送ヘッダーを使って「安全か」「内部か」「クライアント IP」を判定する。

検出の手がかり：

* `--proxy-headers`、`--forwarded-allow-ips`、または同等の設定を検索する。
* `request.client.host`、`request.url.scheme`、`request.headers["x-forwarded-for"]` のセキュリティ上重要な使い方を検索する。

修正：

* 既知のプロキシの背後にある場合に限り Uvicorn のプロキシヘッダーを設定し、`forwarded_allow_ips` をそのプロキシに限定する。([PyPI][4])
* プロキシの背後でも Host の許可リストを維持する。

---

### FASTAPI-LIMITS-001: DoS を防ぐため、リクエストと multipart の上限を必ず適用する

深刻度：低

必須事項：

* エッジ（リバースプロキシ／ロードバランサー）でリクエストサイズの上限を必ず適用し、必要に応じてアプリ内でも検証する。
* multipart/form-data の処理には特に注意を払う。過去の脆弱性には、無制限のバッファリングや DoS の要因が含まれる。([advisories.gitlab.com][9])
* 負荷の高いエンドポイントには、レート制限や IP／ユーザー単位のスロットリングを適用することが望ましい。

安全でないパターン：

* 任意に大きな JSON 本文や multipart フォームを受け入れる。
* サイズやフィールド数を制限せずに multipart フォームを解析する。

検出の手がかり：

* ファイルアップロードのエンドポイントと `multipart/form-data` の使用箇所を特定する。
* プロキシレベルの上限（nginx `client_max_body_size`、ALB の上限など）やアプリレベルのチェックが欠けていないか確認する。

修正：

* リクエスト本文の厳格なサイズ上限と multipart の制約を適用し、Starlette と python-multipart を修正済みバージョンに更新しておく。([advisories.gitlab.com][9])

---

### FASTAPI-FILES-001: パストラバーサルと安全でない静的ファイル公開を防ぐ

深刻度：高

必須事項：

* ユーザーが制御するファイルパスを、厳格な検証と安全なベースディレクトリを介さずに `FileResponse`／ファイルシステム呼び出しへ渡してはならない。
* `StaticFiles` を使用する場合、Starlette を最新の状態に保ち、セキュリティ上の履歴を把握しておく（古いバージョンにはパストラバーサルの勧告がある）。([advisories.gitlab.com][10])
* 安全な取り扱いをせずに、ユーザーのアップロードを実行可能／アクティブなコンテンツ（特に HTML／JS）として静的ルートから配信してはならない。

安全でないパターン：

* `FileResponse(request.query_params["path"])`
* アップロードに HTML／JS／SVG が含まれ、インラインで配信される場所に `StaticFiles(directory="uploads")` をマウントする。

検出の手がかり：

* ルート内の `FileResponse(`、`StaticFiles(`、`open(` を検索する。
* パスが信頼できない入力に由来するかを追跡する。

修正：

* ファイルには不透明な ID を使い、ID をサーバー側に保存したパスへ対応付ける。
* 適切な場合は、信頼できないコンテンツを添付ファイルとしてダウンロードさせる。

---

### FASTAPI-FILES-002: ファイル配信エンドポイントにおける Range ヘッダー DoS を緩和する

深刻度：低（影響を受けるバージョンを使用し、ファイル配信が有効な場合）

必須事項：

* `FileResponse`／`StaticFiles` を使用する場合、既知のファイル配信 DoS の問題に対する修正が Starlette に適用された状態を必ず維持する。
* 通常と異なる `Range` ヘッダーの処理とファイル配信は、DoS の攻撃対象領域として扱う。([advisories.gitlab.com][19])

安全でないパターン：

* 脆弱な Starlette バージョンで大きなファイルを配信する。
* ファイルのエンドポイントにレート制限や CDN による防御がない。

検出の手がかり：

* Starlette のバージョンを特定し、影響範囲内であれば問題として記録する。
* `FileResponse` と `StaticFiles` の使用箇所を探す。

修正：

* 勧告の指針に従い、修正済みバージョンへ Starlette をアップグレードする。([advisories.gitlab.com][19])
* 適切な場合は、ファイルのエンドポイントにエッジキャッシュ／レート制限を追加する。

---

### FASTAPI-UPLOAD-001: ファイルアップロードは必ず検証し、安全に保存・配信する

深刻度：中

必須事項：

* アップロードサイズの上限を（アプリとエッジの両方で）必ず適用する。
* 拡張子だけでなく、許可リストとコンテンツチェックを使ってファイルの種類を必ず検証する。([OWASP Cheat Sheet Series][20])
* サーバー側でファイル名（ランダム ID）を生成し、元のファイル名を信頼しないことが望ましい。
* 明示的な意図がない限り、アクティブな可能性のある形式は安全に（添付ファイルとしてダウンロードさせて）配信する。

安全でないパターン：

* 任意のファイル形式を受け入れ、そのままインラインで返す。
* ユーザー指定のファイル名を保存パスとして使う。

検出の手がかり：

* アップロードハンドラーと、ファイルの書き込み先や書き込み方法を調べる。
* アップロードディレクトリが直接公開されていないか確認する。

修正：

* 許可リストによる検証、安全な保存、安全な配信を実装し、該当する場合はスキャン／隔離を追加する。([OWASP Cheat Sheet Series][20])

---

### FASTAPI-INJECT-001: SQL インジェクションを防ぐ（パラメーター化クエリ／ORM を使用する）

深刻度：高

必須事項：

* パラメーター化クエリ、または内部でパラメーター化を行う ORM を必ず使用する。
* 信頼できない入力を使い、文字列連結／f-string で SQL を組み立ててはならない。([OWASP Cheat Sheet Series][21])

安全でないパターン：

* `f"SELECT ... WHERE id={user_id}"`
* `"... WHERE name = '%s'" % user_input`

検出の手がかり：

* `.execute(...)` の近くにある Python 文字列内の SQL キーワードを grep で検索する。
* 信頼できないデータが DB 呼び出しへ渡される経路を追跡する。

修正：

* パラメーター化クエリ／ORM のクエリ API に置き換え、クエリ前に型を検証する。([OWASP Cheat Sheet Series][21])

---

### FASTAPI-INJECT-002: OS コマンドインジェクションを防ぐ

深刻度：重大～高（露出状況による）

必須事項：

* 信頼できない入力を含むシェルコマンドの実行を避ける。
* subprocess が必要な場合：

  * 引数は必ずリストで渡す（文字列ではなく）
  * 攻撃者の影響を受ける文字列を使って `shell=True` を使用してはならない
  * 可変部分には厳格な許可リストを使うことが望ましい（[OWASP Cheat Sheet Series][22]）

安全でないパターン：

* `os.system(user_input)`
* `subprocess.run(f"cmd {user}", shell=True)`
* ユーザー入力文字列を `bash -c`、`sh -c`、PowerShell などに渡す。

検出の手がかり：

* `os.system`、`subprocess`、`Popen`、`shell=True` を検索する。
* リクエスト／DB のデータがこれらの呼び出しに渡る経路を追跡する。

修正：

* シェルコマンドの代わりにライブラリ API を使う。
* 避けられない場合は、コマンドをハードコードし、検証済みパラメーターを許可リストで制限する。対応していれば `--` 区切り文字を使う。([OWASP Cheat Sheet Series][22])

---

### FASTAPI-SSRF-001: 外向き HTTP 通信でサーバーサイドリクエストフォージェリ（SSRF）を防ぐ

深刻度：中（クラウド／VPC 環境では高になる場合がある）

- 注：小規模な単独プロジェクトでは重要度は低い。LAN 内や、同一サーバー上で他のサービスが待ち受けている環境にデプロイする場合に特に重要となる。

必須事項：

* ユーザー提供 URL への外向きリクエストは高リスクとして扱う。
* ユーザーの影響を受ける URL の取得では、宛先（ホスト／ドメインの許可リスト）を検証・制限することが望ましい。
* localhost／プライベート IP 範囲／リンクローカル／クラウドメタデータのエンドポイントへのアクセスをブロックすることが望ましい。
* プロトコルは http／https に必ず制限する。
* タイムアウトを設定し、リダイレクトを慎重に制御することが望ましい。([OWASP Cheat Sheet Series][23])

安全でないパターン：

* `httpx.get(request.query_params["url"])`
* 任意の URL を受け入れる「URL プレビュー／インポート／Webhook テスター」機能。

検出の手がかり：

* リクエスト／DB 由来の URL を使う `requests`、`httpx`、`urllib`、`aiohttp` の呼び出しを検索する。
* `fetch`、`preview`、`proxy`、`webhook`、`import` という名前のエンドポイントを特定する。

修正：

* 厳格な URL 解析と許可リストを実装し、送信トラフィック制御を追加する。短いタイムアウトを設定し、不要であればリダイレクトを無効にする。([OWASP Cheat Sheet Series][23])

---

### FASTAPI-REDIRECT-001: オープンリダイレクトを防ぐ

深刻度：低

必須事項：

* 信頼できない入力（`next`、`redirect`、`return_to`）に由来するリダイレクト先を必ず検証する。
* 同一サイト内の相対パス、またはドメインの許可リストへのリダイレクトを優先することが望ましい。([OWASP Cheat Sheet Series][24])

安全でないパターン：

* `next` がユーザー制御で、検証されていない `RedirectResponse(next)` を返す。

検出の手がかり：

* `RedirectResponse(` またはリダイレクト処理を検索し、リダイレクト先の出所を確認する。

修正：

* 相対パスまたは許可リストにあるドメインのみ許可し、安全な既定値にフォールバックする。([OWASP Cheat Sheet Series][24])

---

### FASTAPI-WS-001: WebSocket エンドポイントは必ず認証し、クロスサイト悪用から保護する

深刻度：中～高（データ／権限による）

必須事項：

* 非公開チャネルの WebSocket 接続は必ず認証する（WebSocket 自体に認証機能はない）。([OWASP Cheat Sheet Series][25])
* ブラウザベースの WebSocket クライアントに適した、Origin／CSRF に類する保護を適用することが望ましい（Origin 検証は一般的な対策）。
* メッセージ頻度と接続試行をレート制限し、アイドル状態／不正な接続を閉じることが望ましい。

安全でないパターン：

* `@app.websocket(...)` が認証チェックなしで接続を受け入れ、信頼する。
* 漏えいやローテーションを考慮せず、認証にクエリ文字列のトークンを使う。

検出の手がかり：

* `@app.websocket`／`websocket_endpoint` を検索し、機密性の高い操作を受け入れる前に認証が行われているか調べる。
* Origin チェック、トークン解析、接続ごとの認可を確認する。

修正：

* ハンドシェイク時に（トークンやセッションなどで）認証を必須とし、アクション／メッセージに対する認可を適用する。
* 適切な場合はブラウザベースのクライアントの Origin を検証し、レート制限とタイムアウトを適用する。([OWASP Cheat Sheet Series][25])

---

### FASTAPI-SUPPLY-001: 依存関係とパッチの衛生管理（セキュリティ上重要な依存関係に注目）

深刻度：低

必須事項：

* セキュリティ上重要な依存関係（FastAPI、Starlette、Uvicorn、Pydantic、python-multipart、認証／JWT ライブラリ）はバージョンを固定し、定期的に更新することが望ましい。
* 既知のセキュリティ勧告には速やかに対応する。
* ファイル配信と multipart 解析の依存関係は、過去の CVE を踏まえ、セキュリティ上重要なものとして扱う。([advisories.gitlab.com][10])

監査で注目する例（過去のもの）：

* Starlette StaticFiles のパストラバーサル（0.27.0 で修正）。([advisories.gitlab.com][10])
* Starlette の multipart/form-data DoS（0.40.0 で修正）。([advisories.gitlab.com][9])
* Starlette FileResponse の Range ヘッダー DoS（0.49.1 で修正）。([advisories.gitlab.com][19])

検出の手がかり：

* `requirements.txt`、ロックファイル、コンテナイメージ、実行環境を確認し、実際にインストールされたバージョンを調べる。
* ファイルのアップロード／配信機能を依存関係のバージョンと対応付ける。

修正：

* 勧告に従って修正済みバージョンへアップグレードし、影響を受ける挙動に対する回帰テストを追加する。

---

## 5) 実践的なスキャンのヒューリスティクス（「探し方」）

実際にスキャンする際は、次の検出力の高いパターンを使う：

* 開発サーバー／デバッグ：

  * `--reload`、`reload=True`、`debug=True`、`FastAPI(debug=True)` ([PyPI][4])
* OpenAPI／ドキュメントの露出：

  * `/docs`、`/redoc`、`/openapi.json`、`docs_url=`、`openapi_url=`
* 認証適用の欠落：

  * 必要な箇所で `Depends()`／`Security()` がないエンドポイント、一貫した依存関係の境界を持たないルーター ([FastAPI][7])
  * クエリパラメーター内のトークン（`token=`、`api_key=`、`key=`）([FastAPI][11])
* セッション／Cookie と CSRF：

  * `SessionMiddleware(` と Cookie のフラグ（`https_only`、`same_site`）([PyPI][5])
  * CSRF チェックのない Cookie 認証を使う POST／PUT／PATCH／DELETE ハンドラー ([OWASP Cheat Sheet Series][2])
* 入力検証と Mass Assignment：

  * `await request.json()` と dict からの直接 DB 書き込み、追加フィールドを受け入れるモデル ([OWASP Cheat Sheet Series][14])
* 過剰なデータ露出：

  * `response_model` を使わずに ORM オブジェクトや dict を返すこと、パスワード／ロール／内部フィールドを含むレスポンス ([FastAPI][15])
* CORS：

  * `CORSMiddleware` と `allow_origins=["*"]`、`allow_origin_regex=".*"`、`allow_credentials=True` ([OWASP Cheat Sheet Series][6])
* ファイル：

  * ユーザー制御のパスを使う `FileResponse(`、アップロードを公開する `StaticFiles(` ([advisories.gitlab.com][10])
* アップロード／multipart：

  * サイズ／フィールドの制約がない `multipart/form-data` エンドポイント、古い Starlette／python-multipart ([advisories.gitlab.com][9])
* インジェクション：

  * f-string／文字列連結で作った SQL 文字列を `.execute(...)` に渡す ([OWASP Cheat Sheet Series][21])
  * `subprocess.*`、`shell=True`、`os.system` ([OWASP Cheat Sheet Series][22])
* SSRF：

  * リクエスト／DB 由来の URL を使う `httpx.get/post` または `requests.*` で、許可リスト／タイムアウトがない ([OWASP Cheat Sheet Series][23])
* リダイレクト：

  * 検証なしの `RedirectResponse(next)` ([OWASP Cheat Sheet Series][24])
* WebSocket：

  * 認証／Origin チェックのない `@app.websocket` ハンドラー、本番設定での `ws://` の使用 ([FastAPI][27])

必ず次の点を確認する：

* データの出所（信頼できないものか、信頼できるものか）* シンクの種類（SQL／サブプロセス／ファイル／テンプレート／HTTP／リダイレクト／WebSocket）
* 存在する保護対策（検証、許可リスト、ミドルウェア、エッジ制御）
* インストール済み依存関係のバージョンと脆弱なバージョン範囲の比較（[advisories.gitlab.com][10]）

---

## 6) 出典（2026-01-27閲覧）

主要なフレームワークのドキュメント：

* FastAPI（PyPIメタデータ、バージョン管理）— `https://pypi.org/project/fastapi/`（[PyPI][1]）
* FastAPIドキュメント：セキュリティ「最初のステップ」（Authorization Bearerヘッダーの規約）— `https://fastapi.tiangolo.com/tutorial/security/first-steps/`（[FastAPI][11]）
* FastAPIリファレンス：依存関係（`Depends`、`Security`）— `https://fastapi.tiangolo.com/reference/dependencies/`（[FastAPI][7]）
* FastAPIリファレンス：APIRouter（ルーター単位の依存関係）— `https://fastapi.tiangolo.com/reference/apirouter/`（[FastAPI][28]）
* FastAPIドキュメント：WebSocket — `https://fastapi.tiangolo.com/advanced/websockets/`（[FastAPI][27]）

ASGI／サーバースタックのドキュメント：

* Starlette（PyPI、一般的な機能）— `https://pypi.org/project/starlette/`（[PyPI][5]）
* Starletteドキュメント：WebSocket — `https://starlette.dev/websockets/`（[Starlette][3]）
* Uvicorn（PyPIメタデータ）— `https://pypi.org/project/uvicorn/`（[PyPI][4]）
* Pydanticドキュメント（v2.12.x）— `https://docs.pydantic.dev/latest/`（[Pydantic][29]）

セキュリティ標準とチートシート：

* OWASPチートシートシリーズ：セッション管理 — `https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html`（[OWASPチートシートシリーズ][8]）
* OWASPチートシートシリーズ：CSRF対策 — `https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html`（[OWASPチートシートシリーズ][2]）
* OWASPチートシートシリーズ：XSS対策 — `https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html`（[OWASPチートシートシリーズ][16]）
* OWASPチートシートシリーズ：マスアサインメント — `https://cheatsheetseries.owasp.org/cheatsheets/Mass_Assignment_Cheat_Sheet.html`（[OWASPチートシートシリーズ][14]）
* OWASP APIセキュリティTop 10（2023）— `https://owasp.org/API-Security/editions/2023/en/0x11-t10/`（[OWASP Foundation][13]）
* OWASPチートシートシリーズ：SQLインジェクション対策 — `https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html`（[OWASPチートシートシリーズ][21]）
* OWASPチートシートシリーズ：OSコマンドインジェクション対策 — `https://cheatsheetseries.owasp.org/cheatsheets/OS_Command_Injection_Defense_Cheat_Sheet.html`（[OWASPチートシートシリーズ][22]）
* OWASPチートシートシリーズ：SSRF対策 — `https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html`（[OWASPチートシートシリーズ][23]）
* OWASPチートシートシリーズ：ファイルアップロード — `https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html`（[OWASPチートシートシリーズ][20]）
* OWASPチートシートシリーズ：未検証のリダイレクトとフォワード — `https://cheatsheetseries.owasp.org/cheatsheets/Unvalidated_Redirects_and_Forwards_Cheat_Sheet.html`（[OWASPチートシートシリーズ][24]）
* OWASPチートシートシリーズ：HTTPセキュリティレスポンスヘッダー — `https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html`（[OWASPチートシートシリーズ][6]）
* OWASPチートシートシリーズ：WebSocketセキュリティ — `https://cheatsheetseries.owasp.org/cheatsheets/WebSocket_Security_Cheat_Sheet.html`（[OWASPチートシートシリーズ][25]）
* OWASP WSTG：サーバーサイドテンプレートインジェクションのテスト — `https://owasp.org/www-project-web-security-testing-guide/v41/4-Web_Application_Security_Testing/07-Input_Validation_Testing/18-Testing_for_Server_Side_Template_Injection`（[OWASP Foundation][17]）
* OWASP WSTG：WebSocketのテスト — `https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/11-Client-side_Testing/10-Testing_WebSockets`（[OWASP Foundation][26]）

テンプレートの安全性に関する参考資料：

* Jinja：サンドボックス — `https://jinja.palletsprojects.com/en/stable/sandbox/`（[jinja.palletsprojects.com][18]）

選定したサプライチェーン／セキュリティ勧告の参考資料（Starletteの例）：

* CVE-2023-29159（StaticFilesのパストラバーサル。0.27.0で修正）— `https://advisories.gitlab.com/pkg/pypi/starlette/CVE-2023-29159/`（[advisories.gitlab.com][10]）
* CVE-2024-47874（multipart/form-dataによるDoS。0.40.0で修正）— `https://advisories.gitlab.com/pkg/pypi/starlette/CVE-2024-47874/`（[advisories.gitlab.com][9]）
* CVE-2025-62727（FileResponseのRangeヘッダーによるDoS。0.49.1で修正）— `https://advisories.gitlab.com/pkg/pypi/starlette/CVE-2025-62727/`（[advisories.gitlab.com][19]）

[1]: https://pypi.org/project/fastapi/ "https://pypi.org/project/fastapi/"
[2]: https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html "https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html"
[3]: https://starlette.dev/websockets/?utm_source=chatgpt.com "Websockets"
[4]: https://pypi.org/project/uvicorn/ "https://pypi.org/project/uvicorn/"
[5]: https://pypi.org/project/starlette/ "https://pypi.org/project/starlette/"
[6]: https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html?utm_source=chatgpt.com "HTTP Security Response Headers Cheat Sheet"
[7]: https://fastapi.tiangolo.com/reference/dependencies/?utm_source=chatgpt.com "Dependencies - Depends() and Security() - FastAPI"
[8]: https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html "https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html"
[9]: https://advisories.gitlab.com/pkg/pypi/starlette/CVE-2024-47874/ "Starlette Denial of service (DoS) via multipart/form-data | GitLab Advisory Database"
[10]: https://advisories.gitlab.com/pkg/pypi/starlette/CVE-2023-29159/ "Starlette has Path Traversal vulnerability in StaticFiles | GitLab Advisory Database"
[11]: https://fastapi.tiangolo.com/tutorial/security/first-steps/?utm_source=chatgpt.com "Security - First Steps - FastAPI"
[12]: https://fastapi.tiangolo.com/tutorial/response-model/ "https://fastapi.tiangolo.com/tutorial/response-model/"
[13]: https://owasp.org/API-Security/editions/2023/en/0x11-t10/ "https://owasp.org/API-Security/editions/2023/en/0x11-t10/"
[14]: https://cheatsheetseries.owasp.org/cheatsheets/Mass_Assignment_Cheat_Sheet.html "https://cheatsheetseries.owasp.org/cheatsheets/Mass_Assignment_Cheat_Sheet.html"
[15]: https://fastapi.tiangolo.com/tutorial/extra-models/ "https://fastapi.tiangolo.com/tutorial/extra-models/"
[16]: https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html "https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html"
[17]: https://owasp.org/www-project-web-security-testing-guide/v41/4-Web_Application_Security_Testing/07-Input_Validation_Testing/18-Testing_for_Server_Side_Template_Injection?utm_source=chatgpt.com "Testing for Server Side Template Injection"
[18]: https://jinja.palletsprojects.com/en/stable/sandbox/?utm_source=chatgpt.com "Sandbox — Jinja Documentation (3.1.x)"
[19]: https://advisories.gitlab.com/pkg/pypi/starlette/CVE-2025-62727/ "Starlette vulnerable to O(n^2) DoS via Range header merging in ``starlette.responses.FileResponse`` | GitLab Advisory Database"
[20]: https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html "https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html"
[21]: https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html "https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html"
[22]: https://cheatsheetseries.owasp.org/cheatsheets/OS_Command_Injection_Defense_Cheat_Sheet.html "https://cheatsheetseries.owasp.org/cheatsheets/OS_Command_Injection_Defense_Cheat_Sheet.html"
[23]: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html "https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html"
[24]: https://cheatsheetseries.owasp.org/cheatsheets/Unvalidated_Redirects_and_Forwards_Cheat_Sheet.html?utm_source=chatgpt.com "Unvalidated Redirects and Forwards Cheat Sheet"
[25]: https://cheatsheetseries.owasp.org/cheatsheets/WebSocket_Security_Cheat_Sheet.html?utm_source=chatgpt.com "WebSocket Security - OWASP Cheat Sheet Series"
[26]: https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/11-Client-side_Testing/10-Testing_WebSockets?utm_source=chatgpt.com "WSTG - Latest | OWASP Foundation"
[27]: https://fastapi.tiangolo.com/advanced/websockets/?utm_source=chatgpt.com "WebSockets - FastAPI"
[28]: https://fastapi.tiangolo.com/reference/apirouter/?utm_source=chatgpt.com "APIRouter class - FastAPI"
[29]: https://docs.pydantic.dev/latest/ "https://docs.pydantic.dev/latest/"