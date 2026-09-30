# Cloudflare Agents SDK

Cloudflare Agents SDK を使うと、状態管理、WebSocket、SQL、スケジューリング、AI 連携を備えた AI エージェントを Durable Objects 上に構築できます。

## 主な利点
永続的なメモリ、リアルタイム接続、スケジュールされたタスク、非同期ワークフローを備えた、状態を持つグローバル分散型 AI エージェントを構築できます。

## 使用する場面
- 永続的な状態とメモリが必要な場合
- リアルタイムの WebSocket 接続が必要な場合
- 長時間実行するワークフロー（数分から数時間）がある場合
- AI モデルを使ったチャットインターフェースを構築する場合
- 状態を保持する定期タスクを実行する場合
- エージェントの状態を使って DB にクエリを実行する場合

## どの種類のエージェントを使うか

| ユースケース | クラス | 主な機能 |
|----------|-------|--------------|
| AI チャットインターフェース | `AIChatAgent` | 自動ストリーミング、ツール、メッセージ履歴、処理の再開 |
| MCP ツールの提供 | `Agent` + MCP | AI システムにツールを公開 |
| 独自のロジックやルーティング | `Agent` | 完全な制御、WebSocket、メール、SQL |
| リアルタイム共同作業 | `Agent` | WebSocket の状態、ブロードキャスト |
| メール処理 | `Agent` | `onEmail()` ハンドラー |

## クイックスタート

**AI チャットエージェント:**
```typescript
import { AIChatAgent } from "agents";
import { openai } from "@ai-sdk/openai";

export class ChatAgent extends AIChatAgent<Env> {
  async onChatMessage(onFinish) {
    return this.streamText({
      model: openai("gpt-4"),
      messages: this.messages,
      onFinish,
    });
  }
}
```

**基本エージェント:**
```typescript
import { Agent } from "agents";

export class MyAgent extends Agent<Env> {
  onStart() {
    this.sql`CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY)`;
  }
  
  async onRequest(request: Request) {
    return Response.json({ state: this.state });
  }
}
```

## 読む順序

| 作業 | 読むファイル |
|------|---------------|
| すぐに使い始める | README のみ |
| チャットエージェントを構築する | README → api.md (AIChatAgent) → patterns.md |
| プロジェクトをセットアップする | README → configuration.md |
| React フロントエンドを追加する | README → api.md (Client Hooks) → patterns.md |
| MCP サーバーを構築する | api.md (MCP) → patterns.md |
| バックグラウンドタスクを実装する | api.md (Scheduling, Task Queue) → patterns.md |
| 問題をデバッグする | gotchas.md |

## パッケージのエントリーポイント

| インポート | 用途 |
|--------|---------|
| `agents` | サーバー側の Agent クラスとライフサイクル |
| `agents/react` | WebSocket 接続用の `useAgent()` フック |
| `agents/ai-react` | AI チャット UI 用の `useAgentChat()` フック |

## このリファレンスの内容
- [configuration.md](./configuration.md) - SDK のセットアップ、wrangler の設定、ルーティング
- [api.md](./api.md) - Agent クラス、ライフサイクル、クライアントフック
- [patterns.md](./patterns.md) - 一般的なワークフローとベストプラクティス
- [gotchas.md](./gotchas.md) - よくある問題と制限

## 関連項目
- durable-objects - エージェントのインフラストラクチャ
- d1 - 外部データベースとの連携
- workers-ai - AI モデルとの連携
- vectorize - RAG パターン向けのベクトル検索