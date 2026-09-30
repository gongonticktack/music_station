# RealtimeKit API リファレンス

Meeting オブジェクト、REST エンドポイント、SDK メソッドの完全な API リファレンス。

## Meeting オブジェクト API

### `meeting.self` - ローカル参加者

```typescript
// Properties: id, userId, name, audioEnabled, videoEnabled, screenShareEnabled, audioTrack, videoTrack, screenShareTracks, roomJoined, roomState
// Methods
await meeting.self.enableAudio() / disableAudio() / enableVideo() / disableVideo() / enableScreenShare() / disableScreenShare()
await meeting.self.setName("Name")  // Before join only
await meeting.self.setDevice(device)
const devices = await meeting.self.getAllDevices() / getAudioDevices() / getVideoDevices() / getSpeakerDevices()
// Events: 'roomJoined', 'audioUpdate', 'videoUpdate', 'screenShareUpdate', 'deviceUpdate', 'deviceListUpdate'
meeting.self.on('roomJoined', () => {})
meeting.self.on('audioUpdate', ({ audioEnabled, audioTrack }) => {})
```

### `meeting.participants` - リモート参加者

**コレクション**:
```typescript
meeting.participants.joined / active / waitlisted / pinned  // Maps
const participants = meeting.participants.joined.toArray()
const count = meeting.participants.joined.size()
const p = meeting.participants.joined.get('peer-id')
```

**参加者のプロパティ**:
```typescript
participant.id / userId / name
participant.audioEnabled / videoEnabled / screenShareEnabled
participant.audioTrack / videoTrack / screenShareTracks
```

**イベント**:
```typescript
meeting.participants.joined.on('participantJoined', (participant) => {})
meeting.participants.joined.on('participantLeft', (participant) => {})
```

### `meeting.meta` - メタデータ
```typescript
meeting.meta.meetingId / meetingTitle / meetingStartedTimestamp
```

### `meeting.chat` - チャット
```typescript
meeting.chat.messages  // Array
await meeting.chat.sendTextMessage("Hello") / sendImageMessage(file)
meeting.chat.on('chatUpdate', ({ message, messages }) => {})
```

### `meeting.polls` - 投票
```typescript
meeting.polls.items  // Array
await meeting.polls.create(question, options, anonymous, hideVotes)
await meeting.polls.vote(pollId, optionIndex)
```

### `meeting.plugins` - コラボレーションアプリ
```typescript
meeting.plugins.all  // Array
await meeting.plugins.activate(pluginId) / deactivate()
```

### `meeting.ai` - AI 機能
```typescript
meeting.ai.transcripts  // Live transcriptions (when enabled in Preset)
```

### 基本メソッド
```typescript
await meeting.join()   // Emits 'roomJoined' on meeting.self
await meeting.leave()
```

## TypeScript の型

```typescript
import type { RealtimeKitClient, States, UIConfig, Participant } from '@cloudflare/realtimekit';

// Main interface
interface RealtimeKitClient {
  self: SelfState;          // Local participant (id, userId, name, audioEnabled, videoEnabled, roomJoined, roomState)
  participants: { joined, active, waitlisted, pinned };  // Reactive Maps
  chat: ChatNamespace;      // messages[], sendTextMessage(), sendImageMessage()
  polls: PollsNamespace;    // items[], create(), vote()
  plugins: PluginsNamespace;  // all[], activate(), deactivate()
  ai: AINamespace;          // transcripts[]
  meta: MetaState;          // meetingId, meetingTitle, meetingStartedTimestamp
  join(): Promise<void>;
  leave(): Promise<void>;
}

// Participant (self & remote share same shape)
interface Participant {
  id: string;                      // Peer ID (changes on rejoin)
  userId: string;                  // Persistent participant ID
  name: string;
  audioEnabled: boolean;
  videoEnabled: boolean;
  screenShareEnabled: boolean;
  audioTrack: MediaStreamTrack | null;
  videoTrack: MediaStreamTrack | null;
  screenShareTracks: MediaStreamTrack[];
}
```

## ストアアーキテクチャ

RealtimeKit はリアクティブストア（イベント駆動の更新、ライブ Map）を使用します:

