---
name: "transcribe"
description: "音声ファイルをテキストに文字起こしします。話者の識別や既知の話者に関するヒントも任意で利用できます。ユーザーが音声や動画からの発話の文字起こし、録音からのテキスト抽出、インタビューや会議での話者のラベル付けを依頼した場合に使用します。"
---


# 音声文字起こし

OpenAI を使用して音声を文字起こしします。要求された場合は、話者の識別も行えます。結果を確実に再現できるよう、同梱の CLI を優先して使用してください。

## 作業手順
1. 入力情報を集めます。音声ファイルのパス、希望する応答形式（text/json/diarized_json）、任意の言語ヒント、既知の話者の参照データを確認します。
2. `OPENAI_API_KEY` が設定されていることを確認します。未設定の場合は、ユーザーにローカル環境で設定するよう依頼します（キーを貼り付けるよう求めないでください）。
3. 同梱の `transcribe_diarize.py` CLI を適切なデフォルト設定（高速なテキスト文字起こし）で実行します。
4. 出力の文字起こし品質、話者ラベル、セグメントの境界を確認します。必要であれば、変更を 1 点に絞って再実行します。
5. このリポジトリで作業する場合は、出力を `output/transcribe/` に保存します。

## 選択基準
- 高速な文字起こしには、デフォルトで `gpt-4o-mini-transcribe` と `--response-format text` を使用します。
- ユーザーが話者ラベルや話者の識別を希望する場合は、`--model gpt-4o-transcribe-diarize --response-format diarized_json` を使用します。
- 音声が約 30 秒を超える場合は、`--chunking-strategy auto` を維持します。
- `gpt-4o-transcribe-diarize` ではプロンプトを使用できません。

## 出力規則
- 評価用の実行には `output/transcribe/<job-id>/` を使用します。
- 複数のファイルを処理する場合は、上書きを避けるために `--out-dir` を使用します。

## 依存関係（不足している場合はインストール）
依存関係の管理には `uv` を優先して使用します。

```
uv pip install openai
```
`uv` が使用できない場合:
```
python3 -m pip install openai
```

## 環境
- 実際の API 呼び出しには `OPENAI_API_KEY` の設定が必要です。
- キーがない場合は、OpenAI プラットフォームの画面でキーを作成し、シェルで環境変数として設定するようユーザーに案内します。
- チャットに完全なキーを貼り付けるようユーザーに求めないでください。

## スキルのパス（一度だけ設定）

```bash
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export TRANSCRIBE_CLI="$CODEX_HOME/skills/transcribe/scripts/transcribe_diarize.py"
```

ユーザー単位のスキルは `$CODEX_HOME/skills` にインストールされます（デフォルト: `~/.codex/skills`）。

## CLI クイックスタート
単一ファイル（デフォルトの高速なテキスト文字起こし）:
```
python3 "$TRANSCRIBE_CLI" \
  path/to/audio.wav \
  --out transcript.txt
```

既知の話者を使った話者の識別（最大 4 人）:
```
python3 "$TRANSCRIBE_CLI" \
  meeting.m4a \
  --model gpt-4o-transcribe-diarize \
  --known-speaker "Alice=refs/alice.wav" \
  --known-speaker "Bob=refs/bob.wav" \
  --response-format diarized_json \
  --out-dir output/transcribe/meeting
```

プレーンテキストでの出力（明示的な指定）:
```
python3 "$TRANSCRIBE_CLI" \
  interview.mp3 \
  --response-format text \
  --out interview.txt
```

## 参考資料
- `references/api.md`: 対応形式、制限、応答形式、既知の話者に関する注意事項。
