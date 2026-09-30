# Cloudflare Containers スキルリファレンス

**対象: Cloudflare Containers のみ。一般的な Cloudflare Workers は対象外です**

Cloudflare Containers を使用する作業で参照します。Workers プラットフォームへのコンテナ化アプリのデプロイ、コンテナ対応 Durable Objects の設定、コンテナのライフサイクル管理、ステートフル／ステートレスなコンテナパターンの実装が対象です。

## ベータ版の状態

⚠️ Containers は現在 **ベータ版** です。API は予告なく変更される場合があります。SLA の保証はありません。カスタムインスタンスタイプは 2026 年 1 月に追加されました。

## 基本概念

**Durable Object としてのコンテナ:** 各コンテナは永続的な ID を持つ Durable Object です。`getByName(id)` または `getRandom()` でアクセスします。

**イメージのデプロイ:** イメージはあらかじめグローバルに取得されます。デプロイではローリング方式が使われます（Workers のように即時ではありません）。

**ライフサイクル:** コールドスタート（2～3 秒）→ 実行中 → `sleepAfter` のタイムアウト → 停止。自動スケーリングはありません。`getRandom()` を使って手動で負荷分散します。

**永続的な ID、一時的なディスク:** コンテナ ID は保持されますが、停止時にディスクはリセットされます。データの永続化には Durable Object ストレージを使用してください。

## クイックスタート

```typescript
import { Container } from "@cloudflare/containers";

export class MyContainer extends Container {
  defaultPort = 8080;
  sleepAfter = "30m";
}

export default {
  async fetch(request: Request, env: Env) {
    const container = env.MY_CONTAINER.getByName("instance-1");
    await container.startAndWaitForPorts();
    return container.fetch(request);
  }
};
```

## 読む順序

| 作業 | ファイル |
|------|-------|
| 新しいコンテナプロジェクトのセットアップ | README → configuration.md |
| コンテナロジックの実装 | README → api.md → patterns.md |
| ルーティングパターンの選択 | patterns.md（ルーティングのセクション） |
| 問題のデバッグ | gotchas.md |
| 本番環境向けの堅牢化 | gotchas.md → patterns.md（ライフサイクル） |

## ルーティングの判断ツリー

**リクエストをどのようにコンテナへ送るか？**

- **同じユーザー／セッションを同じコンテナへ:** セッションアフィニティには `getByName(sessionId)` を使用
- **ステートレスに負荷を分散:** 負荷分散には `getRandom()` を使用
- **コンテナごとにジョブを割り当てる:** `getByName(jobId)` と明示的なライフサイクル管理を使用
- **単一のグローバルインスタンス:** `getByName("singleton")` を使用

## Containers と Workers の使い分け

**Containers を使う場合:**
- ステートフルで長時間実行されるプロセス（セッション、WebSocket、ゲーム）が必要
- 既存のコンテナ化アプリ（Node.js、Python、カスタムバイナリ）を実行する
- ファイルシステムへのアクセスや特定のシステム依存関係が必要
- 専用のコンピューティングリソースでユーザー／セッションごとに分離する

**Workers を使う場合:**
- ステートレスな HTTP ハンドラー
- ミリ秒未満のコールドスタートが必要
- ゼロまでの自動スケーリングが重要
- シンプルなリクエスト／レスポンスのパターン

## このリファレンスの内容

- **[configuration.md](configuration.md)** - Wrangler の設定、インスタンスタイプ、Container クラスのプロパティ、環境変数、アカウント制限
- **[api.md](api.md)** - Container クラス API、起動メソッド、通信（HTTP/TCP/WebSocket）、ルーティングヘルパー、ライフサイクルフック、スケジューリング、状態の確認
- **[patterns.md](patterns.md)** - ルーティングパターン（セッションアフィニティ、負荷分散、シングルトン）、WebSocket の転送、正常終了、Workflow／Queue との統合
- **[gotchas.md](gotchas.md)** - 重要な注意点（WebSocket、起動メソッド）、解決策付きのよくあるエラー、個別の制限、ベータ版に関する注意事項

## 関連項目

- [Durable Objects](../durable-objects/) - Containers は Durable Objects を拡張します
- [Workflows](../workflows/) - コンテナ操作をオーケストレーションします
- [Queues](../queues/) - キューメッセージからコンテナを起動します
- [Cloudflare Docs](https://developers.cloudflare.com/containers/)
