# ADR-0011: Container Instance 切替方式（パターン A・割り切り型）

- **Status**: Proposed
- **Date**: 2026-04-25
- **Deciders**: Yusaku

## Context

Container Instances は ECS の Service に相当するオーケストレーション機構を持たない。デプロイ時の Container Instance 差し替えは自前で設計する必要がある。

選択肢：

- **パターン A（割り切り型）**: 各役割の Container Instance は 1 つ。新インスタンスを起動し、ヘルスチェック後に LB バックエンドセットを差し替え、旧インスタンスを停止
- **パターン B（Blue/Green 型）**: 各役割で常時 2 インスタンスを稼働させ、LB のバックエンドセットでローテーション

個人アプリで、利用者が仲間内であり、数十秒のダウンタイムは許容できる。

### Phase 7 Step 10 時点での確認（2026-10-10 追記）

OCI Container Instances は**イミュータブル**であることを API リファレンスで確認した。既存のインスタンスに対する更新 API（`UpdateContainerInstance` / `UpdateContainer`）が受け付けるのは `displayName` / `freeformTags` / `definedTags` のみで、**イメージ URL・環境変数・起動コマンドを変更する経路が存在しない**。

<!-- Docs: https://docs.oracle.com/en-us/iaas/tools/python/latest/api/container_instances/models/oci.container_instances.models.UpdateContainerInstanceDetails.html -->
<!-- Docs: https://docs.oracle.com/en-us/iaas/tools/python/latest/api/container_instances/models/oci.container_instances.models.UpdateContainerDetails.html -->

したがってイメージの差し替えは常に「新しい Container Instance の作成 + 旧インスタンスの削除」になる。ECS のタスク定義のように「リソースを維持したまま中身だけ差し替える」形は取れない。本 ADR が新インスタンス起動 → ヘルスチェック → 切替 → 旧削除という手順を定めているのは、この制約への対応である。

## Decision

**パターン A** で運用する。各役割の Container Instance は常時 1 つとし、デプロイは以下の手順を実行する `scripts/deploy.sh` で行う：

1. 新 Container Instance を新イメージタグで起動
2. OCI LB の backend-health API をポーリングして healthy になるまで待機
3. LB バックエンドセットに新 Backend を追加
4. 旧 Backend を LB から削除
5. 旧 Container Instance を削除

タグ管理: 新規作成時は `role=new`、切替成功後に `role=current` に昇格させ、現役インスタンスを識別可能にする。

### Phase 7 での扱い（2026-10-10 追記）

**Phase 7（インフラ構築）の段階では Container Instance を Terraform で管理する。`scripts/deploy.sh` の実装は CD パイプラインの構築（Phase 8 以降）に合わせて行う。**

理由は、アプリケーション本体と OCIR のイメージがまだ存在せず、リリース手順を設計する材料が揃っていないため。インフラの到達点（LB からバックエンドに疎通すること）の確認を優先する。

`modules/container_app/` で Container Instance を作成し、LB バックエンドに登録する。イメージタグはルートモジュールの変数として受け取る。`image_url` は変更時に置き換えが発生する属性のため、**タグ変数を書き換えて apply するだけでインスタンスの入れ替えが成立する**。`-replace` の経路を別途用意する必要はない。ダウンタイムを抑えるため `lifecycle { create_before_destroy = true }` を付ける。

Phase 8 で上記手順 1〜5 の `deploy.sh` に移行する場合は、`terraform state rm` で Container Instance をステートから外したうえでモジュールを削除する。Terraform 管理のまま継続する場合は変更不要。

## Alternatives Considered

### パターン B（Blue/Green）を最初から採用

- **不採用理由**:
  - Container Instance を常時 2 台稼働させるためコストが約 2 倍
  - 個人アプリでダウンタイム数十秒は許容できる
  - 後からパターン B に移行する場合も「Container Instance を 1 つ追加して LB バックエンドセットに登録」で済む

### Terraform で Container Instance のライフサイクル全てを管理

- **不採用理由**:
  - 「ヘルスチェック待ち → LB 更新 → 旧停止」のような順序付き手続きと相性が悪い
  - インフラのライフサイクル管理（Terraform）とアプリのデプロイ（スクリプト）は責務を分けるのが自然

### Terraform で作成し、イメージタグを `ignore_changes` で無視する（ECS 型）

Terraform がリソースを保持したまま、CD パイプラインがイメージだけを差し替える形。AWS ECS では `lifecycle { ignore_changes = [task_definition] }` として広く使われている。

- **不採用理由**: OCI Container Instances では成立しない。Context に記載のとおりイメージを変更する更新 API が存在せず、差し替えは必ずインスタンスの削除と再作成になる。Terraform が追跡しているリソースそのものが消えるため、`ignore_changes` では差分を抑えられない

## Consequences

### Positive

- 構成・運用がシンプル
- コストが最小（Container Instance 1 台分のみ）
- LB ヘルスチェックで新インスタンスの起動失敗時もユーザ影響を最小化

### Negative / Trade-off

- デプロイ時に数十秒のダウンタイムが発生する可能性
- Container Instance 自体が異常終了した場合の自動再起動はない（手動対応）

### Neutral

- ロールバックは旧イメージタグを指定して `deploy.sh` を再実行するだけで可能
- Phase 7 では Terraform 管理、Phase 8 でパターン A（`deploy.sh`）に移行するかを再判断する、という二段構えになっている。移行する場合のコストは `terraform state rm` + モジュール削除の一度きりで、後戻りできない選択ではない
