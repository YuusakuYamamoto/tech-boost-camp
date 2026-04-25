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

のどちらかでのみ可能。NAT Gateway は時間課金で月 $32 程度の固定費が発生する。一方 Service Gateway は無料。

担当者は Ubuntu の方が習熟しているが、コスト目標（月数ドル）を踏まえると、NAT Gateway 回避によるコスト削減の優先度が高い。

## Decision

**Oracle Linux 9** を VM の OS として採用する。OS パッチ・パッケージ更新は **Service Gateway 経由で OCI 内の Oracle Linux ミラー**から取得する。NAT Gateway は立てない（ADR-0004）。

## Alternatives Considered

### Ubuntu を採用 + NAT Gateway

- **不採用理由**:
  - NAT Gateway の固定費（月 $32）が、コスト目標（月数ドル）に対して大きすぎる
  - 個人アプリは外部 API 連携を想定しておらず、NAT Gateway 用途が OS パッチに限定される
  - Service Gateway 経由でパッチ取得が無料でできるなら、その方が筋が良い

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

- NAT Gateway 不要になり、月 $32 のコスト削減
- OCI 内ミラーから OS パッチを取得するため、ネットワーク経路が短く、egress 課金もない
- Oracle Linux は OCI で純正サポートされており、トラブル時のドキュメントが豊富

### Negative / Trade-off

- 担当者の Ubuntu 習熟度が活かせない（dnf / yum と systemd の操作を新規に覚える必要）
- Ubuntu の `apt` ベースのドキュメント・サンプルをそのまま流用できない
- Docker 自体は Oracle Linux 上でも問題なく動作するため、PostgreSQL 運用への影響は限定的

### Neutral

- 外部 API 連携が必要になった時点で NAT Gateway を後付けで立てる選択肢は残る（その場合、NAT Gateway 経由でのパッチ取得も併用可）
- Container Instance 側の OS は OCI 管理であり、本決定の影響範囲外
