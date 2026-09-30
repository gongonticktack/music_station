# Vue.js Webセキュリティ仕様（Vue 3.x、TypeScript/JavaScript、一般的なツール：Vite）

このドキュメントは、次の用途を支援する**セキュリティ仕様**として作成されています。

1. 新しいVueコードを対象とした**セキュア・バイ・デフォルトのコード生成**。
2. 既存のVueコードを対象とした**セキュリティレビュー／脆弱性調査**（作業中に問題に気づく受動的な確認、およびリポジトリをスキャンして検出事項を報告する能動的な確認）。

この文書は、「MUST/SHOULD/MAY」による**規範的な要件**と、**監査ルール**（危険なパターンの例、検出方法、修正・緩和方法）で構成されています。

---

## 0) 安全性、境界、および悪用防止の制約（必ず守る）

* シークレット（APIキー、パスワード、秘密鍵、セッションCookie、認証トークン）を要求、出力、ログ記録、コミットしてはなりません。
* 保護機能を無効化してセキュリティを「修正」してはなりません（例：CSPを弱める、安全でないテンプレートコンパイルを有効にする、近道として`v-html`を使う、バックエンドの認証を迂回する、または「トークンをlocalStorageに保存するだけ」など）。
* 監査では、根拠に基づく検出結果を提示しなければなりません。主張を裏付けるファイルパス、コードスニペット、設定値を示してください。
* 不確実な点は正直に扱ってください。エッジ（CDN、リバースプロキシ、WAF、サーバーヘッダー）に保護機能が存在する可能性がある場合は、「リポジトリ内では確認できないため、実行環境／インフラ設定を確認」と報告してください。
* フロントエンドの信頼モデルを常に意識してください。ブラウザーに配信されるコードはすべて、攻撃者が読み取り、改変できます。シークレットや「セキュリティの強制」をフロントエンドのみのロジックに依存させてはなりません。

---

## 1) 動作モード

### 1.1 生成モード（デフォルト）

新しいVueコードの作成または既存コードの変更を依頼された場合：

* この仕様のすべての**MUST**要件に従わなければなりません。
* ユーザーが明示的に別の指示をしない限り、すべての**SHOULD**要件に従うべきです。
* 独自のセキュリティコードより、安全なデフォルトを備えたフレームワーク機能や実績のあるライブラリを優先しなければなりません。
* 新たな危険なシンク（実行時テンプレートコンパイル、`v-html` / `innerHTML`、安全でないURL遷移、動的スクリプト注入など）を導入してはなりません。([Vue.js][1])

### 1.2 受動的レビュー・モード（編集中は常に有効）

Vueリポジトリ内のどこかで作業している間（ユーザーからセキュリティスキャンを依頼されていない場合も含む）：

* この仕様への違反に気づかなければなりません。
* 問題が見つかったら、簡潔な説明と安全な修正方法を添えて伝えるべきです。

### 1.3 能動的監査モード（明示的なスキャン依頼時）

ユーザーから「スキャン」「監査」または「脆弱性を探す」よう依頼された場合：

* この仕様への違反がないか、コードベースを体系的に検索しなければなりません。
* 検出結果を所定の形式（§2.3参照）で出力しなければなりません。

推奨する監査順序：

1. ビルド／デプロイのエントリーポイントとホスティング設定（Docker、CI、静的ホスティング、SSRサーバー）。
2. シークレットの露出（環境変数の使用、`.env*`、ハードコードされたキー）。([vitejs][2])
3. XSSの攻撃対象：テンプレート、`v-html` / `innerHTML`、URL／スタイルへの注入、DOM API。([Vue.js][1])
4. ブラウザーでの認証／セッション処理（トークンの保存、認証情報付きリクエスト、CSRFとの連携）。([Vue.js][1])
5. ルーティング／遷移（オープンリダイレクト、「return_to/next」、安全でない外部遷移）。([Vue.js][1])
6. サードパーティのスクリプトとコンテンツ（CDNアセット、分析ツール、ウィジェット、iframe）。([Vue.js][1])
7. セキュリティヘッダーとブラウザーの堅牢化要件（CSP、クリックジャッキング対策）。([Vue.js][1])
8. 該当する場合はSSR固有の懸念事項（状態のシリアライズ、テンプレートの境界）。([Vue.js][1])

---

## 2) 定義とレビューの指針

### 2.1 信頼できない入力（信頼できると証明されない限り、攻撃者が制御できるものとして扱う）

Vueアプリにおける信頼できない入力には、次のものが含まれます（これらに限定されません）。

* APIから取得するすべてのデータ：`fetch`、`axios`、GraphQLレスポンス、Webhook、サードパーティSDK。
* ルーターによって制御されるデータ：`route.params`、`route.query`、`route.hash`、および`window.location`から派生するすべてのデータ。
* ユーザーが制御する永続化コンテンツ：UIに表示されるDB保存コンテンツ（コメント、プロフィール、CMSコンテンツ）。
* ブラウザーが制御するストレージ：`localStorage`、`sessionStorage`、`IndexedDB`。
* ウィンドウ間メッセージ：`postMessage`の入力。
* DOM clobberingやHTML注入によって攻撃者が影響を与えられるもの（特に、不浄なDOMにVueをマウントする場合）。([Vue.js][1])

