---
name: "playwright-interactive"
description: "`js_repl` を使ってブラウザーや Electron を継続的に操作し、UI をすばやく反復デバッグします。"
---

# Playwright Interactive スキル

永続的な `js_repl` Playwright セッションを使ってローカルの Web アプリや Electron アプリをデバッグし、反復中も同じハンドルを維持して、プロセスの所有関係が変わらない限りツールチェーン全体を再起動せずに、機能面と視覚面の QA を実施します。

## 前提条件

- このスキルでは `js_repl` が有効になっている必要があります。
- `js_repl` が見つからない場合は、`~/.codex/config.toml` で有効にします。

```toml
[features]
js_repl = true
```

- `--enable js_repl` を指定して新しいセッションを開始する方法もあります（`-c features.js_repl=true` と同等です）。
- `js_repl` を有効にした後、新しい Codex セッションを開始してツール一覧を更新します。
- 現時点では、サンドボックスを無効にしてこのワークフローを実行します。Codex を `--sandbox danger-full-access`（または `sandbox_mode=danger-full-access` に相当する設定）で起動してください。これは、サンドボックス内での `js_repl` と Playwright のサポートがまだ整備中である間の暫定要件です。
- デバッグ対象と同じプロジェクトディレクトリからセットアップを実行します。
- `js_repl_reset` は通常の後片付けではなく、復旧用のツールとして扱います。カーネルをリセットすると Playwright のハンドルが破棄されます。

## 初回セットアップ

```bash
test -f package.json || npm init -y
npm install playwright
# Web-only, for headed Chromium or mobile emulation:
# npx playwright install chromium
# Electron-only, and only if the target workspace is the app itself:
# npm install --save-dev electron
node -e "import('playwright').then(() => console.log('playwright import ok')).catch((error) => { console.error(error); process.exit(1); })"
```

後で別のワークスペースに切り替える場合は、そちらでもセットアップを繰り返します。

## 基本ワークフロー

1. テストの前に、簡潔な QA 項目一覧を作成します。
   - 次の 3 つの情報源から項目をまとめます。ユーザーが求めた要件、実際に実装したユーザーに見える機能や動作、最終回答で述べる予定の内容です。
   - これら 3 つの情報源のいずれかに含まれる項目は、最終確認までに少なくとも 1 つの QA チェックに対応付けます。
   - 最終確認する予定の、ユーザーに見える主張を列挙します。
   - 意味のあるユーザー向けコントロール、モード切り替え、実装したインタラクティブな動作をすべて列挙します。
   - 各コントロールや実装した動作によって起こり得る状態変化や表示の変化を列挙します。
   - これを機能 QA と視覚 QA の両方で共有するカバレッジ一覧として使います。
   - 各主張またはコントロールと状態の組み合わせについて、想定する機能チェック、視覚チェックを行う具体的な状態、記録する予定の証拠を記します。
   - 要件の中で視覚的に重要だが主観的なものは、暗黙のままにせず、観察可能な QA チェックに置き換えます。
   - 壊れやすい動作を見つける可能性のある、通常の利用経路から外れた探索シナリオを少なくとも 2 つ追加します。
2. ブートストラップ用セルを 1 回実行します。
3. 必要な開発サーバーを、永続的な TTY セッションで起動するか、起動済みであることを確認します。
4. 適切なランタイムを起動し、同じ Playwright ハンドルを使い続けます。
5. コードを変更するたびに、レンダラーのみの変更なら再読み込みし、メインプロセスや起動処理の変更なら再起動します。
6. 通常のユーザー入力を使って機能 QA を実行します。
7. これとは別に視覚 QA を実施します。
8. ビューポート内に収まることを確認し、主張を裏付けるために必要なスクリーンショットを撮影します。
9. タスクが完了したときに限り、Playwright セッションを終了します。

## ブートストラップ（1 回実行）

```javascript
var chromium;
var electronLauncher;
var browser;
var context;
var page;
var mobileContext;
var mobilePage;
var electronApp;
var appWindow;

try {
  ({ chromium, _electron: electronLauncher } = await import("playwright"));
  console.log("Playwright loaded");
} catch (error) {
  throw new Error(
    `Could not load playwright from the current js_repl cwd. Run the setup commands from this workspace first. Original error: ${error}`
  );
}
```

バインディングのルール:

- 後続の `var` セルで再利用する共通のトップレベル Playwright ハンドルには `js_repl` を使います。
- 以下のセットアップ用セルは、意図的に簡潔な正常系としてあります。ハンドルが古くなっているようなら、そのバインディングを `undefined` に設定してセルを再実行し、あちこちに復旧処理を追加しないでください。
- コンテキストからページを何度も探し直すのではなく、対象とする画面ごとに名前付きハンドル（`page`、`mobilePage`、`appWindow`）を 1 つ使います。

共通 Web ヘルパー:

```javascript
var resetWebHandles = function () {
  context = undefined;
  page = undefined;
  mobileContext = undefined;
  mobilePage = undefined;
};

var ensureWebBrowser = async function () {
  if (browser && !browser.isConnected()) {
    browser = undefined;
    resetWebHandles();
  }

  browser ??= await chromium.launch({ headless: false });
  return browser;
};

var reloadWebContexts = async function () {
  for (const currentContext of [context, mobileContext]) {
    if (!currentContext) continue;
    for (const p of currentContext.pages()) {
      await p.reload({ waitUntil: "domcontentloaded" });
    }
  }
  console.log("Reloaded existing web tabs");
};
```

## セッションモードの選択

Web アプリでは、デフォルトで明示的なビューポートを使用し、ネイティブウィンドウモードは別の検証工程として扱います。

- 通常の反復作業、ブレークポイントの確認、再現可能なスクリーンショット、スナップショットの差分確認、モデルを利用したローカライズには、明示的なビューポートを使います。マシン間で安定し、ホストのウィンドウマネージャーによるばらつきを避けられるため、これをデフォルトとします。
- 高 DPI の動作を確実に検証する必要がある場合は、ネイティブウィンドウモードへ切り替えるのではなく、明示的なビューポートを維持して `deviceScaleFactor` を追加します。
- 起動時のウィンドウサイズ、OS レベルの DPI 動作、ブラウザーのクローム操作、ホストのディスプレイ設定に依存する可能性のあるバグを検証するときは、画面表示ありの別工程としてネイティブウィンドウモード（`viewport: null`）を使います。
- Electron では常にネイティブウィンドウの動作を前提とします。Electron は Playwright を通じて `noDefaultViewport` で起動するため、実際のデスクトップウィンドウとして扱い、サイズを変更する前に起動時のサイズとレイアウトを確認します。
- 最終確認にレイアウトのブレークポイントと実際のデスクトップ動作の両方が必要なら、両方の工程を実施します。まず決定論的な QA のために明示的なビューポートを使い、その後、最終的な環境固有の確認のためにネイティブウィンドウを検証します。
- モードの切り替えはコンテキストのリセットとして扱います。ビューポートをエミュレートした `context` をネイティブウィンドウの工程で再利用したり、その逆をしたりしないでください。古い `page` と `context` を閉じ、新しいモード用に作り直します。

## Web セッションの開始または再利用

デスクトップとモバイルの Web セッションは、同じ `browser`、ヘルパー、QA フローを共有します。主な違いは、作成するコンテキストとページの組み合わせです。

### デスクトップ Web コンテキスト

デバッグ対象のアプリに `TARGET_URL` を設定します。ローカルサーバーでは `127.0.0.1` より `localhost` を優先します。

```javascript
var TARGET_URL = "http://127.0.0.1:3000";

if (page?.isClosed()) page = undefined;

await ensureWebBrowser();
context ??= await browser.newContext({
  viewport: { width: 1600, height: 900 },
});
page ??= await context.newPage();

await page.goto(TARGET_URL, { waitUntil: "domcontentloaded" });
console.log("Loaded:", await page.title());
```

`context` または `page` が古くなっている場合は、`context = page = undefined` に設定してセルを再実行します。

### モバイル Web コンテキスト

`TARGET_URL` がすでにある場合は再利用し、ない場合はモバイル用の対象を直接設定します。

```javascript
var MOBILE_TARGET_URL = typeof TARGET_URL === "string"
  ? TARGET_URL
  : "http://127.0.0.1:3000";

if (mobilePage?.isClosed()) mobilePage = undefined;

await ensureWebBrowser();
mobileContext ??= await browser.newContext({
  viewport: { width: 390, height: 844 },
  isMobile: true,
  hasTouch: true,
});
mobilePage ??= await mobileContext.newPage();

await mobilePage.goto(MOBILE_TARGET_URL, { waitUntil: "domcontentloaded" });
console.log("Loaded mobile:", await mobilePage.title());
```

`mobileContext` または `mobilePage` が古くなっている場合は、`mobileContext = mobilePage = undefined` に設定してセルを再実行します。

