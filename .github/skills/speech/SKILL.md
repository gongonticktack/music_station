---
name: "speech"
description: "ユーザーが、OpenAI Audio API を使ったテキスト読み上げナレーションやボイスオーバー、アクセシビリティ向け読み上げ、音声プロンプト、一括音声生成を依頼した場合に使用します。組み込み音声を使い、付属の CLI (`scripts/text_to_speech.py`) を実行してください。実際の API 呼び出しには `OPENAI_API_KEY` が必要です。カスタム音声の作成は対象外です。"
---


# 音声生成スキル
現在のプロジェクト向けに音声を生成します（ナレーション、製品デモのボイスオーバー、IVR プロンプト、アクセシビリティ向け読み上げ）。既定では `gpt-4o-mini-tts-2025-12-15` と組み込み音声を使用し、再現性のある実行を実現するため、付属の CLI を優先します。

## 使用する場面
- テキストから単一の音声クリップを生成する
- プロンプトを一括生成する（多数の行やファイル）

## 判断フロー（単一か一括か）
- ユーザーが複数の行やプロンプトを提示した場合、または多数の出力を求めている場合 -> **一括**
- それ以外 -> **単一**

## ワークフロー
1. 目的を判断します。単一か一括かを決めます（上の判断フローを参照）。
2. 必要な入力を最初にそろえます。正確なテキスト（原文どおり）、希望する音声、読み上げスタイル、形式、制約を確認します。
3. 一括生成の場合は、tmp/ に一時 JSONL を作成し（1行につき1ジョブ）、一度実行してから JSONL を削除します。
4. 入力テキストを書き換えずに、指示を短いラベル付き仕様にまとめます。
5. 適切な既定値を使って付属の CLI (`scripts/text_to_speech.py`) を実行します（references/cli.md を参照）。
6. 重要なクリップは、聞き取りやすさ、ペース、発音、制約への準拠を確認します。
7. 変更点を1つ（音声、速度、または指示）に絞って調整し、再確認します。
8. 最終成果物を保存または返却し、最終的に使用したテキスト、指示、フラグを記載します。

## 一時ファイルと出力の規約
- 中間ファイル（JSONL 一括生成ファイルなど）には `tmp/speech/` を使用し、完了後に削除します。
- このリポジトリで作業する場合、最終成果物は `output/speech/` に保存します。
- `--out` または `--out-dir` で出力先を指定し、ファイル名は安定して内容が分かるものにします。

## 依存関係（不足している場合はインストール）
依存関係の管理には `uv` を優先してください。

Python パッケージ:
```
uv pip install openai
```
`uv` が利用できない場合:
```
python3 -m pip install openai
```

## 環境
- 実際の API 呼び出しには `OPENAI_API_KEY` を設定する必要があります。

キーが設定されていない場合は、次の手順をユーザーに案内してください:
1. OpenAI プラットフォームの UI で API キーを作成します: https://platform.openai.com/api-keys
2. ユーザーのシステムで `OPENAI_API_KEY` を環境変数として設定します。
3. 必要であれば、使用している OS やシェルでの環境変数の設定方法を案内すると申し出ます。
- チャットにキー全体を貼り付けるよう、ユーザーに求めてはいけません。ローカルで設定してもらい、準備ができたら知らせてもらいます。

この環境でインストールできない場合は、不足している依存関係と、ローカルでのインストール方法をユーザーに伝えてください。

## 既定値とルール
- ユーザーが別のモデルを指定しない限り、`gpt-4o-mini-tts-2025-12-15` を使用します。
- 既定の音声: `cedar`。より明るい声を希望する場合は `marin` を優先します。
- 組み込み音声のみを使用します。このスキルではカスタム音声は対象外です。
- `instructions` は GPT-4o mini TTS モデルでサポートされますが、`tts-1` または `tts-1-hd` ではサポートされません。
- 1回のリクエストにつき、入力は4096文字以下にする必要があります。長いテキストは分割します。
- 1分あたり50リクエストを上限とします。CLI の `--rpm` は50が上限です。
- 実際の API 呼び出しを行う前に、必ず `OPENAI_API_KEY` が設定されていることを確認します。
- 音声が AI で生成されたことを、エンドユーザーにはっきり伝えてください。
- すべての API 呼び出しに OpenAI Python SDK（`openai` パッケージ）を使用し、生の HTTP は使わないでください。
- 新たに単発スクリプトを書くより、付属の CLI (`scripts/text_to_speech.py`) を優先してください。
- `scripts/text_to_speech.py` は絶対に変更しないでください。不足している機能がある場合は、ほかの作業に着手する前にユーザーに尋ねてください。

