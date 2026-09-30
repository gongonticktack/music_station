# API リファレンス

## Agent クラス

### AIChatAgent

自動ストリーミング、メッセージ履歴、ツール、再開可能なストリーミングに対応した AI チャット用です。

```ts
import { AIChatAgent } from "agents";
import { openai } from "@ai-sdk/openai";

export class ChatAgent extends AIChatAgent<Env> {
  async onChatMessage(onFinish) {
    return this.streamText({
      model: openai("gpt-4"),
      messages: this.messages, // Auto-managed message history
      tools: {
        getWeather: {
          description: "Get weather",
          parameters: z.object({ city: z.string() }),
          execute: async ({ city }) => `Sunny, 72°F in ${city}`
        }
      },
      onFinish, // Persist response to this.messages
    });
  }
}
```

### Agent（基底クラス）

独自のロジック、WebSocket、メール、SQL を全面的に制御できます。

```ts
import { Agent } from "agents";

export class MyAgent extends Agent<Env, State> {
  // Lifecycle methods below
}
```

**型パラメーター:** `Agent<Env, State, ConnState>` — Env バインディング、エージェントの状態、接続の状態

## ライフサイクルフック

```ts
onStart() { // Init/restart
  this.sql`CREATE TABLE IF NOT EXISTS users (id TEXT, name TEXT)`;
}

async onRequest(req: Request) { // HTTP
  const {pathname} = new URL(req.url);
  if (pathname === "/users") return Response.json(this.sql<{id,name}>`SELECT * FROM users`);
  return new Response("Not found", {status: 404});
}

async onConnect(conn: Connection<ConnState>, ctx: ConnectionContext) { // WebSocket
  conn.accept();
  conn.setState({userId: ctx.request.headers.get("X-User-ID")});
  conn.send(JSON.stringify({type: "connected", state: this.state}));
}

async onMessage(conn: Connection<ConnState>, msg: WSMessage) { // WS messages
  const m = JSON.parse(msg as string);
  this.setState({messages: [...this.state.messages, m]});
  this.connections.forEach(c => c.send(JSON.stringify(m)));
}

async onEmail(email: AgentEmail) { // Email routing
  this.sql`INSERT INTO emails (from_addr,subject,body) VALUES (${email.from},${email.headers.get("subject")},${await email.text()})`;
}
```

## 状態、SQL、スケジューリング

```ts
// State
this.setState({count: 42}); // Auto-syncs
this.setState({...this.state, count: this.state.count + 1});

// SQL (parameterized queries prevent injection)
this.sql`CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, name TEXT)`;
this.sql`INSERT INTO users (id,name) VALUES (${userId},${name})`;
const users = this.sql<{id,name}>`SELECT * FROM users WHERE id = ${userId}`;

// Scheduling
await this.schedule(new Date("2026-12-25"), "sendGreeting", {msg:"Hi"}); // Date
await this.schedule(60, "checkStatus", {}); // Delay (sec)
await this.schedule("0 0 * * *", "dailyCleanup", {}); // Cron
await this.cancelSchedule(scheduleId);
```

## RPC メソッド（@callable）

```ts
import { Agent, callable } from "agents";

export class MyAgent extends Agent<Env> {
  @callable()
  async processTask(input: {text: string}): Promise<{result: string}> {
    return { result: await this.env.AI.run("@cf/meta/llama-3.1-8b-instruct", {prompt: input.text}) };
  }
}
// Client: const result = await agent.processTask({ text: "Hello" });
// Must return JSON-serializable values
```

## 接続と AI

```ts
// Connections (type: Agent<Env, State, ConnState>)
this.connections.forEach(c => c.send(JSON.stringify(msg))); // Broadcast
conn.setState({userId:"123"}); conn.close(1000, "Goodbye");

// Workers AI
const r = await this.env.AI.run("@cf/meta/llama-3.1-8b-instruct", {prompt});

// Manual streaming (prefer AIChatAgent)
const stream = await client.chat.completions.create({model: "gpt-4", messages, stream: true});
for await (const chunk of stream) conn.send(JSON.stringify({chunk: chunk.choices[0].delta.content}));
```

**型安全な状態:** `Agent<Env, State, ConnState>` — 3 番目のパラメーターは `conn.state` の型を指定します。

## MCP 連携

ツールを公開するための Model Context Protocol:

```ts
// Register & use MCP server
await this.mcp.registerServer("github", {
  url: env.MCP_SERVER_URL,
  auth: { type: "oauth", clientId: env.GITHUB_CLIENT_ID, clientSecret: env.GITHUB_CLIENT_SECRET }
});
const tools = await this.mcp.getAITools(["github"]);
return this.streamText({ model: openai("gpt-4"), messages: this.messages, tools, onFinish });
```

## タスクキュー

```ts
await this.queue("processVideo", { videoId: "abc123" }); // Add task
const tasks = await this.dequeue(10); // Process up to 10
```

## コンテキストとクリーンアップ

```ts
const agent = getCurrentAgent<MyAgent>(); // Get current instance
async destroy() { /* cleanup before agent destroyed */ }
```

## AI 連携

```ts
// Workers AI
const r = await this.env.AI.run("@cf/meta/llama-3.1-8b-instruct", {prompt});

// Manual streaming (prefer AIChatAgent for auto-streaming)
const stream = await client.chat.completions.create({model: "gpt-4", messages, stream: true});
for await (const chunk of stream) {
  if (chunk.choices[0]?.delta?.content) conn.send(JSON.stringify({chunk: chunk.choices[0].delta.content}));
}
```

## クライアントフック（React）

```ts
// useAgent() - WebSocket connection + RPC
import { useAgent } from "agents/react";
const agent = useAgent({ agent: "MyAgent", name: "user-123" }); // name for idFromName
const result = await agent.processTask({ text: "Hello" }); // Call @callable methods
// agent.readyState: 0=CONNECTING, 1=OPEN, 2=CLOSING, 3=CLOSED

// useAgentChat() - AI chat UI
import { useAgentChat } from "agents/ai-react";
const agent = useAgent({ agent: "ChatAgent" });
const { messages, input, handleInputChange, handleSubmit, isLoading, stop, clearHistory } = 
  useAgentChat({ 
    agent, 
    maxSteps: 5,        // Max tool iterations
    resume: true,       // Auto-resume on disconnect
    onToolCall: async (toolCall) => {
      // Client tools (human-in-the-loop)
      if (toolCall.toolName === "confirm") return { ok: window.confirm("Proceed?") };
    }
  });
// status: "ready" | "submitted" | "streaming" | "error"
```
