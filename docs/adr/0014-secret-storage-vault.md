# ADR-0014: シークレットストレージに OCI Vault を採用

- **Status**: Proposed
- **Date**: 2026-04-25
- **Deciders**: Yusaku

## Context

アプリケーションが扱うシークレットには以下が含まれる：

- DB 接続パスワード（セルフホスト PostgreSQL）
- Google OAuth クライアントシークレット（ADR-0016）
- セッション暗号化キー
- OCIR イメージ pull 認証（必要に応じて）

これらを安全に保管・管理するためのストレージが必要。OCI 上で利用可能な選択肢として：

- **OCI Vault**: OCI ネイティブのキー・シークレット管理サービス
- **HashiCorp Vault のセルフホスト**: 自前運用
- **環境変数で IaC コード内に暗号化埋め込み**

がある。

## Decision

**OCI Vault** を採用する。Vault は 1 つで運用する（環境分離なし）。

構造：

- **Vault**: シークレットおよび鍵の入れ物
- **Master Encryption Key (MEK)**: シークレット暗号化用の鍵（Software 保護モードで作成、コスト抑制のため）
- **Secret**: 個別のシークレット（バージョン管理される）

## Alternatives Considered

### HashiCorp Vault のセルフホスト

- **不採用理由**: Vault サーバ自体の運用負担が大きく、個人アプリの規模に対して過剰

### IaC コード内に暗号化埋め込み（SOPS 等）

- **不採用理由**:
  - シークレット更新のたびに Git コミット・デプロイが必要
  - リソースプリンシパル経由の自動取得ができない

## Consequences

### Positive

- マネージドサービスのため運用負担が小さい
- Container Instances / VM からリソースプリンシパル認証で取得可能（API キー不要）
- バージョン管理されており、過去バージョンへのロールバックも可能
- Terraform で管理できる（初期値設定に限る）

### Negative / Trade-off

- ECS Fargate のような「task definition で Secret OCID を指定 → 環境変数に自動展開」機能がない（ADR-0015 で別途設計）
- Vault サービス自体は無料だが、MEK のコスト・シークレット数に応じた月額が発生（小規模なら無視できる範囲）

### Neutral

- ローカル開発時は Vault を使わず、`.env.local` ファイルでシークレットを管理
