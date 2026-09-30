---
name: hatch-pet
description: キャラクターアート、生成画像、企業や見込み顧客のブランド要素、またはビジュアル参考資料から、Codex互換のアニメーションペットやペット用スプライトシートを作成、修復、検証、目視でQAし、パッケージ化します。軽量ワーカーを使ったCodexペットのワークフロー、ピクセルアート以外のカスタムペットスタイル、見込み顧客や企業のマスコットペット、または未使用セルを透明にした完全な8x9アニメーションペットアトラス、QA用コンタクトシート、pet.jsonのパッケージ化をユーザーが求めている場合に使用します。このスキルは、ビジュアル生成にインストール済みの$imagegenシステムスキルを組み合わせ、決定論的なスプライトシート組み立てには同梱スクリプトを使用します。
---

# ペットの作成

## 概要

コンセプト、ブランド要素、企業名や見込み顧客名、1枚以上の参考画像、またはこれらの組み合わせから、Codex互換のアニメーションペットを作成します。このワークフローでは、アトラスの幾何形状、検証、ビジュアルQA、パッケージ化に決定論的なhatch-petパイプラインを使い、状態ごとの簡潔なプロンプトを使用しながら、ペットに適したあらゆるビジュアルスタイルを利用できます。

ユーザー向けの入力は任意です。ユーザーがペット名を省略した場合は、コンセプト、ブランド、企業名、または参考ファイル名から推測します。それができない場合は、短く親しみやすい名前を選びます。説明が省略された場合は、コンセプトや参考資料から推測します。参考画像が省略された場合は、まずテキストからベースのペットを生成し、そのベースをすべてのアニメーション行の正式な参照画像として使います。

## 生成の委任

通常のビジュアル生成にはすべて`$imagegen`を使用します。

ベースアート、行ストリップ、または修復行を生成する前に、インストール済みの画像生成スキルを読み込み、その指示に従います。

```text
${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/SKILL.md
```

Image API、画像CLI、またはその他の画像生成手段を直接呼び出してはいけません。`$imagegen`自身に、まず組み込み機能を使う経路とフォールバック規則を選ばせます。`$imagegen`がフォールバックに確認が必要だと示した場合は、続行する前にユーザーに尋ねます。

`$imagegen`を呼び出すときは、生成するペットのプロンプトを正式なビジュアル仕様として渡します。ペットのプロンプトは簡潔で、状態を明確にし、スプライト制作に適した内容にして、列挙された入力画像に基づかせます。長い方針やQA規則はこのスキルと決定論的なレビュー用スクリプトに残し、各画像プロンプトに詰め込みません。プロンプトを汎用の`$imagegen`共有プロンプトスキーマで囲まないでください。

このスキルのスクリプトは、レイアウトガイドとプロンプトの準備、承認済みの`running-left`の反転、フレームの抽出、行の検証、最終アトラスの合成、コンタクトシートとモーションプレビューのQAメディア作成など、決定論的な画像処理にのみ使用します。マニフェストの更新、パッケージ化、クリーンアップは、親側で実行するシェルや`jq`の手順で処理します。

## ストレージの制御

組み込みの`$imagegen`経路は、`${CODEX_HOME:-$HOME/.codex}/generated_images`配下にもファイルを書き出す場合でも、生成したPNGのバイト列を呼び出し元のロールアウトに保存します。後でファイルを削除すればファイルシステムの使用量は減らせますが、すでに書き込まれたロールアウトのサイズは小さくなりません。画像生成は独立させ、範囲を限定してください。

- ビジュアルジョブごとに軽量な生成ワーカーを1つ使います。複数のベースや行のジョブを同じワーカーにまとめてはいけません。
- ワーカーが返す内容は`selected_source=...`と`qa_note=...`だけにします。最終回答にMarkdownの画像プレビュー、base64、その他のビジュアル添付を含めてはいけません。
- 親側は生成されたPNGをすべて目視で開いてはいけません。各ジョブのQAにはワーカーを使い、最終コンタクトシートだけを確認します。
- 選んだ生成出力を`decoded/`にコピーした後、選択元が`${CODEX_HOME:-$HOME/.codex}/generated_images`内にある場合はそこから削除し、可能なら空になった生成ディレクトリも削除します。
- ストレージを重視する完全な実行では、利用可能な場合に`$imagegen`のCLIフォールバックを使うかユーザーに尋ねます。この経路にはローカルのAPI認証情報とユーザーの明示的な確認が必要ですが、組み込み画像のペイロードがロールアウトのイベントに埋め込まれるのを避けられる場合があります。

## ブランドの調査

具体的なアバターの説明や参考画像ではなく、ブランド名、企業名、製品名、または見込み顧客名が提示された場合は、ペットの実行準備を始める前に、軽量な調査サブエージェントを実行します。調査ワーカーはウェブ検索を使い、ブランドサイト、製品ページ、ドキュメント、会社概要ページ、プレスページ、ブランドページなどの公式情報を優先します。公式ページの情報が乏しい場合に限り、信頼できる二次情報源を使います。検索範囲は絞り、ビジュアルや性格の手掛かりを得るのに必要な範囲にとどめ、市場調査の報告書にはしません。

ユーザーがすでに具体的なマスコットやアバターの説明、または参考画像を提示している場合は、ユーザーがブランド調査を明示的に依頼しない限り、調査を省略します。

調査ワーカーの担当事項:

