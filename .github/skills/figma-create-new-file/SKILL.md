---
name: figma-create-new-file
description: 新しい空の Figma ファイルを作る。ユーザーが Figma デザインまたは FigJam ファイルの新規作成を望む場合や、use_figma の呼び出し前に新しいファイルが必要な場合に使う。必要なら whoami でプランを特定する。使い方 — /figma-create-new-file [editorType] [fileName]（例: /figma-create-new-file figjam My Whiteboard）
---

# create_new_file — 新しい Figma ファイルの作成

`create_new_file` MCP ツールで、ユーザーの下書きフォルダに新しい空の Figma ファイルを作る。通常、`use_figma` で作業するための新規ファイルが必要なときに先に使う。

## スキルの引数

このスキルは任意の引数を受け付ける: `/figma-create-new-file [editorType] [fileName]`

- **editorType**: `design`（既定値）または `figjam`
- **fileName**: 新しいファイルの名前（既定値は "Untitled"）

例:
- `/figma-create-new-file` — "Untitled" というデザインファイルを作る
- `/figma-create-new-file figjam My Whiteboard` — "My Whiteboard" という FigJam ファイルを作る
- `/figma-create-new-file design My New Design` — "My New Design" というデザインファイルを作る

スキルの呼び出しから引数を読み取る。editorType がなければ `"design"`、fileName がなければ `"Untitled"` を使う。

## 作業手順

### ステップ 1: planKey を特定する

`create_new_file` ツールには `planKey` パラメーターが必要。次の基準に従う。

1. **ユーザーが既に planKey を示している場合**（以前の `whoami` 呼び出しや依頼文など）→ その値を直接使い、ステップ 2 に進む。

2. **planKey がない場合** → `whoami` ツールを呼ぶ。応答には `plans` 配列があり、各プランには `key`、`name`、`seat`、`tier` が含まれる。

   - **プランが1つの場合**: その `key` 項目を自動的に使う。
   - **プランが複数の場合**: どのチームまたは組織にファイルを作るかユーザーに尋ね、該当プランの `key` を使う。

### ステップ 2: create_new_file を呼ぶ

`create_new_file` ツールには次を渡す。

| パラメーター | 必須 | 説明 |
|-------------|----------|-------------|
| `planKey`   | はい | ステップ 1 で得たプランのキー |
| `fileName`  | はい | 新しいファイルの名前 |
| `editorType`| はい | `"design"` または `"figjam"` |

例:
```json
{
  "planKey": "team:123456",
  "fileName": "My New Design",
  "editorType": "design"
}
```

### ステップ 3: 結果を使う

ツールは次を返す。
- `file_key` — 作成されたファイルのキー
- `file_url` — Figma でファイルを開くための直接 URL

`use_figma` など、後続のツール呼び出しには `file_key` を使う。

## 重要な注意点

- ファイルは選択したプランの、ユーザーの**下書きフォルダ**に作成される。
- 対応するエディター種別は `"design"` と `"figjam"` のみ。
- 次に `use_figma` を使う場合は、呼び出し前に `figma-use` スキルを読み込む。
