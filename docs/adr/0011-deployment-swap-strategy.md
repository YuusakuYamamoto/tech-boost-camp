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

## Decision

**パターン A** で運用する。各役割の Container Instance は常時 1 つとし、デプロイは以下の手順を実行する `scripts/deploy.sh` で行う：

1. 新 Container Instance を新イメージタグで起動
2. OCI LB の backend-health API をポーリングして healthy になるまで待機
3. LB バックエンドセットに新 Backend を追加
4. 旧 Backend を LB から削除
5. 旧 Container Instance を削除

タグ管理: 新規作成時は `role=new`、切替成功後に `role=current` に昇格させ、現役インスタンスを識別可能にする。

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
