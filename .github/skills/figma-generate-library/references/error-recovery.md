> [figma-generate-library スキル](../SKILL.md)の一部です。

# エラー復旧リファレンス

20～100回以上の呼び出しにわたるデザインシステム構築で、失敗、部分的な状態、未完了の実行に対処するための手順です。

---

## 1. 基本手順: STOP → Inspect → Identify → Clean → Fix → Retry

**クリーンアップせずに失敗したスクリプトを再実行してはいけません。** 失敗したスクリプトによって、フレーム、コンポーネント、変数などが中途半端に作成され、部分的な状態が残っている可能性があります。その状態の上から再実行すると問題が重なり、復旧できなくなることがあります。

必ず次の順序で復旧してください。

```
1. 停止 — use_figma での書き込みをこれ以上行わない。
2. 調査 — 現在のページに get_metadata を呼び出す。必要に応じて get_screenshot も呼ぶ。
3. 特定 — dsb_run_id の pluginData タグで、失敗した試行の成果物を探す。
4. 清掃 — 対象を絞ったスクリプトで孤立ノードを除去する（pluginData に基づき、名前では判定しない）。
5. 確認 — get_metadata を再実行し、清掃が完了したことを確認する。
6. 修正 — 失敗したスクリプトを直す。
7. 再試行 — 最後の正常なチェックポイントから、修正したスクリプトを実行する。
8. 記録 — 結果を状態台帳に反映する。
```

失敗が軽微に見えても、手順4を省略してはいけません。部分的に作成されたフレームやコンポーネントは蓄積し、後続の手順で混乱を招きます。

---

## 2. `pluginData` に基づくクリーンアップ: 名前による照合が危険な理由

### 名前のプレフィックスによる照合が失敗する理由

「名前が `Button` で始まるすべてのノード」を削除するクリーンアップスクリプトは、ユーザーが手動で作成した同名のノードや、以前の承認済みフェーズで作成されたノードまで削除する可能性があります。名前による照合では、「失敗した試行で生じた孤立ノード」と「意図的に作成されたユーザーノード」を区別できません。

さらに、バリアント名（`Size=Medium, Style=Primary, State=Default`）には、安全に対象を絞りつつ正当なノードに影響しないような、一貫したプレフィックスがありません。

### `setPluginData` / `getPluginData` の仕組み

`pluginData` は各ノードに紐付くキーと値のストアです。セッションをまたいで保持され、Figma UI 上ではユーザーに表示されません。同じ `pluginId` を持つプラグインだけが、そのプラグインのスコープに属するデータを読み書きできます。次の3つのキーを使用してください。

```javascript
node.setPluginData('dsb_run_id', 'ds-build-2024-001'); // identifies the build run
node.setPluginData('dsb_phase',  'phase3');             // which phase created this node
node.setPluginData('dsb_key',    'componentset/button');// unique logical key

// Reading:
const runId = node.getPluginData('dsb_run_id'); // returns '' if never set
const key   = node.getPluginData('dsb_key');
```

未設定のキーに対して `getPluginData` が返すのは `null` ではなく `''`（空文字列）です。必ず `!== ''` で確認してください。

**作成したすべてのノードに、作成直後にタグを付けてください** — 失敗する可能性のある後続処理を行う前に付けます。`createComponent()` の実行後、タグ付けの行に到達する前に失敗すると、そのノードはタグのない孤立ノードになります。この間をできるだけ短くするため、作成と同じ一連の処理の中でタグを付けてください。

```javascript
const comp = figma.createComponent();
comp.setPluginData('dsb_run_id', RUN_ID);  // tag immediately
comp.setPluginData('dsb_key', key);         // tag immediately
// ... then do the rest of the setup
```

### `dsb_run_id` を使った `cleanupOrphans` スクリプト全体

このスクリプトは、指定した `dsb_run_id` と、必要に応じて `dsb_phase` のフィルターに一致するタグ付きノードをすべて見つけて削除します。失敗が発生したページで実行してください。

