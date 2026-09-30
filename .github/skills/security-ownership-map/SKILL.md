---
name: "security-ownership-map"
description: "git リポジトリを分析して人とファイルのセキュリティ上の所有関係を図式化し、バス係数と機微なコードの所有状況を計算して、グラフデータベースや可視化用に CSV/JSON を出力する。git 履歴に基づくセキュリティ面の所有者分析やバス係数分析（担当者のいない機微なコード、セキュリティ担当者、リスク面からの CODEOWNERS の実態確認、機微な箇所の集中、所有者のクラスタなど）をユーザーが明示的に求めた場合のみ使用する。一般的なメンテナー一覧やセキュリティ以外の所有者に関する質問には使用しない。"
---

# セキュリティ上の所有関係マップ

## 概要

git 履歴から人とファイルの二部グラフを作り、所有関係のリスクを計算して、Neo4j/Gephi 用のグラフデータを出力する。ファイルの共変更グラフ（共通コミットに基づく Jaccard 類似度）も作成し、大規模でノイズの多いコミットを除外して、一緒に変更されるファイルをクラスタ化する。

## 要件

- Python 3
- `networkx`（必須。コミュニティ検出は既定で有効）

インストール:

```bash
pip install networkx
```

## 手順

1. リポジトリと期間を指定する（`--since/--until` は任意）。
2. 機微性の判定ルールを決める（既定値または CSV 設定を使用）。
3. `scripts/run_ownership_map.py` で所有関係マップを作る（共変更グラフは既定で有効。巨大なコミットは `--cochange-max-files` で除外する）。
4. コミュニティは既定で計算される。GraphML 出力は任意（`--graphml`）。
5. `scripts/query_ownership.py` で出力を照会し、範囲を絞った JSON を取得する。
6. 保存して可視化する（`references/neo4j-import.md` を参照）。

共変更グラフは既定で、よくある「接着剤」のようなファイル（ロックファイル、`.github/*`、エディター設定）を無視する。これにより、クラスタが共通の基盤ファイルの編集ではなく、実際のコード変更を反映する。`--cochange-exclude` または `--no-default-cochange-excludes` で変更できる。Dependabot のコミットも既定で除外する。`--no-default-author-excludes` で解除するか、`--author-exclude-regex` でパターンを追加する。

Linux の `Kbuild` のようなビルド補助ファイルを共変更クラスタから除外する場合:

```bash
python skills/skills/security-ownership-map/scripts/run_ownership_map.py \
  --repo /path/to/linux \
  --out ownership-map-out \
  --cochange-exclude "**/Kbuild"
```

## クイックスタート

リポジトリのルートから実行する:

```bash
python skills/skills/security-ownership-map/scripts/run_ownership_map.py \
  --repo . \
  --out ownership-map-out \
  --since "12 months ago" \
  --emit-commits
```

既定では、作成者の識別情報と作成日時を使い、マージコミットは除外する。必要に応じて `--identity committer`、`--date-field committer`、`--include-merges` を使う。

例（共変更の除外設定を上書き）:

```bash
python skills/skills/security-ownership-map/scripts/run_ownership_map.py \
  --repo . \
  --out ownership-map-out \
  --cochange-exclude "**/Cargo.lock" \
  --cochange-exclude "**/.github/**" \
  --no-default-cochange-excludes
```

コミュニティは既定で計算される。無効にするには:

```bash
python skills/skills/security-ownership-map/scripts/run_ownership_map.py \
  --repo . \
  --out ownership-map-out \
  --no-communities
```

## 機微性の判定ルール

既定では、認証、暗号、秘密情報に関係する一般的なパスに印を付ける。CSV ファイルを指定すると上書きできる:

```
# pattern,tag,weight
**/auth/**,auth,1.0
**/crypto/**,crypto,1.0
**/*.pem,secrets,1.0
```

`--sensitive-config path/to/sensitive.csv` で使用する。

## 出力ファイル

`ownership-map-out/` の内容:

- `people.csv`（人のノード）
- `files.csv`（ファイルのノード）
- `edges.csv`（変更した関係のエッジ）
- `cochange_edges.csv`（Jaccard 重み付きのファイル間共変更エッジ。`--no-cochange` を指定すると出力されない）
- `summary.json`（セキュリティ上の所有関係に関する調査結果）
- `commits.jsonl`（`--emit-commits` 指定時のみ）
- `communities.json`（共変更エッジがあれば既定で計算。各コミュニティの `maintainers` を含む。`--no-communities` で無効化）
- `cochange.graph.json`（`community_id` と `community_maintainers` を含む NetworkX の node-link JSON。共変更エッジがない場合は `ownership.graph.json`）
- `ownership.graphml` / `cochange.graphml`（`--graphml` 指定時のみ）

`people.csv` にはコミット作成者の時差から推定したタイムゾーンの `primary_tz_offset`、`primary_tz_minutes`、`timezone_offsets` が含まれる。

