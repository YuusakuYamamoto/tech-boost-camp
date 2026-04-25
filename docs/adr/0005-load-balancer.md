# ADR-0005: Public Load Balancer による HTTPS 終端とパスベースルーティング

- **Status**: Proposed
- **Date**: 2026-04-25
- **Deciders**: Yusaku

## Context

ユーザのアクセス経路に関する前提：

- 仲間内が自宅・モバイルからアクセス
- 認証は Google アカウントログイン（事前 allowlist 制御、ADR-0016）
- HTTPS 終端の位置、フロント / バックの振り分け方法、Container Instance 差し替え時のエントリポイント固定が必要

## Decision

**OCI Public Load Balancer（Flexible LB、最小帯域 10 Mbps）** を VCN 内に 1 つ配置し、以下を担わせる：

- HTTPS 終端（証明書を LB で一元管理）
- パスベースルーティング: `/api/*` → NestJS、それ以外 → Next.js
- Container Instance のヘルスチェック
- Container Instance 差し替え時のバックエンドセット切替

ドメインは 1 つに統一する。

OCI の最初の LB（10 Mbps まで）は無料枠の対象のため、本構成では LB 自体のコストはかからない。

## Alternatives Considered

### Container Instance に直接 Public IP を付与し、TLS 終端も担わせる

- **不採用理由**:
  - フロント・バックそれぞれに証明書を配布・更新する運用負担
  - Container Instance 差し替え時に DNS 切替が必要となりダウンタイムが伸びる

### フロント用ドメインとバック用ドメインを分ける（CORS 構成）

- **不採用理由**:
  - CORS 設定・プリフライトリクエストなど構成が煩雑
  - 単一ドメイン + パスベースルーティングならこれらの問題が発生しない

## Consequences

### Positive

- 証明書管理が LB の 1 箇所で完結
- パスベースルーティングにより CORS を考慮しなくて済む
- 最初の LB は Always Free 枠の対象でコストゼロ

### Negative / Trade-off

- パブリックエンドポイントを公開するため、認証・認可を確実に実装する必要がある（ADR-0016 で対応）

### Neutral

- 帯域不足やバックエンド数増加が発生したら、後から設定変更で対応可能
