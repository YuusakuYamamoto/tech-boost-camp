# ADR-0007: CI/CD プラットフォームに GitHub Actions を採用

- **Status**: Proposed
- **Date**: 2026-04-25
- **Deciders**: Yusaku

## Context

ソースコードは GitHub（個人アカウント）で管理している。CI/CD の選択肢として、

- GitHub Actions（GitHub 標準）
- OCI DevOps（Oracle 純正の CI/CD サービス）
- Jenkins / CircleCI 等のサードパーティ製

要件は以下：

- インフラ構築（Terraform）とアプリケーションデプロイ（Container Instance 差し替え）の両方を扱う
- 月次無料枠を使い切った場合に手動デプロイにも切り替えられる構成にしたい
- リポジトリ内に CI/CD 定義を置きたい

## Decision

**GitHub Actions** を CI/CD プラットフォームとして採用する。  
ワークフロー定義は `.github/workflows/` 配下に配置する。  
無料枠超過時の手動運用にも対応できるよう、デプロイ処理の本体は `scripts/deploy.sh` 等のスクリプトに切り出し、ワークフロー側はスクリプト呼び出しに徹する。

## Alternatives Considered

### OCI DevOps

- **不採用理由**:
  - ソースコードが GitHub にあるため、トリガ管理・コード取得は GitHub Actions が自然
  - OCI DevOps の運用知見がない

### Jenkins 等の自前ホスト型

- **不採用理由**:
  - CI/CD 基盤自体の運用負担を取り込む必要がある
  - 個人アプリの規模に対して過剰

## Consequences

### Positive

- ソースコードと CI/CD 定義が同じリポジトリで一元管理される
- Pull Request との統合・差分検証が自然
- 標準的な選択肢のため、知見・サンプルが豊富

### Negative / Trade-off

- 月次無料枠を超えると課金されるか実行が止まる
- GitHub-hosted runner は VCN 内のプライベート IP に到達できないため、ヘルスチェック等は OCI API を経由する必要がある（ADR-0012 参照）

### Neutral

- デプロイ処理本体をスクリプトに切り出すことで、無料枠超過時にローカルからスクリプトを直接実行する手段を確保している
