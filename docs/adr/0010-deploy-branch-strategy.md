# ADR-0010: デプロイトリガに `deployment/{app}` ブランチを採用

- **Status**: Proposed
- **Date**: 2026-04-25
- **Deciders**: Yusaku

## Context

CI/CD のデプロイトリガとして、業界では複数の方式が使われている：

- **main 直 push**: main にマージしたら即デプロイ
- **tag push**: バージョンタグでデプロイ
- **専用ブランチへの push**: `deployment/{app}` のような専用ブランチへの push でデプロイ

本プロジェクトは：

- 環境は単一（dev / prod 分離なし）
- 検証はローカルで実施し、OCI 上にデプロイされた時点で公開状態
- 「デプロイしたくない」「main は進めるがデプロイは見送る」を表現したい

## Decision

**`deployment/{app}` 形式の専用ブランチへの push をデプロイトリガとする**。

具体例：

- `deployment/frontend`
- `deployment/backend`
- `deployment/infra`

各ブランチへの push は fast-forward only（rebase なし、force push なし）でルール化する。

会社プロジェクトと異なり、環境次元はないので `deployment/{app}` の 2 階層のみ。

## Alternatives Considered

### main 直 push（CD）

- **不採用理由**:
  - 「main の状態」と「OCI 上にデプロイ済みの状態」を一致させ続けるのが負担
  - 「main は進めるがデプロイは見送る」が表現できない

### tag push のみ

- **不採用理由**:
  - 個人アプリでは検証環境への素早いデプロイが必要で、tag を切る運用は儀式が重い

## Consequences

### Positive

- 「今 OCI 上に何が乗っているか」が `deployment/{app}` の HEAD で一目で分かる
- 既存の運用知見が活かせる
- main を進めながら、デプロイのタイミングは独立に制御できる

### Negative / Trade-off

- ブランチ数が増える（とはいえ 3 つ）
- force push 等の事故を防ぐため、ブランチ保護ルールの設定が必要

### Neutral

- main → `deployment/{app}` への反映は、レビュー済みの main コミットを fast-forward で進める運用とする