- 関連する情報源を2～4件ウェブ検索し、公式ページを優先する
- 固定された項目の羅列ではなく、状況に応じたMarkdownの概要を作成する
- アイデンティティ／カテゴリ、対象ユーザー／利用状況、ビジュアルシステム、性格／トーン、製品／分野のモチーフ、マスコットへの翻訳の手掛かり、避けるべき要素、根拠／確度を扱う
- 情報源から推測したマスコットの指針には、推測であることを明記する
- ロゴ、判読可能なマーク、UIスクリーンショット、スローガン、テキストをコピーしない
- `Generation handoff`セクションを最後に設け、`brand_name`、`brand_brief`、`avatar_seed`、`avoid`、`brand_sources`だけを簡潔に記載する
- 画像を生成したり、実行用フォルダーを準備したり、無関係なファイルを編集したりしない

次の調査ワーカープロンプトを使用します。

```text
Research a brand for hatch-pet mascot creation.

Brand/product/prospect: <brand name>
User context: <short user request>
Output file: <absolute path to brand-discovery.md>

Use web search. Prefer official brand, product, docs, about, press, or brand pages. Use reputable secondary sources only if official sources are too thin. Write an adaptive markdown brief to the output file. Headings may flex by brand, but the brief must cover:
- identity/category: canonical name, product type, what it does
- audience/use context: who it serves and where it appears
- visual system: palette, shapes, line quality, materials, typography feel, iconography, patterns
- personality/tone: emotional traits, energy, formality, playfulness
- product/domain motifs: objects, workflows, verbs, metaphors, environments
- mascot translation cues: candidate forms, signature traits, props, what must read at pet size
- avoidances: logos/text, trademark-sensitive elements, misleading cues, competitor confusion, poor mascot fits
- evidence/confidence: source URLs plus notes where evidence is weak or inferred

Do not copy logos, readable marks, UI screenshots, slogans, or text. Clearly label mascot guidance that is inferred rather than directly sourced.

End the brief with a `Generation handoff` section containing exactly:
- brand_name=<canonical brand/product name>
- brand_brief=<one sentence, max 45 words, covering palette/tone/domain motifs/personality>
- avatar_seed=<short mascot-safe visual idea, no logo copying>
- avoid=<short comma-separated list>
- brand_sources=<comma-separated source URLs>

Return exactly:
brand_discovery_file=<absolute output file path>
brand_name=<canonical brand/product name>
brand_brief=<same compact sentence from Generation handoff>
avatar_seed=<same short seed from Generation handoff>
avoid=<same short avoid list from Generation handoff>
brand_sources=<same comma-separated URLs from Generation handoff>
```

親側は実行準備の前にMarkdownの概要を保存し、ユーザーがより適切なアバター説明を提示していない場合は、`prepare_pet_run.py`に基づく簡潔な`--brand-discovery-file`値とともに、`--brand-name`、`--brand-brief`、繰り返し指定する`--brand-source`を付けて、概要を`--pet-notes`に`avatar_seed`として渡します。レビュー用に概要全体を保持し、プロンプトには簡潔な引き継ぎ項目だけを反映します。ウェブ検索が利用できず、ユーザーがブランド名だけを提示した場合は、生成前にブランドの手掛かりを尋ねます。

通常のペット実行では、ビジュアル生成ジョブは最大10件を想定します。ベースのペットが1件、行ストリップのジョブが9件です。Codexアプリの仕様では現在、`idle`、`running-right`、`running-left`、`waving`、`jumping`、`failed`、`waiting`、`running`、`review`の9つの状態をすべて使います。決定論的に生成するビジュアルは`running-left`だけです。これは、`running-right`を生成して目視で確認し、安全に反転できると明示的に承認した後に限り、`running-right`を反転して作成できます。反転が適切でない場合は、通常の根拠画像付き`running-left`行として`$imagegen`を生成します。

ビジュアル出力を選んだ後、親エージェントはその画像を変更せずジョブの`decoded/`パスにコピーし、`imagegen-jobs.json`でジョブを完了として記録します。行の出力を作成する補助スクリプトを書いてはいけません。決定論的なPythonスクリプトで処理できるのは、すでに生成済みのビジュアル出力だけです。

ベースジョブだけはプロンプトのみでも構いません。`$imagegen`を使って生成するすべての行ストリップジョブでは、`imagegen-jobs.json`に記載された入力画像を使います。この入力には、選択したベース出力をコピーした後に作成される正式なベース参照画像も含まれます。根拠となる画像が添付されていない行の生成は無効として扱います。

## ペットに適したスタイル

デフォルトのスタイルは`auto`です。ユーザーのプロンプトと参考資料からペットのスタイルを推測し、すべての行でそのスタイルを保ちます。ユーザーがスタイルを指定した場合はそれに従います。対応するスタイルプリセットには、`pixel`、`plush`、`clay`、`sticker`、`flat-vector`、`3d-toy`、`painterly`、`brand-inspired`、`auto`があります。

ペットに適していれば、どのスタイルでも構いません。

- `192x208`セル内に収まり、全身のシルエットが読み取れるコンパクトな形
- すべての行で一貫した顔、プロポーション、素材、配色、小道具
- きれいに除去できるクロマキー背景
- ペットの表示サイズで読み取れる大きさのディテール
- ユーザーが承認済みの参考アートを明示的に提示し、それらを使うよう依頼した場合を除き、テキスト、ラベル、UI、判読可能なロゴがないこと

