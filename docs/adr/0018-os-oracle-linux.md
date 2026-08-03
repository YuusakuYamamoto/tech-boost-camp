# ADR-0018: DB VM の OS に Oracle Linux を採用

- **Status**: Proposed
- **Date**: 2026-04-25
- **Deciders**: Yusaku

## Context

PostgreSQL を稼働させる Compute VM（ADR-0002）の OS として、複数の選択肢がある：

- **Oracle Linux**: OCI 上で純正サポート、OCI 内部に専用ミラーが存在
- **Ubuntu**: 一般的、Docker・PostgreSQL の公式情報が豊富
- **Rocky Linux / AlmaLinux**: RHEL 系の代替

OS 選定で重要な観点は **OS パッケージリポジトリへのアクセス経路**。VM 上で `apt update` / `dnf update` 等を実行すると、外部のパッケージリポジトリへの通信が発生する。これは VCN 内のプライベートサブネットからは、

- **NAT Gateway 経由**（外部インターネット）
- **Service Gateway 経由**（OCI 内ミラー）

のどちらかでのみ可能。Service Gateway は無料。NAT Gateway は従量課金（$0.0025/GB のデータ処理料）で固定費は発生しない。

担当者は Ubuntu の方が習熟しているが、OS パッチを無料・高速で取得できる Service Gateway 経由を優先し、Oracle Linux を採用する。なお Docker Hub からの PostgreSQL イメージ取得には NAT Gateway が必要だが（ADR-0004 参照）、OS パッチとは経路を分けて管理する。

## Decision

**Oracle Linux 9** を VM の OS として採用する。OS パッチ・パッケージ更新は **Service Gateway 経由で OCI 内の Oracle Linux ミラー**から取得する（egress 課金ゼロ）。Docker Hub からの PostgreSQL イメージ取得のみ NAT Gateway 経由とし、OS パッチとは経路を分けて管理する（ADR-0004）。

## Alternatives Considered

### Ubuntu を採用 + NAT Gateway

- **不採用理由**:
  - NAT Gateway が追加されたことで Ubuntu も技術的には選択可能になったが、引き続き Oracle Linux を優先する
  - Oracle Linux では OS パッチを Service Gateway 経由（egress 課金ゼロ）で取得でき、NAT Gateway 経由より高速・安価
  - OCI での純正サポートおよびドキュメントが充実しており、トラブル対応が容易
  - すでに Terraform / cloud-init が Oracle Linux 前提で構築済みであり、Ubuntu への移行コストに見合うメリットがない

### Ubuntu を採用 + パッチ手動適用（ローカルから SSH 経由）

- **不採用理由**:
  - 現実的な運用ではない（SSH トンネルや一時的な NAT Gateway 立て直しが必要）
  - 手間が大きく、結局自動化したくなる

### Rocky Linux / AlmaLinux

- **不採用理由**:
  - OCI 内に専用ミラーが整備されているか不明（要検証）
  - Oracle Linux と RHEL 互換であり、選定する積極的な理由がない
  - Oracle Linux は OCI で純正サポートされており、選択が素直

## Consequences

### Positive

- OS パッチは Service Gateway 経由（OCI 内ミラー）で取得するため、ネットワーク経路が短く egress 課金もない
- Oracle Linux は OCI で純正サポートされており、トラブル時のドキュメントが豊富
- Docker Hub 経由の PostgreSQL イメージ取得には NAT Gateway を使うが、OS パッチ経路と役割を分けることでコストを最小化

### Negative / Trade-off

- 担当者の Ubuntu 習熟度が活かせない（dnf / yum と systemd の操作を新規に覚える必要）
- Ubuntu の `apt` ベースのドキュメント・サンプルをそのまま流用できない
- Docker 自体は Oracle Linux 上でも問題なく動作するため、PostgreSQL 運用への影響は限定的

### Neutral

- Container Instance 側の OS は OCI 管理であり、本決定の影響範囲外
