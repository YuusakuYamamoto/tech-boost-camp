# ADR-0002: PostgreSQL は VM 上の Docker でセルフホスト運用

- **Status**: Proposed
- **Date**: 2026-04-25
- **Deciders**: Yusaku

## Context

アプリケーションの DB は PostgreSQL である前提。OCI 上にホストする方法として、主に以下の選択肢がある：

- **OCI Database with PostgreSQL**（マネージド）
- **Compute VM 上にセルフホスト**（Docker 経由含む）

コスト：マネージドは月 $200〜250 程度、セルフホスト（Ampere A1 Always Free + Block Volume）は月数ドル。

個人アプリの前提：

- 月数ドル以内のコスト目標
- データの「失っても致命的ではない度合い」が比較的高い（仲間内利用、万一データ消失しても「ごめんね」で済む）
- 担当者は同種の構成を会社プロジェクトでも検討中で、運用知識を計画的に蓄積したい
- 利用者数が少なく、HA 要件は低い

## Decision

**VM 上の Docker でセルフホスト** で運用する。会社プロジェクトと異なり、移行トリガは設けない（永続的にセルフホスト）。

### 構成

| 項目                | 内容                                             |
| ------------------- | ------------------------------------------------ |
| VM シェイプ         | Ampere A1 Flex（1 OCPU + 6 GB、Always Free 枠内）|
| OS                  | Oracle Linux 9（ADR-0018 参照）                  |
| PostgreSQL 起動方法 | 公式 Docker イメージを `docker compose` で起動   |
| データ配置          | Block Volume（50 GB、専用）に `/mnt/pgdata` でマウント |
| バックアップ        | `pg_dumpall` を cron で日次取得 → Object Storage |
| バックアップ保持    | 7 日分ローテーション                             |

データ用の Block Volume を OS ボリュームとは別に分離することで、VM が壊れても別 VM にデータを引き継げる構成にする。

## Alternatives Considered

### マネージド PostgreSQL を採用

- **不採用理由**:
  - 月 $200〜250 のコストが目標（数ドル）と桁違い
  - 利用者数・データ重要度から見てマネージドの恩恵が必要な水準ではない

### apt / dnf で PostgreSQL を VM 上に直接インストール

- **不採用理由**:
  - PostgreSQL のバージョン変更・設定変更が OS 依存になる
  - 担当者が Docker に習熟しているため、Docker 経由のほうが扱いやすい
  - ローカル開発環境（docker-compose）との構成差を最小化できる

### Container Instance 内で PostgreSQL を動かす

- **不採用理由**:
  - Container Instances のエフェメラルストレージ（15 GB）を超えるデータは扱えない
  - 永続データを持たせる用途には不向き
  - データ永続化のために結局 Block Volume が必要

## Consequences

### Positive

- 月額 DB コストが Block Volume 代の数ドル程度に収まる
- Docker ベースなので、ローカル開発環境（docker-compose）と本番セルフホストの構成差を最小化できる
- PostgreSQL 運用経験を積める
- データ用 Block Volume を OS ボリュームと分離しているため、VM 自体に問題が起きてもデータの復旧が可能

### Negative / Trade-off

PostgreSQL 関連の運用作業が発生する：

- **週次**: バックアップ正常動作の確認、ログ目視、ディスク使用量確認
- **月次**: OS パッチ適用（VM のリブートを伴うため作業時間外、1〜2 時間）
- **年に数回**: PostgreSQL のマイナーバージョンアップ
- **突発**: ディスク満杯、接続数枯渇、VM ホスト障害等への対応

その他のトレードオフ：

- ハードウェア障害時の自動フェイルオーバーがない
- HA 構成が提供されない
- データ消失時のリスクは自己責任

### Neutral

- データの「失っても致命的ではない」前提でのみ成立する構成
- バックアップから復旧する手順を月 1 回程度試すことで、運用知識を計画的に獲得する
