# Codexペットの仕様

## スプライトアトラス

- 形式: PNGまたはWebP。
- サイズ: `1536x1872`。
- グリッド: 8列 x 9行。
- セル: `192x208`。
- 背景: 透明。
- 未使用セル: 完全に透明。

Webviewアニメーションは、固定された行数と列数を使ってCSSの背景位置を指定します。ラベル、余白、枠線、グリッド線、セルの外側にはみ出す影、追加フレームを入れないでください。

## ローカルのカスタムペットパッケージ

ファイルを次の場所に配置します:

```text
${CODEX_HOME:-$HOME/.codex}/pets/<pet-name>/
├── pet.json
└── spritesheet.webp
```

マニフェストの形式:

```json
{
  "id": "pet-name",
  "displayName": "Pet Name",
  "description": "One short sentence.",
  "spritesheetPath": "spritesheet.webp"
}
```

アプリは、`${CODEX_HOME:-$HOME/.codex}/pets/` の下にあるフォルダー名を使ってカスタムペットを読み込みます。
