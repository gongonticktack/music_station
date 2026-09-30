# 例：市場調査

**ユーザーの依頼**：「AI コーディングアシスタント市場の現状を調査し、Notion に要約ドキュメントを作成する」

## ワークフロー

### 1. 検索
```
Notion:notion-search
query: "AI coding assistants market"
```
Engineering、Strategy、Product の各チームスペースから、関連するページが 3 件見つかりました。

### 2. 取得と分析
```
Notion:notion-fetch (3x)
```
ソースページから市場規模、競争環境、技術トレンドを抽出しました。

### 3. ドキュメントの作成
```
Notion:notion-create-pages
```

## 出力（要約版）

```markdown
# AI Coding Assistants Market Research - Oct 2025

## Executive Summary
The AI coding assistant market is experiencing 150%+ YoY growth. GitHub Copilot dominates with 60% share, but specialized tools are gaining traction in specific niches.

## Key Findings

### Market Size and Growth
$800M in 2024 → $2.5B projected by 2026. Developer adoption: 23% (2023) → 47% (2024).
Source: <mention-page url="...">Market Trends Q3 2025</mention-page>

### Competitive Landscape
- GitHub Copilot: 60% (strong IDE integration)
- Cursor: 15% (rapid growth, full IDE)
- Tabnine: 10% (enterprise, on-premise)
- Cody: 5% (codebase-aware)
- CodeWhisperer: 8% (AWS integration)
Source: <mention-page url="...">AI Tools Competitive Analysis</mention-page>

### Technology Trends
Key differentiators: context awareness, customization, multi-modal interfaces, code verification.
Source: <mention-page url="...">Developer Tools Landscape</mention-page>

## Next Steps
1. Monitor Cursor growth and feature releases
2. Evaluate Cody's codebase-aware capabilities
3. Document enterprise security/compliance requirements
4. Track pricing trends
```

## 主なポイント
- 複数のチームスペースから関連ページを発見
- 競争、市場、技術の各観点を統合
- ソースページへのリンクを含む適切な引用を使用
- 実行可能な提案を作成