### 2.2 状態を変更するアクション（フロントエンドの観点）

次のいずれかを行えるアクションは、状態を変更するものです。

* API呼び出しを通じてデータを作成、更新、削除する。
* 認証／セッション状態を変更する（ログイン、ログアウト、トークン更新）。
* 特権操作（決済、管理者操作）を実行する。
* 副作用を引き起こす（メール送信、Webhookの起動、アカウント設定の変更）。

### 2.3 必須の監査検出形式

検出した各問題について、次の項目を出力してください。

* ルールID：
* 重大度：Critical / High / Medium / Low
* 場所：ファイルパス + コンポーネント／関数 + 行番号
* 根拠：該当するコード／設定の正確なスニペット
* 影響：何が起こり得るか、誰が悪用できるか
* 修正：安全な変更（差分は最小限にする）
* 緩和策：即時修正が難しい場合の多層防御
* 誤検知に関する注記：不確実な場合に確認すべき点

---

## 3) セキュアなベースライン：本番環境の最低限の設定（本番環境では必須）

これは、Vue／フロントエンドでよくある設定ミスを防ぐための最小限の「本番環境ベースライン」です。

* **本番ビルド**を配信しなければなりません（開発ビルドや開発サーバーを配信してはなりません）。([Vue.js][3])
* フロントエンドのバンドルにシークレットを含めてはなりません。クライアントに公開されるすべての環境変数は公開情報として扱ってください。([vitejs][2])
* 信頼できないテンプレートを描画したり、ユーザー提供のVueテンプレートを許可したりしてはなりません（任意のJavaScript実行と同等です）。([Vue.js][1])
* 生HTMLの注入（`v-html`、`innerHTML`）は、コンテンツが信頼できる場合、または強固にサンドボックス化されている場合を除き、避けるべきです。([Vue.js][1])
* サーバー／CDNレイヤーで、基本的なセキュリティヘッダー（特にCSPとクリックジャッキング対策）を設定すべきです。([OWASP Cheat Sheet Series][4])
* 安全な認証パターンを使用すべきです（セッショントークンにはHttpOnly Cookieを優先し、CSRF対策についてバックエンドと連携してください）。([Vue.js][1])

---

## 4) ルール（生成＋監査）

各ルールには、必須の対処、安全でないパターン、検出の手がかり、および修正方法が含まれます。

### VUE-DEPLOY-001: 本番環境で開発／プレビューサーバーを実行しない

重大度：High

必須事項：

* Vite／Vueの開発サーバー（`vite`、`npm run dev`、HMR）を本番サーバーとしてデプロイしてはなりません。
* 本番サーバーとして`vite preview`を使用してはなりません。([vitejs][5])
* `vite build`でビルドし、SSRを使用している場合は本番品質の静的サーバー／CDN、または本番SSRサーバーでビルド済みアセットを配信しなければなりません。([vitejs][6])

安全でないパターン：

* Docker／Procfile／systemdで、`vite`、`npm run dev`、または`vite preview`を本番エントリーポイントとして実行している。
* HMRエンドポイントが外部に公開されている。

検出の手がかり：

* 検索対象：`vite`、`npm run dev`、`pnpm dev`、`yarn dev`、`vite preview`、`vue-cli-service serve`。
* Dockerの`CMD`、`ENTRYPOINT`、CIデプロイスクリプト、プラットフォーム設定を確認する。

修正：

* `vite build`で成果物をビルドする。
* 強化されたホスティング（CDN／静的サーバー）で`dist/`を配信するか、バックエンドサーバーに静的アセットとして組み込む。

注記：

* 開発／プレビューサーバーをローカルで使うのは問題ありません。本番エントリーポイントとして使われている場合にのみ指摘してください。

---

### VUE-DEPLOY-002: Vueの本番ビルドを使用し、本番環境ではdevtoolsを無効にする

重大度：Medium（本番環境でdevtools／デバッグフックが有効な場合はHigh）

必須事項：

* バンドラーを使わず、CDN／セルフホストからVueを読み込む場合、本番環境では`.prod.js`ビルドを使用しなければなりません。([Vue.js][3])
* 本番バンドルでVue devtoolsが有効にならないようにし、本番用devtoolsフラグを意図的に有効にしないようにすべきです。([Vue.js][7])

安全でないパターン：

* 本番環境に開発用ビルド成果物が含まれている。
* 本番用devtools／診断フックを明示的に有効にしている。

検出の手がかり：

* CDNビルドを使用している場合は、HTML内の`vue.global.js`／非`.prod.js`の派生形を検索する。
* Vueの`__VUE_PROD_DEVTOOLS__`などの機能フラグをビルド設定で検索する。([Vue.js][7])

