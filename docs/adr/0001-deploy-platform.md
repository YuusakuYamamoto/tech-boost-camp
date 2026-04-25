# ADR-0001: デプロイプラットフォームに OCI Container Instances を採用

- **Status**: Proposed
- **Date**: 2026-04-25
- **Deciders**: Yusaku

## Context

個人アプリケーション（Next.js + NestJS + PostgreSQL）を OCI 上にデプロイする必要がある。前提条件は以下：

- 担当者は Docker・Terraform の運用経験あり、Kubernetes の運用経験はなし
- 利用ユーザーは仲間内（数名）に限定。同時アクセスは数名程度
- 認証付きパブリック公開（allowlist による制御）
- コスト目標は月数ドル以内
- 個人 OCI テナンシーで運用するため Always Free 枠を最大限活用したい

OCI における選択肢として、Compute VM / Container Instances / OKE（Kubernetes）が候補となる。

## Decision

**OCI Container Instances**（serverless container 実行環境）を採用する。  
Next.js（フロント）と NestJS（バックエンド）をそれぞれ独立した Container Instance として起動し、前段に OCI Public Load Balancer を配置する 3 層構成とする（DB は別途 ADR-0002 参照）。

シェイプは Ampere A1（Arm64）を選択し、Always Free 枠を活用する。

## Alternatives Considered

### Compute VM + Docker Compose

1 台の VM に全コンテナを同居させる最小構成。
- **不採用理由**: Docker のレイヤがあるとはいえ、VM 自体の OS パッチ管理・プロセス管理が増える。Container Instances なら OS レイヤを意識せずに済む。

### OCI OKE（Kubernetes）

- **不採用理由**: 個人アプリの規模に対して過剰。K8s 運用経験もない。

### Compute VM + Container Instances 混在（DB は VM、アプリは Container Instances）

これは ADR-0002 で採用する構成と一致するため、Compute VM の利用は DB に限定する。

## Consequences

### Positive

- Always Free 枠（Ampere A1: 月 3,000 OCPU 時間 + 18,000 GB 時間）でほぼ運用可能
- Docker イメージの差し替えだけでデプロイが完結（VM の OS 管理は不要）
- 後でアプリ規模が拡大しても、シェイプ変更で対応可能

### Negative / Trade-off

- ECS の Service にあたるオーケストレーション層がない（Container Instance 差し替えは自前スクリプト、ADR-0011 参照）
- 水平オートスケールの標準機能なし
- ECS Fargate のような Vault シークレット直接注入は不可（ADR-0015 参照）

### Neutral

- 将来 OKE への移行が必要になっても、コンテナイメージ自体は変更不要で再利用可能