### ネイティブウィンドウの Web 検証

```javascript
var TARGET_URL = "http://127.0.0.1:3000";

await ensureWebBrowser();

await page?.close().catch(() => {});
await context?.close().catch(() => {});
page = undefined;
context = undefined;

browser ??= await chromium.launch({ headless: false });
context = await browser.newContext({ viewport: null });
page = await context.newPage();

await page.goto(TARGET_URL, { waitUntil: "domcontentloaded" });
console.log("Loaded native window:", await page.title());
```

## Electron セッションの開始または再利用

現在のワークスペースが Electron アプリで、`ELECTRON_ENTRY` の `.` が正しいエントリーファイルを指している場合は、`package.json` に `main` を設定します。特定のメインプロセスファイルを直接対象にする必要がある場合は、代わりに `./main.js` のようなパスを使います。

```javascript
var ELECTRON_ENTRY = ".";

if (appWindow?.isClosed()) appWindow = undefined;

if (!appWindow && electronApp) {
  await electronApp.close().catch(() => {});
  electronApp = undefined;
}

electronApp ??= await electronLauncher.launch({
  args: [ELECTRON_ENTRY],
});

appWindow ??= await electronApp.firstWindow();

console.log("Loaded Electron window:", await appWindow.title());
```

`js_repl` が Electron アプリのワークスペースから起動されていない場合は、起動時に `cwd` を明示します。

アプリのプロセスが古くなっているようなら、`electronApp = appWindow = undefined` に設定してセルを再実行します。

すでに Electron セッションがあり、メインプロセス、preload、または起動処理の変更後にプロセスを再起動する必要がある場合は、このセルを再実行するのではなく、次のセクションの再起動用セルを使います。

## 反復中のセッション再利用

可能な限り同じセッションを維持します。

Web レンダラーの再読み込み:

```javascript
await reloadWebContexts();
```

Electron のレンダラーのみを再読み込み:

```javascript
await appWindow.reload({ waitUntil: "domcontentloaded" });
console.log("Reloaded Electron window");
```

メインプロセス、preload、または起動処理の変更後に Electron を再起動:

```javascript
await electronApp.close().catch(() => {});
electronApp = undefined;
appWindow = undefined;

electronApp = await electronLauncher.launch({
  args: [ELECTRON_ENTRY],
});

appWindow = await electronApp.firstWindow();
console.log("Relaunched Electron window:", await appWindow.title());
```

起動時に `cwd` の明示が必要な場合は、ここでも同じ `cwd` を含めます。

デフォルトの方針:

- 各 `js_repl` セルは、1 回の操作に集中した短いものにします。
- 既存のトップレベルバインディング（`browser`、`context`、`page`、`electronApp`、`appWindow`）を再利用し、再宣言しないでください。
- 分離が必要な場合は、同じブラウザー内に新しいページまたはコンテキストを作成します。
- Electron では、メインプロセスの調査または専用の診断に限り `electronApp.evaluate(...)` を使います。
- ヘルパーの誤りはその場で修正します。カーネルが実際に壊れていない限り、REPL をリセットしないでください。

## チェックリスト

### セッションのループ

- `js_repl` のブートストラップは 1 回だけ行い、反復中も同じ Playwright ハンドルを維持します。
- 対象のランタイムを現在のワークスペースから起動します。
- コードを変更します。
- 変更内容に応じた方法で再読み込みまたは再起動します。
- 探索中に別のコントロール、状態、またはユーザーに見える主張が判明したら、共有 QA 項目一覧を更新します。
- 機能 QA を再実行します。
- 視覚 QA を再実行します。
- 評価対象の状態が最新であることを確認してから、最終成果物を記録します。

### 再読み込みの判断

- レンダラーのみの変更: 既存のページまたは Electron ウィンドウを再読み込みします。
- メインプロセス、preload、または起動処理の変更: Electron を再起動します。
- プロセスの所有関係や起動コードに新たな不確実性がある場合: 推測せずに再起動します。

### 機能 QA

