# gpt-4o-transcribe-diarize クイックリファレンス

- 入力形式: mp3、mp4、mpeg、mpga、m4a、wav、webm。
- 最大ファイルサイズ: 1 リクエストあたり 25 MB。
- response_format の選択肢: text、json、diarized_json。
- 音声が約 30 秒を超える場合は、chunking_strategy を指定します（チャンクに分割するには "auto" を使用）。
- 既知の話者: extra_body の known_speaker_names と known_speaker_references（データ URL）を使用して、最大 4 件の参照を指定できます。
- gpt-4o-transcribe-diarize ではプロンプトを使用できません。
