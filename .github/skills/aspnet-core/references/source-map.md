# ASP.NET Core の資料マップ

このスキルは、ASP.NET Core の公式ドキュメントツリーと概要ページをもとにまとめたものです。詳しいドキュメントを開く前に、このファイルを使ってタスクに対応する Microsoft Learn の分野を見つけてください。

主要な資料:

- https://learn.microsoft.com/aspnet/core/
- https://raw.githubusercontent.com/dotnet/AspNetCore.Docs/main/aspnetcore/toc.yml
- https://github.com/dotnet/AspNetCore.Docs/tree/main/aspnetcore

## ドキュメントツリーとの対応

| ASP.NET Core ドキュメントの分野 | 最初に参照するこのスキルの資料 |
| --- | --- |
| 概要、はじめに、新機能 | `stack-selection.md`、`versioning-and-upgrades.md` |
| 基礎 | `program-and-pipeline.md` |
| Web アプリ | `ui-blazor.md`、`ui-razor-pages.md`、`ui-mvc.md` |
| API | `apis-minimal-and-controllers.md` |
| リアルタイムアプリ | `realtime-grpc-and-background-work.md` |
| リモートプロシージャコールアプリ | `realtime-grpc-and-background-work.md` |
| サーバー、ホスティングとデプロイ | `testing-performance-and-operations.md` |
| テスト、デバッグ、トラブルシューティング | `testing-performance-and-operations.md` |
| データアクセス | `data-state-and-services.md` |
| セキュリティと ID 管理 | `security-and-identity.md` |
| パフォーマンス | `testing-performance-and-operations.md` |
| 移行と更新 | `versioning-and-upgrades.md` |

## Microsoft Learn で直接参照する分野

次のトピックは ASP.NET Core のドキュメントツリーに含まれていますが、ここではそれぞれ専用の資料ファイルに展開していません:

- グローバリゼーションとローカリゼーション
- 高度なホスティングと YARP の詳細
- デバッガーと診断ツールの具体的な使い方
- 個々の型に関する詳細な API リファレンスページ

タスクの中心がこれらの分野のいずれかである場合は、このスキルの資料ファイルを確認してから、該当する Microsoft Learn のセクションに直接進んでください。

## 詳細を調べる際の実践的なルール

- まず、このスキルで対象を絞った資料から始める
- タスクがプラットフォームの特定の細部に依存する場合は、対応する Learn の記事を開く
- タスクがバージョン固有の動作に依存する場合は、適切なモニカーまたは破壊的変更のページを確認する
