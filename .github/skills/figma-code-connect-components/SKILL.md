---
name: figma-code-connect-components
description: Code Connect の対応付けツールで Figma のデザインコンポーネントをコードのコンポーネントに結び付ける。ユーザーが「code connect」「このコンポーネントをコードに接続」「このコンポーネントを対応付け」「コンポーネントをコードにリンク」「Code Connect の対応を作成」と述べる場合や、Figma デザインとコード実装の対応付けを望む場合に使う。`use_figma` によるキャンバスへの書き込みには `figma-use` を使う。
---

# Code Connect コンポーネント

## 概要

Figma の Code Connect 機能で、デザインコンポーネントを対応するコード実装に結び付ける。Figma のデザイン構造を分析し、コードベースから一致するコンポーネントを探し、デザインとコードの一貫性を保つ対応付けを設定する。

## スキルの対象範囲

- `get_code_connect_suggestions` と `send_code_connect_mappings` を使う作業で使用する。
- Plugin API スクリプトで Figma キャンバスに書き込む必要がある場合は [figma-use](../figma-use/SKILL.md) に切り替える。
- コードや説明から Figma 内のページ全体の画面を作成・更新する場合は [figma-generate-design](../figma-generate-design/SKILL.md) に切り替える。
- Figma から製品コードを実装する場合は [figma-implement-design](../figma-implement-design/SKILL.md) に切り替える。

## 前提条件

- Figma MCP サーバーが接続され、利用できること。
- ユーザーがノード ID を含む Figma URL を示すこと: `https://figma.com/design/:fileKey/:fileName?node-id=1-2`
  - **重要:** Figma URL には `node-id` パラメーターが必要。ない場合は Code Connect の対応付けに失敗する。
- **または** `figma-desktop` MCP を使う場合: ユーザーが Figma デスクトップアプリでノードを直接選択できる（URL は不要）。
- **重要:** Figma コンポーネントはチームライブラリに公開されている必要がある。Code Connect が使えるのは公開済みのコンポーネントまたはコンポーネントセットのみ。
- **重要:** Code Connect を利用できるのは Organization と Enterprise のプランのみ。
- コンポーネントを調べるため、プロジェクトのコードベースにアクセスできること。

## 必須の作業手順

**次の順序で進め、手順を省略しない。**

### ステップ 1: Code Connect の候補を取得する

`get_code_connect_suggestions` を呼び、未対応のコンポーネントを一度にすべて特定する。このツールは自動的に次を行う。

- Figma のシーングラフからコンポーネント情報を取得する。
- 選択範囲にある公開済みコンポーネントを特定する。
- 既存の Code Connect の対応付けを確認し、接続済みのコンポーネントを除外する。
- 未対応の各コンポーネントの名前、プロパティ、サムネイル画像を返す。

#### 選択肢 A: `figma-desktop` MCP を使う（URL なし）

`figma-desktop` MCP サーバーが接続され、ユーザーが Figma URL を示していない場合は、直ちに `get_code_connect_suggestions` を呼ぶ。URL の解析は不要で、デスクトップ MCP サーバーは開いている Figma ファイルで現在選択中のノードを自動的に使う。

**注意:** ユーザーは Figma デスクトップアプリを開き、ノードを選択しておく必要がある。`fileKey` はパラメーターとして渡さず、サーバーは現在開いているファイルを使う。

#### 選択肢 B: Figma URL がある場合

URL から `fileKey` と `nodeId` を抽出し、`get_code_connect_suggestions` を呼ぶ。

**重要:** Figma URL からノード ID を取り出すときは形式を変換する。

- URL 形式はハイフンを使う: `node-id=1-2`
- ツールではコロンが必要: `nodeId=1:2`

**Figma URL の解析:**

- URL 形式: `https://figma.com/design/:fileKey/:fileName?node-id=1-2`
- ファイルキーの抽出: `:fileKey`（`/design/` の次の部分）
- ノード ID の抽出: URL の `1-2` を、ツール用に `1:2` に変換する。