## 指示の補足
ユーザーの指示を、ラベル付きの短い仕様に整えます。暗黙の詳細を明示するだけにとどめ、要件を新たに作り出してはいけません。

簡単な確認（補足と創作の違い）:
- ユーザーが「デモのナレーション」と言った場合、明瞭で一定のペース、親しみやすい口調など、暗黙の読み上げ上の制約を加えてもかまいません。
- ユーザーが求めていない新しい人物像、アクセント、感情表現を加えてはいけません。

テンプレート（関連する行だけを含める）:
```
Voice Affect: <overall character and texture of the voice>
Tone: <attitude, formality, warmth>
Pacing: <slow, steady, brisk>
Emotion: <key emotions to convey>
Pronunciation: <words to enunciate or emphasize>
Pauses: <where to add intentional pauses>
Emphasis: <key words or phrases to stress>
Delivery: <cadence or rhythm notes>
```

補足のルール:
- 簡潔にし、ユーザーがすでに示した、またはほかの箇所で示唆した詳細だけを加えてください。
- 入力テキストを書き換えてはいけません。
- 成功に不可欠な詳細が欠けていて作業を進められない場合は質問してください。それ以外の場合は、そのまま進めてください。

## 例

### 単一の例（ナレーション）
```
Input text: "Welcome to the demo. Today we'll show how it works."
Instructions:
Voice Affect: Warm and composed.
Tone: Friendly and confident.
Pacing: Steady and moderate.
Emphasis: Stress "demo" and "show".
```

### 一括生成の例（IVR プロンプト）
```
{"input":"Thank you for calling. Please hold.","voice":"cedar","response_format":"mp3","out":"hold.mp3"}
{"input":"For sales, press 1. For support, press 2.","voice":"marin","instructions":"Tone: Clear and neutral. Pacing: Slow.","response_format":"wav"}
```

## 指示作成のベストプラクティス（短い一覧）
- 指示は「声の特徴 -> 口調 -> ペース -> 感情 -> 発音／間 -> 強調」の順に構成します。
- 短い行を4〜8行にまとめ、矛盾する指示を避けます。
- 名前や頭字語には、「A-I を一字ずつ発音する」などの発音ヒントを加えるか、テキスト内に発音を音写して記載します。
- 編集や反復では、「ペースを一定に保つ」など、変えない条件を再度記載して、意図しない変化を抑えます。
- 変更点を1つに絞った追加依頼で調整します。

詳しい原則: `references/prompting.md`。コピーして使える仕様: `references/sample-prompts.md`。

## 用途別ガイダンス
特定の読み上げスタイルが求められている場合は、次のモジュールを使用してください。用途に応じた既定値とテンプレートが用意されています。
- ナレーション／解説: `references/narration.md`
- 製品デモ／ボイスオーバー: `references/voiceover.md`
- IVR／電話プロンプト: `references/ivr.md`
- アクセシビリティ向け読み上げ: `references/accessibility.md`

## CLI と環境に関するメモ
- CLI のコマンドと例: `references/cli.md`
- API パラメーターのクイックリファレンス: `references/audio-api.md`
- 指示のパターンと例: `references/voice-directions.md`
- ネットワーク承認やサンドボックスの設定が妨げになっている場合: `references/codex-network.md`

## リファレンス一覧
- **`references/cli.md`**: `scripts/text_to_speech.py` を使った音声生成や一括生成の実行方法（コマンド、フラグ、レシピ）。
- **`references/audio-api.md`**: API パラメーター、制限、音声一覧。
- **`references/voice-directions.md`**: 指示のパターンと例。
- **`references/prompting.md`**: 指示作成のベストプラクティス（構成、制約、反復パターン）。
- **`references/sample-prompts.md`**: コピーして使える指示のレシピ（例のみ。追加の解説なし）。
- **`references/narration.md`**: ナレーションや解説用のテンプレートと既定値。
- **`references/voiceover.md`**: 製品デモのボイスオーバー用テンプレートと既定値。
- **`references/ivr.md`**: IVR／電話プロンプト用のテンプレートと既定値。
- **`references/accessibility.md`**: アクセシビリティ向け読み上げ用のテンプレートと既定値。
- **`references/codex-network.md`**: 環境、サンドボックス、ネットワーク承認に関するトラブルシューティング。