# Next.js (TypeScript/JavaScript) Web セキュリティ仕様 (Next.js 16.1.x、Node.js 20.9+)

このドキュメントは、次の用途を支援する**セキュリティ仕様**として作成されています。

1. 新しい Next.js バックエンドコード（Route Handlers、API Routes、Server Actions、Proxy/Middleware）の**デフォルトで安全なコード生成**。
2. 既存の Next.js リポジトリに対する**セキュリティレビュー／脆弱性の調査**（作業中に問題に気づく受動的な確認、およびリポジトリをスキャンして検出事項を報告する能動的な確認）。

これは意図的に、**規範的要件**（「MUST/SHOULD/MAY」）と**監査ルール**（不適切なパターンの見分け方、検出方法、修正または軽減方法）をまとめたものとして記述されています。

対象範囲: Next.js **16.1.x**（App Router のドキュメントに示されている最新系列）([Next.js][1])、Node.js **20.9+** で実行（Next.js のシステム要件に準拠）。([Next.js][2])

---

## 0) 安全性、境界、および不正利用への制約（必ず遵守）

* シークレット（API キー、パスワード、秘密鍵、セッション Cookie、OAuth トークン、`process.env` ダンプ、認証情報を含むデータベース URL）を要求、出力、ログ記録、またはコミットしてはなりません。
* 保護機能を無効にすることでセキュリティ上の「修正」を行ってはなりません（例: オリジンチェックの無効化、CORS の緩和による `*`、認可チェックの省略、Cookie のセキュリティフラグの無効化、「難しい」という理由での CSP の無効化）。
* 監査では、根拠に基づく検出事項を提示しなければなりません。各指摘を裏付けるファイルパス、コードスニペット、設定値を示してください。
* 不確実性を正直に扱ってください。保護機能がインフラストラクチャ（リバースプロキシ、CDN、WAF、プラットフォームのヘッダー）に存在する可能性がある場合は、「アプリコードでは確認できない。実行時／設定を確認」と報告してください。
* 明確に強制された認証境界がない限り、リクエストを受け付けるすべてのサーバーコードに攻撃者がアクセスできるものと見なしてください（「UI からリンクされていない」だけでは不十分です）。
* TypeScript の型を**セキュリティ境界ではない**ものとして扱ってください。型は実行時入力を検証しないため、実行時のチェックが必要です。([Next.js][3])

---

## 1) 運用モード

### 1.1 生成モード（既定）

新しい Next.js コードの作成または既存コードの変更を依頼された場合:

* この仕様の**MUST**要件をすべて遵守しなければなりません。
* ユーザーが明示的に別の指示をしない限り、**SHOULD**要件もすべて遵守するべきです。
* カスタムのセキュリティコードより、安全な状態を既定とする API や実績のあるライブラリを優先しなければなりません。
* 新たなリスクの高い処理箇所（動的コード実行、安全でないリダイレクト、ユーザーファイルの HTML としての配信、SSRF を招く URL フェッチャー、SQL 文字列の組み立てなど）を導入してはなりません。

### 1.2 受動的レビュー モード（編集中は常に有効）

Next.js リポジトリ内のどこで作業している場合でも（ユーザーがセキュリティスキャンを依頼していない場合も含む）:

* この仕様への違反に「気づく」必要があります（MUST）。
* 問題が見つかった時点で、簡潔な説明と安全な修正方法を添えて伝えるべきです（SHOULD）。

### 1.3 能動的監査モード（明示的なスキャン依頼時）

ユーザーが「スキャン」「監査」「脆弱性を調査」と依頼した場合:

* この仕様への違反がないか、コードベースを体系的に検索しなければなりません。
* 検出事項を構造化された形式（§2.3 を参照）で出力しなければなりません。

推奨される監査順序:

1. デプロイのエントリーポイントと環境（Dockerfile、`package.json` スクリプト、ホスティング設定）。
2. Next.js の設定（`next.config.*`）、Proxy/Middleware、ルーティングパターン。
3. 認証、セッション、Cookie。
4. CSRF 保護と状態変更エンドポイント（Server Actions、Route Handlers、API Routes）。
5. XSS（React と CSP）および安全でない HTML レンダリング。
6. キャッシュ／データ漏えいの危険性（静的レンダリング、キャッシュ、「use cache」）。
7. ファイル処理（アップロード／ダウンロード）とパストラバーサル。
8. インジェクションの種類（SQL／ORM の誤用、コマンド実行、安全でないデシリアライズ）。
9. 外向きリクエスト（SSRF）。
10. リダイレクト処理（オープンリダイレクト）。
11. CORS とセキュリティヘッダー。

---

## 2) 定義とレビューの指針

### 2.1 信頼できない入力（信頼できると証明されない限り、攻撃者が制御できるものとして扱う）

Next.js バックエンドにおける信頼できない入力には、次のものが含まれます。

App Router:

* Route Handler の params とリクエストデータ:

  * `context.params`（動的セグメント）、検索パラメーター（`request.url`、`new URL(request.url).searchParams`）
  * `request.headers`、`request.cookies`
  * `await request.json()`、`await request.formData()`、`await request.text()`
* Server Components／Server Functions で使われる動的 API:

  * `headers()` と `cookies()` の値 ([Next.js][4])

Pages Router:

* `pages/api/*` ハンドラー内の `req.query`、`req.cookies`、`req.body` ([Next.js][3])

さらに:

* 外部システムからのあらゆるデータ（Webhook、サードパーティ API、メッセージキュー）
* ユーザーに由来する、永続化されたユーザーコンテンツ（DB の行）

### 2.2 状態変更リクエスト

データの作成／更新／削除、認証／セッション状態の変更、副作用（購入、メール送信、Webhook 送信）の発生、または特権操作の開始が可能なリクエストは、状態変更リクエストです。

Next.js に関する特記事項:

* **Server Actions** はネットワークリクエスト経由で呼び出され、状態を変更できるため、状態変更エンドポイントとして扱ってください。([Next.js][5])

### 2.3 必須の監査検出事項フォーマット

検出した問題ごとに、次の項目を出力してください。

* ルール ID:
* 深刻度: Critical / High / Medium / Low
* 場所: ファイルパス + 関数／ルート名 + 行番号
* 根拠: 該当する正確なコード／設定スニペット
* 影響: 何が起こり得るか、誰が悪用できるか
* 修正: 安全な変更（最小限の差分を優先）
* 軽減策: 直ちに修正するのが難しい場合の多層防御
* 誤検知に関する注記: 不確かな場合に確認する内容

---

## 3) 安全なベースライン: 本番環境での最低限の設定（本番環境では必須）

これは、Next.js バックエンドでよくある設定ミスを防ぐための最小限の「本番環境ベースライン」です。