ピクセルアート以外のスタイルも標準的な選択肢です。アトラスと読みやすさの制約を満たしていれば、ぬいぐるみ、粘土、ステッカー、ベクター、3Dトイ、絵画風のマスコット、インク画、ブランドに着想を得た表現を受け入れます。

## 透明度とエフェクト

ペットの行は透明な`192x208`セルに加工されるため、生成される各ピクセルはペットのスプライトに属するか、きれいに除去できるクロマキー背景でなければなりません。装飾的なエフェクトより、ポーズ、表情、シルエットの変化を優先します。

透明度の不変条件は決定論的なラスター処理パイプラインが担います。完全に透明になるピクセルは、隠れたRGBの残留値が残らないよう正規化されます。また、書き出されたファイルがこの条件に違反している場合は、アトラスの検証に失敗する必要があります。色の縁取りや透明ピクセルの残留値がある出力を、見た目に一貫性がなくても許容することで問題を取り繕ってはいけません。

許可するエフェクトは、次の条件をすべて満たす必要があります。

- 状態に関係し、アニメーションを説明する助けになる。
- ペットのシルエットの近くに浮いているのではなく、ペットに物理的に付いている、触れている、または重なっている。
- ペットと同じフレーム枠内に収まり、独立したスプライト要素を作らない。
- 不透明で、きれいに抽出できる程度には輪郭が明瞭で、クロマキー色を使わない。
- `192x208`で見ても読み取れ、画面を煩雑にしない大きさである。

通常は次の要素を避けます。透明背景の処理や構成要素の抽出を妨げることが多いためです。

- 波線、動きの弧、スピード線、アクションの軌跡、残像、ぼかし、にじみ
- 離れた星、散らばったきらめき、浮かぶ句読点、浮かぶアイコン、落ちる涙、分離した煙の雲、浮遊するほこり
- 落ち影、接地影、ドロップシャドウ、楕円形の床の影、床面の模様、着地跡、衝撃の破裂表現、光彩、ハロー、オーラ、柔らかな透明エフェクト
- テキスト、ラベル、フレーム番号、見えるグリッド、ガイド線、吹き出し、思考吹き出し、UIパネル、コード片、チェッカーボードの透明背景、白背景、黒背景、風景
- ペット、小道具、エフェクト、ハイライト、影に使われたクロマキー色に近い色
- 孤立したピクセル、つながっていない輪郭の断片、斑点／ノイズ、切れた体の部分、重なったポーズ、隣のフレーム枠にまたがるポーズ

状態ごとの指針:

- `idle`: 落ち着いた、注意を引きすぎない状態にします。控えめな呼吸、小さなまばたき、頭や体のわずかな揺れ、ごく小さな素材の揺らぎ、またはペットらしさを損なわない静かな動きだけを使います。ループには、目で見て分かる微細な変化を必ず含めてください。実質的に同一の画像を6枚並べただけのものは受け入れないでください。手を振る、歩く、走る、跳ぶ、話す、作業する、確認する、感情を表す、大きな身振りをする、アイテムと関わる、新しい小道具を追加する表現は避けてください。
- `waving`: 前足、手、翼、または四肢のポーズだけで手を振る様子を表現します。ジェスチャーの周りに波線、動きを示す弧や線、きらめき、記号、浮遊する効果を描かないでください。
- `jumping`: 体の位置だけで上下の動きを表現します。影、ほこり、着地跡、衝撃の効果、バウンスパッド、床を示す手がかりを描かないでください。
- `failed`: 許可された効果のルールに従う場合、涙、付着した煙の塊、付着した星は使用できます。赤い×印、浮遊する記号、離れて浮く煙や星、独立した涙のしずくは使用しないでください。
- `waiting`: 期待して尋ねるポーズで、Codexが承認、助け、またはユーザーからの入力を必要としていることを示します。通常の待機状態やレビュー状態とは明確に区別してください。
- `running`: 進行中のタスク、処理、思考、スキャン、タイピング、集中した作業を表現します。文字どおり足で走る、ジョギング、全力疾走、トレッドミル上の動き、膝を高く上げる、歩幅を大きくする、腕を振る、特定の方向へ移動する、スピード線、ほこりの雲、床の影、動きの軌跡、離れて浮く動きの効果は表現しないでください。
- `review`: 体を傾ける、まばたき、目線、頭の傾き、前足や手の位置で集中を表します。虫眼鏡、紙、コード、UI、句読点、記号、その他の新しい小道具は、基本のペットの特徴にすでに含まれている場合を除き、追加しないでください。
- `running-right` と `running-left`: 体、四肢、小道具の動きだけで、方向を伴う引きずり動作を表現します。`running-right` は右を向いて右へ移動し、`running-left` は左を向いて左へ移動する必要があります。ループ中のリズムは、ほぼ静止した一歩を繰り返すのではなく、目で見て分かるように交互に変化させてください。スピード線、ほこりの雲、床の影、動きの軌跡、離れて浮く動きの効果は描かないでください。

## 進捗を見える形で示す計画

ペットの作業を行うたびに、ユーザーが進捗を確認できるチェックリストを表示します。作業開始前にチェックリストを作成し、同時に有効にするステップは常に1つだけにして、各ステップの完了時に更新してください。

通常のペット作業では、`<Pet>` をペットの名前、または `your pet` に置き換えて、次のチェックリストを使います。

1. `<Pet>` の準備をする。
2. `<Pet>` のメインの見た目を考える。
3. `<Pet>` のポーズを思い描く。
4. `<Pet>` を孵化させる。