修正：

* 本番ビルド成果物に切り替え、コンパイル時フラグが本番用に設定されていることを確認する。

---

### VUE-SECRETS-001: フロントエンドのコードや環境変数にシークレットを含めない

重大度：High（実際の認証情報が漏えいした場合はCritical）

必須事項：

* フロントエンドのコードと設定はすべて公開情報として扱わなければなりません。
* 次の場所にシークレットを埋め込んではなりません。

  * ソースコード
  * リポジトリにコミットされた`.env`ファイル
  * バンドルに含まれる`import.meta.env.*`変数
* クライアントバンドルに含まれる環境変数はすべて、攻撃者が読み取れるものと想定しなければなりません。([vitejs][2])

安全でないパターン：

* 真のシークレット（公開識別子にすぎないものではない）を含む`VITE_API_KEY=...`。
* JS／TSにハードコードされたAPIキー、秘密トークン、サービス認証情報、署名鍵。

検出の手がかり：

* 検索対象：`VITE_`、`import.meta.env`、`.env`、`.env.production`、`.env.*.local`。
* `API_KEY`、`SECRET`、`TOKEN`、`PRIVATE_KEY`、`BEGIN`、`sk-`、`AKIA`などを検索する。

修正：

* シークレットをバックエンド／エッジ関数に移す。
* 必要に応じて、バックエンドで発行した短期間有効なトークンをブラウザーで使用する。

注記：

* Viteのドキュメントでは、`.env.*.local`をgitignoreに追加すべきであり、`VITE_*`変数はクライアントバンドルに含まれるため、機密情報を入れてはならないと明記されています。([vitejs][2])

---

### VUE-SECRETS-002: Viteの環境変数公開範囲を広げない

重大度：High

必須事項：

* すべての環境変数をクライアントに公開するようViteを設定してはなりません。
* `envPrefix`は厳格かつ明示的に保つべきです。

安全でないパターン：

* 「環境変数を使えるようにする」ため、`envPrefix`に広すぎる値（または`''`）を設定する。
* ビルド時にサーバーのシークレットをHTMLのグローバル変数へ注入するカスタムスクリプト。

検出の手がかり：

* `vite.config.*`で`envPrefix`を確認する。
* `define: { 'process.env': ... }`や、`window.__CONFIG__`への手動注入を探す。

修正：

* シークレットはサーバー側に保持する。
* 公開を意図して設計された非機密情報だけを公開する。

注記：

* Viteのドキュメントによると、公開されるのはプレフィックス付きの変数のみであり、公開された変数はクライアントバンドルに含まれます。([vitejs][2])

---

### VUE-XSS-001: Vueのデフォルトのエスケープ処理を優先し、生HTMLの注入を避ける

重大度：High

必須事項：

* 可能な限り、テキスト補間と属性バインディングにはVueの自動エスケープを利用しなければなりません。([Vue.js][1])
* 次の方法でユーザー提供のHTMLを描画してはなりません。

  * `v-html`
  * レンダー関数／JSX内の`innerHTML`
  * 直接的なDOM API（`element.innerHTML`、`insertAdjacentHTML`）
    ただし、HTMLが信頼できる場合、または堅牢にサニタイズされ、リスクが明示的に受け入れられている場合を除きます。([Vue.js][1])

安全でないパターン：

* `<div v-html="userProvidedHtml"></div>`
* `h('div', { innerHTML: userProvidedHtml })`
* `<div innerHTML={userProvidedHtml}></div>`
* `el.innerHTML = untrusted`

検出の手がかり：

* 検索対象：`v-html`、`innerHTML`、`insertAdjacentHTML`、`DOMParser`、`document.write`。

修正：

* 信頼できないコンテンツはテキストとして描画する（補間を使用）。
* HTMLの描画が必要な場合（例：Markdown）、保守が継続されているHTMLサニタイザーでサニタイズし、多層防御（CSP、Trusted Types）を適用する。([Vue.js][1])

注記：

* Vueのドキュメントは、ユーザー提供のHTMLについて、サンドボックス化するか厳密に自身だけに公開する場合を除き、「100%安全」ではないと明確に警告しています。([Vue.js][1])

---

### VUE-XSS-002: 信頼できないテンプレートを絶対に使用しない（クライアント側のテンプレート／コード注入）

重大度：Critical

必須事項：

* 信頼できないコンテンツをVueコンポーネントのテンプレートとして使用してはなりません。
* 「ユーザーがVueテンプレートを記述できる」ことは「アプリ内で任意のJavaScriptを実行できる」ことと同等であり、SSRのコンテキストではさらに問題になり得るものとして扱わなければなりません。([Vue.js][1])
* 実行時のみのビルド（テンプレートをビルド時にコンパイルする）を優先し、審査済みの必要性がない限り、実行時コンパイラーを含めないようにすべきです。

