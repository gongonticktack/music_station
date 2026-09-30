# エラーパターン（簡易版）

ログのパターンから、考えられる原因と対処法をすばやく特定するために使います。

| ログのパターン | 考えられる原因 | 簡単な対処法 |
| --- | --- | --- |
| `KeyError`, `not defined`, `missing environment` | 環境変数が不足している | render.yaml または MCP で環境変数を追加し、再デプロイする |
| `EADDRINUSE`, `listen EADDRINUSE` | ポートのバインド競合 | `0.0.0.0:$PORT` にバインドする |
| `Cannot find module`, `ModuleNotFoundError` | 依存関係が不足している | マニフェストに依存関係を追加して再ビルドする |
| `ECONNREFUSED`, `connection refused` | DB に接続できない | DATABASE_URL と DB のステータスを確認する |
| `Health check timeout` | 正常な応答がない | ヘルスエンドポイントとポートを追加／確認する |
| `exit 137`, `out of memory` | メモリ不足（OOM） | メモリ使用量を減らすか、プランをアップグレードする |
| `Command failed`, `build failed` | ビルドコマンドに問題がある | ビルドコマンドまたは依存関係を修正する |
