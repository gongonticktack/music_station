# Music Station / Seed-VC

## 概要

参照音声を使って、音声・歌声の声質を変換するWindows向けローカルWebアプリです。[Seed-VC公式実装](https://github.com/Plachtaa/seed-vc)を基に、環境構築とブラウザ操作をまとめています。

## 主な機能

- 変換元音声と参照音声のアップロード。
- Seed-VC V1による歌声変換。
- 生成ステップ数・変換調整・音程調整の設定。
- 全区間の進捗表示、生成WAVの試聴・保存。

歌声変換と参照音声への自動音程合わせは常時有効、長さは1.0倍に固定です。変換調整の初期値は0.9です。Seed-VC V1は元音声の旋律や歌い回しを大きく作り替えるモデルではありません。

## 推奨要件

| 項目 | 環境 |
| --- | --- |
| OS | Windows 64-bit |
| GPU | NVIDIA GPUとCUDA対応ドライバー |
| Python | 起動スクリプトがローカルのPython 3.10.11を準備 |
| ブラウザ | 現行のChromeまたはEdge |
| 通信・容量 | 初回モデル取得用のインターネット接続、数GB以上の空き容量 |

既存の動作確認環境はRTX 5070 Tiです。必要VRAMは入力・設定に依存し、本リポジトリでは最低値を定義していません。

## 必要なライブラリ

| 分類 | 主な依存関係 |
| --- | --- |
| GPU推論 | PyTorch、torchvision、torchaudio（CUDA 12.8系の配布元から導入） |
| Web画面 | Gradio 5.23.0 |
| 音声処理 | librosa、SciPy、soundfile、pydub、FFmpeg |
| モデル | transformers、huggingface-hub、accelerate、einops |
| その他 | NumPy、hydra-core、PyYAMLなど |

Web用一覧は`requirements-web.txt`、公式側の依存関係は`seed-vc/requirements.txt`を参照してください。PyTorchは起動スクリプトが別途導入します。

## 使い方

1. リポジトリをダウンロードまたはcloneします。
2. ルートの`start.bat`をダブルクリックします。
3. 初回はPython、CUDA対応PyTorch、Web用依存関係、FFmpeg、Hugging Faceのモデル重みを準備します。
4. ブラウザで `http://127.0.0.1:7860/` を開きます。
5. 「変換元の音声」に変換したいファイル、「参照音声」に変換先の声のサンプルを指定します。
6. 必要に応じて設定を調整し、「変換する」を押します。
7. 完成したWAVを試聴し、保存します。

停止は起動コンソールで`Ctrl+C`、または`Stop Seed-VC.cmd`です。既存のSeed-VCが起動中なら、再起動時にそのプロセスを停止します。別アプリが7860番を使用中の場合は起動できません。

## フォルダ構成

| 相対パス | 役割 |
| --- | --- |
| `seed-vc/` | Seed-VC本体、モデル処理、Web画面 |
| `seed-vc/app.py` | Music StationのGradio画面 |
| `seed-vc/seed_vc_wrapper.py` | 音声変換のラッパー |
| `seed-vc/checkpoints/` | モデルが取得するチェックポイント |
| `scripts/smoke_test.py` | 動作確認用スクリプト |
| `requirements-web.txt` | Web用依存関係 |
| `start-seed-vc.ps1` | 環境準備と起動 |
| `start.bat`、`Start Seed-VC.cmd` | Windows起動入口 |
| `Stop Seed-VC.cmd` | 停止 |
| `.tools/`、`.venv/` | ローカルランタイム・キャッシュ・Python環境 |
| `.logs/` | 起動・推論ログ |
| `.github/` | 開発ルールとスキル |

## 仕組みと保存先

参照音声から声の特徴を読み取り、元音声の内容や旋律を保ちながら声質を変換します。音声はローカルのGradio一時ファイルで処理し、完成したWAVをブラウザから保存します。モデル取得には外部通信を使用しますが、待受先は`127.0.0.1:7860`です。

## トラブル対処

- 起動・依存導入失敗：`.logs/seed-vc.log`を確認し、通信を復旧して再起動します。
- CUDAが利用できない：NVIDIAドライバーとGPUを確認します。起動時にCUDAの利用可否を検証します。
- モデル取得失敗：再起動して取得を再試行します。モデルキャッシュを手動削除した場合は`.tools/models-ready.stamp`も削除します。
- ポート使用中：7860番を使用するアプリを確認します。

## 利用条件

Seed-VC本体のライセンスは`seed-vc/LICENSE`を参照してください。声・音源・モデル重みの利用条件はそれぞれ確認してください。