安全でないパターン：

* `createApp({ template: '<div>' + userProvidedString + '</div>' }).mount(...)`
* DBにテンプレートを保存し、ブラウザーでコンパイル／描画する。
* Vueテンプレート構文を入力できる管理者／CMS機能。

検出の手がかり：

* 値が静的文字列ではない`template:`を検索する。
* `@vue/compiler-dom`、`compile(`、「実行時コンパイラー」ビルドの選択、動的なSFCコンパイルを検索する。
* 「テンプレートエディター」「カスタムテンプレート」「テーマHTML」機能を検索する。

修正：

* テンプレートはコードとして扱い、開発者が管理する状態に保つ。
* エンドユーザーによるカスタマイズが必要な場合は、サニタイザーを通してレンダリングする安全な形式（制限付きMarkdownサブセット）を使用するか、サンドボックス化されたiframe内に隔離する。

---

### VUE-XSS-003: ユーザー提供のサーバーレンダリングHTMLが含まれる可能性のあるDOMにVueをマウントしない

深刻度: 中

必須事項:

* サーバーレンダリングされ、ユーザーが提供したコンテンツを含む可能性のあるノードにVueをマウントしてはならない（「HTMLとしては安全」な攻撃者制御のHTMLも、Vueテンプレートとして扱われると危険になる可能性があるため）。([Vue.js][1])
* アプリのDOMはVueが制御するテンプレート／コンポーネントから描画し、Vueは「無菌」なルート要素にマウントすることが望ましい。

安全でないパターン:

* サーバーがユーザーコンテンツを`#app`に出力し、その後Vueを`#app`にマウントして、そのDOMをテンプレートとしてコンパイル／解釈する。
* ユーザー生成コンテンツを含む大規模なサーバーレンダリングページに「Vueを散りばめる」。

検出の手がかり:

* サーバーテンプレート（例: Rails／Django／Expressのテンプレート）で、Vueのマウントルート内にユーザーのHTMLが挿入されていないか確認する。
* `mount('#app')`を探し、`#app`にサーバーレンダリングされたUGCが含まれていないか確認する。

修正:

* ユーザーがレンダリングしたHTMLをVueのマウントルートの外に移動するか、Vueコンポーネントから安全な方法（テキスト／サニタイズ済みHTML）でレンダリングする。

---

### VUE-XSS-004: バインディングとナビゲーションにおけるURLインジェクションを防ぐ

深刻度: 高

必須事項:

* ユーザーの影響を受けるURLをナビゲーションシンク（`href`、`src`、`action`、`window.location`、`window.open`、外部へのルーター遷移）にバインドする前に、必ず検証／サニタイズする。
* `<a :href="userProvidedUrl">`のようなバインディングで、`javascript:`によるURL実行を必ず防ぐ。([Vue.js][1])
* プロトコルと宛先を検証することが望ましい（`https:`と想定ホストを許可リスト化し、意図する場合に限り`mailto:`／`tel:`を許可する）。

安全でないパターン:

* `<iframe :src="userProvidedUrl">`
* `window.location = route.query.next`
* `window.open(userProvidedUrl)`

検出の手がかり:

* 信頼できない入力を使う`:href=`、`:src=`、`window.location`、`location.href`、`window.open`、`router.push(`を検索する。
* クエリパラメーター`next`、`return_to`、`redirect`を探す。

修正:

* 制御可能なルート名／パスを使った内部ナビゲーションを優先する。
* 外部URLの場合: `new URL(...)`で解析し、プロトコル／ホストを許可リスト化し、`javascript:`やその他の危険なスキームを拒否する。
* ユーザーURLを保存する前にバックエンドでサニタイズおよび検証する（Vueのドキュメントはバックエンドでのサニタイズを明示的に推奨している）。([Vue.js][1])

---

### VUE-XSS-005: スタイル／CSSインジェクションとUIの偽装を防ぐ

深刻度: 低

必須事項:

* 攻撃者が制御するCSS文字列を広範にバインドしてはならない（例: `:style="userProvidedStyles"`）。
* ユーザーカスタマイズが必要な場合は、Vueのスタイルオブジェクト構文を使い、安全で具体的なプロパティのみを許可することが望ましい。([Vue.js][1])
* ユーザーがレイアウト／CSSを制御できる機能は、サンドボックス化されたiframe内に隔離することが望ましい。

安全でないパターン:

* スタイルが攻撃者に制御される`:style="userProvidedStyles"`。
* ユーザー提供の`<style>`コンテンツをレンダリングすること（Vueが一部のパターンをブロックしても、回避を試みてはならない）。

検出の手がかり:

* API／ユーザーコンテンツに由来する定数以外の変数にバインドされた`:style="`を検索する。
* 「custom CSS」、「theme editor」、「profile CSS」を検索する。

修正:

* プロパティと値を許可リスト化し、生のスタイル文字列を避ける。
* リッチなユーザーカスタマイズにはサンドボックス化されたiframeを使う。