各ステップの内容:

- `Getting <Pet> ready.` ペットの名前、説明、参照画像、スタイルプリセット、スタイルメモ、作業フォルダーを選ぶか確認します。ブランド、製品、企業の名前だけが指定された依頼では、最初にブランド調査ワーカーを実行し、簡潔なブランド概要、参照URL、アバターの種を記録します。
- `Imagining <Pet>'s main look.` ペットのメイン参照画像を生成します。これをビジュアルの正式な基準とします。
- `Picturing <Pet>'s poses.` 軽量ワーカーを使ってポーズ行を生成します。まず `idle` と `running-right` から始め、アイデンティティと歩容を確認します。`running-right` を反転しても明らかに問題がない場合に限り、`running-left` を反転生成します。
- `Hatching <Pet>.` 承認済みのポーズから最終的なペットファイルを作成し、コンタクトシート、プレビュー、検証結果を確認して、問題箇所を修正します。`pet.json` と `spritesheet.webp` を保存し、最後に出力パスを報告します。

実際のファイル、画像、または判断が存在する場合に限り、ステップを完了扱いにします。修復作業の場合は、チェックリスト全体を最初からやり直さず、最初に該当するステップから始めてください。

## 標準ワークフロー

1. ペット作業用フォルダーとimagegenジョブマニフェストを準備します。

```bash
SKILL_DIR="${CODEX_HOME:-$HOME/.codex}/skills/hatch-pet"
python "$SKILL_DIR/scripts/prepare_pet_run.py" \
  --pet-name "<Name>" \
  --description "<one sentence>" \
  --reference /absolute/path/to/reference.png \
  --output-dir /absolute/path/to/run \
  --pet-notes "<stable pet description>" \
  --brand-discovery-file /absolute/path/to/brand-discovery.md \
  --brand-name "<optional researched brand name>" \
  --brand-brief "<optional compact researched brand cue sentence>" \
  --brand-source "https://example.com/source" \
  --style-preset auto \
  --style-notes "<optional freeform style notes>" \
  --force
```

上記の引数は、ユーザーの制約を表すために必要なフラグを除き、すべて省略可能です。テキストのみの依頼では、コンセプトを `--pet-notes` に渡し、`--reference` は省略します。必要に応じて、`prepare_pet_run.py` が名前、説明、クロマキー、出力ディレクトリーを推定します。
ブランドのみの依頼では、最初に調査ワーカーを実行してMarkdownの概要を保存します。その後、概要ファイルのパスを `--brand-discovery-file` に、`avatar_seed` を `--pet-notes` に、`brand_name` を `--brand-name` に、`brand_brief` を `--brand-brief` に渡し、各参照URLは `--brand-source` を繰り返して渡します。

2. 次に実行可能な `$imagegen` ジョブを `imagegen-jobs.json` で確認します。ジョブの `status` が `complete` 以外で、かつ `depends_on` 内のすべてのIDがすでに完了している場合、そのジョブは実行可能です。ステータス表示用のヘルパースクリプトを追加するより、`jq` またはエディターでマニフェストを直接読む方法を優先してください。

```bash
jq '.jobs[] | {id, kind, status, depends_on, prompt_file, retry_prompt_file, input_images, output_path, derivation_policy}' /absolute/path/to/run/imagegen-jobs.json
```

3. 通常は軽量ワーカーを使ってビジュアルジョブを生成します。

- まず、軽量なベース用ワーカーを使って `base` を生成し、コピーします。
- 次に、アイデンティティと歩容の確認用として、各行につき軽量ワーカーを1つ使い、`idle` と `running-right` を生成してコピーします。
- `running-right` を確認し、ビジュアル上のアイデンティティ、小道具の配置、模様、照明、方向の意味が正しく保たれる場合に限って `running-left` を反転生成します。
- 反転すると意味やアイデンティティが変わる場合は、軽量ワーカーを使って通常の方法で `running-left` を生成します。
- 残りの行は軽量ワーカーで生成し、各ジョブに指定された入力画像をすべて使用します。

実行可能な各ビジュアルジョブについて、`imagegen-jobs.json` に記載されたプロンプトファイルと、役割ラベル付きで指定されたすべての入力画像を用いて `$imagegen` を呼び出します。`$imagegen` 自体が別経路に振り分ける場合を除き、標準の組み込み `image_gen` 経路を使用します。親エージェントは画像の取り扱いを最小限にしてください。生成されたベースや各行を、親の実行内ですべて開いてはいけません。ワーカーが返すのは、選択したソースパスと1文のQAメモだけです。親エージェントは、選択されたソースパスをマニフェストに記録します。

`prepare_pet_run.py` は、各アニメーション状態につき1枚、合計9枚の行別レイアウトガイド画像を `references/layout-guides/` に作成します。行ジョブには、フレーム数、間隔、中央配置、安全な余白をモデルが正しく設定できるよう、一致するガイドをレイアウト専用の入力として添付します。これらのガイドは、画面に表示しない構成参照として扱います。生成される行ストリップに、枠、境界線、中央マーク、ラベル、ガイドの色、ガイドの背景を表示してはいけません。

行ストリップを生成するときは、行プロンプト内のアイデンティティ固定指示を最優先にします。基準となるベースと同じスタイル、顔、模様、色調、素材、小道具のデザイン、体の比率、シルエットを維持してください。行ジョブには通常、レイアウトガイドと基準ベースが添付されます。デコード済みのベースは決定論的な処理用として作業フォルダーに保持し、重複する生成入力としては送信しません。

