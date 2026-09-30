# 例: 顧客との会議の準備

**ユーザーの依頼**: 「木曜日にあるAcme Corpとの営業会議の準備をして」

## ワークフロー

### 1. 顧客情報を検索する
```
Notion:notion-search
query: "Acme Corp"
```

見つかった情報:
- 初回通話のCRMメモ
- 製品デモへのフィードバック
- 価格提案
- 競合分析

### 2. 詳細を取得する
```
Notion:notion-fetch (4 pages)
```

**主な情報**:
- **会社**: 従業員500人のフィンテック系スタートアップ、シリーズB
- **課題**: 手作業のワークフロー、データのサイロ化、スケーリングの問題
- **意思決定者**: CTO（技術面）、VP Product（ユーザーニーズ）、CFO（予算）
- **導入時期**: 第1四半期までにソリューションが必要
- **予算**: 年間5万～7万5,000ドル
- **競合状況**: 当社とCompetitor A、Competitor Bを比較検討中

### 3. 調査情報を加える
Codexの調査で次の情報を追加:
- フィンテック業界のコンプライアンス要件
- 金融製品で一般的に必要となる連携
- シリーズB企業で一般的な調達プロセス

### 4. 社内向け事前資料を作成する
```
Notion:notion-create-pages
pages: [{
  properties: {
    title: "Acme Corp Meeting - Pre-Read (Internal)"
  },
  content: "# Acme Corp Meeting - Pre-Read (Internal)

## Company Overview
**Company**: Acme Corp (500-person fintech, Series B)
**Decision Makers**: CTO, VP Product, CFO
Source: <mention-page url='...'>CRM Notes</mention-page>

## Their Pain Points → Our Solutions
- Manual workflows → Workflow automation
- Data silos → API integrations
- Scaling issues → Enterprise features

## Competitive Position
**Our advantages over Competitor A/B**:
- Better integration ecosystem (Stripe, Plaid)
- Stronger compliance features
- Faster implementation (4 weeks vs 12 weeks)

## Pricing Strategy
Recommend: $60K/year (mid-range of their budget)

## Potential Objections & Responses
..."
}]
```

### 5. 会議のアジェンダを作成する
```
Notion:notion-create-pages
pages: [{
  properties: {
    title: "Acme Corp - Product Demo & Q&A"
  },
  content: "# Acme Corp - Product Demo & Q&A

## Meeting Details
**Date**: Thursday, Oct 17, 2025 @ 2pm PST
**Attendees**: CTO, VP Product, CFO (Acme) | Sales Lead, Solutions Engineer (Us)
**Duration**: 60 minutes

## Objective
Demonstrate how our platform solves Acme's workflow automation and integration challenges.

## Agenda

**1. Introductions** (5 min)

**2. Understand Current Workflow** (10 min)
- Current pain points
- Integration requirements
- Success criteria

**3. Product Demo** (25 min)
- Workflow automation capabilities
- API integrations (Stripe, Plaid)
- Security & compliance features

**4. Pricing & Implementation** (10 min)

**5. Next Steps** (10 min)
"
}]
```

### 6. 参考資料をリンクする
アジェンダをCRMページ、価格表、技術連携ドキュメントにリンクしました。

## 成果物

**社内向け事前資料**: 営業チーム向けの全情報
**顧客向けアジェンダ**: プロフェッショナルな会議構成
**両方ともNotionに保存**し、参考資料へのリンクを付与

## 成功のポイント
- 顧客固有の課題を把握した
- 業界情報（フィンテックのコンプライアンス）を調査した
- 顧客のニーズに機能を結び付けた
- 競合との差別化ポイントを準備した
- 顧客のユースケースに合わせてデモを構成した
- 想定される反論への回答を事前に準備した
- アジェンダに明確な次のステップを設けた
