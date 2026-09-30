# Cloudflare Argo Smart Routing スキルリファレンス

## 概要

Cloudflare Argo Smart Routing は、リアルタイムのネットワーク障害を検出し、最も効率的なネットワーク経路を通じてウェブトラフィックをルーティングするパフォーマンス最適化サービスです。ネットワークの状況を継続的に監視し、Cloudflare のネットワーク内で最速かつ最も信頼性の高い経路を通じてトラフィックをインテリジェントにルーティングします。

**Smart Shield に関する注意:** Argo Smart Routing は、DDoS 保護とパフォーマンスを強化するため、Cloudflare の Smart Shield 製品に統合されています。既存の Argo のお客様は、Smart Shield の機能へ段階的に移行する間も、すべての機能を引き続き利用できます。

## クイックスタート

### cURL で有効化
```bash
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/{zone_id}/argo/smart_routing" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"value": "on"}'
```

### TypeScript SDK で有効化
```typescript
import Cloudflare from 'cloudflare';

const client = new Cloudflare({ apiToken: process.env.CLOUDFLARE_API_TOKEN });

const result = await client.argo.smartRouting.edit({
  zone_id: 'your-zone-id',
  value: 'on',
});

console.log(`Argo enabled: ${result.value}`);
```

## 基本概念

### 機能
- **インテリジェントなルーティング**: 混雑、停止、パケット損失をリアルタイムで検出
- **グローバルな最適化**: 300か所以上の Cloudflare データセンターを経由してルーティング
- **自動フェイルオーバー**: 問題を検出すると経路を切り替える（通常1秒未満）
- **既存の構成で動作**: オリジンの変更は不要

### 請求モデル
- 従量課金制: トラフィック1GBごとに課金（DDoS／WAF によって軽減されたトラフィックは除く）
- 有効化する前に請求設定が必要
- Enterprise 以上のプランで利用可能（ゾーンの利用資格を確認してください）

### 使用に適したケース
- 世界各地にユーザーがいる**本番環境の高トラフィックサイト**
- **レイテンシに敏感なアプリケーション**（API、リアルタイムサービス）
- **Cloudflare プロキシの背後にあるサイト**（オレンジ色の雲が設定された DNS レコード）
- パフォーマンス向上を最大化するため、**Tiered Cache と併用**する場合

### 使用に適さないケース
- 開発／ステージング環境（費用を抑えるため）
- トラフィックの少ないサイト（月間1TB未満）で、費用が効果を上回る可能性がある場合
- トラフィックの大半が単一リージョンからのサイト

## Argo を有効にすべきか

| 状況 | 推奨事項 |
|----------------|----------------|
| 世界各地で使われる本番アプリ、月間トラフィック1TB超 | ✅ 有効化 — 投資対効果がプラスになる可能性が高い |
| Enterprise プランで、レイテンシが重要な API | ✅ 有効化 — パフォーマンスが重要 |
| リージョン限定のサイト、月間トラフィック100GB未満 | ⚠️ 要検討 — 費用に見合わない可能性あり |
| 開発／ステージング環境 | ❌ 無効化 — 本番環境でのみ使用 |
| 請求が未設定 | ❌ 先に請求を設定 |

## 作業別の読み進め方

| 目的 | 最初に読む | 次に読む |
|-----------|------------|-----------|
| Argo を初めて有効化する | 上記のクイックスタート → [configuration.md](configuration.md) | [gotchas.md](gotchas.md) |
| TypeScript／Python SDK を使う | [api.md](api.md) | [patterns.md](patterns.md) |
| Terraform／IaC のセットアップ | [configuration.md](configuration.md) | - |
| Spectrum TCP アプリで有効化する | [patterns.md](patterns.md) → Spectrum セクション | [api.md](api.md) |
| 有効化の問題をトラブルシューティングする | [gotchas.md](gotchas.md) | [api.md](api.md) |
| 請求／使用状況を管理する | [patterns.md](patterns.md) → 請求セクション | [gotchas.md](gotchas.md) |

## このリファレンスの内容

- **[api.md](api.md)** - API エンドポイント、SDK メソッド、エラー処理、Python／TypeScript の例
- **[configuration.md](configuration.md)** - Terraform のセットアップ、環境設定、請求設定
- **[patterns.md](patterns.md)** - Tiered Cache の統合、Spectrum TCP アプリ、請求管理、検証パターン
- **[gotchas.md](gotchas.md)** - よくあるエラー、権限の問題、制限事項、ベストプラクティス

## 関連項目

- [Cloudflare Argo Smart Routing Docs](https://developers.cloudflare.com/argo-smart-routing/)
- [Cloudflare Smart Shield](https://developers.cloudflare.com/smart-shield/)
- [Spectrum Documentation](https://developers.cloudflare.com/spectrum/)
- [Tiered Cache](https://developers.cloudflare.com/cache/how-to/tiered-cache/)
