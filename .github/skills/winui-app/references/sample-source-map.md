---
title: サンプルとソースの対応表
priority: MEDIUM
tags: sources, mapping, lookup, gallery, docs, toolkit
sources:
  - https://learn.microsoft.com/windows/apps/get-started/samples
  - https://github.com/microsoft/WinUI-Gallery
  - https://github.com/microsoft/WindowsAppSDK-Samples
  - https://github.com/CommunityToolkit/Windows
---

## このリファレンスについて

取り組むタスクは決まっているものの、最初に確認すべき公式ソースを特定したい場合に、このファイルを使用します。

| タスク | 最初に確認するソース | 代替ソース |
| --- | --- | --- |
| PC で WinUI アプリをビルドできるか確認する | `../SKILL.md` | `foundation-environment-audit-and-remediation.md` |
| 不足している前提条件をインストールする | `../SKILL.md` | `foundation-environment-audit-and-remediation.md` |
| 新しいパッケージ アプリまたは非パッケージ アプリを開始する | `../SKILL.md` | `foundation-setup-and-project-selection.md` |
| パッケージ アプリと非パッケージ アプリのどちらを選ぶか決める | Learn の Windows App SDK デプロイ ドキュメント | WindowsAppSDK-Samples の `Samples/Unpackaged` |
| ナビゲーション付きのシェルを構築する | WinUI Gallery のナビゲーション ページ | Learn のナビゲーション基礎 |
| カスタム タイトル バーを設計する | Learn のタイトル バー ガイダンス | WinUI Gallery のタイトル バー サンプル |
| Mica またはシステムの背景素材を追加する | Learn の Mica ガイダンス | WindowsAppSDK-Samples の `Samples/Mica` |
| 設定ページを設計する | WinUI Gallery のコントロール ページ | CommunityToolkit の `SettingsControls` |
| リストやコレクションに使うコントロールを選ぶ | WinUI Gallery のコントロール ページ | Learn の応答性とレイアウトのガイダンス |
| アクセシビリティを改善する | Learn のアクセシビリティ ドキュメント | WinUI Gallery の標準コントロールの動作 |
| 応答性を診断する | Learn の `winui-perf.md` | `testing-debugging-and-review-checklists.md` の WPR/WPA ガイダンス |
| 通知やアクティベーションのフローを追加する | WindowsAppSDK-Samples | Learn の Windows App SDK ライフサイクル ドキュメント |
| CommunityToolkit を追加するか判断する | `community-toolkit-controls-and-helpers.md` | Toolkit のコンポーネント ディレクトリ |

## ソースの優先順位

- 要件と動作のガイダンスには、まず Learn を確認します。
- 具体的なコントロールの使い方やシェルの構成には、まず WinUI Gallery を確認します。
- シナリオ API とプラットフォーム統合には、まず WindowsAppSDK-Samples を確認します。
- タスクで Toolkit 固有の機能が明確に必要な場合に限り、CommunityToolkit を使用します。