行に対する `$imagegen` の応答が転送レベルの `Bad Request` だった場合は、生成された `retry_prompt_file` を使って同じ行を1回だけ再試行します。再試行プロンプトでは、行ID、フレーム数、クロマキー、基準ベースのアイデンティティ、状態の動作を維持します。基準ベースは添付したままにします。再試行も失敗した場合は、別の生成経路に切り替えず、失敗した行とプロンプトのパスを報告して停止します。

4. ジョブの生成結果を選択したら、デコード済み出力パスへコピーし、ジョブを完了として記録します。`base` の場合は、基準アイデンティティ参照も作成します。

```bash
RUN_DIR=/absolute/path/to/run
JOB_ID=<job-id>
SOURCE=/absolute/path/to/generated-output.png
OUTPUT_REL=$(jq -r --arg id "$JOB_ID" '.jobs[] | select(.id == $id) | .output_path' "$RUN_DIR/imagegen-jobs.json")
mkdir -p "$(dirname "$RUN_DIR/$OUTPUT_REL")"
cp "$SOURCE" "$RUN_DIR/$OUTPUT_REL"
```

```bash
if [ "$JOB_ID" = "base" ]; then mkdir -p "$RUN_DIR/references"; cp "$RUN_DIR/$OUTPUT_REL" "$RUN_DIR/references/canonical-base.png"; fi
```

```bash
UPDATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
TMP_MANIFEST=$(mktemp)
jq --arg id "$JOB_ID" --arg source "$SOURCE" --arg at "$UPDATED_AT" '(.jobs[] | select(.id == $id)) += {status: "complete", source_path: $source, completed_at: $at}' "$RUN_DIR/imagegen-jobs.json" > "$TMP_MANIFEST"
mv "$TMP_MANIFEST" "$RUN_DIR/imagegen-jobs.json"
```

コピー元が `${CODEX_HOME:-$HOME/.codex}/generated_images` 以下にある場合は、デコード済みコピーの作成後に元の生成ファイルを削除します。

```bash
GENERATED_ROOT="${CODEX_HOME:-$HOME/.codex}/generated_images"
case "$SOURCE" in
  "$GENERATED_ROOT"/*)
    rm -f "$SOURCE"
    rmdir "$(dirname "$SOURCE")" 2>/dev/null || true
    ;;
esac
```

5. 見た目に問題がない場合に限り、`running-right` から `running-left` を生成します。

```bash
python "$SKILL_DIR/scripts/derive_running_left_from_running_right.py" \
  --run-dir /absolute/path/to/run \
  --confirm-appropriate-mirror \
  --decision-note "<why mirroring preserves this pet's identity>"
```

このスクリプトは、生成済みの各フレーム枠をその場で反転し、左向きの行でも右向きの行と時間順序を保ちます。アニメーションのタイミングが逆転する、ストリップ全体を反転する方法に置き換えないでください。

6. すべてのジョブが完了したら、画像処理スクリプトを直接実行します。

```bash
RUN_DIR=/absolute/path/to/run
mkdir -p "$RUN_DIR/final" "$RUN_DIR/qa"
```

```bash
python "$SKILL_DIR/scripts/extract_strip_frames.py" \
  --decoded-dir "$RUN_DIR/decoded" \
  --output-dir "$RUN_DIR/frames" \
  --states all \
  --method auto
```

```bash
python "$SKILL_DIR/scripts/inspect_frames.py" \
  --frames-root "$RUN_DIR/frames" \
  --json-out "$RUN_DIR/qa/review.json" \
  --require-components
```

```bash
python "$SKILL_DIR/scripts/compose_atlas.py" \
  --frames-root "$RUN_DIR/frames" \
  --output "$RUN_DIR/final/spritesheet.png" \
  --webp-output "$RUN_DIR/final/spritesheet.webp"
```

```bash
python "$SKILL_DIR/scripts/validate_atlas.py" \
  "$RUN_DIR/final/spritesheet.webp" \
  --json-out "$RUN_DIR/final/validation.json"
```

```bash
python "$SKILL_DIR/scripts/make_contact_sheet.py" \
  "$RUN_DIR/final/spritesheet.webp" \
  --output "$RUN_DIR/qa/contact-sheet.png"
```

```bash
python "$SKILL_DIR/scripts/render_animation_previews.py" \
  --frames-root "$RUN_DIR/frames" \
  --output-dir "$RUN_DIR/qa/previews"
```

プレビューGIFで、フレームごとのセル内フィット抽出が原因と思われるサイズのちらつきや基準位置の跳ねが見られ、元の行ストリップでは倍率と配置が安定していた場合は、明示的な行安定化モードでフレーム抽出をやり直します。その後、確認、アトラス合成、検証、コンタクトシート作成、プレビュー生成も再実行してください。

```bash
python "$SKILL_DIR/scripts/extract_strip_frames.py" \
  --decoded-dir "$RUN_DIR/decoded" \
  --output-dir "$RUN_DIR/frames" \
  --states all \
  --method stable-slots
```

```bash
python "$SKILL_DIR/scripts/inspect_frames.py" \
  --frames-root "$RUN_DIR/frames" \
  --json-out "$RUN_DIR/qa/review.json" \
  --require-components \
  --allow-stable-slots
```