---

### VUE-XSS-006: ユーザー提供のJavaScriptをイベントハンドラー属性にバインドしない

深刻度: 重大

必須事項:

* 攻撃者が提供した文字列をイベントハンドラー属性（例: `onclick`、`onfocus`など）にバインドしてはならない。
* サンドボックス化され、自己にのみ公開されることが保証されていない限り、「ユーザー提供のJS」は安全でないものとして扱わなければならない。([Vue.js][1])

安全でないパターン:

* `<div :onclick="userProvidedString">`
* `<a :onmouseenter="userProvidedString">`

検出の手がかり:

* `:on`の後にイベント属性名（`:onclick`、`:onload`など）が続く箇所を検索する。
* `setAttribute('on`のパターンを検索する。

修正:

* 開発者が制御するハンドラーを使った実際のイベントリスナーを使用する。
* ユーザーによるスクリプト実行が本当に必要な場合は、隔離する（サンドボックス化されたiframeと厳格な境界を使用する）。

---

### VUE-ROUTER-001: クライアント側のルートガードを認可として扱わない

深刻度: 高

必須事項:

* 認可の強制にVue Routerのガード、UIの非表示、またはクライアント側チェックに依存してはならない。
* 特権的な操作と機密データの応答すべてについて、バックエンドで認可を強制しなければならない。([OWASP Cheat Sheet Series][8])

安全でないパターン:

* 「`beforeEach`が`user.isAdmin`を確認するから、管理者ルートは保護されている。」
* 「許可されていない限りフロントエンドから呼び出されない」と想定している機密APIエンドポイント。

検出の手がかり:

* `router.beforeEach`でロールベースの制御を検索し、バックエンドでも強制されているか確認する。
* サーバー側の裏付けがない「ルートメタデータによるセキュリティ」パターン（`meta.requiresAdmin`）を探す。

修正:

* ルートガードはUX上の目的（誤操作によるアクセスを減らすこと）に限って使い、実際のチェックはサーバー側で強制する。

---

### VUE-ROUTER-002: オープンリダイレクトと安全でない「return_to/next」の処理を防ぐ

深刻度: 低

必須事項:

* 信頼できない入力に由来するリダイレクト先（`next`、`return_to`、`redirect`）を必ず検証する。
* 同一サイト内の相対パス、または明示的な宛先の許可リストのみを許可することが望ましい。
* `http`／`https`以外のプロトコル（`javascript:`など）を許可してはならない。

安全でないパターン:

* `router.push(route.query.next as string)`
* `window.location.href = route.query.redirect`

検出の手がかり:

* `route.query.next`、`route.query.redirect`、`return_to`、`continue`、`callback`を検索する。
* 値がルーター／windowのナビゲーションシンクに渡されるまで追跡する。

修正:

* `/`で始まる相対パスのみを許可し（`//host`、`javascript:`などは拒否する）、それ以外は拒否する。
* 制御可能な名前付きルートへのリダイレクトを優先する。

注記:

* Vueのドキュメントも、サニタイズ済みURLであっても安全な宛先が保証されるとは限らないと述べている。([Vue.js][1])

---

### VUE-AUTH-001: トークンの保管ではXSSの可能性を前提とする

深刻度: 低

必須事項:

* JavaScriptからアクセスできるトークンは、どれもXSSを通じて盗まれる可能性があると想定しなければならない。
* セッショントークンには、バックエンドが設定するHttpOnly Cookieを優先し、必要に応じてCSRF対策を組み合わせることが望ましい。([Vue.js][1])
* 長期間有効なトークン（特にリフレッシュトークン）を`localStorage`／`sessionStorage`に保存しないことが望ましい。

安全でないパターン:

* 長期間有効なBearerトークンに`localStorage.setItem('token', ...)`を使う。
* JavaScriptからアクセス可能なストレージにリフレッシュトークンを保存する。

検出の手がかり:

* `localStorage`、`sessionStorage`、`indexedDB`、`persist`、`pinia-plugin-persistedstate`を検索する。
* 保存された値が認証／セッション情報かどうかを特定する。

修正:

* HttpOnly Cookieを使ったバックエンド管理のセッションを優先する。
* Bearerトークンが避けられない場合は、有効期間を短くし、メモリに保存して頻繁にローテーションする。さらに強力なXSS対策（CSP、Trusted Types、厳格なサニタイズ）を組み合わせる。([OWASP Cheat Sheet Series][4])

---

### VUE-CSRF-001: Cookieを使用する場合はバックエンドと連携してCSRF対策を行う

深刻度: 高（Cookie認証による状態変更リクエストの場合）

注: アプリケーションがCookieベースの認証を使用していない場合（たとえばAuthorizationヘッダーを渡す場合）、CSRFは問題にならない。

必須事項:

