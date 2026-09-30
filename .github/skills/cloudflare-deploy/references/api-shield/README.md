# Cloudflare API Shieldリファレンス

APIの検出、保護、監視を包括的に行うセキュリティスイート、API Shieldの専門的なガイドです。

## 読む順序

| タスク | 読むファイル |
|------|---------------|
| 初期設定 | README → configuration.md |
| JWT検証の実装 | configuration.md → api.md |
| スキーマ検証の追加 | configuration.md → patterns.md |
| API攻撃の検出 | patterns.md → api.md |
| 問題の調査 | gotchas.md |

## 機能の選択

どのような保護が必要ですか？

```
├─ Validate request/response structure → Schema Validation 2.0 (configuration.md)
├─ Verify auth tokens → JWT Validation (configuration.md)
├─ Client certificates → mTLS (configuration.md)
├─ Detect BOLA attacks → BOLA Detection (patterns.md)
├─ Track auth coverage → Auth Posture (patterns.md)
├─ Stop volumetric abuse → Abuse Detection (patterns.md)
└─ Discover shadow APIs → API Discovery (api.md)
```

## このリファレンスの内容

- **[configuration.md](configuration.md)** - 設定、セッション識別子、ルール、トークンとmTLSの設定
- **[api.md](api.md)** - エンドポイント管理、ディスカバリー、検証API、GraphQLの操作
- **[patterns.md](patterns.md)** - 一般的なパターン、段階的な適用、OWASPとの対応、ワークフロー
- **[gotchas.md](gotchas.md)** - トラブルシューティング、誤検知、パフォーマンス、ベストプラクティス

## クイックスタート

API Shieldは、エンタープライズ向けのAPIセキュリティ機能（ディスカバリー、Schema Validation 2.0、JWT、mTLS、BOLAの検出、認証状況）を提供します。Enterpriseのアドオンとして利用でき、プレビューアクセスも可能です。

## 関連項目

- [API Shieldのドキュメント](https://developers.cloudflare.com/api-shield/)
- [APIリファレンス](https://developers.cloudflare.com/api/resources/api_gateway/)
- [OWASP API Security Top 10](https://owasp.org/www-project-api-security/)
