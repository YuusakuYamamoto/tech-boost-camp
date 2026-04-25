# ADR-0009: CI/CD パイプラインを役割別に分離

- **Status**: Proposed
- **Date**: 2026-04-25
- **Deciders**: Yusaku

## Context

モノレポでインフラコード（Terraform）とアプリコード（Next.js / NestJS）が同居する構成。CI/CD を組む際、

- 全変更で同じパイプラインを動かす
- 役割ごとにパイプラインを分離する

の選択肢がある。インフラ変更とアプリ変更は実行内容が大きく異なる（前者は `terraform plan/apply`、後者は Docker build + Container Instance 差し替え）ため、混在させると無駄な実行・事故が発生しやすい。

## Decision

CI/CD パイプラインを以下の単位で分離する：

| パイプライン                       | トリガパス             | 内容                                                             |
| ---------------------------------- | ---------------------- | ---------------------------------------------------------------- |
| `infra.yml`                        | `terraform/**`         | `terraform plan` → `terraform apply`                             |
| `frontend.yml`                     | `apps/frontend/**`     | テスト・lint → Docker build → OCIR push → Container Instance 差替 |
| `backend.yml`                      | `apps/backend/**`      | テスト・lint → Docker build → OCIR push → Container Instance 差替 |

GitHub Actions の `paths` フィルタで、変更箇所に応じた適切なパイプラインのみが起動する。

会社プロジェクトと異なり、環境次元（dev / prod）はないため、パイプラインの軸は役割のみ。

## Alternatives Considered

### 単一パイプラインで全変更を扱う

- **不採用理由**:
  - フロント変更だけの時に backend のビルドまで走るのは無駄
  - インフラ変更とアプリデプロイが同時に走ると、変更の影響範囲が読みにくい

## Consequences

### Positive

- 変更箇所に応じた最小限の処理のみ実行される
- 障害時のパイプライン特定が容易
- インフラ変更とアプリデプロイが独立して実行される

### Negative / Trade-off

- フロントとバックを同時に変更する PR では 2 つのパイプラインが並行起動する
- パイプライン定義の重複（イメージビルド・push 部分）が発生する。共通化が必要になれば再利用可能ワークフローに切り出す

### Neutral

- テストや他チェックは将来追加しても良い（lint / 型チェック / セキュリティスキャン等）
