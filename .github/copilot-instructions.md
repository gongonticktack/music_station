# GitHub Copilot Instructions

このファイルはスキルへの道案内です。作業内容に合う `.github/skills/` の `SKILL.md` を選び、実作業前に読んでください。全体の配置は [スキル一覧](../docs/skills-inventory.md) を参照してください。

通常の作業では、モデルやサービスを問わず [ai-resource-efficiency](skills/ai-resource-efficiency/SKILL.md) を参照してください。このリポジトリ固有の指示は、作業内容に応じて次を参照してください。

- 共通の作業方針: [work-guidelines](skills/work-guidelines/SKILL.md)
- UI の変更: [ui-design](skills/ui-design/SKILL.md)
- アプリ構成、起動、出力: [app-structure](skills/app-structure/SKILL.md)
- README の作成・更新: [readme](skills/readme/SKILL.md)
- コード変更後の説明・テスト・確認: [quality-checks](skills/quality-checks/SKILL.md)

## スキルの選択

- 依頼の目的、対象ファイル、使用するサービス、各スキルの適用条件を照合する。名前の単語が一致するだけで選ばず、該当しないスキルは使わない。
- 該当する `SKILL.md` を実作業前に読む。`references/`、`reference/`、`scripts/` は必要なものだけ確認する。
- 複数のスキルを使う場合は、前提となるものから読む。Figma ファイル内の操作では `figma-use` を先に確認し、画面生成では `figma-generate-design` も確認する。デプロイでは依頼されたサービスのスキルを選ぶ。
- スキルの指示よりユーザーの明示的な依頼を優先し、依頼の範囲外へ作業を広げない。
- `openai-docs` は `skills/` 直下と `.system` に重複している。まず `.system` を確認し、必要なら直下の定義との差分を確認する。

## 選択の目安

| 依頼 | スキル |
| --- | --- |
| ASP.NET Core / WinUI 3 | `aspnet-core` / `winui-app` |
| ChatGPT Apps SDK、OpenAI 製品・API、Codex | `chatgpt-apps` / `openai-docs` |
| CLI、Jupyter Notebook、ローカル Web アプリ | `cli-creator` / `jupyter-notebook` / `webapp-delivery` |
| Figma の参照、作成、実装 | `figma` と目的に合う `figma-*` |
| GitHub PR、CI、コミットから PR 作成 | `gh-address-comments` / `gh-fix-ci` / `yeet` |
| Cloudflare、Netlify、Render、Vercel への公開 | 対応する `*-deploy` |
| Linear、Notion | `linear` / 目的に合う `notion-*` |
| PDF、画像、スクリーンショット、音声、文字起こし | `pdf` / `imagegen` / `screenshot` / `speech` / `transcribe` |
| ブラウザー自動操作、対話的 UI 調査 | `playwright` / `playwright-interactive` |
| 明示的なセキュリティレビュー、所有者分析、脅威分析 | `security-best-practices` / `security-ownership-map` / `security-threat-model` |
| Sentry、Codex 用ペット | `sentry` / `hatch-pet` |
| 目標定義、Codex への移行 | `define-goal` / `migrate-to-codex` |
| スキル・プラグインの作成や導入 | `.system` の `skill-creator` / `skill-installer` / `plugin-creator` |
