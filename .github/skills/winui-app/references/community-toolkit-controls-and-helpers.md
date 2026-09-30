---
title: CommunityToolkit のコントロールとヘルパー
priority: MEDIUM
tags: communitytoolkit, controls, helpers, animations, settingscontrols
sources:
  - https://github.com/CommunityToolkit/Windows
  - https://learn.microsoft.com/dotnet/communitytoolkit/windows/getting-started
---

## このリファレンスの用途

WinUI 3 アプリに Windows Community Toolkit を追加するかどうか判断する際に、このファイルを使用します。

## 推奨事項

- まずプラットフォーム標準のコントロールを検討します。
- 設定画面の表現を充実させる、セグメント コントロールを使う、用途を絞ったアニメーション ヘルパーを使うなど、明確な不足を補う場合に限り、必要な Toolkit パッケージを追加します。
- 問題を解決できる最小限のパッケージ構成にします。

## 避けること

- WinUI の標準機能で要件を満たせるか確認せず、便利そうだからという理由で Toolkit パッケージを追加すること。
- わずかな見た目の違いのために、複数の Toolkit パッケージを導入すること。
- 新しい依存関係で、根本的な UX の問題を覆い隠すこと。

## 導入を検討できる領域

- `SettingsControls`
  - 設定画面やカードに便利
- `Segmented`
  - タブやラジオボタンのグループよりも、選択肢をセグメントで示す方が分かりやすい場合に便利
- `HeaderedControls`
  - ラベル付きのコントロールグループに便利
- `Animations`
  - 組み込みのトランジションでは不十分な場合に便利
- ヘルパーと拡張機能
  - WinUI の定型的な配線コードをすっきり減らせる場合に便利

## パッケージに関する指針

- WinUI 3 互換の Toolkit パッケージを優先します。
- アプリで実際に使うものだけを追加します。
- Toolkit への依存関係を追加した理由と、採用しなかった組み込みの代替機能を文書化します。

## サンプルとソースの参照先

- CommunityToolkit の `components/SettingsControls`
- CommunityToolkit の `components/Segmented`
- CommunityToolkit の `components/HeaderedControls`
- Toolkit のアニメーションおよびヘルパー パッケージ

## レビュー チェックリスト

- WinUI の組み込み機能ですでに問題を解決できませんか？
- 依存関係の範囲は限定され、導入理由も明確ですか？
- 新しいコントロールは、アプリ全体のデザイン言語に合っていますか？
- このパッケージによってカスタム コードが十分に減るか、UX が改善されますか？
