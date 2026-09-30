# CLI リファレンス（`scripts/text_to_speech.py`）

このファイルには、同梱の音声生成CLIの「コマンド一覧」が記載されています。`SKILL.md` は概要を先に示す構成にし、詳しいCLIの情報はこちらに記載してください。

## このCLIでできること
- `speak`: 音声ファイルを1つ生成する
- `speak-batch`: JSONLファイルから複数のジョブを実行する（1行につき1ジョブ）
- `list-voices`: 対応する音声を一覧表示する

実際のAPI呼び出しには、ネットワークアクセスと `OPENAI_API_KEY` が必要です。`--dry-run` では不要です。

## クイックスタート（どのリポジトリからでも実行可能）
スキルCLIのパスを固定します（`CODEX_HOME` のデフォルトは `~/.codex`）。

```
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export TTS_GEN="$CODEX_HOME/skills/speech/scripts/text_to_speech.py"
```

ドライラン（API呼び出しなし、ネットワーク不要、`openai` パッケージ不要）:

```
python "$TTS_GEN" speak --input "Test" --dry-run
```

音声を生成（`OPENAI_API_KEY` とネットワークが必要）:

```
uv run --with openai python "$TTS_GEN" speak \
  --input "Today is a wonderful day to build something people love!" \
  --voice cedar \
  --instructions "Voice Affect: Warm and composed. Tone: upbeat and encouraging." \
  --response-format mp3 \
  --out speech.mp3
```

`uv` がインストールされていない場合は、現在のPython環境を使います。

```
python "$TTS_GEN" speak --input "Hello" --voice cedar --out speech.mp3
```

## ガードレール（重要）
- すべてのTTS作業には `python "$TTS_GEN" ...`（または同等のフルパス指定）を使ってください。
- ユーザーから明示的に依頼されない限り、単発の実行スクリプト（例: `gen_audio.py`）を作成しないでください。
- `scripts/text_to_speech.py` は**絶対に変更しないでください**。不足しているものがある場合は、ほかの作業を始める前にユーザーに尋ねてください。

## デフォルト設定（フラグで上書きされない限り）
- モデル: `gpt-4o-mini-tts-2025-12-15`
- 声: `cedar`
- 応答形式: `mp3`
- 速度: `1.0`
- バッチの1分あたりリクエスト数の上限: `50`

## 入力制限
- 1回のリクエストで指定する入力テキストは4096文字以下にしてください。
- それより長いテキストは、短いチャンクに分割してください（手動またはバッチJSONLを使用）。

## 指示の互換性
- `instructions` はGPT-4o mini TTSモデルで使用できます。
- `tts-1` と `tts-1-hd` は指示を無視します（CLIは警告を出して指示を削除します）。

## よく使うレシピ

音声を一覧表示:
```
python "$TTS_GEN" list-voices
```

ペースを明示して生成:
```
python "$TTS_GEN" speak \
  --input "Welcome to the demo. We'll show how it works." \
  --instructions "Tone: friendly and confident. Pacing: steady and moderate." \
  --out demo.mp3
```

バッチ生成（JSONL）:
```
mkdir -p tmp/speech
cat > tmp/speech/jobs.jsonl << 'JSONL'
{"input":"Thank you for calling. Please hold.","voice":"cedar","response_format":"mp3","out":"hold.mp3"}
{"input":"For sales, press 1. For support, press 2.","voice":"marin","instructions":"Tone: clear and neutral. Pacing: slow.","response_format":"wav"}
JSONL

python "$TTS_GEN" speak-batch --input tmp/speech/jobs.jsonl --out-dir out --rpm 50

# Cleanup (recommended)
rm -f tmp/speech/jobs.jsonl
```

注:
- `--rpm` でレート制限を調整できます（デフォルトは `50`、最大値も `50`）。
- JSONLではジョブごとに設定を上書きできます（`model`、`voice`、`response_format`、`speed`、`instructions`、`out`）。
- JSONLファイルは一時ファイルとして扱ってください。`tmp/` 以下に作成し、実行後に削除してください（コミットしないでください）。

## 関連項目
- APIパラメーターのクイックリファレンス: `references/audio-api.md`
- 指示のパターンと例: `references/voice-directions.md`
