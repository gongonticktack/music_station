# 仕様の解析

## 仕様の検索

解析を始める前に、仕様ページを見つけます。

```
1. Search for spec:
   Notion:notion-search
   query: "[Feature Name] spec" or "[Feature Name] specification"
   
2. Handle results:
   - If found → use page URL/ID
   - If multiple → ask user which one
   - If not found → ask user for URL/ID

Example:
Notion:notion-search
query: "User Profile API spec"
query_type: "internal"
```

## 仕様の読み取り

仕様が見つかったら、`Notion:notion-fetch`で取得します。

1. 全文を読む
2. 重要なセクションを特定する
3. 構造化された情報を抽出する
4. 曖昧な点や不足している情報を記録する

```
Notion:notion-fetch
id: "spec-page-id-from-search"
```

## 仕様によくある構成

### 要件ベースの仕様

```
# Feature Spec
## Overview
[Feature description]

## Requirements
### Functional
- REQ-1: [Requirement]
- REQ-2: [Requirement]

### Non-Functional
- PERF-1: [Performance requirement]
- SEC-1: [Security requirement]

## Acceptance Criteria
- AC-1: [Criterion]
- AC-2: [Criterion]
```

抽出する項目:
- 機能要件の一覧
- 非機能要件の一覧
- 受け入れ条件の一覧

### ユーザーストーリーベースの仕様

```
# Feature Spec
## User Stories
### As a [user type]
I want [goal]
So that [benefit]

**Acceptance Criteria**:
- [Criterion]
- [Criterion]
```

抽出する項目:
- ユーザーペルソナ
- 必要な目標/機能
- ストーリーごとの受け入れ条件

### 技術設計書

```
# Technical Design
## Problem Statement
[Problem description]

## Proposed Solution
[Solution approach]

## Architecture
[Architecture details]

## Implementation Plan
[Implementation approach]
```

抽出する項目:
- 解決する問題
- 提案する解決策の方針
- アーキテクチャ上の決定事項
- 実装に関する指針

### 製品要件定義書（PRD）

```
# PRD: [Feature]
## Goals
[Business goals]

## User Needs
[User problems being solved]

## Features
[Feature list]

## Success Metrics
[How to measure success]
```

抽出する項目:
- ビジネス目標
- ユーザーニーズ
- 機能一覧
- 成功指標

## 抽出方法

### 要件の特定

次の項目を確認します:
- 「必須」「望ましい」「予定」などの表現
- 番号付き要件（REQ-1など）
- ユーザーストーリー（「〜として、〜したい」）
- 受け入れ条件のセクション
- 機能一覧

### 分類

要件を次のように分類します:

**機能要件**: システムが行うこと
- ユーザーが実行できる操作
- システムの振る舞い
- データ操作

**非機能要件**: システムの性能や品質
- パフォーマンス目標
- セキュリティ要件
- スケーラビリティの要件
- 可用性要件
- コンプライアンス要件

**制約**: 制限事項
- 技術的制約
- ビジネス上の制約
- スケジュール上の制約

### 優先度の抽出

優先度を示す表現を特定します:
- 「重大」「必須」「P0」
- 「重要」「実装すべき」「P1」
- 「あると望ましい」「実装してもよい」「P2」
- 「将来対応」「今回は対象外」「P3」

優先度に基づいて実装フェーズに割り当てます。

## 曖昧さへの対応

### 不明確な要件

要件が曖昧な場合:

```markdown
## Clarifications Needed

### [Requirement ID/Description]
**Current text**: "[Ambiguous requirement]"
**Question**: [What needs clarification]
**Impact**: [Why this matters for implementation]
**Assumed for now**: [Working assumption if any]
```

確認タスクを作成するか、仕様にコメントを追加します。

### 情報の不足

重要な情報が不足している場合:

```markdown
## Missing Information

- **[Topic]**: Spec doesn't specify [what's missing]
- **Impact**: Blocks [affected tasks]
- **Action**: Need to [how to resolve]
```

