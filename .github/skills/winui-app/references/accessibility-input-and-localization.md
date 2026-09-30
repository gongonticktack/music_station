---
title: アクセシビリティ、入力、ローカライズ
priority: HIGH
tags: accessibility, keyboard, narrator, automation, localization, high-contrast
sources:
  - https://learn.microsoft.com/windows/apps/design/accessibility/accessibility
  - https://learn.microsoft.com/windows/apps/design/accessibility/keyboard-accessibility
  - https://learn.microsoft.com/windows/apps/design/accessibility/high-contrast-themes
  - https://learn.microsoft.com/windows/apps/design/globalizing/globalizing-portal
  - https://github.com/microsoft/WinUI-Gallery
---

## この参考資料の用途

キーボードアクセシビリティ、ナレーター対応、自動化プロパティ、入力手段の同等なサポート、ハイコントラスト、ローカライズに対応できる UI に関する作業には、このファイルを使用します。

## 推奨事項

- 意味のある UI 要素には、アクセシブルな名前、ヘルプテキスト、ランドマークを設定します。
- 主要なワークフローをキーボードだけで最後まで操作できるようにします。
- ハイコントラストでも問題なく表示されるビジュアルにします。
- ローカライズ可能な文字列を使い、文字列が長くなっても対応できるレイアウトにします。
- プラットフォームが想定する範囲で、マウス、タッチ、ペン、キーボードを等しくサポートします。

## 避けること

- アクセシブルな名前のない、アイコンだけの操作。
- フォーカストラップ、隠れたタブ位置、キーボード操作だけでは抜け出せない状態。
- ローカライズを妨げる、XAML やコードビハインド内のハードコードされた文字列。
- 文字列が長くなると崩れるテキストレイアウト。

## ガイダンス

- 自動化プロパティを意図的に使用します。
- 表示されるフォーカスと論理的なタブ順序を維持します。
- コンテキストメニュー、フライアウト、ダイアログは、マウスだけでなくキーボードでも確認します。
- 必要に応じて、テキストの拡大、コントラストの変更、RTL に対応します。
- マウスとタッチのどちらのハードウェアでも使いやすいよう、タッチ対象と間隔を確保します。

## WinUI Gallery の参考例

- アクセシビリティ関連のコントロールサンプル
- シェルコード内の自動化ヘルパーのパターン
- 有用なアクセシビリティ動作が標準で備わっている WinUI コントロール

## レビューチェックリスト

- キーボードだけを使うユーザーがタスクを完了できますか？
- ナレーターが重要な UI を説明するための情報は十分ですか？
- ハイコントラストでも読みやすさを保てますか？
- 文字列とレイアウトは、ローカライズや RTL による拡張に対応できていますか？
