---
title: Windows App SDK のライフサイクル、通知、デプロイ
priority: HIGH
tags: windows-app-sdk, lifecycle, activation, notifications, deployment, packaged, unpackaged
sources:
  - https://learn.microsoft.com/windows/apps/windows-app-sdk/
  - https://learn.microsoft.com/windows/apps/windows-app-sdk/deploy-packaged-apps
  - https://learn.microsoft.com/windows/apps/windows-app-sdk/deploy-unpackaged-apps
  - https://github.com/microsoft/WindowsAppSDK-Samples
---

## このリファレンスの用途

単純な XAML UI の作業を超えて、ライフサイクル、アクティベーション、通知、パッケージ化と非パッケージ化の違い、またはランタイム初期化の指針が必要なときに、このファイルを使用してください。

## 推奨事項

- 抽象化を設計する前に、該当する WindowsAppSDK サンプルでシナリオを把握してください。
- 製品の制約に合う場合は、パッケージ化してデプロイしてください。
- インストーラーや外部の場所に関する要件がある場合、または開発中に実行可能ファイルを直接繰り返し起動する必要がある場合は、非パッケージ化の手順を明示してください。

## 避けること

- どちらの方法が該当するかを明示せず、パッケージ化と非パッケージ化の手順を一つの回答に混在させること。
- デプロイ要件を任意の詳細事項として扱うこと。
- Windows App SDK の API ですでに対応できるライフサイクル動作を再実装すること。
- 明示的なガードや代替経路を用意せず、パッケージ ID に依存する API を非パッケージ化の起動コードで使用すること。

## 指針

- アクティベーション、インスタンス管理、再起動、状態通知には、AppLifecycle の指針とサンプルを使用してください。
- 独自の配信ロジックを考案せず、プッシュ通知やアプリ通知には通知サンプルを使用してください。
- パッケージ化アプリでは、フレームワーク依存デプロイとランタイムパッケージの要件を考慮してください。
- 非パッケージ化アプリでは、ブートストラッパーとランタイム初期化の要件を考慮してください。
- 非パッケージ化アプリでは、選択したデプロイ方式を通じてアプリが意図的にパッケージ ID を確立しない限り、パッケージ ID はないものとして扱ってください。
- ストレージ、設定、起動サービスをデプロイ方式に合わせてください。サービスがパッケージ化ストレージやアクティベーションを前提としている場合は、非パッケージ化でローカル検証を行う前に設計し直してください。
- ビルドや公開の手順を示す前に、デプロイ方式を説明してください。

## サンプルと参照先

- WindowsAppSDK-Samples `Samples/AppLifecycle`
- WindowsAppSDK-Samples `Samples/Notifications`
- WindowsAppSDK-Samples `Samples/Unpackaged`
- WindowsAppSDK-Samples `Samples/CustomControls`
- パッケージ化および非パッケージ化のデプロイに関する Learn ガイド

## レビューチェックリスト

- アプリのデプロイ方式は明示されていますか？
- ライフサイクルとアクティベーションの動作に、その場しのぎの回避策ではなくプラットフォーム API を使用していますか？
- 通知要件に合ったサンプルとランタイムの指針を選んでいますか？
- 推奨内容は、パッケージ化または非パッケージ化の制約に合っていますか？