### 要件の競合

要件が競合する場合:

```markdown
## Conflicting Requirements

**Conflict**: REQ-1 says [X] but REQ-5 says [Y]
**Impact**: [Implementation impact]
**Resolution needed**: [Decision needed]
```

## 受け入れ条件の解析

### 明示された条件

明記された受け入れ条件:

```
## Acceptance Criteria
- User can log in with email and password
- System sends confirmation email
- Session expires after 24 hours
```

チェックリストに変換します:
- [ ] ユーザーがメールアドレスとパスワードでログインできる
- [ ] システムが確認メールを送信する
- [ ] セッションは24時間後に期限切れになる

### 暗黙の条件

要件から導きます:

```
Requirement: "Users can upload files up to 100MB"

Implied acceptance criteria:
- [ ] Files up to 100MB upload successfully
- [ ] Files over 100MB are rejected with error message
- [ ] Progress indicator shows during upload
- [ ] Upload can be cancelled
```

### テスト可能な条件

条件がテスト可能であることを確認します:

❌ **テスト不可**: 「システムが速い」
✓ **テスト可能**: 「ページが2秒未満で読み込まれる」

❌ **テスト不可**: 「ユーザーがインターフェースを気に入っている」
✓ **テスト可能**: 「テストユーザーの90%がタスクを正常に完了する」

## 技術的な詳細の抽出

### アーキテクチャ情報

次の情報を抽出します:
- システムの構成要素
- データモデル
- API/インターフェース
- 連携ポイント
- 技術の選定

### 設計上の決定事項

次の点を記録します:
- 技術の選定
- アーキテクチャパターン
- 採用したトレードオフ
- 示されている根拠

### 実装の指針

次の項目を確認します:
- 推奨されるアプローチ
- コード例
- 推奨ライブラリ
- 記載されているベストプラクティス

## 依存関係の特定

### 外部依存関係

仕様から次の項目を特定します:
- 必要なサードパーティサービス
- 必要な外部API
- インフラ要件
- ツール/ライブラリの依存関係

### 内部依存関係

次の項目を特定します:
- 先に必要となる他の機能
- 必要な共有コンポーネント
- チーム間の依存関係
- データの依存関係

### スケジュール上の依存関係

次の点を記録します:
- 厳守すべき期限
- マイルストーン間の依存関係
- 作業順序の要件

## スコープの抽出

### 対象範囲

明示的に含まれるもの:
- 実装する機能
- サポートするユースケース
- 対象となるユーザー/ペルソナ

### 対象外

明示的に除外されるもの:
- 後回しにする機能
- サポートしないユースケース
- 対応しないエッジケース

### 前提

前提とされているもの:
- 環境に関する前提
- ユーザーに関する前提
- システム状態に関する前提

## リスクの特定

リスク情報を抽出します:

### 技術的リスク
- 実績のない技術
- 複雑な連携
- パフォーマンス上の懸念
- スケーラビリティの不確実性

### ビジネス上のリスク
- 市場投入のタイミング
- リソースの確保状況
- 他者への依存

### 軽減策

仕様に記載されている軽減策を記録します。

## 仕様の品質評価

仕様の完全性を評価します:

✓ **良い仕様**:
- 要件が明確
- 受け入れ条件が明記されている
- 優先度が定義されている
- リスクが特定されている
- 技術的な方針が示されている

⚠️ **不完全な仕様**:
- 要件が曖昧
- 受け入れ条件が不足
- 優先度が不明確
- リスク分析がない
- 技術的な詳細がない

不足事項を記録し、確認タスクを作成します。

## 解析チェックリスト

実装計画を作成する前に:

☐ すべての機能要件を特定した
☐ 非機能要件を記録した
☐ 受け入れ条件を抽出した
☐ 依存関係を特定した
☐ リスクを記録した
☐ 曖昧な点を文書化した
☐ 技術的な方針を理解した
☐ スコープが明確である
☐ 優先度が定義されている