```
get_code_connect_suggestions(fileKey=":fileKey", nodeId="1:2")
```

**応答の処理:**

- ツールが **"No published components found in this selection"** を返した場合 → ユーザーに伝えて停止する。先にコンポーネントをチームライブラリに公開する必要がある可能性がある。
- ツールが **"All component instances in this selection are already connected to code via Code Connect"** を返した場合 → すべて対応付け済みであることをユーザーに伝える。
- それ以外では、未対応の各コンポーネントについて次を含む一覧が返る。
  - コンポーネント名
  - ノード ID
  - コンポーネントのプロパティ（prop の名前と値を含む JSON）
  - 目視確認用のコンポーネントのサムネイル画像

### ステップ 2: コードベースから対応するコンポーネントを探す

`get_code_connect_suggestions` が返した未対応の各コンポーネントについて、コードベースから対応するコンポーネントを探す。

**探す項目:**

- Figma コンポーネント名と一致する、または類似する名前
- Figma の階層に合うコンポーネント構造
- Figma のプロパティ（バリエーション、テキスト、スタイル）に対応する props
- 一般的なコンポーネントディレクトリ（`src/components/`、`components/`、`ui/` など）内のファイル

**検索の手順:**

1. 名前が一致するコンポーネントファイルを探す。
2. 候補ファイルを読み、構造と props を確認する。
3. コードのコンポーネントの props と、ステップ 1 で返された Figma コンポーネントのプロパティを比較する。
4. プログラミング言語（TypeScript、JavaScript）とフレームワーク（React、Vue など）を特定する。
5. 次を考慮し、構造の類似性から最適な候補を特定する。
   - prop 名と Figma のプロパティとの対応
   - Figma の既定値と一致する既定値
   - CSS クラスやスタイルオブジェクト
   - 意図を明確にする説明コメント
6. 同程度に妥当な候補が複数ある場合は、prop のインターフェースが最も近いものを選び、ツール呼び出し前に理由を1〜2文のコメントで記す。

**検索例:**

- Figma コンポーネントが "PrimaryButton" なら、`Button.tsx`、`PrimaryButton.tsx`、`Button.jsx` を探す。
- よくあるパス `src/components/`、`app/components/`、`lib/ui/` を確認する。
- Figma のバリエーションに合う `variant`、`size`、`color` などの props を探す。

### ステップ 3: 対応候補をユーザーに示す

見つかった候補を示し、どの対応付けを作るかユーザーに選んでもらう。候補はすべて、一部のみ、またはまったく採用しないことができる。

**次の形式で示す:**

```
次のコンポーネントがデザインに対応します:
- [ComponentName](path/to/component): DesignComponentName、nodeId [nodeId](figmaUrl?node-id=X-Y)
- [AnotherComponent](path/to/another): AnotherDesign、nodeId [nodeId2](figmaUrl?node-id=X-Y)

これらのコンポーネントを接続しますか？ すべて採用、個別に選択、または見送りができます。
```

**正確に一致するコンポーネントが見つからない場合:**

- 最も近い候補を2件示す。
- 違いを説明する。
- どちらを使うかユーザーに確認するか、正しいパスを示してもらう。

**ユーザーがすべての対応付けを断った場合**は、その旨を伝えて停止する。以後のツール呼び出しは不要。

### ステップ 4: Code Connect の対応付けを作る

ユーザーが選択を確定したら、採用された対応付けだけを渡して `send_code_connect_mappings` を呼ぶ。このツールは一度の呼び出しですべての対応付けをまとめて作る。

**例:**

```
send_code_connect_mappings(
  fileKey=":fileKey",
  nodeId="1:2",
  mappings=[
    { nodeId: "1:2", componentName: "Button", source: "src/components/Button.tsx", label: "React" },
    { nodeId: "1:5", componentName: "Card", source: "src/components/Card.tsx", label: "React" }
  ]
)
```