## LLM 向け照会補助ツール

グラフ全体をコンテキストへ読み込まずに、`scripts/query_ownership.py` で小さく範囲を絞った JSON を取得する。

例:

```bash
python skills/skills/security-ownership-map/scripts/query_ownership.py --data-dir ownership-map-out people --limit 10
python skills/skills/security-ownership-map/scripts/query_ownership.py --data-dir ownership-map-out files --tag auth --bus-factor-max 1
python skills/skills/security-ownership-map/scripts/query_ownership.py --data-dir ownership-map-out person --person alice@corp --limit 10
python skills/skills/security-ownership-map/scripts/query_ownership.py --data-dir ownership-map-out file --file crypto/tls
python skills/skills/security-ownership-map/scripts/query_ownership.py --data-dir ownership-map-out cochange --file crypto/tls --limit 10
python skills/skills/security-ownership-map/scripts/query_ownership.py --data-dir ownership-map-out summary --section orphaned_sensitive_code
python skills/skills/security-ownership-map/scripts/query_ownership.py --data-dir ownership-map-out community --id 3
```

各コミュニティに保存する担当者数は `--community-top-owners 5`（既定値）で調整する。

## 基本的なセキュリティ照会

所有関係についてよくある質問に、範囲を絞った出力で答えるためのコマンド:

```bash
# 担当者のいない機微なコード（変更が古く、バス係数が低い）
python skills/skills/security-ownership-map/scripts/query_ownership.py --data-dir ownership-map-out summary --section orphaned_sensitive_code

# 機微性タグに関わる、表に出ていない所有者
python skills/skills/security-ownership-map/scripts/query_ownership.py --data-dir ownership-map-out summary --section hidden_owners

# バス係数が低い機微な箇所
python skills/skills/security-ownership-map/scripts/query_ownership.py --data-dir ownership-map-out summary --section bus_factor_hotspots

# バス係数が1以下の認証・暗号ファイル
python skills/skills/security-ownership-map/scripts/query_ownership.py --data-dir ownership-map-out files --tag auth --bus-factor-max 1
python skills/skills/security-ownership-map/scripts/query_ownership.py --data-dir ownership-map-out files --tag crypto --bus-factor-max 1

# 機微なコードを最も多く変更している人
python skills/skills/security-ownership-map/scripts/query_ownership.py --data-dir ownership-map-out people --sort sensitive_touches --limit 10

# 共変更する近傍ファイル（所有関係の変化を把握するためのクラスタの手掛かり）
python skills/skills/security-ownership-map/scripts/query_ownership.py --data-dir ownership-map-out cochange --file path/to/file --min-jaccard 0.05 --limit 20

# コミュニティの担当者
python skills/skills/security-ownership-map/scripts/query_ownership.py --data-dir ownership-map-out community --id 3

# 特定ファイルが属するコミュニティの月別担当者
python skills/skills/security-ownership-map/scripts/community_maintainers.py \
  --data-dir ownership-map-out \
  --file network/card.c \
  --since 2025-01-01 \
  --top 5

# 月別ではなく四半期別に集計
python skills/skills/security-ownership-map/scripts/community_maintainers.py \
  --data-dir ownership-map-out \
  --file network/card.c \
  --since 2025-01-01 \
  --bucket quarter \
  --top 5
```

注記:
- 変更回数は既定で作成者のコミットごとに1回と数える（ファイルごとではない）。ファイルごとに数えるには `--touch-mode file` を使う。
- 変動を平滑化するには `--window-days 90` または `--weight recency --half-life-days 180` を使う。
- ボットは `--ignore-author-regex '(bot|dependabot)'` で除外する。
- 安定した担当者だけを表示するには `--min-share 0.1` を使う。
- 暦上の四半期単位でまとめるには `--bucket quarter` を使う。
- 作成者ではなくコミッターに帰属させるには `--identity committer` または `--date-field committer` を使う。
- マージコミットを含めるには `--include-merges` を使う（既定では除外）。

### 要約の形式（既定）

必要に応じてフィールドを追加し、次の構造を使う:

```json
{
  "orphaned_sensitive_code": [
    {
      "path": "crypto/tls/handshake.rs",
      "last_security_touch": "2023-03-12T18:10:04+00:00",
      "bus_factor": 1
    }
  ],
  "hidden_owners": [
    {
      "person": "alice@corp",
      "controls": "認証コードの63%"
    }
  ]
}
```

## グラフの保存

CSV を Neo4j に取り込む場合は `references/neo4j-import.md` を使う。制約、Cypher によるインポート、可視化のヒントが含まれる。

## 注記

- `summary.json` の `bus_factor_hotspots` にはバス係数の低い機微なファイルが並び、`orphaned_sensitive_code` はそのうち最近変更されていないものを示す。
- `git log` が大きすぎる場合は `--since` または `--until` で期間を狭める。
- 所有関係の変化を明らかにするため、`summary.json` と CODEOWNERS を比較する。
