# ADR-0006: IaC ツールに Terraform を採用、単一環境構成

- **Status**: Proposed
- **Date**: 2026-04-25
- **Deciders**: Yusaku

## Context

OCI 上のインフラリソース（VCN・Container Instance・LB・PostgreSQL VM・Vault・IAM 等）をコードで管理する必要がある。

- 担当者は Terraform の運用経験あり
- 環境は単一（dev / prod 分離なし、検証はローカルで実施）
- 同一リポジトリ内（モノレポ）で管理する

## Decision

**Terraform** を IaC ツールとして採用する。  
ディレクトリ構成は以下のようにシンプルに保つ：

```
terraform/
├── modules/             # 必要に応じてモジュール化
│   ├── network/
│   ├── container_app/
│   ├── postgres_vm/
│   └── ...
└── main.tf              # ルートモジュール、モジュールを呼び出す
```

`envs/` のような環境別ディレクトリは作らない（単一環境のため）。state は OCI Object Storage に保管する。

## Alternatives Considered

### 環境別ディレクトリ構成（envs/dev、envs/prod）

- **不採用理由**: 環境が単一のため、ディレクトリ階層を増やすメリットがない

### Pulumi 等の手続き型 IaC

- **不採用理由**: チームの Terraform 経験が活かせる、OCI Provider の成熟度・コミュニティ事例ともに Terraform が優位

### OCI Resource Manager

- **不採用理由**: GitHub Actions 主導の CI/CD（ADR-0007）と統合する場合、Terraform CLI を直接叩く運用が自然

### state を Local や Git 管理

- **不採用理由**: state ファイルにはセンシティブ情報が含まれる可能性があり、Git にコミットするのは不適切。Object Storage バックエンドのセットアップは一度きり

## Consequences

### Positive

- 既存の Terraform 知識をそのまま流用できる
- シンプルなディレクトリ構成で見通しが良い
- state を Object Storage に保管することで、複数マシンからの操作が可能

### Negative / Trade-off

- 後から複数環境に拡張する場合、ディレクトリ構成の見直しが必要
- state ファイルの管理が必要（破壊的操作時のバックアップ等）

### Neutral

- 個人アプリでは「動くことを優先」とし、モジュール化は必要に応じて段階的に進める
- 会社プロジェクトとは別リポジトリのため、コードの共通化は行わない（ADR・運用ノートで知識を共有）