- 最終確認には実際のユーザー操作を使います。キーボード、マウス、クリック、タッチ、または Playwright の同等の入力 API を使います。
- 少なくとも 1 つの重要なフローをエンドツーエンドで検証します。
- 内部状態だけでなく、そのフローで画面に表示される結果を確認します。
- リアルタイム性の高いアプリやアニメーション主体のアプリでは、実際の操作タイミングでの動作を確認します。
- その場限りの抜き取り確認ではなく、共有 QA 項目一覧に沿って進めます。
- 最終確認の前に、主要な正常系だけでなく、目に見える明白なコントロールをすべて少なくとも 1 回操作します。
- インベントリにある、元に戻せるコントロールや状態を持つトグルについては、一連の動作全体をテストします。初期状態、変更後の状態、初期状態への復帰を確認してください。
- スクリプトによるチェックに合格したら、意図された経路だけをたどるのではなく、通常の入力を使って30〜90秒の短い探索的な確認を行います。
- 探索的な確認で新たな状態、コントロール、主張が見つかった場合は、共有QAインベントリに追加し、サインオフ前に確認します。
- `page.evaluate(...)` と `electronApp.evaluate(...)` は状態の確認や準備には使えますが、サインオフ用の入力には数えません。

### ビジュアルQA

- ビジュアルQAは機能QAとは別のものとして扱います。
- テスト前に定義し、QA中に更新した同じ共有QAインベントリを使います。暗黙の別リストを使ってビジュアル確認を始めないでください。
- ユーザーに見える主張を改めて列挙し、それぞれを明示的に確認します。機能テストに合格したからといって、見た目に関する主張も立証されたと思い込まないでください。
- ユーザーに見える主張は、それが認識されるべき特定の状態で確認されるまで、サインオフできません。
- スクロールする前に、初期表示領域を確認します。
- 初期表示でインターフェースの主要な主張が視覚的に裏付けられていることを確認します。中核となる約束の要素がそこで明確に認識できない場合は、バグとして扱います。
- メインの操作領域だけでなく、必要な表示領域をすべて確認します。
- 共有QAインベントリにすでに列挙されている状態とモードを確認します。タスクがインタラクティブな場合は、意味のある操作後の状態も少なくとも1つ確認します。
- 動きや遷移が体験の一部である場合は、落ち着いた後の状態に加え、遷移中の状態も少なくとも1つ確認します。
- ラベル、オーバーレイ、注釈、ガイド、ハイライトが変化するコンテンツに追従する設計であれば、該当する状態変化の後にその対応関係を確認します。
- 動的な表示や操作に依存する表示は、安定性、重なり順、読みやすさを判断できるだけの時間をかけて確認します。1枚のスクリーンショットだけでサインオフしないでください。
- 読み込みや操作後に情報量が増えるインターフェースでは、空、読み込み中、折りたたみ状態だけでなく、QA中に到達できる最も情報量の多い現実的な状態も確認します。
- 製品に定められた最小サポート表示領域またはウィンドウサイズがある場合は、そのサイズで別途ビジュアルQAを行います。ない場合は、現実的な範囲で小さめのサイズを選び、明示的に確認します。
- 要素が存在することと、意図どおり実装されていることを区別します。コントラスト不足、隠れ、切り抜き、不安定さなどにより、意図された操作要素が技術的には存在していても明確に認識できない場合は、ビジュアル上の不合格として扱います。
- 評価中の状態で必要な表示領域が切れている、一部が表示されない、隠れている、または表示領域の外に押し出されている場合は、ページ全体のスクロール指標が許容範囲に見えてもバグとして扱います。
- 切り抜き、はみ出し、歪み、レイアウトの偏り、余白の不統一、配置の問題、読みにくいテキスト、コントラスト不足、重なり順の崩れ、不自然な遷移状態を確認します。
- 正しさだけでなく、美的な品質も評価します。UIは意図が感じられ、まとまりがあり、タスクにふさわしく見た目にも優れている必要があります。
- サインオフには表示領域のスクリーンショットを優先します。ページ全体のキャプチャは補助的なデバッグ資料としてのみ使い、詳しく見る必要がある領域は焦点を絞って撮影します。
- 動きのためにスクリーンショットの判断が難しい場合は、UIが落ち着くまで少し待ってから、実際に評価する画像を撮影します。
- サインオフ前に、「このインターフェースの表示部分で、まだ詳しく確認していないところはどこか」と明示的に問いかけます。
- サインオフ前に、「ユーザーが細部まで見たとき、この結果で最も問題になりそうな表示上の欠陥は何か」と明示的に問いかけます。

### サインオフ