```javascript
(async () => {
  try {
    const TARGET_RUN_ID = 'ds-build-2024-001'; // run ID to clean
    const TARGET_PHASE  = 'phase3';            // optionally filter by phase ('' = all phases)
    const PAGE_NAME     = 'Button';            // page to clean (or null for all pages)

    const pagesToSearch = PAGE_NAME
      ? [figma.root.children.find(p => p.name === PAGE_NAME)].filter(Boolean)
      : figma.root.children;

    const removed = [];
    const skipped = [];

    for (const page of pagesToSearch) {
      await figma.setCurrentPageAsync(page);

      const orphans = page.findAll(node => {
        const runId = node.getPluginData('dsb_run_id');
        if (runId !== TARGET_RUN_ID) return false;
        if (TARGET_PHASE && node.getPluginData('dsb_phase') !== TARGET_PHASE) return false;
        return true;
      });

      // Remove leaf-first to avoid removing parents before children
      // Sort by depth (deepest first) to avoid double-remove errors
      const sorted = orphans.slice().sort((a, b) => {
        let depthA = 0, depthB = 0;
        let n = a; while (n.parent) { depthA++; n = n.parent; }
        n = b; while (n.parent) { depthB++; n = n.parent; }
        return depthB - depthA;
      });

      for (const node of sorted) {
        try {
          if (node.removed) continue; // already removed (was a child of removed parent)
          node.remove();
          removed.push({ id: node.id, name: node.name, key: node.getPluginData('dsb_key') });
        } catch (e) {
          skipped.push({ id: node.id, name: node.name, error: e.message });
        }
      }
    }

    figma.closePlugin(JSON.stringify({ removed: removed.length, skipped: skipped.length, details: removed }));
  } catch (e) { figma.closePluginWithFailure(e.toString()); }
})();
```

クリーンアップ後、再実行する前に対象ページで `get_metadata` を呼び出し、孤立ノードがなくなったことを確認してください。

---

## 3. 冪等性パターン: 作成前の確認

すべての作成処理の最初に、冪等性を確認してください。エンティティがすでに存在する場合（想定した `dsb_key` のタグが付いている場合）は、作成をスキップして既存の ID を返します。

### 変数コレクションの作成前確認

```javascript
(async () => {
  try {
    const KEY = 'collection/color';
    const RUN_ID = 'ds-build-2024-001';
    const COLLECTION_NAME = 'Color';

    // Check: does a collection tagged with this key already exist?
    const allCollections = await figma.variables.getLocalVariableCollectionsAsync();
    // Variables/collections support pluginData too — check by name as fallback
    // Note: VariableCollection pluginData is set via collection.setPluginData(...)
    const existing = allCollections.find(c =>
      c.getPluginData('dsb_key') === KEY
    );

    if (existing) {
      figma.closePlugin(JSON.stringify({
        collectionId: existing.id,
        modeIds: existing.modes.map(m => ({ name: m.name, id: m.modeId })),
        alreadyExisted: true,
      }));
      return;
    }

    // Create fresh
    const collection = figma.variables.createVariableCollection(COLLECTION_NAME);
    collection.setPluginData('dsb_run_id', RUN_ID);
    collection.setPluginData('dsb_key', KEY);

    // Rename default mode, add second mode
    collection.renameMode(collection.modes[0].modeId, 'Light');
    const darkModeId = collection.addMode('Dark');

    figma.closePlugin(JSON.stringify({
      collectionId: collection.id,
      modeIds: [
        { name: 'Light', id: collection.modes[0].modeId },
        { name: 'Dark',  id: darkModeId },
      ],
    }));
  } catch (e) { figma.closePluginWithFailure(e.toString()); }
})();
```

### ページの作成前確認

```javascript
(async () => {
  try {
    const KEY = 'page/button';
    const PAGE_NAME = 'Button';
    const RUN_ID = 'ds-build-2024-001';

    // Check by pluginData key first, then by name as fallback
    let page = figma.root.children.find(p => p.getPluginData('dsb_key') === KEY);
    if (!page) {
      page = figma.root.children.find(p => p.name === PAGE_NAME);
    }

    if (page) {
      // Ensure it's tagged if it was found by name only
      if (!page.getPluginData('dsb_key')) {
        page.setPluginData('dsb_run_id', RUN_ID);
        page.setPluginData('dsb_key', KEY);
      }
      figma.closePlugin(JSON.stringify({ pageId: page.id, alreadyExisted: true }));
      return;
    }

    page = figma.createPage();
    page.name = PAGE_NAME;
    page.setPluginData('dsb_run_id', RUN_ID);
    page.setPluginData('dsb_key', KEY);

    figma.closePlugin(JSON.stringify({ pageId: page.id, alreadyExisted: false }));
  } catch (e) { figma.closePluginWithFailure(e.toString()); }
})();
```

