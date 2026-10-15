# ADR-0011: アプリケーションの入れ替えは Docker Compose の再作成で行う

- **Status**: Proposed
- **Date**: 2026-04-25
- **Deciders**: Yusaku

> **改訂（2026-10-15）**: ADR-0001 の改訂（Container Instances → Compute VM + Docker Compose）に伴い、全面的に書き換えた。当初は Container Instance を差し替えるパターン A（`scripts/deploy.sh`）を定めていたが、実行基盤が変わったため前提ごと変更している。

## Context

新しいイメージをリリースする際の、実行中コンテナの入れ替え方を決める必要がある。

アプリは `tbcamp-app-vm`（Compute VM）上で Docker Compose により実行する（ADR-0001）。LB のバックエンドには**この VM の固定プライベート IP** が登録される。

ここが Container Instances との決定的な違いになる。

| | Container Instances | Compute VM + Compose |
| -- | ------------------- | -------------------- |
| イメージの差し替え | インスタンスの再作成が必須（イミュータブル） | コンテナの再作成。ホストは変わらない |
| LB バックエンドの IP | インスタンスごとに変わる | **変わらない** |
| 入れ替え時の LB 操作 | バックエンドの登録変更が必要 | **不要** |

Container Instances の更新 API（`UpdateContainerInstance` / `UpdateContainer`）が受け付けるのは `displayName` とタグのみで、イメージ URL・環境変数・起動コマンドを変更する経路がない。これが「イミュータブル」と言える根拠である。

<!-- Docs: https://docs.oracle.com/en-us/iaas/tools/python/latest/api/container_instances/models/oci.container_instances.models.UpdateContainerInstanceDetails.html -->
<!-- Docs: https://docs.oracle.com/en-us/iaas/tools/python/latest/api/container_instances/models/oci.container_instances.models.UpdateContainerDetails.html -->

**LB のバックエンド登録がデプロイのたびに変化しない**ため、当初 ADR が定めていた「新インスタンス起動 → ヘルスチェック → バックエンド差し替え → 旧削除」という手順そのものが不要になる。

利用者は仲間内であり、数十秒のダウンタイムは許容できる。

## Decision

**`docker compose pull` + `docker compose up -d` による再作成**で入れ替える。

### 手順

1. 新しいイメージタグを反映した `docker-compose.yml` を `tbcamp-config` バケットにアップロードする
2. アプリ VM 上で設定を再取得し、コンテナを再作成する

```bash
sudo systemctl restart tbcamp-app-bootstrap.service
```

起動スクリプトが以下を行う。

- `tbcamp-config` バケットから `docker-compose.yml` を取得
- Vault からシークレットを取得し `.env` に書き出す（ADR-0015）
- `docker compose pull` でイメージを取得
- `docker compose up -d` でコンテナを再作成

3. LB のヘルスチェックが healthy に戻ることを確認する

### イメージタグの扱い

`latest` は使わない。`docker-compose.yml` に具体的なタグを記述し、バケットのバージョニングで履歴を残す。ロールバックは旧タグの compose をアップロードして再起動するだけで済む。

### Terraform の責務

Terraform が管理するのは VM・NSG・LB バックエンド登録までとする。**コンテナの入れ替えは Terraform の管轄外**である。アプリのリリースのたびに Terraform を流す必要はない。

`docker-compose.yml` を Terraform で `tbcamp-config` バケットに配置する場合（`postgres_vm` の `oci_objectstorage_object.compose` と同じ形）、イメージタグの変更が Terraform の差分として現れる。この扱いは Phase 8 の CD 設計で決める。

## Alternatives Considered

### パターン A: 新インスタンスを起動してから LB バックエンドを差し替える（当初の決定）

Container Instances を前提とした方式。新 Container Instance を起動し、backend-health API をポーリングして healthy になってから LB バックエンドセットを差し替え、旧インスタンスを削除する。

- **不採用理由**:
  - 実行基盤を Compute VM に変更したため、前提が消滅した（ADR-0001）
  - VM 上では LB バックエンドの IP が変わらないため、差し替える対象がない
  - ヘルスチェックを待ってから切り替える意義は、コンテナ再作成の数秒〜数十秒に対して見合わない

### パターン B: Blue/Green（常時 2 系統を稼働）

- **不採用理由**:
  - アプリ VM をもう 1 台増やすことになり、A1 枠（4 OCPU / 24 GB）の残りが 1 OCPU / 6 GB になる。将来の拡張余地が狭まる
  - 個人アプリでダウンタイム数十秒は許容できる
  - 必要になった時点で、アプリ VM を 1 台追加して LB バックエンドに登録すれば移行できる

### ゼロダウンタイムを狙って同一 VM 上で新旧コンテナを並走させる

ポートを変えて新コンテナを起動し、LB バックエンドのポートを切り替える方式。

- **不採用理由**:
  - LB バックエンドの `port` は更新不可（非 Updatable）で、差し替えにはリソースの再作成が必要
  - 切り替えの順序制御を自前で書くことになり、得られるものに対して複雑すぎる

## Consequences

### Positive

- **LB の構成がデプロイに影響されない**。バックエンド登録は一度行えば以降変化しない
- 入れ替え手順が `systemctl restart` の 1 コマンドに収まる
- ロールバックは旧タグの compose を置き直すだけ
- `postgres_vm` の `postgres-bootstrap.service` と同じ型のため、仕組みが 2 箇所で共通になる

### Negative / Trade-off

- コンテナ再作成の間（数秒〜数十秒）、LB がヘルスチェックに失敗して 502 を返す
- frontend と backend が同じ Compose に属するため、**片方だけを入れ替えることが難しい**。両方が同時に再作成される
- VM 自体が異常終了した場合の自動復旧はない。Docker の restart policy と systemd で部分的に補う

### Neutral

- 現時点では手動の `systemctl restart` を前提とする。自動化（イメージのビルド、OCIR への push、VM 上での再起動）は Phase 8 の CD パイプラインで扱う
- 将来 Container Instances の容量が確保できるようになった場合、本 ADR の方式は使えなくなる。そのときは ADR-0001 とあわせて再検討する
