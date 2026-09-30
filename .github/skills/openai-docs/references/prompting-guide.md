GPT-5.5 は、プロンプトで目標とする結果を定義し、効率的な解決方法をモデルが選べる余地を残すと、最もよく機能します。以前のモデルと比べると、より短く、結果を重視したプロンプトで十分な場合がよくあります。望ましい結果、重要な制約、利用できる根拠、最終回答に含めるべき内容を説明してください。

古いプロンプト群の指示をすべて引き継ぐのは避けてください。従来のプロンプトでは、以前のモデルが課題から逸れずに進めるよう、手順を細かく指定しがちでした。GPT-5.5 では、それが余分な情報となり、モデルが検討できる選択肢を狭めたり、過度に機械的な回答につながったりすることがあります。

GPT-5.5 の挙動の変化について詳しくは、[GPT-5.5 の使用ガイド](/api/docs/guides/latest-model)から参照してください。このガイドでは、そうした挙動の変化に伴うプロンプトの変更に焦点を当てます。

ここで紹介するパターンは出発点です。製品の利用場面、ツール、評価、ユーザー体験の目標に合わせて調整してください。

## パーソナリティと振る舞い

GPT-5.5 の標準的な文体は、効率的で直接的、かつタスク志向です。これは本番環境のシステムに役立ちます。回答が要点に集中し、振る舞いを制御しやすく、不要な前置きや会話的な言い回しを避けられます。

顧客向けアシスタント、サポート業務、コーチング体験などの対話型製品では、パーソナリティと協働の進め方の両方を定義してください。

- **パーソナリティ**は、アシスタントの話し方を決めます。口調、温かみ、率直さ、丁寧さ、ユーモア、共感、表現の洗練度などです。
- **協働の進め方**は、アシスタントの仕事の進め方を決めます。いつ質問するか、いつ推測して進めるか、どの程度主体的に動くか、どれだけ背景情報を伝えるか、いつ作業を確認するか、不確実性やリスクにどう対処するかなどです。

どちらも短くまとめてください。パーソナリティに関する指示はユーザー体験を、協働に関する指示はタスク遂行時の振る舞いを形作るものです。いずれも、明確な目標、成功基準、ツールの使用規則、終了条件の代わりにはなりません。

落ち着いてタスクに取り組むアシスタント向けのパーソナリティ設定例:

```text
# Personality
You are a capable collaborator: approachable, steady, and direct. Assume the user is competent and acting in good faith, and respond with patience, respect, and practical helpfulness.

Prefer making progress over stopping for clarification when the request is already clear enough to attempt. Use context and reasonable assumptions to move forward. Ask for clarification only when the missing information would materially change the answer or create meaningful risk, and keep any question narrow.

Stay concise without becoming curt. Give enough context for the user to understand and trust the answer, then stop. Use examples, comparisons, or simple analogies when they make the point easier to grasp. When correcting the user or disagreeing, be candid but constructive. When an error is pointed out, acknowledge it plainly and focus on fixing it.

Match the user's tone within professional bounds. Avoid emojis and profanity by default, unless the user explicitly asks for that style or has clearly established it as appropriate for the conversation.
```

表現力豊かに協働するアシスタント向けのパーソナリティ設定例:

```text
# Personality
Adopt a vivid conversational presence: intelligent, curious, playful when appropriate, and attentive to the user's thinking. Ask good questions when the problem is blurry, then become decisive once there is enough context.

Be warm, collaborative, and polished. Conversation should feel easy and alive, but not chatty for its own sake. Offer a real point of view rather than merely mirroring the user, while staying responsive to their goals and constraints.

Be thoughtful and grounded when the task calls for synthesis or advice. State a clear recommendation when you have enough context, explain important tradeoffs, and name uncertainty without becoming evasive.
```

表現力を重視する製品では、温かみ、好奇心、ユーモア、独自の見解を明示的に加えてください。ただし、設定は短く保ちます。パーソナリティは体験を形作るために使い、目標の曖昧さやタスクの指示不足を補うためには使わないでください。

## 冒頭の一言で、最初の応答が表示されるまでの時間を改善する

ストリーミングを使うアプリケーションでは、最初の応答が表示されるまでの時間をユーザーは気にします。GPT-5.5 は、目に見えるテキストを出す前に、推論、計画、ツール呼び出しの準備に時間を使うことがあります。

長いタスクやツールを多用するタスクでは、短い冒頭の一言から始めるようモデルに指示してください。依頼を受け取ったことを伝え、最初の手順を述べる簡潔な更新です。基となるタスクを変えずに、応答の速さについての体感を改善できます。