### コンポーネントセットの作成前確認

```javascript
(async () => {
  try {
    const KEY = 'componentset/button';
    const PAGE_ID = 'PAGE_ID_FROM_STATE';
    const RUN_ID = 'ds-build-2024-001';

    const page = await figma.getNodeByIdAsync(PAGE_ID);
    await figma.setCurrentPageAsync(page);

    const existing = page.findAll(n =>
      n.type === 'COMPONENT_SET' && n.getPluginData('dsb_key') === KEY
    );

    if (existing.length > 0) {
      figma.closePlugin(JSON.stringify({
        componentSetId: existing[0].id,
        alreadyExisted: true,
      }));
      return;
    }

    // ... proceed with creation
    figma.closePlugin(JSON.stringify({ componentSetId: null, alreadyExisted: false }));
  } catch (e) { figma.closePluginWithFailure(e.toString()); }
})();
```

---

## 4. 状態台帳

### JSON スキーマ

呼び出しをまたいで、状態台帳をコンテキスト内で（Figma ファイル内ではなく）管理してください。ノード ID、完了した手順、保留中の検証についての信頼できる情報源です。

```json
{
  "runId": "ds-build-2024-001",
  "phase": "phase3",
  "step": "component-button/combine-variants",
  "completedSteps": [
    "phase0",
    "phase1/collections",
    "phase1/primitives",
    "phase1/semantics",
    "phase2/pages",
    "phase2/foundations-docs",
    "phase3/component-avatar",
    "phase3/component-icon"
  ],
  "entities": {
    "collections": {
      "primitives": "VariableCollectionId:1234:5678",
      "color":      "VariableCollectionId:1234:5679",
      "spacing":    "VariableCollectionId:1234:5680"
    },
    "variables": {
      "color/bg/primary":         "VariableId:2345:1",
      "color/bg/secondary":       "VariableId:2345:2",
      "color/bg/disabled":        "VariableId:2345:3",
      "color/text/on-primary":    "VariableId:2345:4",
      "color/text/on-secondary":  "VariableId:2345:5",
      "color/text/disabled":      "VariableId:2345:6",
      "spacing/sm":               "VariableId:2345:7",
      "spacing/md":               "VariableId:2345:8",
      "spacing/lg":               "VariableId:2345:9",
      "radius/md":                "VariableId:2345:10"
    },
    "modes": {
      "color/light": "2345:1",
      "color/dark":  "2345:2"
    },
    "pages": {
      "Cover":       "0:1",
      "Foundations": "0:2",
      "Button":      "0:3"
    },
    "components": {
      "Icon":        "3456:1",
      "Avatar":      "3456:2",
      "Button":      "3456:3"
    },
    "componentSets": {
      "Button": "4567:1"
    }
  },
  "pendingValidations": [
    "Button:metadata",
    "Button:screenshot"
  ],
  "userCheckpoints": {
    "phase0": "approved-2024-01-15",
    "phase1": "approved-2024-01-15",
    "phase2": "approved-2024-01-15",
    "component-avatar": "approved-2024-01-15"
  }
}
```

### 呼び出し間での状態保持

`use_figma` の呼び出しが成功するたびに:
1. `closePlugin` の戻り値からすべての ID を抽出する
2. 台帳の適切な `entities` セクションに追加する
3. 完了した手順を `completedSteps` に追加する
4. この呼び出しで検証した項目があれば、`pendingValidations` から削除する
5. 現在の位置に合わせて `phase` と `step` を更新する

### セッション開始時の再読み込み

会話が中断後に再開された場合は、状態台帳を読み込み、主要なエンティティが引き続き存在することを確認してください。

```javascript
(async () => {
  try {
    // Verify that critical nodes from the ledger still exist
    const toVerify = {
      'color-collection':  'VariableCollectionId:1234:5679',
      'button-page':       '0:3',
      'button-componentset': '4567:1',
    };

    const results = {};
    for (const [label, id] of Object.entries(toVerify)) {
      const node = await figma.getNodeByIdAsync(id)
        .catch(() => null);
      results[label] = node ? { found: true, name: node.name } : { found: false };
    }

    figma.closePlugin(JSON.stringify(results));
  } catch (e) { figma.closePluginWithFailure(e.toString()); }
})();
```