* APIリクエストにCookie（`credentials: 'include'`／`withCredentials: true`）が含まれ、そのCookieでユーザーを認証する場合は、バックエンドと連携したCSRF対策（トークン／ヘッダー方式、Originチェック、多層防御としてのSameSite Cookie）を必ず導入する。([Vue.js][1])
* バックエンドの保護を無効化したり、フロントエンドで`mode: 'no-cors'`を使用したりして、「CORS／CSRFエラーを解決」してはならない。

安全でないパターン:

* CSRFトークン／ヘッダーをどこでも使わずに`fetch(url, { credentials: 'include', method: 'POST', body: ... })`を使用する。
* バックエンド側で厳格なオリジン許可リストを設定せず、クロスオリジンの資格情報付きリクエストを有効にする。

検出の手がかり:

* `credentials: 'include'`、`withCredentials`、`xsrf`、`csrf`、`X-CSRF-Token`、`X-XSRF-TOKEN`を検索する。
* APIラッパーモジュールでヘッダーとCookieの設定を確認する。

修正:

* バックエンドが発行するCSRFトークンを実装し、状態変更リクエストでそのトークンを必須にする。
* 互換性がある場合はCookieに`SameSite=Lax/Strict`を設定し、適切な場合にはOrigin／Refererを確認する（バックエンド側で実施）。([OWASP Cheat Sheet Series][9])

注記:

* Vueのドキュメントは、CSRFは主にバックエンドで対処するものと明記している一方、CSRFトークンの送信について連携することを推奨している。([Vue.js][1])

---

### VUE-HTTP-001: URLに秘密情報を含めない。ナビゲーション／ログでの機密データ漏えいを避ける

深刻度: 中

必須事項:

* トークン／秘密情報をクエリ文字列やフラグメントに含めてはならない（ログ、リファラー、ブラウザー履歴から漏れるため）。
* 本番環境では、機密値をコンソールに記録しないことが望ましい。

安全でないパターン:

* 短期間のOAuth引き渡し以外の用途で`/?token=...`、`/#access_token=...`を使う。
* トークン／PIIを含む`console.log(userSession)`。

検出の手がかり:

* ルーターでの解析、認証コールバックハンドラー、分析ログにある`token=`を検索する。
* 認証コード周辺の`console.log(`を検索する。

修正:

* AuthorizationヘッダーまたはHttpOnly Cookieを使う。
* ログから機密情報を除去し、デバッグログは開発環境のみで有効にする。

---

### VUE-HEADERS-001: デプロイ層でセキュリティヘッダーを必須にする

深刻度: 中

必須事項:

* Vueアプリに適したCSP（`Content-Security-Policy`）をデプロイすることが望ましい。
* 意図的な埋め込みが必要な場合を除き、クリックジャッキング対策（CSPの`frame-ancestors`、および／または`X-Frame-Options`）をデプロイすることが望ましい。
* `X-Content-Type-Options: nosniff`と、必要に応じてその他のヘッダー（Referrer-Policy、Permissions-Policy）をデプロイすることが望ましい。([OWASP Cheat Sheet Series][4])

安全でないパターン:

* UGCまたはリッチHTMLのレンダリングがあるアプリで、サーバー／CDN設定にヘッダーの設定が見当たらない。
* 十分な根拠なく、CSPに`unsafe-inline`／`unsafe-eval`が含まれている。

検出の手がかり:

* ホスティング設定（nginx、Netlify／Vercelのヘッダー設定、CloudFront／Cloudflareルール）を確認する。
* リポジトリ内に見当たらない場合は、「エッジで確認」として指摘する。

修正:

* エッジまたはサーバーでヘッダーを設定する。保守的なCSPから始めて、徐々に厳格化する。

---

### VUE-CSP-001: 可能な場合はTrusted TypesとDOM XSS対策を使用する

深刻度: 低

必須事項:

* DOMへの注入箇所が多いアプリ（リッチテキスト、プラグイン、`v-html`）では、DOM XSSのリスクを抑えるためTrusted Typesの有効化を検討することが望ましい。([web.dev][10])
* Trusted Typesは多層防御として扱い、サニタイズの代替にしてはならない。

安全でないパターン:

* サニタイズやCSPの強化を行わずに`innerHTML`／`v-html`を頻繁に使用する。

検出の手がかり:

* `v-html`、`innerHTML`、`insertAdjacentHTML`を検索する。
* CSPヘッダーがリポジトリ内にある場合は、`require-trusted-types-for 'script'`の使用を確認する。

修正:

* HTMLの注入箇所を減らして一元管理し、入力をサニタイズし、適切な箇所にTrusted Typesポリシーを追加する。

---

### VUE-THIRDPARTY-001: 動的なサードパーティスクリプトの注入を避け、事前に検証した静的な読み込みを優先する

深刻度: 低

必須事項:

* URLがユーザー制御の場合、`<script src="...">`を注入してはならない。
* サードパーティのウィジェット／分析ツールはサプライチェーンリスクとして扱い、検証済みで固定されたソースからのみ読み込むことが望ましい。