```typescript
// Subscribe to state changes
meeting.self.on('audioUpdate', ({ audioEnabled, audioTrack }) => {});
meeting.participants.joined.on('participantJoined', (p) => {});

// Access current state synchronously
const isAudioOn = meeting.self.audioEnabled;
const count = meeting.participants.joined.size();
```

**主な原則:** 状態の更新後にイベントが発生します。`.toArray()` は必要な場合に限って使用してください。コレクションはライブ Map です。

## REST API

ベース: `https://api.cloudflare.com/client/v4/accounts/{account_id}/realtime/kit/{app_id}`

### ミーティング
```bash
GET    /meetings                                    # List all
GET    /meetings/{meeting_id}                       # Get details
POST   /meetings                                    # Create: {"title": "..."}
PATCH  /meetings/{meeting_id}                       # Update: {"title": "...", "record_on_start": true}
```

### 参加者
```bash
GET    /meetings/{meeting_id}/participants                          # List all
GET    /meetings/{meeting_id}/participants/{participant_id}         # Get details
POST   /meetings/{meeting_id}/participants                          # Add: {"name": "...", "preset_name": "...", "custom_participant_id": "..."}
PATCH  /meetings/{meeting_id}/participants/{participant_id}         # Update: {"name": "...", "preset_name": "..."}
DELETE /meetings/{meeting_id}/participants/{participant_id}         # Delete
POST   /meetings/{meeting_id}/participants/{participant_id}/token   # Refresh token
```

### アクティブセッション
```bash
GET  /meetings/{meeting_id}/active-session               # Get active session
POST /meetings/{meeting_id}/active-session/kick          # Kick users: {"user_ids": ["id1", "id2"]}
POST /meetings/{meeting_id}/active-session/kick-all      # Kick all
POST /meetings/{meeting_id}/active-session/poll          # Create poll: {"question": "...", "options": [...], "anonymous": false}
```

### 録画
```bash
GET  /recordings?meeting_id={meeting_id}                 # List recordings
GET  /recordings/active-recording/{meeting_id}           # Get active recording
POST /recordings                                         # Start: {"meeting_id": "...", "type": "composite"} (or "track")
PUT  /recordings/{recording_id}                          # Control: {"action": "pause"} (or "resume", "stop")
POST /recordings/track                                   # Track recording: {"meeting_id": "...", "layers": [...]}
```

### ライブ配信
```bash
GET  /livestreams?exclude_meetings=false                                # List all
GET  /livestreams/{livestream_id}                                       # Get details
POST /meetings/{meeting_id}/livestreams                                 # Start for meeting
POST /meetings/{meeting_id}/active-livestream/stop                      # Stop
POST /livestreams                                                       # Create independent: returns {ingest_server, stream_key, playback_url}
```

### セッションと分析
```bash
GET  /sessions                                                          # List all
GET  /sessions/{session_id}                                             # Get details
GET  /sessions/{session_id}/participants                                # List participants
GET  /sessions/{session_id}/participants/{participant_id}               # Call stats
GET  /sessions/{session_id}/chat                                        # Download chat CSV
GET  /sessions/{session_id}/transcript                                  # Download transcript CSV
GET  /sessions/{session_id}/summary                                     # Get summary
POST /sessions/{session_id}/summary                                     # Generate summary
GET  /analytics/daywise?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD      # Day-wise analytics
GET  /analytics/livestreams/overall                                     # Livestream analytics
```

### Webhook
```bash
GET    /webhooks                    # List all
POST   /webhooks                    # Create: {"url": "https://...", "events": ["session.started", "session.ended"]}
PATCH  /webhooks/{webhook_id}       # Update
DELETE /webhooks/{webhook_id}       # Delete
```

## セッションのライフサイクル

```
Initialization → Join Intent → [Waitlist?] → Meeting Screen (Stage) → Ended
                                   ↓ Approved
                               [Rejected → Ended]
```

UI Kit が状態遷移を自動的に処理します。

## 関連項目

- [設定](./configuration.md) - セットアップとインストール
- [パターン](./patterns.md) - 使用例
- [README](./README.md) - 概要とクイックスタート