`stable-slots` は、QAの結果に基づく意図的な修正として使用し、標準設定にはしないでください。クリッピングされた横幅の広いポーズや問題のある元ストリップを見逃すことなく、抽出処理が原因の動きのちらつきを減らす必要があります。

クリーンアップ前に想定される出力:

```text
run/
  pet_request.json
  imagegen-jobs.json
  prompts/
  decoded/
  frames/frames-manifest.json
  final/spritesheet.webp
  final/validation.json
  qa/contact-sheet.png
  qa/previews/*.gif
  qa/review.json
  qa/run-summary.json
```

パッケージ出力は、標準では作業フォルダーの外に書き込まれます。`CODEX_HOME` が設定されている場合はその値を使い、そうでなければ `$HOME/.codex` を使います。

```text
${CODEX_HOME:-$HOME/.codex}/pets/<pet-name>/
  pet.json
  spritesheet.webp
```

シェルと `jq` を使ってパッケージ化します。

```bash
RUN_DIR=/absolute/path/to/run
PET_ID=$(jq -r '.pet_id' "$RUN_DIR/pet_request.json")
DISPLAY_NAME=$(jq -r '.display_name' "$RUN_DIR/pet_request.json")
DESCRIPTION=$(jq -r '.description' "$RUN_DIR/pet_request.json")
PET_DIR="${CODEX_HOME:-$HOME/.codex}/pets/$PET_ID"
mkdir -p "$PET_DIR"
cp "$RUN_DIR/final/spritesheet.webp" "$PET_DIR/spritesheet.webp"
jq -n --arg id "$PET_ID" --arg displayName "$DISPLAY_NAME" --arg description "$DESCRIPTION" '{id: $id, displayName: $displayName, description: $description, spritesheetPath: "spritesheet.webp"}' > "$PET_DIR/pet.json"
```
パッケージング後に `qa/run-summary.json` を書き込みます。

```bash
jq -n --arg run_dir "$RUN_DIR" --arg spritesheet "$RUN_DIR/final/spritesheet.webp" --arg validation "$RUN_DIR/final/validation.json" --arg contact_sheet "$RUN_DIR/qa/contact-sheet.png" --arg review "$RUN_DIR/qa/review.json" --arg package "$PET_DIR" '{ok: true, run_dir: $run_dir, spritesheet: $spritesheet, validation: $validation, contact_sheet: $contact_sheet, review: $review, package: $package}' > "$RUN_DIR/qa/run-summary.json"
```

決定論的な画像処理の後、ペットを採用する前に、軽量なビジュアル QA ワーカーで `qa/contact-sheet.png` と `qa/previews/*.gif` を確認します。決定論的な検証は必要ですが、それだけでは十分ではありません。いずれかの行で、種や体型、顔、模様、配色、素材、プロップのデザイン、スタイル、予期しないプロップの向き、または全体のシルエットが変化している場合は、採用を見送ります。モーションプレビューでは、意図しないサイズの跳ね、方向ごとの動きの周期の逆転や停滞、向きの誤り、技術的には変化していても見た目にはほとんど動かないアイドルループも不合格にします。

モデルによるビジュアル QA でコンタクトシートが承認されたら、中間実行アーティファクトを削除します。

`pet_request.json`、`final/spritesheet.webp`、`final/validation.json`、`qa/contact-sheet.png`、`qa/previews/`、`qa/review.json`、`qa/run-summary.json` は保持します。生成したプロンプトファイル、レイアウトガイド、デコード済みの行ストリップ、抽出したフレーム、`final/spritesheet.png`、imagegen ジョブマニフェストは削除します。ユーザーがデバッグ用アーティファクトを希望している場合、または実行に修正が必要な場合は、クリーンアップをスキップします。

## 軽量ビジュアルワーカー

画像を多く扱う作業では、原則として軽量なサブエージェントを使用します。これにより、各 `$imagegen` の生成処理を選定画像1枚に限定し、コンタクトシートの画像データを親スレッドに持ち込まずに済み、9状態にわたるアプリの契約を維持しつつコストを抑えられます。

## サブエージェントへの委任

ユーザーが明示的に禁止していない限り、この実行ではサブエージェントを使用します。ユーザーがサブエージェントの使用を許可していない場合、または使用意図が曖昧な場合は、並行して作業するサブエージェントを起動してよいかユーザーに確認します。

親エージェントの担当事項:

- ユーザーがブランド、製品、会社、または見込み顧客の名前だけを提示した場合、準備の前にブランド調査ワーカーを実行する
- 実行環境を準備し、`imagegen-jobs.json` を確認する
- ベースジョブ、各行のジョブ、最終コンタクトシート QA を軽量ワーカーに割り当てる
- 選定されたワーカーの出力をデコード先のパスにコピーし、`imagegen-jobs.json` のジョブを完了済みにする
- 選定したベース出力から `references/canonical-base.png` を作成する
- 適切な場合、承認済みの `running-left` のミラー派生処理を実行する
- 決定論的な画像処理、パッケージング、修正のための再生成、クリーンアップを実行する

ベースワーカーの担当事項:

- `base` ジョブのみを処理する
- `prompts/base-pet.md` を読み、記載された参照画像を使用する
- `$imagegen` のみを使用する
- プロンプトに短いブランド着想の一文が含まれる場合は、広義のビジュアルや性格のガイダンスとして扱い、ロゴ、判読可能なマーク、UI のスクリーンショット、スローガン、テキストを模倣しない
- `selected_source=/absolute/path/to/selected-output.png` と `qa_note=<one sentence>` のみを返す