**各対応付けの主なパラメーター:**

- `nodeId`: Figma のノード ID（コロン形式: `1:2`）
- `componentName`: 接続するコンポーネントの名前（例: "Button"、"Card"）
- `source`: コードのコンポーネントファイルへのパス（プロジェクトのルートからの相対パス）
- `label`: Code Connect の対応付けに付けるフレームワークまたは言語のラベル。使用できる値は次のとおり。
  - Web: 'React', 'Web Components', 'Vue', 'Svelte', 'Storybook', 'Javascript'
  - iOS: 'Swift UIKit', 'Objective-C UIKit', 'SwiftUI'
  - Android: 'Compose', 'Java', 'Kotlin', 'Android XML Layout'
  - 複数プラットフォーム: 'Flutter'
  - 文書: 'Markdown'

**呼び出し後:**

- 成功した場合: ツールは対応付けの作成を確認する。
- エラーの場合: 失敗した対応付けとその理由（例: "Component is already mapped to code"、"Published component not found"、"Insufficient permissions"）を報告する。

処理後に**要約を示す**:

```
Code Connect の要約:
- 接続成功: 3
  - Button (1:2) → src/components/Button.tsx
  - Card (1:5) → src/components/Card.tsx
  - Input (1:8) → src/components/Input.tsx
- 接続不可: 1
  - CustomWidget (1:10) - コードベースに対応するコンポーネントが見つからない
```

## 例

### 例 1: ボタンコンポーネントの接続

ユーザーの依頼: 「この Figma のボタンをコードに接続して: https://figma.com/design/kL9xQn2VwM8pYrTb4ZcHjF/DesignSystem?node-id=42-15」

**対応:**

1. URL を解析する: fileKey=`kL9xQn2VwM8pYrTb4ZcHjF`、nodeId=`42-15` → `42:15` に変換する。
2. `get_code_connect_suggestions(fileKey="kL9xQn2VwM8pYrTb4ZcHjF", nodeId="42:15")` を実行する。
3. 応答には、`variant`（primary/secondary）と `size`（sm/md/lg）のプロパティを持つ未対応の Button コンポーネントとサムネイル画像が示される。
4. コードベースから Button コンポーネントを探し、`src/components/Button.tsx` を見つける。
5. `Button.tsx` を読み、`variant` と `size` の props があることを確認する。
6. ユーザーに示す:
   ```
   対応するコンポーネントが見つかりました:
   - [Button](src/components/Button.tsx): Button、nodeId [42:15](https://figma.com/design/kL9xQn2VwM8pYrTb4ZcHjF/DesignSystem?node-id=42-15)

   このコンポーネントを接続しますか？
   ```

7. ユーザーが「はい」と答える。
8. TypeScript の React コンポーネントであることを確認する。
9. `send_code_connect_mappings(fileKey="kL9xQn2VwM8pYrTb4ZcHjF", nodeId="42:15", mappings=[{ nodeId: "42:15", componentName: "Button", source: "src/components/Button.tsx", label: "React" }])` を実行する。

**結果:** Figma のボタンコンポーネントがコードの Button コンポーネントに接続される。

### 例 2: 複数のコンポーネントから一部を選ぶ

ユーザーの依頼: 「このフレームのコンポーネントを接続して: https://figma.com/design/pR8mNv5KqXzGwY2JtCfL4D/Components?node-id=10-50」

**対応:**

1. URL を解析する: fileKey=`pR8mNv5KqXzGwY2JtCfL4D`、nodeId=`10-50` → `10:50` に変換する。
2. `get_code_connect_suggestions(fileKey="pR8mNv5KqXzGwY2JtCfL4D", nodeId="10:50")` を実行する。
3. 応答に未対応のコンポーネントが3つ示される: ProductCard、Badge、CustomWidget。
4. コードベースを探す:
   - ProductCard: `src/components/ProductCard.tsx` が見つかる（props が一致）。
   - Badge: `src/components/Badge.tsx` が見つかる（props が一致）。
   - CustomWidget: 対応するコンポーネントは見つからない。