エンティティが見つからない場合は、それを作成したフェーズが未完了として扱い、そのチェックポイントから再実行します。

---

## 5. 再開プロトコル

### ステップ 1: `dsb_run_id` タグを使ってファイルを調査する

```javascript
(async () => {
  try {
    const TARGET_RUN_ID = 'ds-build-2024-001';
    const inventory = { pages: [], variables: [], componentSets: [], frames: [] };

    // Scan pages
    for (const page of figma.root.children) {
      if (page.getPluginData('dsb_run_id') === TARGET_RUN_ID) {
        inventory.pages.push({ id: page.id, name: page.name, key: page.getPluginData('dsb_key') });
      }
    }

    // Scan variables
    const allVars = await figma.variables.getLocalVariablesAsync();
    for (const v of allVars) {
      if (v.getPluginData('dsb_run_id') === TARGET_RUN_ID) {
        inventory.variables.push({ id: v.id, name: v.name, key: v.getPluginData('dsb_key') });
      }
    }

    // Scan all component sets and frames on each page
    for (const page of figma.root.children) {
      await figma.setCurrentPageAsync(page);
      const nodes = page.findAll(n => n.getPluginData('dsb_run_id') === TARGET_RUN_ID);
      for (const n of nodes) {
        if (n.type === 'COMPONENT_SET') {
          inventory.componentSets.push({ id: n.id, name: n.name, key: n.getPluginData('dsb_key') });
        } else if (n.type === 'FRAME') {
          inventory.frames.push({ id: n.id, name: n.name, key: n.getPluginData('dsb_key') });
        }
      }
    }

    figma.closePlugin(JSON.stringify(inventory));
  } catch (e) { figma.closePluginWithFailure(e.toString()); }
})();
```

### ステップ 2: インベントリから状態を復元する

インベントリのキーを状態台帳のスキーマに対応付けます。`dsb_key` がある各エンティティについて、該当するセクションにその ID を追加します。対応するステップを `completedSteps` として記録します。

マッピング例:
```
key: 'collection/color'        → entities.collections.color
key: 'variable/color/bg/primary' → entities.variables['color/bg/primary']
key: 'page/button'             → entities.pages.Button
key: 'componentset/button'     → entities.componentSets.Button
```

### ステップ 3: 再開位置を特定する

再開位置は、ワークフロー内で `completedSteps` に含まれていない最初のステップです。インベントリで Button コンポーネントセットの存在が確認でき、保留中の検証リストに `'Button:screenshot'` がある場合、再開位置は再作成ではなくスクリーンショット検証の呼び出しです。

ワークフローのチェックポイント表を使って、続行するフェーズを判断します:

```
フェーズ 0 完了: 計画したすべてのページが entities.pages に記録されている
フェーズ 1 完了: 計画したすべての変数が正しいスコープで entities.variables に記録されている
フェーズ 2 完了: 構造用の全ページと基盤の説明用フレームが存在する
フェーズ 3 完了（コンポーネントごと）: componentSet があり、保留中の検証がなく、ユーザー確認が記録されている
```

---

## 6. 失敗の分類

### 回復可能なエラー

これらは、すでに作成済みのエンティティに影響を与えずに修正して再試行できます:

| カテゴリ | 例 | 復旧方法 |
|---|---|---|
| レイアウトエラー | バリアントが (0,0) に重なって配置されている、パディング値が間違っている | 位置調整のステップだけを再実行する |
| 命名の問題 | バリアント名の誤字、大文字・小文字の誤り | `dsb_key` でノードを検索し、`name` プロパティを更新する |
| プロパティの紐付け漏れ | `componentPropertyReferences` が設定されていない | ID でコンポーネントセットを検索し、プロパティ紐付けのステップを再実行する |
| 変数のバインド漏れ | fill がバインドされず、ハードコードされている | `dsb_key` でノードを検索し、fill を再バインドする |
| 間違った変数のバインド | 間違った変数 ID にバインドされている | 正しい変数 ID で再バインドする |
| テキストが表示されない | テキストを書き込む前にフォントが読み込まれていない | 先に `loadFontAsync` を実行してから、テキスト作成を再実行する |
| バリアントの部分作成 | タイムアウト前に 18 個中 12 個だけ作成された | 部分的に作成されたセットをクリーンアップし、バリアント作成全体を再実行する |

