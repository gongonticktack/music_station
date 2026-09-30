# Cloudflare DDoS 防御

L3/4 と L7 にわたる DDoS 攻撃に対し、自律的かつ常時稼働の防御を提供します。

## 防御の種類

- **HTTP DDoS (L7)**：HTTP/HTTPS トラフィックを保護。フェーズ `ddos_l7`、ゾーン／アカウント単位
- **Network DDoS (L3/4)**：UDP/SYN/DNS フラッド。フェーズ `ddos_l4`、アカウント単位のみ
- **Adaptive DDoS**：7 日間のベースラインを学習して逸脱を検知。4 種類のプロファイル（Origins、User-Agents、Locations、Protocols）

## プラン別の利用可否

| 機能 | Free | Pro | Business | Enterprise | Enterprise Advanced |
|---------|------|-----|----------|------------|---------------------|
| HTTP DDoS (L7) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Network DDoS (L3/4) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Override rules | 1 | 1 | 1 | 1 | 10 |
| Custom expressions | ✗ | ✗ | ✗ | ✗ | ✓ |
| Log action | ✗ | ✗ | ✗ | ✗ | ✓ |
| Adaptive DDoS | ✗ | ✗ | ✗ | ✓ | ✓ |
| Alert filters | Basic | Basic | Basic | Advanced | Advanced |

## アクションと感度

- **アクション**：`block`、`managed_challenge`、`challenge`、`log`（Enterprise Advanced のみ）
- **感度**：`default`（高）、`medium`、`low`、`eoff`（実質オフ）
- **オーバーライド**：カテゴリ／タグ単位、または個別のルール ID 単位
- **適用範囲**：ゾーンレベルのオーバーライドはアカウントレベルより優先されます

## 読む順序

| ファイル | 目的 | 次の場合に読む |
|------|---------|------------------|
| [configuration.md](./configuration.md) | ダッシュボードでの設定、ルール構造、適応型プロファイル | 初めて DDoS 防御を設定する場合 |
| [api.md](./api.md) | API エンドポイント、SDK の使用方法、ルールセット ID の特定 | 設定を自動化する場合、またはプログラムからアクセスする必要がある場合 |
| [patterns.md](./patterns.md) | 防御戦略、多層防御、動的な対応 | 実装パターンや多層セキュリティが必要な場合 |
| [gotchas.md](./gotchas.md) | 誤検知、調整、エラー処理 | 既存の防御をトラブルシューティングまたは最適化する場合 |

## 関連項目
- [waf](../waf/) - アプリケーション層のセキュリティルール
- [bot-management](../bot-management/) - ボットの検知と軽減