5. ユーザーに示す:
   ```
   次のコンポーネントがデザインに対応します:
   - [ProductCard](src/components/ProductCard.tsx): ProductCard、nodeId [10:51](https://figma.com/design/pR8mNv5KqXzGwY2JtCfL4D/Components?node-id=10-51)
   - [Badge](src/components/Badge.tsx): Badge、nodeId [10:52](https://figma.com/design/pR8mNv5KqXzGwY2JtCfL4D/Components?node-id=10-52)

   CustomWidget (10:53) に対応するコンポーネントは見つかりませんでした。

   これらのコンポーネントを接続しますか？ すべて採用、個別に選択、または見送りができます。
   ```

6. ユーザー: 「ProductCard だけ接続して、Badge は今は見送って」
7. `send_code_connect_mappings(fileKey="pR8mNv5KqXzGwY2JtCfL4D", nodeId="10:50", mappings=[{ nodeId: "10:51", componentName: "ProductCard", source: "src/components/ProductCard.tsx", label: "React" }])` を実行する。

**結果:** ユーザーの選択に従い、ProductCard だけが接続される。

### 例 3: コンポーネントの作成が必要な場合

ユーザーの依頼: 「このアイコンを接続して: https://figma.com/design/8yJDMeWDyBz71EnMOSuUiw/Icons?node-id=5-20」

**対応:**

1. URL を解析する: fileKey=`8yJDMeWDyBz71EnMOSuUiw`、nodeId=`5-20` → `5:20` に変換する。
2. `get_code_connect_suggestions(fileKey="8yJDMeWDyBz71EnMOSuUiw", nodeId="5:20")` を実行する。
3. 応答には色とサイズのプロパティを持つ未対応の CheckIcon コンポーネントが示される。
4. コードベースから CheckIcon を探すが、一致するものはない。
5. 汎用の Icon コンポーネントを探し、他のアイコンがある `src/icons/` ディレクトリを見つける。
6. ユーザーに伝える: 「CheckIcon コンポーネントは見つかりませんでしたが、`src/icons/` にアイコンのディレクトリがあります。次のどれにしますか？
   - まず新しい CheckIcon.tsx コンポーネントを作成してから接続する
   - 別の既存アイコンに接続する
   - CheckIcon が他の場所にあれば、そのパスを示す」
7. ユーザーがパスを示す: "src/icons/CheckIcon.tsx"
8. ファイルから言語とフレームワークを特定する。
9. `send_code_connect_mappings(fileKey="8yJDMeWDyBz71EnMOSuUiw", nodeId="5:20", mappings=[{ nodeId: "5:20", componentName: "CheckIcon", source: "src/icons/CheckIcon.tsx", label: "React" }])` を実行する。

**結果:** CheckIcon コンポーネントが Figma デザインに接続される。

## 推奨される方法

### 積極的にコンポーネントを探す

ユーザーにファイルパスを尋ねるだけでなく、コードベースから対応するコンポーネントを積極的に探す。これにより使いやすさが増し、対応付けの機会も見つけられる。

### 構造の正確な照合

Figma とコードのコンポーネントを比べる際は、名前だけで判断せず、次を確認する。

- props が合う（バリエーションの種類、サイズの選択肢など）。
- コンポーネントの階層が合う（入れ子の要素）。
- コンポーネントの用途が同じ。

### 明確な説明

対応付けの作成を提案するときは、次を明確に説明する。

- 見つかったもの
- 対応候補として妥当な理由
- 対応付けによって何が起こるか
- props をどのように結び付けるか

### 曖昧さへの対応

複数のコンポーネントが対応しうる場合は、推測で決めず候補を示す。どれを接続するかの最終判断はユーザーに委ねる。

### 正確な候補がない場合