- 機能上の操作経路が、通常のユーザー入力で合格しました。
- 共有QAインベントリに照らして確認範囲が明確です。どの要件、実装機能、コントロール、状態、主張を確認したかを記録し、意図的に除外した項目も明記します。
- ビジュアルQAで、関連するインターフェース全体を確認しました。
- ユーザーに見える各主張に対応するビジュアル確認を行い、その主張が重要となる状態および表示領域またはウィンドウサイズで確認したスクリーンショットをレビュー済みです。
- 想定される初期表示と、必要な最小サポート表示領域またはウィンドウサイズについて、表示領域への適合確認に合格しました。
- 製品がウィンドウで起動する場合は、手動でサイズ変更や位置変更を行う前に、起動時のサイズ、配置、初期レイアウトを確認しました。
- UIは機能するだけでなく、視覚的にまとまりがあり、タスクに対して美的に見劣りしません。
- 機能の正しさ、表示領域への適合、美的品質はそれぞれ個別に合格する必要があります。どれか1つに合格しても、他の合格を意味しません。
- インタラクティブな製品では短い探索的な確認を完了し、その確認範囲を応答に記載しました。
- スクリーンショットのレビューと数値チェックが食い違った場合は、サインオフ前にその差異を調査しました。スクリーンショットで見える切り抜きは解決すべき不合格であり、数値指標で覆すことはできません。
- 確認した結果、見つからなかった主な欠陥の種類を簡潔に明記します。
- クリーンアップを実行したか、または追加作業のため意図的にセッションを継続しました。

## スクリーンショットの例

`codex.emitImage(...)` を通じてスクリーンショットを出力する場合は、次のセクションにあるCSS正規化済みの手順を標準として使ってください。これらは、モデルが解釈するスクリーンショットや、座標に基づく後続操作に使うスクリーンショットの標準的な例です。生のキャプチャは、忠実度を重視するデバッグの場合に限って例外的に使います。生キャプチャの例は正規化の説明の後にあります。

### モデルに渡すスクリーンショット（標準）

モデルによる解釈のために `codex.emitImage(...)` でスクリーンショットを出力する場合は、出力前に、キャプチャした正確な領域をCSSピクセルに正規化します。これにより、返された座標を後でクリックに使う場合にPlaywrightのCSSピクセルと一致させられ、画像データのサイズとモデルのトークン消費も抑えられます。

標準では、生のネイティブウィンドウのスクリーンショットを出力しないでください。RetinaやDPIのアーティファクトのデバッグ、ピクセル単位で正確な描画の検査など、生ピクセルの忠実度がデータサイズより重要となるケースで、明示的に必要な場合に限り正規化を省略します。モデルに出力しないローカルのみの確認では、生のキャプチャを使って構いません。

ネイティブウィンドウモード（`page.screenshot({ scale: "css" })`）では、`viewport: null` だけで十分だと思い込まないでください。macOSのRetinaディスプレイ上のChromiumでは、`scale: "css"` を指定しても、ヘッド付きネイティブウィンドウのスクリーンショットがデバイスピクセルサイズで返ることがあります。Electronは `noDefaultViewport` で動作するため、Playwright経由で起動したElectronウィンドウにも同じ注意が当てはまり、`appWindow.screenshot({ scale: "css" })` もデバイスピクセルの出力を返す場合があります。

WebページとElectronウィンドウでは、別々の正規化手順を使います。

- Web：まず `page.screenshot({ scale: "css" })` をそのまま使います。ネイティブウィンドウのChromiumがなおデバイスピクセルの出力を返す場合は、スクラッチページを作らず、現在のページ内でcanvasを使ってサイズを変更します。
- Electron：スクラッチページとして `appWindow.context().newPage()` や `electronApp.context().newPage()` を使わないでください。Electronのコンテキストでは、この方法は安定して動作しません。メインプロセスで `BrowserWindow.capturePage(...)` を使ってキャプチャし、`nativeImage.resize(...)` でサイズを変更して、そのバイト列を直接出力します。

共通のヘルパーと規約：

```javascript
var emitJpeg = async function (bytes) {
  await codex.emitImage({
    bytes,
    mimeType: "image/jpeg",
    detail: "original",
  });
};

var emitWebJpeg = async function (surface, options = {}) {
  await emitJpeg(await surface.screenshot({
    type: "jpeg",
    quality: 85,
    scale: "css",
    ...options,
  }));
};

var clickCssPoint = async function ({ surface, x, y, clip }) {
  await surface.mouse.click(
    clip ? clip.x + x : x,
    clip ? clip.y + y : y
  );
};

var tapCssPoint = async function ({ page, x, y, clip }) {
  await page.touchscreen.tap(
    clip ? clip.x + x : x,
    clip ? clip.y + y : y
  );
};
```

