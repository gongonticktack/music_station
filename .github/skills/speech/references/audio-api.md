# Audio Speech API クイックリファレンス

## エンドポイント
- 音声を生成: `POST /v1/audio/speech`

## デフォルトモデル
- `gpt-4o-mini-tts-2025-12-15`

## その他の音声モデル（指定された場合）
- `gpt-4o-mini-tts`
- `tts-1`
- `tts-1-hd`

## 主なパラメーター
- `model`: 音声モデル
- `input`: 合成するテキスト（最大4096文字）
- `voice`: 組み込み音声の名前
- `instructions`: 任意のスタイル指示（`tts-1` または `tts-1-hd` では未対応）
- `response_format`: `mp3`、`opus`、`aac`、`flac`、`wav`、または `pcm`
- `speed`: 0.25～4.0

## 組み込み音声
- `alloy`、`ash`、`ballad`、`cedar`、`coral`、`echo`、`fable`、`marin`、`nova`、`onyx`、`sage`、`shimmer`、`verse`

## 出力に関する注意
- デフォルトの形式は `mp3` です。
- `pcm` はヘッダーのない、生の24 kHz・16ビット・リトルエンディアンのサンプルです。
- `wav` にはヘッダーが含まれます（すぐに再生する場合に適しています）。

## コンプライアンスに関する注意
- 音声がAIによって生成されたことを明確に開示してください。
