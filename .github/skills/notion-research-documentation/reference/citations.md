# 引用スタイル

## 基本的なページ引用

情報源は必ずNotionページへのメンションで引用します。

```markdown
<mention-page url="https://notion.so/workspace/Page-Title-uuid">Page Title</mention-page>
```

URLは必ず指定します。タイトルは任意ですが、読みやすくなります。

```markdown
<mention-page url="https://notion.so/workspace/Page-Title-uuid"/>
```

## インライン引用

参照した情報の直後に引用を記載します。

```markdown
The Q4 revenue increased by 23% quarter-over-quarter (<mention-page url="...">Q4 Financial Report</mention-page>).
```

## 複数の情報源

複数の情報源に基づく情報の場合:

```markdown
Customer satisfaction has improved across all metrics (<mention-page url="...">Q3 Survey Results</mention-page>, <mention-page url="...">Support Analysis</mention-page>).
```

## セクション単位の引用

1つの情報源に基づく長いセクションでは:

```markdown
### Engineering Priorities

According to the <mention-page url="...">Engineering Roadmap 2025</mention-page>:

- Focus on API scalability
- Improve developer experience
- Migrate to microservices architecture
```

## 情報源セクション

ドキュメントの末尾に必ず「Sources」セクションを含めます。

```markdown
## Sources

- <mention-page url="...">Strategic Plan 2025</mention-page>
- <mention-page url="...">Market Analysis Report</mention-page>
- <mention-page url="...">Competitor Research: Q3</mention-page>
- <mention-page url="...">Customer Interview Notes</mention-page>
```

長いリストでは、カテゴリ別にまとめます。

```markdown
## Sources

### Primary Sources
- <mention-page url="...">Official Roadmap</mention-page>
- <mention-page url="...">Strategy Document</mention-page>

### Supporting Research
- <mention-page url="...">Market Trends</mention-page>
- <mention-page url="...">Customer Feedback</mention-page>

### Background Context
- <mention-page url="...">Historical Analysis</mention-page>
```

## 内容の引用

情報源から直接引用する場合:

```markdown
The product team noted: "We need to prioritize mobile experience improvements" (<mention-page url="...">Product Meeting Notes</mention-page>).
```

引用ブロックの場合:

```markdown
> We need to prioritize mobile experience improvements to meet our Q4 goals. This includes performance optimization and UI refresh.
>
> — <mention-page url="...">Product Meeting Notes - Oct 2025</mention-page>
```

## データの引用

データを提示する場合は、情報源を引用します。

```markdown
| Metric | Q3 | Q4 | Change |
|--------|----|----|--------|
| Revenue | $2.3M | $2.8M | +21.7% |
| Users | 12.4K | 15.1K | +21.8% |

Source: <mention-page url="...">Financial Dashboard</mention-page>
```

## データベースの引用

データベースの内容を参照する場合:

```markdown
Based on analysis of the <mention-database url="...">Projects Database</mention-database>, 67% of projects are on track.
```

## ユーザーの引用

特定の人に情報を帰属させる場合:

```markdown
<mention-user url="...">Sarah Chen</mention-user> noted in <mention-page url="...">Architecture Review</mention-page> that the microservices migration is ahead of schedule.
```

## 引用の頻度

**引用しすぎ**（すべての文に引用を付ける）:
```markdown
The revenue increased (<mention-page url="...">Report</mention-page>). 
Costs decreased (<mention-page url="...">Report</mention-page>). 
Margin improved (<mention-page url="...">Report</mention-page>).
```

**引用が不足**（情報の帰属先を示さない）:
```markdown
The revenue increased, costs decreased, and margin improved.
```

**適切なバランス**（まとめて引用する）:
```markdown
The revenue increased, costs decreased, and margin improved (<mention-page url="...">Q4 Financial Report</mention-page>).
```

## 古くなった情報

情報源の内容が古くなっている可能性がある場合は、その旨を記載します。

```markdown
The original API design (<mention-page url="...">API Spec v1</mention-page>, last updated January 2024) has been superseded by the new architecture in <mention-page url="...">API Spec v2</mention-page>.
```

## 相互参照

関連する調査ドキュメントへのリンクを記載します。

```markdown
## Related Research

This research builds on previous findings:
- <mention-page url="...">Market Analysis - Q2 2025</mention-page>
- <mention-page url="...">Competitor Landscape Review</mention-page>

For implementation details, see:
- <mention-page url="...">Technical Implementation Guide</mention-page>
```

## 引用の検証

調査を完成させる前に確認します。

✓ 重要な主張すべてに情報源の引用がある
✓ すべてのページメンションに有効なURLがある
✓ Sourcesセクションに引用したページがすべて含まれている
✓ 古い情報源にはその旨が記されている
✓ 直接引用であることが明確に示されている
✓ データの情報源が明記されている

## 引用スタイルの一貫性

引用スタイルを1つ選び、文書全体で統一します。

**インライン形式**（簡潔）:
```markdown
Revenue grew 23% (Financial Report). Customer count increased 18% (Metrics Dashboard).
```

**正式形式**（完全なメンション）:
```markdown
Revenue grew 23% (<mention-page url="...">Q4 Financial Report</mention-page>). Customer count increased 18% (<mention-page url="...">Metrics Dashboard</mention-page>).
```

クリックして移動できるため、ほとんどの調査ドキュメントでは**正式形式を推奨します**。

