# 例：競合分析

## ユーザーの依頼

> 「競合他社の料金モデルを調査し、比較ドキュメントを作成する」

## ワークフローの実行

### ステップ 1：競合情報を検索

```
Notion:notion-search
query: "competitor pricing"
query_type: "internal"
filters: {
  created_date_range: {
    start_date: "2024-01-01"
  }
}
```

**見つかった結果：**
- 「Competitor Analysis - Stripe」（Product）
- 「Market Research Q3 2024」（Strategy）
- 「Pricing Strategy Discussion」（Product）
- 「Competitor Feature Matrix」（Product）

### ステップ 2：取得して分析

```
Notion:notion-fetch for each page
```

**抽出した情報：**

**Stripe**：
- 従量課金：取引ごとに 2.9% + $0.30
- 月額料金なし
- 取引量に応じた割引あり

**Square**：
- 従量課金：取引ごとに 2.6% + $0.10
- 月額プラン：より低い料率で月額 $29
- ハードウェア費用は別途

**PayPal**：
- 標準：取引ごとに 3.49% + $0.49
- アドバンス：月額 $30 + 2.59% + $0.49
- 複数通貨の手数料あり

**Adyen**：
- Interchange++ 料金モデル
- 企業向けの個別料金
- 初期費用と月額料金が発生

### ステップ 3：比較ドキュメントを作成

```
Notion:notion-create-pages

pages: [{
  properties: {
    "title": "Competitor Pricing Analysis - Payment Processors"
  },
  content: "[Comparison document using template]"
}]
```

## 出力ドキュメント

```markdown
# Competitor Pricing Analysis - Payment Processors

**Date**: October 14, 2025  
**Research Team**: Product Strategy

## Executive Summary

We analyzed four major payment processor competitors: Stripe, Square, PayPal, and Adyen. Pricing models vary from simple pay-as-you-go (Stripe) to complex interchange-plus (Adyen). Key insight: All competitors offer volume discounts for high-transaction merchants, with breakpoints typically at $100K/month processing volume.

## Comparison Matrix

| Feature | Stripe | Square | PayPal | Adyen |
|---------|--------|--------|--------|-------|
| **Base Rate** | 2.9% + $0.30 | 2.6% + $0.10 | 3.49% + $0.49 | Interchange++ |
| **Monthly Fee** | $0 | $0-29 | $0-30 | Custom |
| **Volume Discounts** | Yes, >$80K | Yes, >$250K | Yes, >$100K | Yes, custom |
| **Setup Fee** | $0 | $0 | $0 | $1,000-5,000 |
| **Multi-currency** | 1% extra | 3% extra | 3-4% extra | Included |
| **Chargeback Fee** | $15 | $15-25 | $20 | Custom |
| **Target Market** | Startups-Enterprise | Small-Medium | Small-Medium | Enterprise |

## Detailed Analysis

### Stripe

**Pricing Structure**:
- **Standard**: 2.9% + $0.30 per successful card charge
- **Volume discounts**: Available for businesses processing >$80,000/month
- **International cards**: +1% fee
- **Currency conversion**: 1% above market rate

**Strengths**:
- Simple, transparent pricing
- No setup fees or monthly minimums
- Excellent developer experience
- Quick onboarding

**Weaknesses**:
- Higher per-transaction fee for high volume
- Volume discounts less aggressive than Adyen

**Best for**: Startups and growth-stage companies needing quick integration

**Source**: <mention-page url="...">Competitor Analysis - Stripe</mention-page>

### Square

**Pricing Structure**:
- **Pay-as-you-go**: 2.6% + $0.10 per tap, dip, or swipe
- **Keyed-in**: 3.5% + $0.15
- **Plus plan**: $29/month for lower rates (2.5% + $0.10)
- **Premium plan**: Custom pricing

**Strengths**:
- Lowest per-transaction fee for in-person
- All-in-one hardware + software
- No long-term contracts

**Weaknesses**:
- Higher rates for online/keyed transactions
- Hardware costs ($49-$299)
- Less suitable for online-only businesses

**Best for**: Brick-and-mortar retail and restaurants

**Source**: <mention-page url="...">Market Research Q3 2024</mention-page>

### PayPal

**Pricing Structure**:
- **Standard**: 3.49% + $0.49 per transaction
- **Advanced**: $30/month + 2.59% + $0.49
- **Payments Pro**: Additional $30/month for direct credit card processing

**Strengths**:
- Huge customer base (PayPal checkout)
- Buyer protection increases trust
- International reach (200+ countries)

**Weaknesses**:
- Highest per-transaction fees
- Complex fee structure
- Account holds and reserves common

**Best for**: Businesses where PayPal brand trust matters (e-commerce, marketplaces)

**Source**: <mention-page url="...">Pricing Strategy Discussion</mention-page>

### Adyen

**Pricing Structure**:
- **Interchange++**: Actual interchange + scheme fees + fixed markup
- **Setup fee**: $1,000-5,000 (negotiable)
- **Monthly minimum**: Typically $10,000+ processing volume
- **Per-transaction**: Interchange + 0.6% + $0.12 (example)

**Strengths**:
- Most transparent cost structure at scale
- Lowest effective rate for high volume
- True multi-currency (100+ currencies)
- Direct connections to schemes

**Weaknesses**:
- Complex pricing requires analysis
- High minimums ($10K+/month)
- Longer integration time
- Not suitable for small businesses

**Best for**: Enterprise with $1M+/month processing volume

**Source**: <mention-page url="...">Competitor Feature Matrix</mention-page>

## Pricing Trends & Insights

### Volume-Based Discounting
All competitors offer discounts at scale:
- **Entry point**: $80K-$250K/month processing
- **Typical discount**: 10-30 basis points reduction
- **Negotiation leverage**: Begins at $500K/month+

### Hidden Costs to Consider

| Cost Type | Stripe | Square | PayPal | Adyen |
|-----------|--------|--------|--------|-------|
| Chargeback | $15 | $15-25 | $20 | $15-25 |
| Account verification | $0 | $0 | $0 | Varies |
| PCI compliance | $0 | $0 | $0 | $0 |
| Currency conversion | 1% | 3% | 3-4% | 0% |
| Refund fees | Returned | Returned | Not returned | Varies |

### Market Positioning

```
取引量大 / 大企業
    ↑
    |                    Adyen
    |                      
    |         Stripe             
    |    
    |  Square    PayPal
    |
    └──────────────────→
      小規模 / シンプル        複雑 / 国際対応