複数の手順が必要になりそうなタスク、ツール呼び出しが必要なタスク、長時間続くエージェントのワークフローでは、このパターンを使ってください。

```text
Before any tool calls for a multi-step task, send a short user-visible update that acknowledges the request and states the first step. Keep it to one or two sentences.
```

メッセージの段階を分けて表示するコーディングエージェントでは、さらに明示的にできます。

```text
You must always start with an intermediary update before any content in the analysis channel if the task will require calling tools. The user update should acknowledge the request and explain your first step.
```

## 結果を先に示すプロンプトと終了条件

GPT-5.5 は、プロンプトに目標とする結果、成功基準、制約、利用できる背景情報を定義し、そこに至る方法をモデルに選ばせると、最も力を発揮します。

多くのタスクでは、すべての手順ではなく到達点を説明してください。そうすることで、タスクに適した検索方法、ツール、推論方法をモデルが選べます。

推奨する形:

```text
Resolve the customer's issue end to end.

Success means:
- the eligibility decision is made from the available policy and account data
- any allowed action is completed before responding
- the final answer includes completed_actions, customer_message, and blockers
- if evidence is missing, ask for the smallest missing field
```

**不要な絶対規則は避けてください。** 古いプロンプトでは、モデルの振る舞いを制御するために `ALWAYS`、`NEVER`、`must`、`only` のような厳格な指示をよく使います。こうした語は、安全上の規則、必須の出力フィールド、決して行ってはならない操作など、真に例外のない条件に使ってください。検索するか、確認を求めるか、ツールを使うか、作業を続けるかといった判断が必要な場面では、代わりに判断基準を示してください。

すべての手順が本当に必要な場合を除き、次のような指示は避けてください。

```text
First inspect A, then inspect B, then compare every field, then think through
all possible exceptions, then decide which tool to call, then call the tool,
then explain the entire process to the user.
```

終了条件を明示してください。

```text
Resolve the user query in the fewest useful tool loops, but do not let loop minimization outrank correctness, accessible fallback evidence, calculations, or required citation tags for factual claims.

After each result, ask: "Can I answer the user's core request now with useful evidence and citations for the factual claims?" If yes, answer.
```

根拠が不足している場合の対応を定義してください。

```text
Use the minimum evidence sufficient to answer correctly, cite it precisely, then stop.
```

## 書式

GPT-5.5 は、出力の書式や構成を細かく指定できます。理解しやすさや製品との適合性が高まる場合に、その特性を活用してください。

`text.verbosity` を設定し、期待する出力の形を説明してください。複雑な構成は、理解しやすくなる場合や、製品の UI で安定した形式の成果物が必要な場合に限って使います。API における `text.verbosity` の既定値は `medium` です。より短く簡潔な回答を望むなら `low` を使ってください。

自然な会話形式の書式:

```text
Let formatting serve comprehension. Use plain paragraphs as the default format for normal conversation, explanations, reports, documentation, and technical writeups. Keep the presentation clean and readable without making the structure feel heavier than the content.

Use headers, bold text, bullets, and numbered lists sparingly. Reach for them when the user requests them, when the answer needs clear comparison or ranking, or when the information would be harder to scan as prose. Otherwise, favor short paragraphs and natural transitions.

Respect formatting preferences from the user. If they ask for a terse answer, minimal formatting, no bullets, no headers, or a specific structure, follow that preference unless there is a strong reason not to.
```

想定読者と長さについても明示してください。

```text
Write for a senior business audience. Keep the answer under 400 words. Use short paragraphs and only include bullets when they improve scannability. Prioritize the conclusion first, then the reasoning, then caveats.
```

編集、書き直し、要約、顧客向けメッセージでは、文体の改善を求める前に、保持すべきものをモデルに伝えてください。このパターンは、内容を増やさずに文章を洗練させたい場合に役立ちます。

```text
Preserve the requested artifact, length, structure, and genre first. Quietly improve clarity, flow, and correctness. Do not add new claims, extra sections, or a more promotional tone unless explicitly requested.
```

## 根拠、出典、情報取得の上限

根拠に基づく回答では、出典の示し方をプロンプトに含めてください。何に裏付けが必要か、どの程度の根拠があれば十分か、根拠がない場合にどう振る舞うべきかを定義します。根拠が見つからないことを、自動的に事実としての「いいえ」に置き換えてはいけません。詳しい説明と例は、[出典の書式ガイド](/api/docs/guides/citation-formatting)を参照してください。

### 情報取得の上限を明示する

情報取得の上限は、検索を終えるための規則です。十分な根拠がいつそろったと判断するかをモデルに伝えます。