- Webでは `page` または `mobilePage` を、Electronでは `appWindow` を `surface` として使います。
- `clip` は、レンダラー内の `getBoundingClientRect()` から得られるCSSピクセルとして扱います。
- 可逆の忠実度が特に必要な場合を除き、`quality: 85` のJPEGを優先します。
- 画像全体をキャプチャする場合は、返された `{ x, y }` をそのまま使います。
- クリップした画像をキャプチャする場合は、クリック時にクリップ領域の原点を加算します。

### WebのCSS正規化

明示的な表示領域を使うコンテキスト、および多くの場合のWeb全般で推奨される方法：

```javascript
await emitWebJpeg(page);
```

モバイルWebでも同じ方法を使います。`mobilePage` の代わりに `page` を指定します。

```javascript
await emitWebJpeg(mobilePage);
```

モデルが `{ x, y }` を返した場合は、その座標を直接クリックします。

```javascript
await clickCssPoint({ surface: page, x, y });
```

モバイルWebのクリック方法：

```javascript
await tapCssPoint({ page: mobilePage, x, y });
```

通常の方法でWebの `clip` スクリーンショットまたは要素スクリーンショットを撮る場合は、通常 `scale: "css"` をそのまま使えます。クリック時に領域の原点を加算します。

- `await emitWebJpeg(page, { clip })`
- `await emitWebJpeg(mobilePage, { clip })`
- `await clickCssPoint({ surface: page, clip, x, y })`
- `await tapCssPoint({ page: mobilePage, clip, x, y })`
- `await clickCssPoint({ surface: page, clip: box, x, y })` の後に `const box = await locator.boundingBox()`

`scale: "css"` を使ってもネイティブウィンドウのWebキャプチャがデバイスピクセルサイズで返る場合の代替策：

```javascript
var emitWebScreenshotCssScaled = async function ({ page, clip, quality = 0.85 } = {}) {
  var NodeBuffer = (await import("node:buffer")).Buffer;
  const target = clip
    ? { width: clip.width, height: clip.height }
    : await page.evaluate(() => ({
        width: window.innerWidth,
        height: window.innerHeight,
      }));

  const screenshotBuffer = await page.screenshot({
    type: "png",
    ...(clip ? { clip } : {}),
  });

  const bytes = await page.evaluate(
    async ({ imageBase64, targetWidth, targetHeight, quality }) => {
      const image = new Image();
      image.src = `data:image/png;base64,${imageBase64}`;
      await image.decode();

      const canvas = document.createElement("canvas");
      canvas.width = targetWidth;
      canvas.height = targetHeight;

      const ctx = canvas.getContext("2d");
      ctx.imageSmoothingEnabled = true;
      ctx.drawImage(image, 0, 0, targetWidth, targetHeight);

      const blob = await new Promise((resolve) =>
        canvas.toBlob(resolve, "image/jpeg", quality)
      );

      return new Uint8Array(await blob.arrayBuffer());
    },
    {
      imageBase64: NodeBuffer.from(screenshotBuffer).toString("base64"),
      targetWidth: target.width,
      targetHeight: target.height,
      quality,
    }
  );

  await emitJpeg(bytes);
};
```

表示領域全体の代替キャプチャでは、返された `{ x, y }` を直接CSS座標として扱います。

```javascript
await emitWebScreenshotCssScaled({ page });
await clickCssPoint({ surface: page, x, y });
```

クリップした代替キャプチャでは、クリック時にクリップ領域の原点を加算します。

```javascript
await emitWebScreenshotCssScaled({ page, clip });
await clickCssPoint({ surface: page, clip, x, y });
```

### ElectronのCSS正規化

Electronでは、スクラッチのPlaywrightページを開く代わりにメインプロセスで正規化します。以下のヘルパーは、コンテンツ領域全体またはCSSピクセル単位で切り取った領域の、CSSスケール済みバイト列を返します。`clip` はコンテンツ領域のCSSピクセルとして扱います。たとえば、レンダラー内の `getBoundingClientRect()` から得た値を使います。

```javascript
var emitElectronScreenshotCssScaled = async function ({ electronApp, clip, quality = 85 } = {}) {
  const bytes = await electronApp.evaluate(async ({ BrowserWindow }, { clip, quality }) => {
    const win = BrowserWindow.getAllWindows()[0];
    const image = clip ? await win.capturePage(clip) : await win.capturePage();

    const target = clip
      ? { width: clip.width, height: clip.height }
      : (() => {
          const [width, height] = win.getContentSize();
          return { width, height };
        })();

    const resized = image.resize({
      width: target.width,
      height: target.height,
      quality: "best",
    });

    return resized.toJPEG(quality);
  }, { clip, quality });

  await emitJpeg(bytes);
};
```
Electronウィンドウ全体：