```

## Strategic Implications

### For Startups (<$100K/month)
**Recommended**: Stripe
- Lowest friction to start
- No upfront costs
- Great documentation
- Acceptable rates at this scale

### For Growing Companies ($100K-$1M/month)
**Recommended**: Stripe or Square
- Negotiate volume discounts
- Evaluate interchange++ if international
- Consider Square if in-person dominant

### For Enterprises (>$1M/month)
**Recommended**: Adyen or Negotiated Stripe
- Interchange++ models save significantly
- Direct scheme connections
- Multi-region capabilities matter
- ROI on integration complexity

## Recommendations

1. **Immediate**: Benchmark our current 2.8% + $0.25 against Stripe's standard
2. **Short-term**: Request volume discount quote from Stripe at our current $150K/month
3. **Long-term**: Evaluate Adyen when we cross $1M/month threshold

## Next Steps

- [ ] Request detailed pricing proposal from Stripe for volume discounts
- [ ] Create pricing calculator comparing all 4 at different volume levels
- [ ] Interview customers about payment method preferences
- [ ] Analyze our transaction mix (domestic vs international, card types)

## Sources

### Primary Research
- <mention-page url="...">Competitor Analysis - Stripe</mention-page>
- <mention-page url="...">Market Research Q3 2024</mention-page>
- <mention-page url="...">Pricing Strategy Discussion</mention-page>
- <mention-page url="...">Competitor Feature Matrix</mention-page>

### External References
- Stripe.com pricing page (Oct 2025)
- Square pricing documentation
- PayPal merchant fees
- Adyen pricing transparency report
```

## 成功の鍵

1. **構造化された比較**：一覧しやすいマトリクス形式
2. **複数の評価軸**：価格、機能、対象市場
3. **戦略的な提案**：データだけでなく、そこから得られる示唆も含める
4. **視覚要素**：表と位置づけ図
5. **実行可能な次のステップ**：明確な推奨事項
6. **包括的な出典**：社内調査と外部検証

## 実践されているワークフローパターン

- **日付で絞り込んだ検索**（最近の情報のみ）
- **複数の競合情報の統合**（4 社）
- **比較テンプレート**（マトリクス + 詳細分析）
- **戦略的な考察**（示唆と推奨事項）
- **行動につなげる構成**（次のステップを含む）

