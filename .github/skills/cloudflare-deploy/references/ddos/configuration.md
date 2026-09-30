# DDoS の設定

## ダッシュボードでの設定

1. Security > DDoS に移動します
2. HTTP DDoS または Network-layer DDoS を選択します
3. ルールセット、カテゴリ、ルールごとに感度とアクションを設定します
4. 必要に応じて式を指定してオーバーライドを適用します (Enterprise Advanced)
5. Adaptive DDoS の切り替えを有効にします (Enterprise/Enterprise Advanced、7 日間のトラフィック履歴が必要)

## ルールの構造

```typescript
interface DDoSOverride {
  description: string;
  rules: Array<{
    action: "execute";
    expression: string; // Custom expression (Enterprise Advanced) or "true" for all
    action_parameters: {
      id: string; // Managed ruleset ID (discover via api.md)
      overrides: {
        sensitivity_level?: "default" | "medium" | "low" | "eoff";
        action?: "block" | "managed_challenge" | "challenge" | "log"; // log = Enterprise Advanced only
        categories?: Array<{
          category: string; // e.g., "http-flood", "udp-flood"
          sensitivity_level?: string;
        }>;
        rules?: Array<{
          id: string;
          action?: string;
          sensitivity_level?: string;
        }>;
      };
    };
  }>;
}
```

## 式の利用可否

| プラン | カスタム式 | 例 |
|------|-------------------|---------|
| Free/Pro/Business | ✗ | `"true"` のみ使用可能 |
| Enterprise | ✗ | `"true"` のみ使用可能 |
| Enterprise Advanced | ✓ | `ip.src in {...}`, `http.request.uri.path matches "..."` |

## 感度の対応関係

| UI | API | しきい値 |
|----|-----|-----------|
| 高 | `default` | 最も積極的 |
| 中 | `medium` | バランス型 |
| 低 | `low` | 積極性を抑えた設定 |
| ほぼオフ | `eoff` | 緩和を最小限にする |

## よく使われるカテゴリ

- `http-flood`, `http-anomaly` (L7)
- `udp-flood`, `syn-flood`, `dns-flood` (L3/4)

## オーバーライドの優先順位

複数のオーバーライド層は次の順序で適用されます (上位ほど優先):

```
Zone-level > Account-level
Individual Rule > Category > Global sensitivity/action
```

**例**: `/api/*` に対するゾーンルールは、アカウントレベルのグローバル設定を上書きします。

## Adaptive DDoS プロファイル

**利用可能なプラン**: Enterprise、Enterprise Advanced  
**学習期間**: 7 日間のトラフィック履歴が必要です

| プロファイルの種類 | 説明 | 検出対象 |
|--------------|-------------|---------|
| **Origins** | オリジンサーバーごとのトラフィックパターン | 特定のオリジンへの異常なリクエスト |
| **User-Agents** | User-Agent ごとのトラフィックパターン | 悪意のある、または異常なユーザーエージェント文字列 |
| **Locations** | 地理的な場所ごとのトラフィックパターン | 特定の国や地域からの攻撃 |
| **Protocols** | プロトコルごとのトラフィックパターン (L3/4) | プロトコル固有のフラッド攻撃 |

API で特定の adaptive ルール ID を指定して設定します (api.md#typed-override-examples を参照)。

## アラート

Notifications から設定します:
- アラートの種類: `http_ddos_attack_alert`、`layer_3_4_ddos_attack_alert`、`advanced_*` バリアント
- フィルター: ゾーン、ホスト名、RPS/PPS/Mbps のしきい値、IP、プロトコル
- 通知手段: メール、webhook、PagerDuty

API の例は [api.md](./api.md#alert-configuration) を参照してください。