### 構造の破損（ロールバックまたは再起動が必要）

これらのエラーでは、先に進めても信頼できない状態がファイルに残ります:

| カテゴリ | 例 | 復旧方法 |
|---|---|---|
| コンポーネントの循環参照 | コンポーネントのインスタンスが誤って自分自身の中にネストされている | 影響を受けたコンポーネントを完全にクリーンアップし、Call 1 からそのコンポーネントを再開する |
| コンポーネント以外を指定した `combineAsVariants` | 異なるノード型を `combineAsVariants` に渡したため、予期しないマージが発生した | 不正なコンポーネントセットを削除し、バリアント作成から再実行する |
| 変数コレクション ID のずれ | コレクションが削除・再作成され、状態台帳内の古い ID が無効になっている | Phase 1 をすべて再実行し、状態台帳のすべての ID を更新する |
| ページの削除 | コンポーネントセットの作成後にページが削除された | Phase 2 が未完了として扱い、ページを再作成して影響を受けたコンポーネントの作成を再実行する |
| モード上限超過 | プランが Starter または Professional のため、`addMode` が例外を投げた | モード上限に収まるよう変数コレクションの構成を見直し、Phase 1 を再開する |

**構造の破損からの復旧**: 実行 ID 全体に対して `cleanupOrphans` を実行し、影響を受けたフェーズから再開します。破損した構造をその場で修正しようとしてはいけません。

---

## 7. よくあるエラー一覧

| エラーメッセージ | 考えられる原因 | 対処方法 |
|---|---|---|
| `"Cannot create component from node"` | コンポーネント内のノードに対して `createComponentFromNode` を呼び出そうとした | 新しいコンポーネントを作成する: `figma.createComponent()` |
| `"in addMode: Limited to N modes only"` | プランのモード上限に達した（Starter=1、Professional=4） | 使用するモードを減らすよう設計を見直すか、プランをアップグレードする |
| `"setCurrentPageAsync: page does not exist"` | ページが削除されたか、ID が間違っている | 冪等性パターンを使ってページを再作成する |
| `"Cannot read properties of null"` | `getNodeByIdAsync` が null を返した。ノードが削除されている | 再開プロトコルを実行して存在するものを確認し、状態台帳を更新する |
| `"Expected nodes to be component nodes"` | `combineAsVariants` に ComponentNode 以外を渡した | 配列をフィルタリングする: `nodes.filter(n => n.type === 'COMPONENT')` |
| `"in createVariable: Cannot create variable"` | コレクションが削除されたか、ID が間違っている | `getVariableCollectionByIdAsync` でコレクションの存在を確認する |
| `"font not loaded"` | `loadFontAsync` を先に呼び出さずにテキストのプロパティセッターを呼び出した | テキスト操作の前に `await figma.loadFontAsync({ family, style })` を追加する |
| `"Cannot set properties of a read-only array"` | fills/strokes をインプレースで変更しようとした | 先に複製する: `const fills = JSON.parse(JSON.stringify(node.fills))` |
| `"Expected RGBA color"` | 色の値が 0～1 の範囲外 | RGB の 0～255 の値を 255 で割る: `{ r: 65/255, g: 85/255, b: 143/255 }` |
| `"Cannot add children to a non-parent node"` | リーフノード（text、rect）に子を追加しようとした | 親が FrameNode、ComponentNode、または GroupNode であることを確認する |
| `"in combineAsVariants: nodes must be in the same parent"` | コンポーネントが異なるページにある | 結合する前にすべてのコンポーネントを同じページに移動する |
| `"Script exceeded time limit"` | 1 回の呼び出しでノードを作成するループが多すぎる | 作業を分割し、1 回の呼び出しにつき N/2 個のバリアントを作成する |
| コンポーネントセットが自分自身を削除する | 子なしでコンポーネントセットを作成しようとした | `combineAsVariants` には少なくとも 1 個のノードが必要です。必ず 1 個以上渡してください |
| `addComponentProperty` が予期しない名前を返す | これは正常です。`BOOLEAN`/`TEXT`/`INSTANCE_SWAP` には `#id:id` サフィックスが付きます | 返されたキーをすぐに保存して使用します。入力した名前は使用しません |

---