安全でないパターン:

* `const s=document.createElement('script'); s.src = userProvidedUrl; ...`
* 任意のリモートスクリプトを読み込む「プラグインマーケットプレイス」。

検出の手がかり:

* `createElement('script')`、`.src =`、`appendChild(script)`を検索する。
* 「loadExternalScript」、「injectScript」、「cdnUrl」を検索する。

修正:

* 依存関係をバンドルするか、厳格なオリジン許可リストを設けて完全性を強制する（SRIルールを参照）。
* 信頼できないサードパーティUIにはサンドボックス化されたiframeの利用を検討する。

---

### VUE-SRI-001: CDNでホストされるスクリプト／スタイルにはSubresource Integrityを使用する

深刻度: 低

必須事項:

* CDNからスクリプト／スタイルを読み込む場合は、適切な`crossorigin`設定とともにSubresource Integrity（`integrity`属性）を使用することが望ましい。([MDN Web Docs][11])
* セキュリティ上重要なコードでは、実行時のCDN依存よりもセルフホスティングまたはバンドルを優先することが望ましい。

安全でないパターン:

* `integrity`を指定せずに`<script src="https://cdn.example/...">`を使用する。
* バージョンを固定せず、内容が変更される可能性のあるリモートスクリプトURL。

検出の手がかり:

* `https://`のscript／styleタグについて、`index.html`とサーバーテンプレートを検索する。
* `integrity=`を確認する。

修正:

* SRI ハッシュを追加してバージョンを固定するか、ビルド時にアセットをバンドルする。

---

### VUE-SUPPLY-001: 依存関係とパッチの適切な管理は必須

重大度: 低

必須事項:

* Vue と公式の関連ライブラリを最新の状態に保つことが望ましい。Vue は、可能な限り安全性を高く保つために最新バージョンを使うことを明示的に推奨している。([Vue.js][1])
* セキュリティ勧告には速やかに対応しなければならない。
* 依存関係のバージョンを固定し、ロックファイルをコミットすることが望ましい（本番成果物の差異を抑えるため）。

安全でないパターン:

* 既知の CVE がある古いメジャーバージョン。
* リポジトリにロックファイルがなく、重要な依存関係に広い semver 範囲を指定している。
* テンプレート、レンダリング、コンパイラのパッケージに関する勧告を無視している。

検出のヒント:

* `package.json`、ロックファイル、CI のインストールコマンドを確認する。
* `npm audit` が無効化されていないか、「脆弱性を無視する」スクリプトがないか検索する。

修正:

* 依存関係をアップグレードし、影響を受ける動作に対する回帰テストを追加する。
* CI に依存関係スキャンを追加する。

---

### VUE-SSR-001: SSR では信頼境界が増えるため、状態の埋め込みは XSS に関わるものとして扱う

重大度: 中

必須事項:

* SSR を使う場合、HTML ドキュメントに埋め込むもの（初期状態、シリアライズしたデータ、インラインスクリプト）はすべて、XSS に関わるものとして扱わなければならない。
* 安全でないテンプレートはレンダリング時にサーバー側でコードを実行させるおそれがあるため、「信頼できるテンプレートのみ」というルールをさらに厳格に守らなければならない。([Vue.js][1])
* Vue の SSR ドキュメントと SSR のセキュリティに関するベストプラクティスに従うことが望ましい。([Vue.js][1])

安全でないパターン:

* 信頼できない文字列を SSR テンプレートに連結する。
* 堅牢なエスケープやシリアライズ制御なしに、`<script>` ブロックへ JSON を埋め込む。

検出のヒント:

* サーバーコードで `__INITIAL_STATE__`、`window.__*STATE__`、テンプレートの連結、SSR のレンダリング処理を検索する。
* 信頼できないデータがそれらの出力先に流れ込んでいないか追跡する。

修正:

* 使用している SSR スタックが推奨する安全なシリアライズ方法を使う。
* 信頼できない HTML のレンダリングを避け、サニタイズするか隔離する。

---

## 5) 実践的なスキャンのヒューリスティクス（「探し方」）

実際にスキャンするときは、次のような検出力の高いパターンを使う:

* 本番環境での開発／プレビューサーバー:

  * `npm run dev`、`vite`、`vite preview`、`vue-cli-service serve` ([vitejs][5])
* シークレットの露出:

  * `.env`、`.env.production`、`.env.*.local`、`VITE_`、`import.meta.env`、ハードコードされた `API_KEY` / `SECRET` ([vitejs][2])
* XSS のシンク:

  * `v-html`、`innerHTML`、`insertAdjacentHTML`、`DOMParser`、`document.write` ([Vue.js][1])
* クライアントサイドのテンプレートインジェクション:

  * `template:` の連結、`compile(`、ランタイムコンパイラの使用、無害化されていない DOM へのマウント ([Vue.js][1])
