# RealtimeKit の設定

RealtimeKit のセットアップ、クライアント SDK、wrangler との連携に関する設定ガイドです。

## インストール

### React
```bash
npm install @cloudflare/realtimekit @cloudflare/realtimekit-react-ui
```

### Angular
```bash
npm install @cloudflare/realtimekit @cloudflare/realtimekit-angular-ui
```

### Web Components/HTML
```bash
npm install @cloudflare/realtimekit @cloudflare/realtimekit-ui
```

## クライアント SDK の設定

### React UI Kit
```tsx
import { RtkMeeting } from '@cloudflare/realtimekit-react-ui';
<RtkMeeting authToken="<token>" onLeave={() => {}} />
```

### Angular UI Kit
```typescript
@Component({ template: `<rtk-meeting [authToken]="authToken" (rtkLeave)="onLeave($event)"></rtk-meeting>` })
export class AppComponent { authToken = '<token>'; onLeave() {} }
```

### Web Components
```html
<script type="module" src="https://cdn.jsdelivr.net/npm/@cloudflare/realtimekit-ui/dist/realtimekit-ui/realtimekit-ui.esm.js"></script>
<rtk-meeting id="meeting"></rtk-meeting>
<script>
  document.getElementById('meeting').authToken = '<token>';
</script>
```

### Core SDK の設定
```typescript
import RealtimeKitClient from '@cloudflare/realtimekit';

const meeting = new RealtimeKitClient({
  authToken: '<token>',
  video: true, audio: true, autoSwitchAudioDevice: true,
  mediaConfiguration: {
    video: { width: { ideal: 1280 }, height: { ideal: 720 }, frameRate: { ideal: 30 } },
    audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
    screenshare: { width: { max: 1920 }, height: { max: 1080 }, frameRate: { ideal: 15 } }
  }
});
await meeting.join();
```

## バックエンドのセットアップ

### アプリと認証情報の作成

**ダッシュボード**: https://dash.cloudflare.com/?to=/:account/realtime/kit

**API**:
```bash
curl -X POST 'https://api.cloudflare.com/client/v4/accounts/<account_id>/realtime/kit/apps' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer <api_token>' \
  -d '{"name": "My RealtimeKit App"}'
```

**必須の権限**: **Realtime / Realtime Admin** 権限を持つ API トークン

### プリセットの作成

```bash
curl -X POST 'https://api.cloudflare.com/client/v4/accounts/<account_id>/realtime/kit/<app_id>/presets' \
  -H 'Authorization: Bearer <api_token>' \
  -d '{
    "name": "host",
    "permissions": {
      "canShareAudio": true,
      "canShareVideo": true,
      "canRecord": true,
      "canLivestream": true,
      "canStartStopRecording": true
    }
  }'
```

## Wrangler の設定

### 基本設定
```jsonc
// wrangler.jsonc
{
  "name": "realtimekit-app",
  "main": "src/index.ts",
  "compatibility_date": "2025-01-01",  // Use current date
  "vars": {
    "CLOUDFLARE_ACCOUNT_ID": "abc123",
    "REALTIMEKIT_APP_ID": "xyz789"
  }
  // Secrets: wrangler secret put CLOUDFLARE_API_TOKEN
}
```

### データベースとストレージを使用する場合
```jsonc
{
  "d1_databases": [{ "binding": "DB", "database_name": "meetings", "database_id": "d1-id" }],
  "r2_buckets": [{ "binding": "RECORDINGS", "bucket_name": "recordings" }],
  "kv_namespaces": [{ "binding": "SESSIONS", "id": "kv-id" }]
}
```

### 複数環境
```bash
# Deploy to environments
wrangler deploy --env staging
wrangler deploy --env production
```

## TURN サービスの設定

RealtimeKit では、制限の厳しいネットワーク経由で接続するために Cloudflare の TURN サービスを利用できます。

```jsonc
// wrangler.jsonc
{
  "vars": {
    "TURN_SERVICE_ID": "your_turn_service_id"
  }
  // Set secret: wrangler secret put TURN_SERVICE_TOKEN
}
```

アカウントで有効にすると TURN は自動的に設定されるため、クライアント側の変更は不要です。

## テーマとデザイントークン

```typescript
import type { UIConfig } from '@cloudflare/realtimekit';

const uiConfig: UIConfig = {
  designTokens: {
    colors: {
      brand: { 500: '#0066ff', 600: '#0052cc' },
      background: { 1000: '#1A1A1A', 900: '#2D2D2D' },
      text: { 1000: '#FFFFFF', 900: '#E0E0E0' }
    },
    borderRadius: 'extra-rounded',  // 'rounded' | 'extra-rounded' | 'sharp'
    theme: 'dark'  // 'light' | 'dark'
  },
  logo: { url: 'https://example.com/logo.png', altText: 'Company' }
};

// Apply to React
<RtkMeeting authToken={token} config={uiConfig} onLeave={() => {}} />

// Or use CSS variables
// :root { --rtk-color-brand-500: #0066ff; --rtk-border-radius: 12px; }
```

## 国際化（i18n）

### 言語文字列のカスタマイズ
```typescript
import { useLanguage } from '@cloudflare/realtimekit-ui';

const customLanguage = {
  'join': 'Entrar',
  'leave': 'Salir',
  'mute': 'Silenciar',
  'unmute': 'Activar audio',
  'turn_on_camera': 'Encender cámara',
  'turn_off_camera': 'Apagar cámara',
  'share_screen': 'Compartir pantalla',
  'stop_sharing': 'Dejar de compartir'
};

const t = useLanguage(customLanguage);

// React usage
<RtkMeeting authToken={token} t={t} onLeave={() => {}} />
```

### 対応ロケール
デフォルトで利用できるロケール: `en`, `es`, `fr`, `de`, `pt`, `ja`, `zh`

```typescript
import { setLocale } from '@cloudflare/realtimekit-ui';
setLocale('es');  // Switch to Spanish
```

## 関連項目

- [API](./api.md) - ミーティング API、REST エンドポイント
- [Patterns](./patterns.md) - バックエンド連携の例
- [README](./README.md) - 概要とクイックスタート