```javascript
await emitElectronScreenshotCssScaled({ electronApp });
await clickCssPoint({ surface: appWindow, x, y });
```

レンダラーのCSSピクセルを使ったElectron領域の切り抜き：

```javascript
var clip = await appWindow.evaluate(() => {
  const rect = document.getElementById("board").getBoundingClientRect();
  return {
    x: Math.round(rect.x),
    y: Math.round(rect.y),
    width: Math.round(rect.width),
    height: Math.round(rect.height),
  };
});

await emitElectronScreenshotCssScaled({ electronApp, clip });
await clickCssPoint({ surface: appWindow, clip, x, y });
```

### 生スクリーンショットの例外的な使用例

RetinaやDPIに起因する表示上の問題のデバッグ、ピクセル単位で正確なレンダリングの確認、その他忠実度が重視されるレビューなど、生ピクセルがCSS座標との整合性より重要な場合に限り、これらを使用してください。

Webデスクトップの生画像出力：

```javascript
await codex.emitImage({
  bytes: await page.screenshot({ type: "jpeg", quality: 85 }),
  mimeType: "image/jpeg",
  detail: "original",
});
```

Electronの生画像出力：

```javascript
await codex.emitImage({
  bytes: await appWindow.screenshot({ type: "jpeg", quality: 85 }),
  mimeType: "image/jpeg",
  detail: "original",
});
```

モバイルWebコンテキストの実行中に行う、モバイルの生画像出力：

```javascript
await codex.emitImage({
  bytes: await mobilePage.screenshot({ type: "jpeg", quality: 85 }),
  mimeType: "image/jpeg",
  detail: "original",
});
```

## ビューポートへの収まりの確認（必須）

メインウィジェットが見えているというだけで、スクリーンショットに問題がないと判断しないでください。承認前に、スクリーンショットの確認と数値チェックの両方を使い、意図した初期表示が製品要件を満たしていることを明示的に確認してください。

- 承認前に、意図した初期表示を定義してください。スクロール可能なページでは、これはファーストビューの表示です。アプリのようなシェル、ゲーム、エディター、ダッシュボード、ツールでは、操作に必要なコントロールとステータス表示を含む、操作可能な領域全体を指します。
- 収まりを確認する際は、スクリーンショットを主な根拠としてください。数値チェックはスクリーンショットを補助するものであり、目視できるクリッピングを覆すものではありません。
- 意図した初期表示で、必要な表示領域がクリップされている、一部が見切れている、隠れている、またはビューポート外に押し出されている場合、ページ全体のスクロール指標が問題なく見えても承認できません。
- 製品がスクロールするよう設計されており、初期表示で中心的な機能が伝わり、主要な行動喚起や必要な開始時の情報にアクセスできる場合は、スクロールを許容できます。
- 固定シェルのインターフェースでは、主要な操作領域の一部や重要なコントロールに到達するためにスクロールが必要な場合、スクロールを回避策として認めません。
- ドキュメントのスクロール指標だけに頼らないでください。固定高さのシェル、内部ペイン、オーバーフローを非表示にするコンテナーでは、ページ全体のスクロールチェックに問題がなくても、必要なUIがクリップされることがあります。
- ドキュメント全体ではなく、各領域の境界を確認してください。起動時の状態で、必要な表示領域がそれぞれビューポート内に収まっていることを確かめてください。
- Electronやデスクトップアプリでは、手動でサイズや位置を変更する前に、起動したウィンドウのサイズと配置、およびレンダラーの初期表示レイアウトの両方を確認してください。
- ビューポートへの収まりのチェックに合格したことが示すのは、意図した初期表示が意図しないクリッピングやスクロールなしで見えることだけです。UIが視覚的に正しいことや、見た目に優れていることを示すものではありません。

Webまたはレンダラーのチェック：

```javascript
console.log(await page.evaluate(() => ({
  innerWidth: window.innerWidth,
  innerHeight: window.innerHeight,
  clientWidth: document.documentElement.clientWidth,
  clientHeight: document.documentElement.clientHeight,
  scrollWidth: document.documentElement.scrollWidth,
  scrollHeight: document.documentElement.scrollHeight,
  canScrollX: document.documentElement.scrollWidth > document.documentElement.clientWidth,
  canScrollY: document.documentElement.scrollHeight > document.documentElement.clientHeight,
})));
```