行ワーカーの担当事項:

- 行ジョブをちょうど1つ処理する
- 行プロンプトを読み、記載された入力画像をすべて使用する
- `$imagegen` のみを使用する。ローカルでスプライトを描画、編集、タイル化、合成しない
- フレーム数、同一性、クロマ背景、間隔、クリッピング、分離したエフェクトがないかを簡単に目視確認する
- 分離エフェクトを禁止すること、`waving` に波線を付けないこと、方向性のある走行行にスピード線や砂ぼこりを付けないこと、方向性のない `running` 行に文字どおりの足踏み走行をさせないこと、状態プロンプトで許可された場合に限ってスプライトに付着した不透明な涙、煙、星のみを使用することなど、行プロンプトの透明度とエフェクトに関するルールを守る
- `selected_source=/absolute/path/to/selected-output.png` と `qa_note=<one sentence>` のみを返す

最終ビジュアル QA ワーカーの担当事項:

- `qa/contact-sheet.png` と `qa/previews/` 内の行 GIF を確認する。必要に応じて、テキスト情報として `qa/review.json` と `final/validation.json` も参照する
- 9行すべてが Codex アプリの状態契約と同一のペットのアイデンティティに合致していることを検証する
- 簡潔な結果として `visual_qa=pass` または `visual_qa=fail` を返し、不合格の場合は行ごとの修正メモも添える
- ファイルの編集、修正のキュー登録、パッケージング、クリーンアップは行わない

ワーカーのモデル選択:

- ブランド調査では、オーケストレーションではなく簡潔な調査概要を返すため、能力のある小型モデルを優先する
- ビジュアルワーカーでは、モデルの指定が可能な場合、medium 推論の `gpt-5.4-mini` などの能力のある小型モデルを優先する
- オーケストレーションを行う場合、または小型ワーカー用モデルが利用できない場合に限り、親エージェントのデフォルトモデルを使用する
- ユーザーが並列度の引き上げを明示的に求めない限り、同時に実行する生成ワーカーは最大2つとする。決定論的な画像処理後に、最終ビジュアル QA を単一のワーカーで実行する。結果を取り込んだらワーカーを終了する

次のベースワーカープロンプトを使用します。

```text
Generate the hatch-pet base image.

Run dir: <absolute run dir>
Job id: base
Prompt file: <absolute base prompt file>
Input images:
- <absolute path> — <role>

Use $imagegen only. Read the base prompt and attach every listed input image. If the prompt contains brand inspiration, use it only as broad mascot-safe guidance; do not copy logos, readable marks, UI screenshots, slogans, or text. Before returning, visually check that the result is one centered full-body pet on a flat chroma background, with no text, scenery, shadows, or detached effects.

Do not edit manifests, copy into decoded, mark jobs complete, generate rows, run image-processing scripts, repair, package, or open unrelated files.
Do not include Markdown image previews, base64, or extra attachments in the final response.

Return exactly:
selected_source=/absolute/path/to/selected-output.png
qa_note=<one sentence>
```

次の行ワーカープロンプトを使用します。

```text
Generate one hatch-pet row.

Run dir: <absolute run dir>
Row id: <row-id>
Prompt file: <absolute prompt file>
Retry prompt file: <absolute retry prompt file>
Input images:
- <absolute path> — <role>
- <absolute path> — <role>

Use $imagegen only. Read the row prompt and attach every listed input image. If imagegen returns Bad Request, retry once with the retry prompt and the same input images.

Before returning, visually check: exact frame count, same pet identity as canonical base, flat chroma background, complete separated unclipped poses, and no detached effects or guide marks. The prompt's transparency and effects rules are mandatory: no detached effects, no wave marks for `waving`, no speed lines or dust for directional running rows, no literal foot-running for the non-directional `running` row, and only attached opaque sprite-like tears/smoke/stars when allowed by the state prompt.

Do not edit manifests, copy into decoded, mark jobs complete, mirror rows, run image-processing scripts, repair, package, or open unrelated files.
Do not include Markdown image previews, base64, or extra attachments in the final response.

Return exactly:
selected_source=/absolute/path/to/selected-output.png
qa_note=<one sentence>
```

次の最終ビジュアル QA ワーカープロンプトを使用します。

```text
Visually QA one finalized hatch-pet contact sheet.

Run dir: <absolute run dir>
Contact sheet: <absolute run dir>/qa/contact-sheet.png
Preview dir: <absolute run dir>/qa/previews
Review JSON: <absolute run dir>/qa/review.json
Validation JSON: <absolute run dir>/final/validation.json

Inspect the contact sheet and the preview GIFs visually. Confirm the same pet identity, style, palette, silhouette, face, proportions, and props across all rows:
0 idle, 1 running-right, 2 running-left, 3 waving, 4 jumping, 5 failed, 6 waiting, 7 running, 8 review.

Fail rows with identity drift, missing/blank frames, copied guide marks, white/nontransparent backgrounds, cropped bodies, slot overlap, detached effects, shadows/glows/smears/dust, chroma-key artifacts, motion that does not match the row state, unintended size popping, wrong facing direction, reversed or non-alternating gait, or idle loops that are effectively static.

Do not edit files, queue repairs, package, clean up, or inspect unrelated files.

Return exactly:
visual_qa=pass|fail
qa_note=<one sentence summary>
repair_rows=<comma-separated row ids, or none>
repair_notes=<short row-specific notes, or none>
```

