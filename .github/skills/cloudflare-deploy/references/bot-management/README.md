# Cloudflare Bot Management

ML/ヒューリスティック、ボットスコア、JavaScript検出、検証済みボットの処理を用いた、エンタープライズグレードのボット検出・保護・緩和機能です。

## 概要

Bot Managementは複数段階の保護を提供します:
- **Free（Bot Fight Mode）**: 明らかなボットを自動ブロック。設定不要
- **Pro/Business（Super Bot Fight Mode）**: アクションの設定、静的リソースの保護、分析用のグループ化
- **Enterprise（Bot Management）**: 1〜99のきめ細かなスコア、WAF統合、JA3/JA4フィンガープリント、Workers API、高度な分析

## クイックスタート

```txt
# Dashboard: Security > Bots
# Enterprise: Deploy rule template
(cf.bot_management.score eq 1 and not cf.bot_management.verified_bot) → Block
(cf.bot_management.score le 29 and not cf.bot_management.verified_bot) → Managed Challenge
```

## 必要な情報はどれですか？

```txt
├─ Initial setup → configuration.md
│   ├─ Free tier → "Bot Fight Mode"
│   ├─ Pro/Business → "Super Bot Fight Mode"
│   └─ Enterprise → "Bot Management for Enterprise"
├─ Workers API integration → api.md
├─ WAF rules → patterns.md
├─ Debugging → gotchas.md
└─ Analytics → api.md#bot-analytics
```

## 推奨する読み進め方

| タスク | 読むファイル |
|------|---------------|
| ボット保護を有効にする | README → configuration.md |
| Workersでボットを検出する | README → api.md |
| WAFルールのテンプレート | README → patterns.md |
| ボットの問題をデバッグする | gotchas.md |
| 高度な分析 | api.md#bot-analytics |

## 基本概念

**ボットスコア**: 1〜99（1 = 自動化されたアクセスである可能性が極めて高い、99 = 人間である可能性が極めて高い）。しきい値: <30はボットのトラフィックを示します。Enterpriseでは1〜99の詳細なスコアを利用でき、Pro/Businessではグループ化のみ利用できます。

**検出エンジン**: ヒューリスティック（既知のフィンガープリントに基づき、スコア=1を割り当てる）、ML（検出の大半を担い、数十億件のリクエストで教師あり学習を実施）、異常検出（オプション。通常のトラフィックを分析）、JavaScript検出（ヘッドレスブラウザーを検出）。

**検証済みボット**: 逆引きDNSまたはWeb Bot Authで検証された、許可リスト登録済みの良好なボット（検索エンジン、AIクローラー）。`cf.bot_management.verified_bot`または`cf.verified_bot_category`でアクセスできます。

## プラットフォームの制限

| プラン | ボットスコア | JA3/JA4 | カスタムルール | 分析データの保持期間 |
|------|------------|---------|--------------|---------------------|
| Free | なし（自動ブロックのみ） | なし | 5 | 該当なし（分析機能なし） |
| Pro/Business | グループ化のみ | なし | 20/100 | 30日（1回につき72時間） |
| Enterprise | 1〜99の詳細なスコア | あり | 1,000以上 | 30日（1回につき1週間） |

## 基本パターン

```typescript
// Workers: Check bot score
export default {
  async fetch(request: Request): Promise<Response> {
    const botScore = request.cf?.botManagement?.score;
    if (botScore && botScore < 30 && !request.cf?.botManagement?.verifiedBot) {
      return new Response('Bot detected', { status: 403 });
    }
    return fetch(request);
  }
};
```

```txt
# WAF: Block definite bots
(cf.bot_management.score eq 1 and not cf.bot_management.verified_bot)

# WAF: Protect sensitive endpoints
(cf.bot_management.score lt 50 and http.request.uri.path in {"/login" "/checkout"} and not cf.bot_management.verified_bot)
```

## このリファレンスの内容

- [configuration.md](./configuration.md) - 製品プラン、WAFルールの設定、JavaScript検出、MLの自動更新
- [api.md](./api.md) - WorkersのBotManagementインターフェース、WAFフィールド、JA4 Signals
- [patterns.md](./patterns.md) - Eコマース、API保護、モバイルアプリの許可リスト登録、SEOに配慮した処理
- [gotchas.md](./gotchas.md) - 誤検知・見逃し、score=0の問題、JSDの制限、CSP要件

## 関連項目

- [waf](../waf/) - ボット対策に使うWAFカスタムルール
- [workers](../workers/) - Workersのrequest.cf.botManagement API
- [api-shield](../api-shield/) - APIに特化したボット保護