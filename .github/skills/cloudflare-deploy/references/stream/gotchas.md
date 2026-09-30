# Stream の注意点

## よくあるエラー

### "ERR_NON_VIDEO"

**原因:** アップロードしたファイルが有効な動画形式ではありません
**解決策:** ファイルがサポート対象の形式（MP4、MKV、MOV、AVI、FLV、MPEG-2 TS/PS、MXF、LXF、GXF、3GP、WebM、MPG、QuickTime）であることを確認してください

### "ERR_DURATION_EXCEED_CONSTRAINT"

**原因:** 動画の長さが `maxDurationSeconds` の制約を超えています
**解決策:** ダイレクトアップロード設定の `maxDurationSeconds` を増やすか、アップロード前に動画をトリミングしてください

### "ERR_FETCH_ORIGIN_ERROR"

**原因:** URL から動画をダウンロードできませんでした（URL からアップロード）
**解決策:** URL にインターネット経由でアクセスでき、HTTPS を使用しており、動画ファイルが利用可能であることを確認してください

### "ERR_MALFORMED_VIDEO"

**原因:** 動画ファイルが破損しているか、正しくエンコードされていません
**解決策:** FFmpeg で動画を再エンコードするか、ソースファイルの整合性を確認してください

### "ERR_DURATION_TOO_SHORT"

**原因:** 動画の長さは 0.1 秒以上である必要があります
**解決策:** 動画に有効な長さがある（1 フレームだけではない）ことを確認してください

## トラブルシューティング

### 動画が「inprogress」状態のままになる
- **原因**: 大きい、または複雑な動画を処理中
- **解決策**: 処理に最大 5 分かかる場合があります。ポーリングの代わりに Webhook を使用してください

### 署名付き URL が 403 を返す
- **原因**: トークンの有効期限切れ、または署名が無効
- **解決策**: 有効期限のタイムスタンプを確認し、JWK が正しいことと、クロックが同期していることを確認してください

### ライブストリームに接続できない
- **原因**: RTMPS URL またはストリームキーが無効
- **解決策**: API から取得した正確な URL／キーを使用し、ファイアウォールで送信 443 番ポートが許可されていることを確認してください

### Webhook 署名の検証に失敗する
- **原因**: シークレットが正しくないか、タイムスタンプの許容範囲外
- **解決策**: Webhook 設定時に取得した正確なシークレットを使用し、タイムスタンプの 5 分のずれを許容してください

### 動画はアップロードされるが表示されない
- **原因**: トークンを指定せずに `requireSignedURLs` が有効になっている
- **解決策**: 署名付きトークンを生成するか、公開動画の場合は `requireSignedURLs: false` を設定してください

### プレーヤーの読み込みが終わらない
- **原因**: allowedOrigins に関する CORS の問題
- **解決策**: ドメインを `allowedOrigins` 配列に追加してください

## 制限

| リソース | 制限 |
|----------|-------|
| 最大ファイルサイズ | 30 GB |
| 最大フレームレート | 60 fps（推奨）|
| ダイレクトアップロードあたりの最大長さ | `maxDurationSeconds` で設定可能 |
| トークン生成（API エンドポイント） | 1,000 回／日を推奨（それ以上の場合は署名キーを使用）|
| ライブ入力の出力（同時配信） | ライブ入力ごとに 5 件 |
| Webhook の再試行回数 | 5 回（指数バックオフ）|
| Webhook のタイムアウト | 30 秒 |
| 字幕ファイルのサイズ | 5 MB |
| ウォーターマーク画像のサイズ | 2 MB |
| 動画ごとのメタデータキー | 無制限 |
| 1 ページあたりの検索結果 | 最大 1,000 件 |

## パフォーマンスの問題

### アップロードが遅い
- **原因**: ファイルサイズが大きい、またはネットワークに制約がある
- **解決策**: TUS の再開可能なアップロードを使用し、アップロード前に動画を圧縮して、帯域幅を確認してください

### 再生がバッファリングする
- **原因**: ネットワークの混雑、または帯域幅不足
- **解決策**: HLS/DASH で ABR（アダプティブビットレート）を使用し、最大ビットレートを下げてください

### 処理時間が長い
- **原因**: 動画コーデックが複雑、または解像度が高い
- **解決策**: H.264（最も効率的）で事前にエンコードし、解像度を下げてください

## 型安全性

```typescript
// Error response type
interface StreamError {
  success: false;
  errors: Array<{
    code: number;
    message: string;
  }>;
}

// Handle errors
async function uploadWithErrorHandling(url: string, file: File) {
  const formData = new FormData();
  formData.append('file', file);
  const response = await fetch(url, { method: 'POST', body: formData });
  const result = await response.json();
  
  if (!result.success) {
    throw new Error(result.errors[0]?.message || 'Upload failed');
  }
  return result;
}
```

## セキュリティ上の注意点

1. **API トークンをフロントエンドで絶対に公開しない** - クリエイター向けのダイレクトアップロードを使用する
2. **Webhook 署名を必ず検証する** - 偽装された通知を防ぐ
3. **適切なトークン有効期限を設定する** - セキュリティのため短期間にする
4. **非公開コンテンツには requireSignedURLs を使用する** - 不正アクセスを防ぐ
5. **allowedOrigins をホワイトリストに登録する** - 許可されていないサイトでの直リンクや埋め込みを防ぐ

## このリファレンスの内容

- [README.md](./README.md) - 概要とクイックスタート
- [configuration.md](./configuration.md) - セットアップと設定
- [api.md](./api.md) - オンデマンド動画 API
- [api-live.md](./api-live.md) - ライブストリーミング API
- [patterns.md](./patterns.md) - フルスタックのフロー、ベストプラクティス

## 関連項目

- [workers](../workers/) - Stream API を安全にデプロイ