Electronのチェック：

```javascript
console.log(await appWindow.evaluate(() => ({
  innerWidth: window.innerWidth,
  innerHeight: window.innerHeight,
  clientWidth: document.documentElement.clientWidth,
  clientHeight: document.documentElement.clientHeight,
  scrollWidth: document.documentElement.scrollWidth,
  scrollHeight: document.documentElement.scrollHeight,
  canScrollX: document.documentElement.scrollWidth > document.documentElement.clientWidth,
  canScrollY: document.documentElement.scrollHeight > document.documentElement.clientHeight,
})));
```

クリッピングが現実的に起こり得るUIでは、必要な表示領域に対する`getBoundingClientRect()`チェックを数値チェックに追加してください。固定シェルでは、ドキュメントレベルの指標だけでは不十分です。

## 開発サーバー

ローカルWebのデバッグでは、アプリを永続的なTTYセッションで実行し続けてください。短時間で終了するシェルからの単発のバックグラウンドコマンドに頼らないでください。

次のように、プロジェクトで通常使う起動コマンドを実行してください。

```bash
npm start
```

`page.goto(...)`の前に、選択したポートで待ち受けが行われていることと、アプリが応答することを確認してください。

Electronのデバッグでは、`js_repl`から`_electron.launch(...)`を使ってアプリを起動し、同じセッションでプロセスを管理してください。Electronレンダラーが別の開発サーバー（たとえばViteやNext）に依存している場合は、そのサーバーを永続的なTTYセッションで実行し続けてから、`js_repl`でElectronアプリを再起動するか再読み込みしてください。

## クリーンアップ

タスクが実際に完了した場合にのみ、クリーンアップを実行してください。

- このクリーンアップは手動で行います。Codexの終了、ターミナルを閉じること、または`js_repl`セッションの終了によって、`electronApp.close()`、`context.close()`、`browser.close()`が暗黙に実行されることはありません。
- Electronについては、クリーンアップのセルを実行せずにセッションを終了すると、アプリが動作し続ける可能性があると想定してください。

```javascript
if (electronApp) {
  await electronApp.close().catch(() => {});
}

if (mobileContext) {
  await mobileContext.close().catch(() => {});
}

if (context) {
  await context.close().catch(() => {});
}

if (browser) {
  await browser.close().catch(() => {});
}

browser = undefined;
context = undefined;
page = undefined;
mobileContext = undefined;
mobilePage = undefined;
electronApp = undefined;
appWindow = undefined;

console.log("Playwright session closed");
```

デバッグ直後にCodexを終了する場合は、先にクリーンアップのセルを実行し、終了前に`"Playwright session closed"`のログが表示されるのを待ってください。

## よくある失敗と対処

- `Cannot find module 'playwright'`：現在のワークスペースで一度だけセットアップを実行し、`js_repl`を使う前にインポートできることを確認してください。
- Playwrightパッケージはインストール済みだが、ブラウザーの実行ファイルがない：`npx playwright install chromium`を実行してください。
- `page.goto: net::ERR_CONNECTION_REFUSED`：開発サーバーが永続的なTTYセッションでまだ動作していることを確認し、ポートを再確認して、`http://127.0.0.1:<port>`を優先してください。
- `electron.launch`がハングする、タイムアウトする、またはすぐに終了する：ローカルの`electron`依存関係を確認し、`args`の対象を確かめ、起動前にレンダラーの開発サーバーが動作していることを確認してください。
- `Identifier has already been declared`：既存のトップレベル束縛を再利用するか、新しい名前を選ぶか、コードを`{ ... }`で囲んでください。カーネルが実際に応答しなくなった場合にのみ`js_repl_reset`を使ってください。
- Electronの作業中に`browserContext.newPage: Protocol error (Target.createTarget): Not supported`が発生する：スクラッチページとして`appWindow.context().newPage()`や`electronApp.context().newPage()`を使わないでください。model-bound screenshotsセクションにあるElectron専用のスクリーンショット正規化フローを使ってください。
- `js_repl`がタイムアウトした、またはリセットされた：ブートストラップ用のセルを再実行し、より短く、目的を絞ったセルでセッションを再作成してください。
- ブラウザーの起動やネットワーク操作がすぐに失敗する：セッションが`--sandbox danger-full-access`付きで開始されたことを確認し、必要ならそのオプション付きで再起動してください。