* URL インジェクション／オープンリダイレクト:

  * ユーザーデータ由来の `:href="..."` / `:src="..."`
  * `javascript:` の出現箇所
  * `route.query.next` / `redirect` / `return_to` が `router.push` または `window.location` に流れ込む箇所 ([Vue.js][1])
* スタイルのインジェクション:

  * `:style="userProvidedStyles"` またはユーザー操作で変更されるテーマ CSS ([Vue.js][1])
* トークンの保存:

  * `localStorage.setItem('token'...)`、永続化される認証ストア、JavaScript からアクセス可能なストレージ内のリフレッシュトークン
* CSRF 連携に関する危険信号:

  * CSRF ヘッダーやトークンの処理がない `credentials: 'include'` / `withCredentials: true` ([Vue.js][1])
* サードパーティスクリプト:

  * スクリプトの動的な挿入（`createElement('script')`）、SRI のない CDN スクリプト ([MDN Web Docs][11])
* 外部リンクのセキュリティ:

  * `rel="noopener"` / `noreferrer` を指定していない `target="_blank"`（従来のコードや明示性のために、引き続き推奨）([MDN Web Docs][12])

必ず次の点を確認する:

* データの出所（信頼できないものか、信頼できるものか）
* シンクの種類（HTML／DOM への挿入、テンプレートのコンパイル、URL への遷移、スタイルの挿入、スクリプトの挿入）
* 保護策の有無（サニタイズ、許可リスト、CSP／Trusted Types、バックエンドでの検証）

---

## 6) 参考資料（2026-01-27 閲覧）

Vue の一次資料:

* Vue Docs: セキュリティ — `https://vuejs.org/guide/best-practices/security` ([Vue.js][1])
* Vue Docs: テンプレート構文（DOM 内テンプレートに関するセキュリティ警告）— `https://vuejs.org/guide/essentials/template-syntax` ([Vue.js][13])
* Vue Docs: 本番環境へのデプロイ — `https://vuejs.org/guide/best-practices/production-deployment` ([Vue.js][3])
* Vue Docs: 機能フラグ — `https://link.vuejs.org/feature-flags` ([Vue.js][7])

Vite ドキュメント（Vue で一般的に使われるツール）:

* Vite Docs: 環境変数とモード（VITE_* の公開とセキュリティ上の注意）— `https://vite.dev/guide/env-and-mode` ([vitejs][2])
* Vite Docs: CLI（`vite preview` は本番環境向けに設計されていない）— `https://vite.dev/guide/cli` ([vitejs][5])
* Vite Docs: サーバーオプション（`server.host` はパブリックアドレスで待ち受けることがある）— `https://vite.dev/config/server-options` ([vitejs][14])

OWASP およびウェブプラットフォームのセキュリティ強化に関する資料:

* OWASP Cheat Sheet Series: XSS 対策 — `https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html` ([Vue.js][1])
* OWASP Cheat Sheet Series: CSRF 対策 — `https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html` ([OWASP Cheat Sheet Series][9])
* OWASP Cheat Sheet Series: 認可 — `https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html` ([OWASP Cheat Sheet Series][8])
* OWASP Cheat Sheet Series: HTTP ヘッダー — `https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html` ([OWASP Cheat Sheet Series][4])
* HTML5 Security Cheat Sheet（Vue が参照）— `https://html5sec.org/` ([Vue.js][1])

ブラウザー／プラットフォームの資料:

* MDN: `rel="noopener"` — `https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Attributes/rel/noopener` ([MDN Web Docs][12])
* MDN: サブリソース完全性 — `https://developer.mozilla.org/en-US/docs/Web/Security/Subresource_Integrity` ([MDN Web Docs][11])
* web.dev: Trusted Types — `https://web.dev/trusted-types/` ([web.dev][10])

[1]: https://vuejs.org/guide/best-practices/security "https://vuejs.org/guide/best-practices/security"
[2]: https://vite.dev/guide/env-and-mode "https://vite.dev/guide/env-and-mode"
[3]: https://vuejs.org/guide/best-practices/production-deployment "https://vuejs.org/guide/best-practices/production-deployment"
[4]: https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html "https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html"
[5]: https://vite.dev/guide/cli "https://vite.dev/guide/cli"
[6]: https://vite.dev/guide/build "https://vite.dev/guide/build"
[7]: https://vuejs.org/guide/best-practices/production-deployment?utm_source=chatgpt.com "Production Deployment"
[8]: https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html "https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html"
[9]: https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html "https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html"
[10]: https://web.dev/articles/trusted-types "https://web.dev/articles/trusted-types"
[11]: https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Subresource_Integrity?utm_source=chatgpt.com "Subresource Integrity - Security - MDN Web Docs"
[12]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Attributes/rel/noopener "https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Attributes/rel/noopener"
[13]: https://vuejs.org/guide/essentials/template-syntax "Template Syntax | Vue.js"
[14]: https://vite.dev/config/server-options "https://vite.dev/config/server-options"