## 修正ワークフロー

フレームの確認または最終ビジュアル QA が不合格になった場合は、`qa/review.json` を読み、失敗した範囲を最小限にして再生成し、差し替えた行を同じデコード済み出力パスにコピーします。そのジョブは、新しい `source_path` と `completed_at` を記録して完了済みのままにします。シート全体ではなく、不合格となった行を修正してください。

アイデンティティの修正では、canonical base 画像、元の参照画像、コンタクトシート、該当する行の正確な失敗メモを根拠として使用してください。行ワーカーには既存の行プロンプトと、`qa/review.json` の簡潔な修正メモを渡し、canonical なペットのアイデンティティと選択済みのスタイルを維持してください。

抽出が原因でモーションに跳ねが生じた場合は、最初に画像を再生成しないでください。元のストリップで行ごとのスケールとベースラインが保たれている場合は、`--method stable-slots` を使って決定論的パイプラインを再実行し、`--allow-stable-slots` を付けて確認してから、プレビュー GIF を再確認してください。元のストリップ自体がクリッピング、不安定、または意味的に誤っている場合にのみ、行を再生成します。

## ルール

- 主たる生成レイヤーとして `$imagegen` を使用する。
- ブランド、製品、会社、見込み顧客に関する依頼で、具体的なアバターの説明や参照画像がない場合は、ベースを生成する前にブランド調査を行い、その簡潔な概要のみを実行に渡す。
- 唯一のビジュアル生成レイヤーとして `$imagegen` を使用する。このスキルから画像 API、画像 CLI、ローカルのラスター生成器、単発の生成スクリプトを呼び出さない。
- 選択した手段が参照画像に対応している場合は、参照画像を `$imagegen` に添付して見える状態にする。
- 各行ストリップのジョブに、その行の `references/layout-guides/<state>.png` 画像をレイアウト専用ガイドとして添付し、出力にガイドのピクセルが複製されたものを採用しない。
- 原則として、ベース生成、行ストリップのビジュアル生成、最終コンタクトシート QA に軽量なビジュアルワーカーを使用する。マニフェストの更新、決定論的な画像スクリプト、パッケージング、クリーンアップは親エージェントが担当する。
- 明示的に承認された `$imagegen` のミラー派生を除き、すべての通常のビジュアルジョブを `running-left` で生成する。対象はベースとすべての行ストリップ。
- プロンプトのみでの生成が認められるのはベースジョブだけとする。すべての行ジョブで、指定されたグラウンディング画像を添付する。
- `running-right` をミラー化できるか判断する前に、`running-left` を生成する。
- `running-left` をミラー化する場合は、フレーム順とタイミングの意味を保つ。ストリップ全体を一括でミラー化せず、決定論的スクリプトで派生させる。
- `waiting`、`running`、`failed`、`review`、`jumping`、`waving` を別の状態から派生または再利用しない。各状態はアプリ上でそれぞれ異なる意味を持つため、独立した行として生成する。
- 不足している `$imagegen` の出力の代わりに、ローカルで描画、タイル化、変換、またはコード生成した行ストリップを使わない。
- 選定した出力をデコード済みの出力パスにコピーしてから、ビジュアルジョブを完了済みにする。
- アトラスの正確なジオメトリについて、生成画像に頼らない。このスキルの決定論的な画像スクリプトを使用する。
- `pet_request.json` に保存されたクロマキー色を使用し、固定のグリーンスクリーン色を強制しない。
- すべての行を通して、ペットのシルエット、顔、素材、配色、スタイル、プロップを一貫させる。
- `qa/review.json` と `final/validation.json` にエラーがなくても、ビジュアル上のアイデンティティやスタイルのずれはブロッカーとして扱う。
- 参照画像が切り取られている、タイルが繰り返されている、セルの背景が白い、またはスプライトではない断片が見えるコンタクトシートは不合格とする。
- 抽出によるサイズの跳ね、方向性のタイミングの逆転、向きの誤り、または動きのないアイドルループが見られるプレビュー GIF は不合格とする。
- 禁止された分離エフェクト、クロマキー色に隣接するアーティファクト、影、光彩、にじみ、砂ぼこり、着地マーク、波線、スピード線、モーショントレイルを含む行は不合格とする。
- `qa/review.json` のエラーはブロッカーとして扱います。警告がある場合は目視で確認してください。

## 受け入れ基準

- 最終アトラスは PNG または WebP 形式で、サイズは `1536x1872`、透過に対応し、`192x208` のセルを基準にしています。
- 使用するセルは空でなく、未使用のセルは完全に透明です。
- アトラスは `references/animation-rows.md` に記載された行数とフレーム数に従っています。
- コンタクトシートと行ごとの動作プレビューを作成し、軽量なビジュアル QA ワーカーが確認しています。
- `qa/review.json` にエラーがありません。
- 行ごとのレビューで、Codex アプリに十分なアニメーションのループが完成していることを確認しています。
- 動作プレビューに、意図しないサイズのちらつき、方向の動きのリズムの逆転、または行の意味の誤りが見られません。
- ピクセルアート以外のスタイルも、ペットの表示サイズで見やすく、各行で一貫していれば受け入れられます。
- カスタムペットでは、`${CODEX_HOME:-$HOME/.codex}/pets/<pet-name>/pet.json` と `${CODEX_HOME:-$HOME/.codex}/pets/<pet-name>/spritesheet.webp` を一緒にステージングします。