正確に一致するものが見つからなければ、役立つ次の対応を示す。

- 近い候補を示す。
- コンポーネントの作成を提案する。
- ユーザーの指示を求める。

## よくある問題と解決策

### 問題: "No published components found in this selection"

**原因:** Figma コンポーネントがチームライブラリに公開されていない。Code Connect が使えるのは公開済みコンポーネントのみ。
**解決策:** ユーザーが Figma でコンポーネントをチームライブラリに公開する必要がある。

1. Figma でコンポーネントまたはコンポーネントセットを選択する。
2. 右クリックして "Publish to library" を選ぶか、Team Library の公開ダイアログを使う。
3. コンポーネントを公開する。
4. 公開後、同じノード ID で Code Connect の対応付けを再試行する。

### 問題: "Code Connect is only available on Organization and Enterprise plans"

**原因:** ユーザーの Figma プランには Code Connect の利用権がない。
**解決策:** Organization または Enterprise プランにアップグレードするか、管理者に連絡する必要がある。

### 問題: コードベースに対応するコンポーネントがない

**原因:** コードベースの検索で、名前や構造が一致するコンポーネントが見つからなかった。
**解決策:** 別の名前や場所にコンポーネントがあるかユーザーに尋ねる。先に作成する必要があるか、予想外のディレクトリにある可能性がある。

### 問題: "Published component not found"（CODE_CONNECT_ASSET_NOT_FOUND）

**原因:** ソースファイルのパスが誤っているか、その場所にコンポーネントがないか、componentName が実際のエクスポート名と一致しない。
**解決策:** ソースのパスが正しく、プロジェクトのルートからの相対パスであることを確認する。指定した componentName と完全に一致する名前でファイルからエクスポートされているか調べる。

### 問題: "Component is already mapped to code"（CODE_CONNECT_MAPPING_ALREADY_EXISTS）

**原因:** このコンポーネントの Code Connect の対応付けが既にある。
**解決策:** コンポーネントは接続済み。ユーザーが対応付けを更新したい場合は、先に Figma 内の既存のものを削除する必要があるかもしれない。

### 問題: "Insufficient permissions to create mapping"（CODE_CONNECT_INSUFFICIENT_PERMISSIONS）

**原因:** ユーザーに Figma ファイルやライブラリの編集権限がない。
**解決策:** コンポーネントを含むファイルへの編集権限が必要。ファイルの所有者かチーム管理者に連絡する。

### 問題: URL エラーで Code Connect の対応付けに失敗する

**原因:** Figma URL の形式が誤っているか、`node-id` パラメーターがない。
**解決策:** URL が `https://figma.com/design/:fileKey/:fileName?node-id=1-2` の形式であることを確認する。`node-id` は必須。ツール呼び出しでは `1-2` を `1:2` に変換する。

### 問題: 似たコンポーネントが複数ある

**原因:** コードベースに Figma コンポーネントと対応しうるものが複数ある。
**解決策:** ファイルパスとともにすべての候補をユーザーに示し、どれを接続するか選んでもらう。異なる文脈で使う別々のコンポーネントかもしれない（例: `Button.tsx` と `LinkButton.tsx`）。

## Code Connect の役割

Code Connect はデザインとコードを双方向に結び付ける。

**デザイナーにとって:** Figma コンポーネントを実装するコードのコンポーネントを確認できる。
**開発者にとって:** Figma デザインから実装コードに直接移動できる。
**チームにとって:** コンポーネントの対応付けについて信頼できる唯一の情報源を保てる。

作成した対応付けにより、関係が明示され見つけやすくなり、デザインとコードの同期を保てる。

## 追加資料

Code Connect の詳細:

- [Code Connect の文書](https://help.figma.com/hc/en-us/articles/23920389749655-Code-Connect)
- [Figma MCP サーバーのツールと依頼文](https://developers.figma.com/docs/figma-mcp-server/tools-and-prompts/)
