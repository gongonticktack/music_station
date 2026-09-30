# 例: 議論から手順ガイドを作成

**ユーザーの依頼**: 「本番環境へのデプロイに関する議論を、手順ガイドとして保存してください」

## ワークフロー

### 1. チャットから内容を抽出
会話から以下を特定:
- デプロイの前提条件
- 手順を追った作業方法
- よくある問題と解決策
- ベストプラクティスとヒント

### 2. 手順ガイドとして構成
以下のように整理:
- 概要と前提条件
- 番号付きのデプロイ手順
- 確認手順
- トラブルシューティングのセクション
- 関連リソース

### 3. 保存先を探す
```
Notion:notion-search
query: "deployment documentation"
```
見つかった場所: Engineering Wiki → Deployment セクション

### 4. ガイドを作成
```
Notion:notion-create-pages
parent: { page_id: "deployment-section-id" }
```

## 出力

```markdown
# How to Deploy to Production

## Overview
Production deployment using GitHub Actions with zero-downtime rolling updates.
**Time Required**: 15-20 minutes | **Complexity**: Intermediate

## Prerequisites
- [ ] PR approved and merged to main
- [ ] All CI tests passing
- [ ] Database migrations reviewed
- [ ] Feature flags configured

## Deployment Steps

1. **Verify main branch is ready**
   ```bash
   git checkout main && git pull
   ```

2. **リリースにタグを付ける**
   ```bash
   git tag -a v1.2.3 -m "Release v1.2.3"
   git push origin v1.2.3
   ```

3. **デプロイを開始**
   - タグの push によって GitHub Actions が自動的に開始
   - 監視先: https://github.com/org/repo/actions

4. **データベースのマイグレーション**（必要な場合）
   - GitHub Actions 内で自動実行
   - 完了したことをログで確認

5. **デプロイを確認**
   - ヘルスチェックを待つ（2〜3 分）
   - 主要なエンドポイントをテスト
   - Datadog でエラー率を確認

## 確認チェックリスト
- [ ] k8s ダッシュボードですべてのポッドが正常
- [ ] 直近 10 分間のエラー率が 0.1% 未満
- [ ] p95 応答時間が 500ms 未満
- [ ] ログインの流れをテスト
- [ ] Slack の #alerts チャンネルを確認

## トラブルシューティング

**ヘルスチェックが失敗する**
→ ポッドのログを確認: `kubectl logs -f deployment/api -n production`

**マイグレーションエラー**
→ ロールバック: タグを戻すと、マイグレーションは自動的にロールバックされます

**エラー率が高い**
→ 緊急ロールバック: 以前のタグが GitHub Actions によって自動デプロイされます

## ベストプラクティス
- トラフィックの少ない時間帯（PST 午前 2〜4 時）にデプロイする
- エンジニアを 2 人確保する
- デプロイ後 30 分間監視する
- デプロイの通知を Slack の #engineering に投稿する

## 関連ドキュメント
- <mention-page url="...">ロールバック手順</mention-page>
- <mention-page url="...">データベースマイグレーションガイド</mention-page>
```

### 5. 見つけやすくする
```
Notion:notion-update-page
page_id: "engineering-wiki-homepage"
command: "insert_content_after"
```
Engineering Wiki → How-To Guides セクションにリンクを追加しました

## 成功の主な要因
- 議論から暗黙知を記録
- 実行可能な手順として整理
- 実体験に基づくトラブルシューティングを含めた
- Wiki のインデックスからリンクし、見つけやすくした
- メタデータ（所要時間、難易度）を追加