### 3.1 Next.js を本番モードで実行する（必須）

* `next build` + `next start`（またはマネージドプラットフォーム相当の方法）を実行しなければなりません。`next dev` は実行してはなりません。開発モードではエラーやレポートの挙動が異なり、本番環境での公開を想定していません。([Next.js][6])
* 本番環境では `NODE_ENV=production` が設定されていることを確認しなければなりません（Next.js はコマンドに応じて既定値 `NODE_ENV` を設定します。実行環境を確認してください）。([Next.js][7])

### 3.2 セルフホスティングではリバースプロキシ／エッジ層を前段に配置する（公開インターネット向けには必須）

* セルフホスティングする場合、Next.js サーバーの前段にリバースプロキシ（例: nginx）または同等のエッジ層を配置し、不正なリクエスト、低速攻撃、ペイロードサイズ制限、レート制限、および同様の懸念事項に対処しなければなりません。([Next.js][8])

### 3.3 ヘッダー／Cookie の基本方針（推奨）

* セキュリティヘッダーの基本セット（CSP、`X-Content-Type-Options`、CSP の `frame-ancestors` および／または `X-Frame-Options` によるクリックジャッキング対策など）をグローバルに設定するべきです。Next.js のドキュメントでは、Proxy／headers を使った CSP の実装方法が案内されています。([Next.js][7])
* 認証／セッション Cookie には、適切なセキュリティ属性（`Secure`、`HttpOnly`、`SameSite`）を使用しなければなりません。([Next.js][9])
重要な注意: `Secure` は本番環境でのみ設定してください。HTTP を使うローカル開発環境では、Cookie に `Secure` プロパティを設定しないでください。アプリが本番モードで実行されているかどうかに応じて、条件付きで設定してください。また、HTTP でテストする際に `Secure` Cookie を無効にできる `SESSION_COOKIE_SECURE` のようなプロパティも含めてください。

### 3.4 サーバーコードとクライアントコードを明確に分離する（必須）

* シークレットや特権ロジックがクライアントコードにバンドルされないようにしなければなりません。
* `NEXT_PUBLIC_*` 環境変数は公開情報（ブラウザーに公開され、ビルド時にインライン化される）として扱わなければなりません。([Next.js][7])

---

## 4) ルール（生成 + 監査）

各ルールには、必須の実践事項、安全でないパターン、検出の手がかり、修正方法が含まれます。

### NEXT-DEPLOY-001: 本番環境で `next dev` を実行せず、本番モードの挙動を確保する

深刻度: High（本番環境の場合）

注: 特定の Next.js ホスティングプロバイダーにデプロイする場合、この点を心配する必要はありません。

必須事項:

* `next dev` または開発サーバーモードを本番環境にデプロイしてはなりません。
* 公開デプロイでは、本番ビルドと本番ランタイムを使用しなければなりません。([Next.js][6])

安全でないパターン:

* Docker の `CMD`、Procfile、プラットフォームの起動コマンドで `next dev` を実行している。
* 本番環境の設定で `NODE_ENV=development` を使用している。
* デバッグ／開発専用のエンドポイントやフラグが公開されている。

検出の手がかり:

* `package.json` スクリプトとデプロイマニフェストで `next dev` を検索する。
* インフラストラクチャ内で `NODE_ENV=development`、または `NODE_ENV` の欠如を検索する。
* Kubernetes／PM2／systemd のエントリーポイントで `next dev` を確認する。

修正:

* CI／ビルド時には `next build` を、実行時には `next start` を使用します（またはプラットフォーム固有のビルド／実行機能を使用します）。
* 環境に `NODE_ENV=production` が設定されていることを確認します。

注:

* 開発モードはローカル開発であれば問題ありません。本番環境のエントリーポイントとして使われている場合にのみ指摘してください。

---

### NEXT-SUPPLY-001: サポート対象の Next.js リリースを使用し、セキュリティ勧告へのパッチを速やかに適用する

深刻度: High（既知の脆弱なバージョンの場合は Critical）

必須事項:

* サポート対象の Next.js バージョン系列を使用し、セキュリティ更新を速やかに適用しなければなりません。Next.js は LTS／サポートポリシーを公開しています。([Next.js][10])
* 公開された勧告を、パッチ適用済みリリースへの更新など、緊急のアップグレードを促す情報として扱わなければなりません。([GitHub][11])

安全でないパターン:

* バックポートされたセキュリティ修正のない、サポート終了済みの Next.js メジャー／マイナーバージョンを使用している。
* 勧告を無視している、または `next` を脆弱な範囲に固定している。

検出の手がかり:

* `package.json` とロックファイルを確認し、`next` のバージョンを調べる。
* Next.js のサポートポリシーおよび勧告と照合する。