## 8. フェーズ別の復旧ガイダンス

### Phase 1 の実行中に失敗（変数の作成）

症状: 変数コレクションが一部だけ存在する、一部の変数が欠けている、または値が間違っている。

復旧手順:
1. 検査スクリプトを実行して、`dsb_run_id` が付いたすべての変数を見つける
2. 計画に合致する `dsb_key` を持つ各変数について、`valuesByMode` と `scopes` が正しいことを確認する
3. 変数の形式が不正な場合は、`variable.remove()` を呼び出して再作成する
4. コレクション自体の形式が不正な場合は、コレクション全体を削除し、最初から再作成する
5. 計画されたすべての変数が正しいスコープとコード構文で存在するまで、Phase 2 に進まない

**Phase 1 で最もよくある失敗:** 多数の変数を作成する際、1 回の `use_figma` 呼び出しで時間切れになること。対処方法: 変数の作成を分割し、1 回の呼び出しにつき最大 20～30 個までにする。

### Phase 2 の実行中に失敗（ページ／ファイル構造）

症状: 一部のページは存在するが、ほかのページが欠けている。ファウンデーションのドキュメント用フレームが不完全。

復旧手順:
1. 正常に作成されたページを特定する（`dsb_key` タグを確認する）
2. 残りのページを保留として記録し、後続の呼び出しで作成する
3. ファウンデーションのドキュメント用フレームの形式が不正な場合は、そのページで `dsb_phase: 'phase2'` を指定して `cleanupOrphans` を実行し、その後再作成する

ページ構造自体が破損している場合（まれです）を除き、Phase 2 の失敗で Phase 1 のロールバックが必要になることはほとんどありません。

### Phase 3 の実行中に失敗（コンポーネントの作成）

長時間のビルドで最もよくある失敗です。コンポーネントごとに対処してください:

```
呼び出し 1（ページ作成）で失敗した場合:
  → 再試行時に冪等性チェックで処理できる。再実行してよい。

呼び出し 2（説明用フレーム）で失敗した場合:
  → dsb_key='doc/{component}' に対して cleanupOrphans を実行し、再実行する。

呼び出し 3（基本コンポーネント）で失敗した場合:
  → 部分的に作られた基本コンポーネントのノードを削除し、呼び出し 3 から再実行する。

呼び出し 4（バリアント作成）で失敗した場合:
  → コンポーネントのページで dsb_phase='phase3' を指定し、cleanupOrphans を実行する（ページに範囲を限定）。
  → 基本コンポーネントのタグ付けに成功していれば呼び出し 4、そうでなければ呼び出し 3 から再実行する。

呼び出し 5（combineAsVariants とレイアウト）で失敗した場合:
  → 形式の壊れたコンポーネントセットを削除する。
  → このコンポーネントのすべてのバリアント ComponentNode を dsb_key パターンで削除する。
  → 呼び出し 3 から再実行する。

呼び出し 6（コンポーネントのプロパティ）で失敗した場合:
  → コンポーネントセットは既に存在し、構造に問題はない。
  → 呼び出し 6 のみ再実行する。先に componentPropertyDefinitions で既存のプロパティを確認すれば、addComponentProperty を安全に再試行できる。
  → 冪等性チェック: 'Label' プロパティが既にあれば addComponentProperty を省く。
```

**コンポーネントプロパティの冪等性（Call 6 の再試行）:**

```javascript
const existingDefs = cs.componentPropertyDefinitions;
const labelKey = existingDefs['Label']
  ? Object.keys(existingDefs).find(k => k.startsWith('Label'))
  : cs.addComponentProperty('Label', 'TEXT', 'Button');
```

### Phase 4 の実行中に失敗（QA / Code Connect）

Phase 4 は非破壊的です。この段階で失敗しても、Phase 3 の作業は破損しません。よくある失敗:

- **アクセシビリティ監査でコントラストの問題が見つかった場合:** 自動修正しようとしないでください。問題のある変数 ID とトークン名を具体的に報告し、どの値を更新するかユーザーに尋ねてください。
- **命名監査で重複が見つかった場合:** `dsb_key` の値とともに重複項目をすべて一覧にし、どれを残すかユーザーに尋ねてから、重複を削除してください。
- **Code Connect のマッピングに失敗した場合:** 壊れているのではなく、未完了として扱います。続行し、保留状態のままにします。
