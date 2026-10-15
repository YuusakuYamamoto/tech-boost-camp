# ADR-0001: デプロイプラットフォームに Compute VM + Docker Compose を採用

- **Status**: Proposed
- **Date**: 2026-04-25
- **Deciders**: Yusaku

> **改訂（2026-10-15）**: 当初は OCI Container Instances を採用していたが、Phase 7 Step 10 で A1 シェイプの容量が確保できないことが判明したため、Compute VM + Docker Compose に変更した。経緯は Context の「Phase 7 Step 10 での容量問題」を参照。

## Context

個人アプリケーション（Next.js + NestJS + PostgreSQL）を OCI 上にデプロイする必要がある。前提条件は以下：

- 担当者は Docker・Terraform の運用経験あり、Kubernetes の運用経験はなし
- 利用ユーザーは仲間内（数名）に限定。同時アクセスは数名程度
- 認証付きパブリック公開（allowlist による制御）
- コスト目標は月数ドル以内
- 個人 OCI テナンシーで運用するため Always Free 枠を最大限活用したい

OCI における選択肢として、Compute VM / Container Instances / OKE（Kubernetes）が候補となる。

### Phase 7 Step 10 での容量問題（2026-10-15 追記）

当初の決定（Container Instances + Ampere A1）に従って実装し、apply したところ以下で失敗した。

```
Error: 400-InvalidParameter, OutOfCapacity for CI.Standard.A1.Flex
Request Target: POST .../20210415/containerInstances
```

再試行しても同じ結果だった。`400-InvalidParameter` と返るが**設定の誤りではなく、リージョンの在庫不足**である。OCI が権限不足を 404 で返すのと同じく、エラーの分類と実際の原因が一致しない例。

容量レポート API で Compute VM 側を確認した。

```bash
oci compute compute-capacity-report create \
  --availability-domain "oFBl:AP-TOKYO-1-AD-1" \
  --compartment-id "<tenancy OCID>" \
  --shape-availabilities file://shape-availabilities.json
```

<!-- Docs: https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/cmdref/compute/compute-capacity-report/create.html -->

| シェイプ | 構成 | 結果 |
| -------- | ---- | ---- |
| `VM.Standard.A1.Flex` | 1 OCPU / 6 GB | `AVAILABLE` |
| `VM.Standard.A1.Flex` | 1 OCPU / 1 GB | `AVAILABLE` |
| `VM.Standard.A1.Flex` | 3 OCPU / 18 GB | `AVAILABLE` |

Always Free の A1 枠（4 OCPU / 24 GB）も、PostgreSQL VM が 1 OCPU / 6 GB を使っているのみで残っている。**枠はあるが、Container Instances としては確保できない**という状況である。

したがって「Ampere A1 の Always Free 枠を Container Instances で活用する」という当初の前提は、ap-tokyo-1 では成立しない。

補足: この容量レポート API は Compute 用で、`CI.Standard.A1.Flex` を指定すると `NotAuthorizedOrNotFound`（404）が返る。Container Instances の在庫は事前確認できない。

## Decision

**Compute VM 上の Docker Compose** でアプリケーションを実行する。

### 構成

| VM | シェイプ | 役割 |
| -- | -------- | ---- |
| `tbcamp-app-vm` | `VM.Standard.A1.Flex` 1 OCPU / 6 GB | Next.js（:3000）と NestJS（:4000）のコンテナを Docker Compose で実行 |
| `tbcamp-postgres-vm` | `VM.Standard.A1.Flex` 1 OCPU / 6 GB | PostgreSQL（ADR-0002。既存・変更なし） |

合計 2 OCPU / 12 GB で、Always Free の A1 枠（4 OCPU / 24 GB）に収まる。

いずれもプライベートサブネットに配置し、前段に OCI Public Load Balancer を置く 3 層構成とする（ADR-0005）。アプリ VM には固定のプライベート IP を割り当て、LB のバックエンドとして登録する。

### `postgres_vm` の型を踏襲する

アプリ VM は `modules/postgres_vm/` で確立した構成をそのまま使う。

- `docker-compose.yml` は cloud-init に埋め込まず、`tbcamp-config` バケットに置いて起動時に取得する（`metadata` が ForceNew 属性のため）
- シークレットはホストの起動スクリプトが Vault から取得し `.env` に書き出す（ADR-0015）
- 起動処理は systemd の oneshot ユニットに委譲する（cloud-init は初回起動時にしか走らないため）

## Alternatives Considered

### OCI Container Instances（当初の決定）

serverless なコンテナ実行環境。OS レイヤを意識せずに済む点が魅力だった。

- **不採用理由**:
  - **`CI.Standard.A1.Flex` の容量が確保できない**（Context 参照）。Always Free 枠が残っていても在庫がなければ作成できない
  - x86 シェイプ（`CI.Standard.E4.Flex`）には Ampere A1 のような無料枠がない。1 OCPU / 4 GB を 24/7 で動かすと月約 ¥3,575（Cost Estimator 実測）で、Budget $10 の 2.4 倍になる
  - 永続ディスクを接続できないため、どのみち PostgreSQL は VM に置く必要がある。「OS レイヤを意識せずに済む」という利点は、DB 用 VM が残る以上は半分しか得られない

### Compute VM 1 台にアプリと DB を同居

既存の PostgreSQL VM を 3 OCPU / 18 GB に拡張し、全コンテナを同居させる構成。容量は `AVAILABLE` で確認済み。

- **不採用理由**:
  - Next.js の SSR は CPU を消費する。同一 VM で PostgreSQL と競合すると、クエリ応答が不安定になる
  - VM 障害時にアプリと DB が同時に停止する
  - 既存の稼働中 VM を拡張する必要があり、再起動を伴う
  - VM 2 台でも Always Free 枠に収まるため、分離を諦める理由がない

### OCI OKE（Kubernetes）

- **不採用理由**: 個人アプリの規模に対して過剰。K8s 運用経験もない。

## Consequences

### Positive

- Always Free 枠（Ampere A1: 4 OCPU / 24 GB）の範囲で運用でき、コストは増えない
- `postgres_vm` で確立した型（Object Storage からの設定配布、Instance Principal でのシークレット取得、systemd による復旧）をそのまま再利用できる。新規に設計する要素が少ない
- アプリと DB が別 VM のため、リソース競合と障害の波及を避けられる
- Container Instances の在庫状況に左右されない

### Negative / Trade-off

- **OS の管理対象が 1 台増える**。パッチ適用、ディスクの枯渇対策、ログのローテーションを 2 台分行う必要がある。ただし `dnf-automatic` と cron で自動化でき、1 台目でやることを繰り返すだけで新しい種類の作業は増えない
- Container Instances が提供する自動復旧（`container_restart_policy`）は得られない。Docker の restart policy と systemd で代替する
- アプリ VM は `tbcamp-app-instances` Dynamic Group に属し、Vault と OCIR へのアクセス権を持つ。**ホストが侵害された場合の影響範囲は Container Instances より広い**。コンテナ自身には資格情報を持たせない設計で緩和する（ADR-0015、ADR-0022）

### Neutral

- 将来 Container Instances の容量が確保できるようになった場合、コンテナイメージはそのまま再利用できる。ただし移行は LB のバックエンド登録先の差し替えだけでは済まず、入れ替え方式（ADR-0011）とシークレット注入（ADR-0015）もあわせて見直すことになる
- 「VM + Docker Compose + 設定配布 + 自動復旧」という型を 2 回構築することになる。社内システムへの転用という観点では、この型のほうが応用範囲が広い