重要: 以下のマイナーバージョンより古いバージョンは、「react2shell」脆弱性の影響を受けます (https://nextjs.org/blog/CVE-2025-66478):
15.0.5
15.1.9
15.2.6
15.3.6
15.4.8
15.5.7
16.0.7

修正:

* `next` を、サポート対象かつパッチ適用済みのバージョンにアップグレードします。
* 依存関係の更新プロセスと CI チェックを追加します。


---

### NEXT-SECRETS-001: シークレットをコミットまたはブラウザーに公開してはならない

深刻度: High（シークレットがクライアントに公開されている場合は Critical）

必須事項:

* シークレットは環境変数またはシークレットマネージャーに保存し、`.env*` ファイルをコミットしてはなりません。
* `.env*` は機密情報として扱わなければなりません。Next.js は「これらのファイルをコミットすることは、ほとんどの場合望ましくない」と警告しています。([Next.js][7])
* `NEXT_PUBLIC_*` 環境変数はすべて公開情報であり、ブラウザーから見えるもの（ビルド時にクライアントバンドルへインライン化されるもの）として扱わなければなりません。([Next.js][7])

安全でないパターン:

* `.env`、`.env.local`、`.env.production` が Git にコミットされている。
* `NEXT_PUBLIC_API_KEY`、`NEXT_PUBLIC_SECRET`、`NEXT_PUBLIC_DATABASE_URL` などを使用している。
* `process.env` の値を HTML にレンダリングする、または API ルートから返している。

検出の手がかり:

* Git の履歴とリポジトリ内のファイルをスキャンし、`.env` の内容、`DB_PASS=`、`API_KEY=`、`SECRET=` を検索する。
* `NEXT_PUBLIC_` を検索し、機密情報と思われる名前を確認する。
* Client Components（`"use client"`）および共有モジュール内での `process.env` の使用箇所を検索する。

修正:

* シークレットをサーバー専用の環境変数（`NEXT_PUBLIC_` プレフィックスなし）に移します。
* `.env*` が無視対象になっており、デプロイ時にシークレットが注入されることを確認します。
* 漏えいしたキーをローテーションします。

---

### NEXT-SECRETS-002: サーバー専用コードをクライアントにバンドルしない（サーバー／クライアント境界はセキュリティ境界）

深刻度: High

必須事項:

* サーバー専用モジュール（DB クライアント、シークレットに依存するコード）が Client Components や、クライアントにバンドルされる他のコードパスからインポートされないようにしなければなりません。
* サーバー専用のパターン／レイヤー（例: 専用の DAL とサーバー専用モジュール）を使用し、境界違反をセキュリティバグとして扱うべきです。Next.js は機密モジュールに関する「server-only」の概念を明示的に説明しています。([Next.js][6])

安全でないパターン:

* DB クライアント、管理者 SDK、またはシークレットを読み取るモジュールを `"use client"` コンポーネントにインポートしている。
* サーバーとクライアントの両方のコードからインポートされる共有 `lib/` モジュールがシークレットを参照している。

検出の手がかり:

* `"use client"` を検索し、そのインポート内容にサーバー専用の依存関係がないか調べる。
* `components/` または他のクライアントコードパスからインポートされる DB クライアントパッケージ（`pg`、`mysql2`、`mongoose`、`prisma`、管理者 SDK）を探す。
* UI コンポーネント内での `process.env` へのアクセスを検索する。

修正:

* `lib/server/*` にリファクタリングし、サーバーコンテキスト（Route Handlers、Server Components、Server Actions）からのみインポートします。
* 誤ったインポートを防ぐため、明示的な「server-only」ガードパターン（および／またはテスト）を追加します。

---

### NEXT-AUTH-001: 保護対象のすべての操作で、サーバー側の認証／認可を必ず強制する

深刻度: High

必須事項:
* サーバー側のコードで、次の項目の認証と認可を必ず実施すること:

  * Route Handlers (`app/**/route.ts`) ([Next.js][1])
  * API Routes (`pages/api/**`) ([Next.js][3])
  * クライアントから呼び出される Server Actions (`"use server"` functions invoked by clients) ([Next.js][6])
* クライアント側のチェック（UIを隠す、クライアント側のルートガード）だけを唯一の保護策としてはならない。

安全でないパターン:

* セッション検証を行わない機密性の高い Route Handlers。
* データを変更するが、ユーザーの身元や権限を検証しない Server Actions。
* React コンポーネント内だけで行う「認可」チェック。

検出のヒント:

* すべての Route Handlers と API Routes を洗い出し、それぞれについて認証が必要か確認する。
* `"use server"` を grep し、エクスポートされたすべてのアクションについて認証チェックを確認する。
* クエリパラメーターやフォーム送信によって呼び出される管理者向けアクションを検索する。

修正:

* 認証ヘルパーを一元化し、保護対象のすべてのエンドポイント／アクションで呼び出す。
* 各アクションに対して最小権限の認可チェック（ロール／リソースの所有権）を実装する。

---

### NEXT-AUTH-002: Proxy/Middleware ベースの認証でルートの適用漏れを生じさせてはならない

重大度: 高

必須事項:

* 認証チェックに **Proxy** または **Middleware** を使う場合、保護が必要なすべてのルートを対象にすること。
* Next.js のドキュメントによると、Proxy では `matcher` を使用でき、認証目的では Proxy をすべてのルートで実行することが推奨されている。([Next.js][12])
* `matcher` の誤りは認証バイパスのリスクとして扱うこと。

安全でないパターン:

* Proxy/Middleware が「ページ」には適用されるが `/api/*` には適用されない、または一部のルートグループだけを対象にしている。
* 代替のリクエスト形式（フレームワーク内部の形式、RSC ナビゲーションなど）を見落とす「拒否リスト」方式のマッチャー。

検出のヒント:

* `proxy.ts` / `middleware.ts` と、その `matcher` を確認する。
* マッチャーをルート全体（`app/api/**` と `pages/api/**` を含む）と照合する。
* 静的アセットと Next.js の内部エンドポイントを除外するのは意図した場合に限り、機密性の高いルートが含まれていることを確認する。

修正:

* 保護対象のルートプレフィックスを許可リストにするか、Proxy を全体で実行し、内部で許可／拒否を判定する。
* 統合テストを追加する。認証なしで保護対象ルートにリクエストし、拒否されることを検証する。

注記:

* Proxy は一般に「楽観的チェック」に使われるもので、それ自体で完全な認可システムになるわけではない。([Next.js][12])

---

### NEXT-CSRF-001: Cookie 認証を使う状態変更エンドポイントは CSRF 対策を必須とする

重大度: 高

- 重要な注意: 認証に Cookie を使わない場合（つまり認証ヘッダーや別途渡されるトークンによる認証の場合）、CSRF のリスクはない。

必須事項:

* 認証に Cookie を使う状態変更エンドポイント（POST/PUT/PATCH/DELETE）はすべて保護すること。
* **Server Actions** では、Next.js が CSRF 防止のために Origin と Host を比較する。この機能を無効化したり弱めたりしてはならない。([Next.js][5])
* Server Actions を追加の信頼済みオリジン（例: 信頼済みプロキシのドメイン）から呼び出せる必要がある場合は、厳格な許可リストとともに `allowedOrigins` を使うこと。([Next.js][5])
* **Route Handlers** と **API Routes** では、CSRF 対策を明示的に実装すること（トークン、および／または厳格な Origin/Referer チェック + SameSite + カスタムヘッダー）。Route Handlers は「エスケープハッチ」であり、アプリケーション側でセキュリティ上の判断が必要となる。([Next.js][6])

安全でないパターン:

* 状態を変更する POST エンドポイント（Server Actions を含む）が、トークンや Origin のチェックなしにクロスサイトリクエストを受け付ける。
* `allowedOrigins: ['*']`（または広範なワイルドカード）、あるいは「Origin をそのまま反映する」ロジック。
* 状態変更に GET リクエストを使う。

検出のヒント:

* 状態変更エンドポイントをすべて洗い出し、認証方式を確認する。
* `allowedOrigins` を検索し、そのリストが少数かつ具体的で、妥当な理由があることを確認する。([Next.js][5])
* Route Handlers/API Routes で、CSRF トークン検証や Origin/Referer チェックの欠落を確認する。

修正:

* Cookie 認証エンドポイントに CSRF トークン方式を実装する。
* 互換性がある場合は Cookie に `SameSite=Lax` または `Strict` を設定する。ただし SameSite だけで十分とみなしてはならない。
* JSON API エンドポイントでは、特に CSRF トークンを使わない場合、厳格な Origin 検証を行う。

注記:

* XSS は CSRF 対策を無効化し得る。CSRF 対策は XSS 防止の代わりにはならない。

---

### NEXT-SESS-001: 本番環境ではセッション Cookie に安全な属性を必ず設定する

重大度: 中

必須事項（本番環境、HTTPS）:

* セッション／認証 Cookie に以下を必ず設定すること:

  * `Secure: true`（HTTPS 専用）重要な注意: 本番環境でのみ `Secure` を設定すること。HTTP を使うローカル開発環境では、Cookie に `Secure` プロパティを設定しないこと。アプリが本番モードで実行されているかに応じて条件付きで設定すること。また、HTTP でのテスト時に `Secure` Cookie を無効にできる `SESSION_COOKIE_SECURE` のようなプロパティも含めること。
  * `HttpOnly: true`（JavaScript から読み取り不可）
  * `SameSite: 'Lax'`（推奨）、または互換性がある場合は `'Strict'`
* クロスサイト Cookie が本当に必要な場合に限り `SameSite: 'none'` を使い、その場合は `Secure` も必ず設定すること。Cookie オプションは Next.js の Cookie API でサポートされている。([Next.js][9])

安全でないパターン:

* 本番環境で `secure: false`。
* 認証 Cookie に `httpOnly: false`。
* 明確な必要性がないのに `sameSite: 'none'` を使うこと。特に Cookie 認証の状態変更エンドポイントでは避ける。

検出のヒント:

* Cookie の設定箇所（`cookies().set(...)`、`Set-Cookie` ヘッダー、認証ライブラリの Cookie 設定）を検索する。
* Route Handlers と Server Actions で使われている Cookie オプションを確認する。([Next.js][9])

修正:

* 認証／セッション層で安全な Cookie 属性を設定する。
* Cookie の適用範囲を狭める。サブドメイン全体に Cookie を適用する必要が明確にある場合を除き、広範な `domain` は避ける。

---

### NEXT-SESS-002: セッションの有効期間を制限し、固定化／再利用に耐えるようにする

重大度: 低

必須事項:

* アプリに適した上限付きのセッション有効期間を設定することが望ましい。
* ログイン時および権限変更時にセッション識別子をローテーションすることが望ましい。
* 暗号化されていない Cookie を含め、機密情報をクライアントから読み取り可能なストレージに直接保存してはならない。

安全でないパターン:

* ローテーションのない長期間有効な管理者セッション。
* 追加のリスク対策なしに、特権ロールで「永久にログイン状態を保持」すること。
* アクセストークン／リフレッシュトークンを HttpOnly でない Cookie や localStorage に保存すること。

検出のヒント:

* 認証ライブラリの有効期限とローテーションの設定を確認する。
* `localStorage.setItem('token'...)` と HttpOnly でない Cookie の使用箇所を検索する。

修正:

* 特権セッションの有効期間を短くし、ローテーションしながら更新する。
* Cookie には不透明なセッション ID のみを保存し、機密情報はサーバー側に保持する。

---

### NEXT-INPUT-001: 実行時の入力検証は必須（TypeScript は検証ではない）

重大度: 高

必須事項:

* 攻撃者が制御できるすべての入力を実行時に検証し、正規化すること（スキーマ、型チェック、境界値）。
* Next.js の API Routes のドキュメントでは、`req.body` は `any` であり、使用前に検証しなければならないと明記されている。([Next.js][3])
* Server Action の引数を検証すること（信頼できない入力として扱う）。([Next.js][6])

安全でないパターン:

* `req.body` の構造をそのまま信頼する。
* `params.id`/`searchParams` をそのまま DB クエリやファイルパスに渡す。
* JSON を解析した後、検証せずに型が正しいと仮定する。

検出のヒント:

* JSON／フォーム入力を受け付けるエンドポイントを特定し、スキーマ検証の有無を確認する。
* `req.body.` の使用箇所と、Route Handlers 内の `await request.json()` の使用箇所を grep し、検証があることを確認する。

修正:

* スキーマ検証（例: zod/yup/valibot）を追加し、無効な入力には 4xx を返す。
* ID を厳密な型（UUID/int）として検証し、長さや文字種の制約を適用する。

---

### NEXT-HEADERS-001: 必須のセキュリティヘッダーをアプリ内またはエッジで設定する

重大度: 低

必須事項（一般的な Web アプリ）:

* 次の設定が望ましい:

  * CSP (`Content-Security-Policy`)（NEXT-CSP-001 を参照）
  * `X-Content-Type-Options: nosniff`
  * クリックジャッキング対策（CSP の `frame-ancestors` および／または `X-Frame-Options`）
  * 適切な場合は `Referrer-Policy` と `Permissions-Policy`
* Cookie に安全な属性が設定されていることを必ず確認する（NEXT-SESS-001 を参照）。([Next.js][9])

安全でないパターン:

* アプリ内にもエッジにもセキュリティヘッダーがない。
* 意図せず iframe への埋め込みを許可している。
* `nosniff` がないため、`Content-Type` のスニッフィングが可能になっている。

検出のヒント:

* `proxy.ts` / middleware で `response.headers.set(...)` を確認する。([Next.js][7])
* アプリのコードから確認できない場合は、「エッジ／CDN で確認」として指摘する。

修正:

* ヘッダーを一元的に設定する（Proxy/Middleware またはその他の一元管理方式）。
* すべてのルートでヘッダーが一貫するようにする。

---

### NEXT-CSP-001: CSP を使って XSS の影響を抑え、スクリプトには nonce を優先する

重大度: 中

注意: CSP では script-src の設定が最も重要である。他のディレクティブは重要度が低く、開発を容易にするため通常は省略できる。

必須事項:

* CSP を導入することが望ましい。スクリプトには nonce を使うのが理想的。
* nonce の生成やヘッダーへの適用を含め、Next.js の CSP 実装ガイダンスに従うことが望ましい。([Next.js][7])
* 明示的にリスクを受容する場合を除き、`script-src 'unsafe-inline'` などを使って CSP を緩めることを「修正」としてはならない。

安全でないパターン:

* ユーザー生成の HTML／Markdown を表示するアプリに CSP がない。
* 厳格な理由なしにインラインスクリプトや eval を広く許可する CSP。

検出のヒント:

* `Content-Security-Policy` ヘッダーの設定を検索し、そのディレクティブを確認する。
* `next/script` の使用状況と、CSP で必要な場合に nonce が指定されているかを確認する。

修正:

* Next.js のガイダンスに従って CSP を実装し、nonce を一貫して適用する。
* インラインスクリプトを減らし、`eval` を避ける。

注記:

* CSP は多層防御の一部であり、適切な出力エンコーディングやサニタイズの代わりにはならない。

---

### NEXT-XSS-001: React/Next のレンダリングで反射型／格納型 XSS を防ぐ

重大度: 高

必須事項:

* React のデフォルトのエスケープ処理に依存すること。サニタイズせずに信頼できない HTML を DOM に挿入してはならない。
* 次の項目を高リスクのシンクとして扱うこと:

  * `dangerouslySetInnerHTML`
  * ユーザーが制御する文字列を `<script>` タグやイベントハンドラー属性にレンダリングすること
* アップロードされた HTML を有効な HTML として配信してはならない（添付ファイルとして配信するか、サニタイズ／変換する）。

安全でないパターン:

* サニタイザーなしの `<div dangerouslySetInnerHTML={{ __html: userContent }} />`。
* サニタイザーなしで生の HTML を許可する Markdown レンダラー。
* Route Handler から `Content-Type: text/html` でユーザーコンテンツを返すこと。

検出のヒント:

* `dangerouslySetInnerHTML`、`__html:` を検索する。
* HTML を組み立てるテンプレート風の文字列連結を検索する。
* 「HTML をレンダリング」または「プレビュー」する機能を確認する。

修正:

* 信頼できない HTML は、適切に保守されているサニタイザーでサニタイズし、厳格な許可リストを優先する。
* ユーザーコンテンツは HTML ではなくテキストとしてレンダリングする。
* 影響を抑えるため CSP を追加する。

---

### NEXT-ACTION-001: Server Actions は公開エンドポイントと同様に扱う

重大度: 高（特権操作では重大）

必須事項:

* Route Handlers と同じ制御を適用すること:

  * 認証／認可
  * 入力検証
  * CSRF／Origin 対策
  * 機密性の高い操作に対するレート制限
* Server Actions が「到達不能」または「内部向け」だと仮定してはならない。
* Server Action リクエストの保護について理解すること:

  * Next.js は CSRF を軽減するため Origin と Host を比較する。追加のオリジンは `allowedOrigins` を使って明示的に許可リストへ追加する必要がある。([Next.js][5])

安全でないパターン:

* 認証チェックなしで DB の状態を更新する `"use server"` 関数。
* 「動作させるため」に過度に広範な `allowedOrigins` を追加すること。

検出のヒント:

* `"use server"` を grep し、エクスポートされたすべてのアクションを一覧にする。
* 特権的な書き込みを行うアクションを特定し、ユーザーの身元と権限を確認していることを確認する。

修正:

* 認可ヘルパーでアクションをラップする（デフォルト拒否）。
* `allowedOrigins` は最小限に保ち、監査する。

---

### NEXT-ACTION-002: Server Action のクロージャ／バインディングでシークレットを誤って漏らさない

重大度: 中（重要なシークレットが露出する場合は高）

必須事項:

* Server Action がクロージャで取り込む値は機密情報として扱い、意図を持って設計すること。
* Next.js によると、クロージャで取り込まれた値は暗号化／署名されるが、`.bind` 経由で渡される値は暗号化されない。シークレット保護のために `.bind` に依存してはならない。([Next.js][6])* デプロイ間で Server Actions に安定した暗号化キーを使用する場合は、必ず秘密情報として扱い、安全に保管すること（コミットやログへの記録をしない）。([Next.js][6])

安全でないパターン:

* `myAction.bind(null, process.env.SECRET)`、またはクライアントからの影響を受けるべきでない機密トークン／IDをバインドする。
* 秘密情報を含むアクション引数をログに記録する。

検出のヒント:

* Server Action 関数で `.bind(` を検索する。
* Server Actions の近くで `process.env` が使われていないか検索する。

修正:

* アクションに秘密情報をバインドしない。アクション内でサーバー側から秘密情報を取得する。
* アクション引数は最小限にし、検証する。

---

### NEXT-CACHE-001: 静的レンダリングと共有キャッシュによるデータ漏えいを防ぐ

重大度: 高（ユーザー間のデータ漏えいがある場合は重大）

必須事項:

* ユーザー固有または機密データを返すページ／エンドポイントが、静的生成されたり共有キャッシュに保存されたりしないようにすること。
* Route Handlers は既定ではキャッシュされないが、GET ハンドラーはキャッシュや静的動作を有効にできる。ユーザーごとのデータには使用しないこと。([Next.js][1])
* `use cache` や同様のキャッシュ機構は、明示的にプライベートだと証明されない限り、ユーザー間で共有される可能性があるものとして扱うこと。ユーザーごとの DB 結果を共有キャッシュに保存しないこと。([Next.js][1])
* 機密性の高いレスポンス（認証／セッション／ユーザーデータの API）には、明示的な `Cache-Control: no-store`／`private` を設定することが望ましい。

安全でないパターン:

* ユーザー固有データを返すルートで `export const dynamic = 'force-static'` を使用する。([Next.js][1])
* ユーザーごとのキャッシュキーなしで、ユーザー固有データを照会する関数を `use cache` で囲む。([Next.js][1])
* キャッシュが有効な GET エンドポイントから認証／セッションのレスポンスを返す。

検出のヒント:

* `dynamic = 'force-static'`、`revalidate`、`use cache`、`cacheLife`、`unstable_cache` を検索する。
* キャッシュまたは静的化されているすべての GET Route Handler を調べ、公開データだけを返すことを確認する。
* `cookies()`／`headers()`（動的 API）の使用が誤って削除され、ルートが静的化されていないか確認する。([Next.js][1])

修正:

* 機密性の高いルートを動的として指定し、`Cache-Control: no-store` を設定する。
* キャッシュが本当に必要な場合は、キャッシュキーにユーザー ID を含め、ユーザー専用キャッシュに保存する。

---

### NEXT-FILES-001: ユーザーによるアップロードは必ず検証し、安全に保存・配信する

重大度: 中

必須事項:

* エッジとアプリケーションロジックの両方でアップロードサイズの上限を適用すること。
* 拡張子だけでなく、許可リストとコンテンツ検査によってファイル形式を検証すること。
* `public/` ディレクトリの外にアップロードを保存すること（`public/` 以下のものは、既定で静的コンテンツとして配信される）。
* 明示的に意図している場合を除き、実行可能性のある形式は安全に配信すること（`Content-Disposition: attachment`）。

安全でないパターン:

* 任意のファイル形式を受け入れ、そのままインラインで配信する。
* ユーザー指定のファイル名を保存先パスとして使う。
* アップロードを `public/uploads/` に書き込み、そのまま配信する。

検出のヒント:

* `formData()`／multipart の解析、`fs.writeFile`、ストレージ SDK の使用箇所を検索する。
* `public/` 以下に書き込むパスがないか確認する。
* `Content-Type: text/html` を設定する「ダウンロード」エンドポイントや、ユーザーファイルをインラインで配信する箇所を探す。

修正:

* 専用のオブジェクトストア（S3/GCS）または静的ルートの外にある安全なサーバー側ディレクトリを使用する。
* サーバー側でランダムなファイル名を生成し、メタデータは別に保存する。

---

### NEXT-PATH-001: パストラバーサルと安全でないファイルアクセスを防ぐ

重大度: 高

必須事項:

* ユーザーが制御できる文字列をファイルシステムのパスとして使用しないこと。
* 識別子を検証して正規化し、許可リストと安全な基底ディレクトリを使用すること。
* リクエストパラメーターに基づいて任意のファイルを読み込まないこと。

安全でないパターン:

* `fs.readFile(request.nextUrl.searchParams.get('path'))`
* 正規化と境界チェックなしでの `path.join(base, userPath)`

検出のヒント:

* Route Handlers／API Routes 内の `fs.` の使用箇所を検索する。
* リクエストパラメーターから値を受け取る `path.join`／`path.resolve` を検索する。

修正:

* 不透明な ID を使い、サーバー側に保存されたパスに対応付ける。
* 解決されたパスが意図した基底ディレクトリ内にとどまるようにする。
* URL の作成時に `..` が使用されないようサニタイズし、許可しない。

---

### NEXT-SSRF-001: ユーザーの影響を受ける URL への送信リクエストを制限する

重大度: 中（内部ネットワークでは高）

注: これは主に、クラウド／LAN 環境にデプロイするアプリや、同じマシン上に他の HTTP サービスがあるアプリに該当します。Webhook など、機能上どうしてもこの動作が必要な場合もあります。

必須事項:

* ユーザー提供 URL に対するサーバー側の `fetch()` は、すべて高リスクとして扱うこと。
* URL 取得機能では、宛先（ホスト／ドメイン）を許可リストで制限することが望ましい。
* 次をブロックすることが望ましい:

  * localhost／プライベート IP アドレス範囲／リンクローカル
  * クラウドのメタデータエンドポイント
* プロトコルを `http:` と `https:` に制限すること。
* 厳格なタイムアウトを設定し、リダイレクトを制限することが望ましい。

安全でないパターン:

* `await fetch(req.query.url)` または `await fetch((await request.json()).url)`
* 任意の URL を取得する「URL プレビュー」エンドポイント。

検出のヒント:

* サーバーコード内の `fetch(` を検索し、URL の取得元を追跡する。
* 「Webhook テスター」「プレビュー」「URL からインポート」機能を探す。

修正:

* URL を解析して `http/https` を適用し、ホスト名を許可リストで制限する。DNS／IP を再解決し、プライベートアドレス範囲をブロックする。
* タイムアウト（AbortSignal）を設定し、リダイレクト数を制限する。

---

### NEXT-REDIRECT-001: オープンリダイレクトを防ぐ（認証フローを含む）

重大度: 低

必須事項:

* 信頼できない入力（例: `next`、`redirect`、`returnTo`）から導出されるリダイレクト先を検証すること。
* 同一サイト内の相対パスへのリダイレクトを優先することが望ましい。
* 絶対 URL は必ず許可リストと照合して検証すること。
* URL が `http` または `https:` スキーマであることを確認し、`javascript:` スキーマを許可しないこと。

安全でないパターン:

* `redirect(searchParams.get('next')!)`
* チェックを行わない `NextResponse.redirect(new URL(req.nextUrl.searchParams.get('to')!, req.url))`

検出のヒント:

* `redirect(`（サーバーコンポーネント／アクション）と `NextResponse.redirect` を検索する。
* API Routes 内の `res.redirect(` を検索する。([Next.js][3])

修正:

* 相対パス（`/path`）だけを許可し、プロトコル相対（`//evil.com`）や絶対 URL は拒否する。
* 無効な場合は安全な既定値（ホーム／ダッシュボード）にフォールバックする。

---

### NEXT-CORS-001: CORS は明示的に設定し、最小権限にする

重大度: 中（認証情報との組み合わせを誤ると高）

必須事項:

* CORS が不要なら、必ず無効のままにすること。
* Next.js API Routes は既定で CORS ヘッダーを設定しないため、既定では同一オリジンのみが許可される。実際に必要な場合に限り CORS を有効にすること。([Next.js][3])
* CORS を有効にする場合:

  * 信頼できるオリジンを必ず許可リストで制限する（任意の Origin をそのまま反映しない）。
  * 認証情報付きリクエスト（Cookie）の扱いに注意する。広範なオリジン許可と認証情報を決して組み合わせない。
  * メソッドとヘッダーを制限することが望ましい。

安全でないパターン:

* `Access-Control-Allow-Origin: *` と `Access-Control-Allow-Credentials: true` の組み合わせ
* 検証せずに `Origin` を反映する。

検出のヒント:

* `Access-Control-Allow-Origin`、`cors`、「CORS」ミドルウェア／ラッパーを検索する。
* プリフライトの `OPTIONS` ハンドラーを確認する。

修正:

* 厳格なオリジン許可リストを実装し、メソッド／ヘッダーを最小限にする。
* 必要性を確認してレビューした場合を除き、Cookie がクロスオリジンに公開されないようにする。

---

### NEXT-WEBHOOK-001: Webhook エンドポイントは必ず生のボディを使って真正性を検証する

重大度: 中

必須事項:

* **生のリクエストボディ**を使って Webhook の署名を検証すること（解析済みオブジェクトを再シリアライズしたものは使わない）。
* Next.js では、Webhook リクエストの生のボディを検証する用途として、ボディ解析を無効にする方法が挙げられている。([Next.js][3])

安全でないパターン:

* `JSON.stringify(req.body)` に対して Webhook 署名を検証する（書式が変わる可能性がある）。
* 署名検証も許可リストもなしに Webhook を受け入れる。

検出のヒント:

* Webhook エンドポイント（`/api/webhook`、`/app/api/**/webhook`）を見つける。
* 生のボディを使った検証を行っているか確認する。

修正:

* 対象の Webhook ルートに限って Next.js の自動ボディ解析を無効にし、生のバイト列を安全に読み込んで署名を検証してから解析する。

---

### NEXT-INJECT-001: SQL インジェクションを防ぐ（パラメーター化クエリ／ORM を使用する）

重大度: 高

必須事項:

* パラメーター化クエリ、または内部でクエリをパラメーター化する ORM を使用すること。
* 信頼できない入力を使った文字列連結／テンプレート文字列で SQL を組み立てないこと。

安全でないパターン:

* ``db.query(`SELECT * FROM users WHERE id = ${id}`)``
* `"WHERE name = '" + user + "'"`

検出のヒント:

* `SELECT`、`INSERT`、`UPDATE`、`DELETE` 文字列を検索する。
* 信頼できない入力（`params`、`searchParams`、`req.query`、`req.body`、`request.json()`）が DB 呼び出しに渡される箇所を追跡する。

修正:

* プリペアドステートメント／ORM のクエリ API を使用する。
* クエリの前に型を検証し、適切な型へ変換する。

---

### NEXT-INJECT-002: OS コマンドインジェクションと安全でないサブプロセスの使用を防ぐ

重大度: 重大～高

必須事項:

* 攻撃者が制御できる入力を使って OS コマンドを実行しないこと。
* サブプロセスが必要な場合:

  * 単一のシェル文字列ではなく、配列として引数を渡すこと。
  * 攻撃者の影響を受ける文字列とともに `shell: true` を使用しないこと。
  * 変数部分には厳格な許可リストを使うことが望ましい。

安全でないパターン:

* `exec("convert " + filename)`
* `spawn("bash", ["-c", userInput])`
* `spawn(userInput, ["foo"])`

検出のヒント:

* `child_process`、`exec`、`spawn`、`shell: true` を検索する。

修正:

* シェルコマンドの代わりにライブラリー API を使用する。
* コマンドをハードコードし、検証済みのパラメーターを許可リストで制限する（対応している場合は、フラグを分離するために `--` を使用する）。

---

### NEXT-INJECT-003: 動的コード実行と安全でないデシリアライズを避ける

重大度: 高～重大

必須事項:

* 信頼できない文字列に対して `eval`、`new Function`、`vm.runIn*` を使用しないこと。
* 複雑な形式（YAML、XML、独自シリアライズ形式）のデシリアライズはリスクがあるものとして扱い、安全なパーサーと厳格なスキーマを使用すること。

安全でないパターン:

* `eval(req.body.code)`
* 安全でないスキーマでユーザー入力の YAML を解析する。

検出のヒント:

* リテラル以外を引数とする `eval(`、`new Function`、`vm.`、`require(` を検索する。
* 信頼できない入力に対する `js-yaml`、XML パーサー、独自シリアライザーの使用箇所を検索する。

修正:

* 動的実行をなくし、安全なインタープリターまたは厳格なパーサーを使用する。
* 入力を検証し、制約する。

---

### NEXT-LOG-001: ログに秘密情報や機密性の高いヘッダーを含めない

重大度: 中

必須事項:

* 次の情報をログに記録しないこと:

  * `Authorization` ヘッダー
  * Cookie／セッショントークン
  * 認証情報を含むリクエストボディ
  * 環境変数または設定のダンプ
* リダクション機能を備えた構造化ログを実装することが望ましい。

安全でないパターン:

* 認証エンドポイント内の `console.log(req.headers)`
* サーバーコード内の `console.log(process.env)`

検出のヒント:

* サーバールート／アクション内の `console.log(`、`logger.info(`、`debug(` を検索する。
* ヘッダー／Cookie／ボディのログ記録を確認する。

修正:

* 機密フィールドをリダクトし、デバッグに必要な情報だけを記録する。
* クライアントには安全なエラーメッセージを返し、詳細はサーバー側だけに保持する。

---

### NEXT-ERROR-001: 本番環境では実装の詳細が漏れないようエラー処理を行う

重大度: 低

必須事項:

* 本番環境でスタックトレースや内部エラーの詳細をエンドユーザーに公開しないこと。
* 本番モードでの動作を確認する（Next.js の本番環境でのエラー処理は開発環境と異なる）。([Next.js][6])

安全でないパターン:

* JSON レスポンスで `err.stack` を返す。
* 未認証ユーザーに詳細な例外データを表示する。

検出のヒント:

* `res.status(500).json(err)` または `return Response.json(err)` を検索する。
* エラーレスポンスがサニタイズされているか確認する。

修正:

* クライアントには一般的なエラーメッセージを返し、詳細はリダクションしてサーバー側に記録する。

---

### NEXT-PROXY-001: Proxy／Middleware によるヘッダースマグリングや安全でないヘッダー転送を防ぐ

重大度: 中

必須事項:

* リクエストヘッダーを上流へコピー／転送する際は注意すること:

  * 信頼できるプロキシチェーンがない限り、攻撃者が制御できる `x-forwarded-*` ヘッダーを転送しない。
  * 無関係な外部サービスに `Authorization`／Cookie を転送しない。
* Next.js の Proxy パターンではヘッダーを変更することが多いため、それによってセキュリティ上の問題が生じないことを確認する。

安全でないパターン:

* すべてのリクエストヘッダーを無条件に送信先の `fetch()` 呼び出しへ複製する。
* 許可リストを使わずに、`x-forwarded-host` または `host` を信頼して機密性の高い絶対 URL を組み立てる。

検出のヒント:

* `headers()` と `request.headers` の使用箇所を検索する（特に URL の組み立て）。([Next.js][4])
* Proxy/Middleware のヘッダー書き換えを検索する。

修正:

* 転送するヘッダーを明示的な許可リストで指定する。
* コールバック URL やリダイレクトの組み立てに使う前に、ホスト名を検証する。

---

### NEXT-HOST-001: Host/Origin から導出する URL の組み立てには許可リストが必須

重大度: 中

必須事項:

* 検証されていない `Host` ヘッダーから、セキュリティ上重要な絶対 URL（パスワードリセットリンク、OAuth コールバック URL、メールアドレス確認リンク）を直接生成してはならない。
* Server Actions では、Origin/Host の照合は CSRF 対策の一部であるため、これを弱めてはならない。([Next.js][5])

安全でないパターン:

* `const base = "https://" + request.headers.get("host")`
* 検証されていない `x-forwarded-host` を絶対 URL の生成に使う。

検出のヒント:

* `.get('host')`、`.get('x-forwarded-host')`、および絶対 URL の組み立てを検索する。
* 認証関連のメールリンク生成コードを確認する。

修正:

* 設定済みで許可リストに登録された正規のアプリケーションオリジン（例: `APP_ORIGIN=https://example.com`）を使う。
* ホスト名を許可リストに登録し、検証に失敗した場合は処理を拒否する。

---

### NEXT-DOS-001: 不正利用されやすいエンドポイントにはレート制限とリソース制御が必須

重大度: 中

必須事項:

* 以下にレート制限またはスロットリングを実装することが望ましい:

  * ログイン、パスワードリセット、登録
  * 負荷の高い Server Actions
  * Webhook の取り込み
* リクエストサイズ制限を必ず実装する（NEXT-LIMITS-001 を参照）。
* セルフホスティングの場合は、追加の保護策としてリバースプロキシを必ず利用する。([Next.js][8])

安全でないパターン:

* ログインまたはリセットのエンドポイントにスロットリングがない。
* 負荷の高いアクションを認証なし、または頻度無制限で呼び出せる。

検出のヒント:

* 認証エンドポイントを特定し、レート制限があるか確認する。
* 「メール送信」「課金」「レポート生成」の処理フローを検索する。

修正:

* エッジでのレート制限と、アプリケーションレベルでのユーザー別・IP 別スロットリングを追加する。
* 重い処理にはジョブキューを追加し、適切な場合は 202 を返す。

---

## 5) 実践的なスキャンのヒューリスティクス（「探し方」）

実際にスキャンする際は、次の検出力の高いパターンを使う:

* 本番環境の設定ミス:

  * `next dev`、`NODE_ENV=development`、開発専用の起動コマンド ([Next.js][7])
* シークレットの露出:

  * `.env` がコミットされている、機密変数に `NEXT_PUBLIC_` が設定されている ([Next.js][7])
  * `process.env` が `"use client"` モジュールで使われている
* 認証の適用範囲:

  * 認証チェックのない `app/**/route.ts` または `pages/api/**` ([Next.js][1])
  * DB 書き込みを行う `"use server"` アクションに認可チェックがない ([Next.js][6])
  * 機密性の高いルートを除外する `proxy.ts` / `middleware.ts` マッチャー ([Next.js][12])
* CSRF:

  * Cookie 認証を使う POST/PUT/PATCH/DELETE でトークンまたは Origin のチェックがない
  * 範囲が広すぎる `serverActions.allowedOrigins` ([Next.js][5])
* XSS:

  * `dangerouslySetInnerHTML`、サニタイズされていない HTML の Markdown 描画
  * CSP がない、または許可範囲が広すぎる CSP ([Next.js][7])
* キャッシュ／データ漏えい:

  * 機密性の高い GET ハンドラーでの `dynamic = 'force-static'` ([Next.js][1])
  * ユーザー固有データの周辺で使われる `use cache`、`cacheLife`、`unstable_cache` ([Next.js][1])
* ファイル:

  * `public/` 以下へのアップロード書き込み
  * リクエスト入力を使う `fs.readFile` / `path.join`
* SSRF:

  * Route Handlers / Server Actions からの `fetch(userProvidedUrl)`
* リダイレクト:

  * `redirect(searchParams.get('next'))`、`NextResponse.redirect(...)`、`res.redirect(req.query.next)` ([Next.js][3])
* CORS:

  * ワイルドカードオリジン、Origin の反射、認証情報と広範なオリジンの併用 ([Next.js][3])
* 制限:

  * `bodyParser: false` を使う API ルート、および Webhook の生ボディ検証がないこと ([Next.js][3])
  * 正当な理由なく引き上げられた `serverActions.bodySizeLimit` ([Next.js][5])
* 依存関係の衛生管理:

  * サポートポリシーやセキュリティ勧告に抵触する古い `next` のバージョン ([Next.js][10])

必ず次の点を確認する:

* データの出所（信頼できないものか、信頼できるものか）
* シンクの種類（HTML/DOM、SQL、サブプロセス、ファイル、リダイレクト、送信 HTTP）
* 存在する保護策（スキーマ検証、許可リスト、middleware/proxy のチェック、認可ヘルパー、エッジ保護）

---

## 6) 参照元（2026-01-27 閲覧）

フレームワークの一次資料（Next.js）:

* Next.js Docs: インストール（システム要件 / Node バージョン） — `https://nextjs.org/docs/app/getting-started/installation`
* Next.js Docs: Route Handlers — `https://nextjs.org/docs/app/getting-started/route-handlers`
* Next.js Docs: API Routes（Pages Router）— `https://nextjs.org/docs/pages/building-your-application/routing/api-routes`
* Next.js Docs: 環境変数 — `https://nextjs.org/docs/pages/guides/environment-variables`
* Next.js Docs: データセキュリティ — `https://nextjs.org/docs/app/guides/data-security`
* Next.js Docs: コンテンツセキュリティポリシー — `https://nextjs.org/docs/app/guides/content-security-policy`
* Next.js Docs: Proxy — `https://nextjs.org/docs/app/getting-started/proxy`
* Next.js Docs: `serverActions.allowedOrigins` と `serverActions.bodySizeLimit` — `https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions`
* Next.js Docs: `cookies()` — `https://nextjs.org/docs/app/api-reference/functions/cookies`
* Next.js Docs: `headers()` — `https://nextjs.org/docs/app/api-reference/functions/headers`
* Next.js Docs: セルフホスティング（リバースプロキシのガイダンス）— `https://nextjs.org/docs/pages/guides/self-hosting`
* Next.js Docs: サポートポリシー（サポート対象バージョン / LTS）— `https://nextjs.org/docs/support-policy`

Next.js のセキュリティガイダンスと勧告:

* Next.js Blog: Next.js のセキュリティを考える — `https://nextjs.org/blog/security-nextjs-server-components-actions`
* GitHub Security Advisory: Server Components / Server Actions を介した Next.js の DoS（CVE-2026-23864）— `https://github.com/advisories/GHSA-fq29-rrrv-cq2m`
* Next.js Blog: セキュリティ更新（セキュリティ勧告の参考例）— `https://nextjs.org/blog/security-update`

一般的な Web セキュリティの参考資料（推奨される基準）:

* OWASP Cheat Sheet Series（CSRF、セッション管理、XSS 対策、SSRF 対策、ファイルアップロード、HTTP ヘッダー）— `https://cheatsheetseries.owasp.org/`

[1]: https://nextjs.org/docs/app/getting-started/route-handlers "はじめに: Route Handlers | Next.js"
[2]: https://nextjs.org/docs/app/getting-started/deploying?utm_source=chatgpt.com "はじめに: デプロイ"
[3]: https://nextjs.org/docs/pages/building-your-application/routing/api-routes "ルーティング: API Routes | Next.js"
[4]: https://nextjs.org/docs/app/api-reference/functions/headers "関数: headers | Next.js"
[5]: https://nextjs.org/docs/app/api-reference/config/next-config-js/serverActions "next.config.js: serverActions | Next.js"
[6]: https://nextjs.org/blog/security-nextjs-server-components-actions "Next.js のセキュリティを考える | Next.js"
[7]: https://nextjs.org/docs/pages/guides/environment-variables "ガイド: 環境変数 | Next.js"
[8]: https://nextjs.org/docs/pages/guides/self-hosting?utm_source=chatgpt.com "ガイド: セルフホスティング"
[9]: https://nextjs.org/docs/app/api-reference/functions/cookies "関数: cookies | Next.js"
[10]: https://nextjs.org/blog/next-16?utm_source=chatgpt.com "Next.js 16"
[11]: https://github.com/vercel/next.js/security/advisories/GHSA-9g9p-9gw9-jx7f?utm_source=chatgpt.com "画像オプティマイザーのサービス拒否 · 勧告"
[12]: https://nextjs.org/docs/pages/guides/authentication "ガイド: 認証 | Next.js"