```text
For ordinary Q&A, start with one broad search using short, discriminative keywords. If the top results contain enough citable support for the core request, answer from those results instead of searching again.

Make another retrieval call only when:
- The top results do not answer the core question.
- A required fact, parameter, owner, date, ID, or source is missing.
- The user asked for exhaustive coverage, a comparison, or a comprehensive list.
- A specific document, URL, email, meeting, record, or code artifact must be read.
- The answer would otherwise contain an important unsupported factual claim.

Do not search again to improve phrasing, add examples, cite nonessential details, or support wording that can safely be made more generic.
```

## 創作を伴う文章作成での注意点

文章作成のタスクでは、どの主張を出典に基づかせる必要があり、どの部分を創作的に書いてよいかをモデルに伝えてください。これは、スライド、リリース時の文案、顧客向け要約、説明用の話材、経営層向けの短い紹介文、ストーリーの組み立てで特に重要です。

```text
For creative or generative requests such as slides, leadership blurbs, outbound copy, summaries for sharing, talk tracks, or narrative framing, distinguish source-backed facts from creative wording.

- Use retrieved or provided facts for concrete product, customer, metric, roadmap, date, capability, and competitive claims, and cite those claims.
- Do not invent specific names, first-party data claims, metrics, roadmap status, customer outcomes, or product capabilities to make the draft sound stronger.
- If there is little or no citable support, write a useful generic draft with placeholders or clearly labeled assumptions rather than unsupported specifics.
```

## フロントエンド開発と視覚的なセンス

フロントエンドの作業では、UI の品質を高めるための実践的な指示について、[指示の例](/api/docs/guides/frontend-prompt)を参照してください。製品とユーザーの背景、デザインシステムとの整合性、最初の画面の使いやすさ、なじみのある操作要素、想定される状態、画面サイズに応じた動作のほか、ありきたりなヒーローセクション、入れ子のカード、装飾的なグラデーション、画面に表示される説明文、崩れたレイアウトといった、生成 UI で避けたい典型的なパターンを扱っています。

## モデルに作業結果を確認させる

検証できる場合は、GPT-5.5 が出力を確認できるツールを利用できるようにしてください。

コーディングエージェントには、具体的な検証コマンドを実行するよう求めてください。

```text
After making changes, run the most relevant validation available:
- targeted unit tests for changed behavior
- type checks or lint checks when applicable
- build checks for affected packages
- a minimal smoke test when full validation is too expensive

If validation cannot be run, explain why and describe the next best check.
```

視覚的な成果物については、レンダリング後に確認するよう指示します。

```text
Render the artifact before finalizing. Inspect the rendered output for layout, clipping, spacing, missing content, and visual consistency. Revise until the rendered output matches the requirements.
```

エンジニアリングや計画のタスクでは、実装計画の各項目を追跡できるようにします。

```text
For implementation plans, include:
- requirements and where each is addressed
- named resources, files, APIs, or systems involved
- state transitions or data flow where relevant
- validation commands or checks
- failure behavior
- privacy and security considerations
- open questions that materially affect implementation
```

## Phase パラメーター

GPT-5.4 以降、長時間実行される、またはツールの使用が多い Responses ワークフローでは、アシスタント項目の `phase` 値を使って、途中経過の報告と最終回答を区別できます。GPT-5.5 でも同じ方式を使用します。

`previous_response_id` を使用する場合、API は以前のアシスタントの状態を自動的に保持します。アプリケーションがアシスタントの出力項目を次のリクエストに手動で再送する場合は、元の各 `phase` 値を保持し、変更せずに渡してください。これは、レスポンスに前置き、繰り返しのツール呼び出し、途中経過の報告に続く最終回答が含まれる場合に特に重要です。

```text
If manually replaying assistant items:
- Preserve assistant `phase` values exactly.
- Use `phase: "commentary"` for intermediate user-visible updates.
- Use `phase: "final_answer"` for the completed answer.
- Do not add `phase` to user messages.
```

## 推奨するプロンプトの構成

複雑なプロンプトでは、以下の構成を出発点にしてください。各セクションは短くまとめ、動作が変わる場合にのみ詳細を追加します。

```text
Role: [1-2 sentences defining the model's function, context, and job]

# Personality
[tone, demeanor, and collaboration style]

# Goal
[user-visible outcome]

# Success criteria
[what must be true before the final answer]

# Constraints
[policy, safety, business, evidence, and side-effect limits]

# Output
[sections, length, and tone]

# Stop rules
[when to retry, fallback, abstain, ask, or stop]
```
