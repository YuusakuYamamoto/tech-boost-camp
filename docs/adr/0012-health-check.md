# ADR-0012: ヘルスチェックを liveness / readiness の 2 段で実装

- **Status**: Proposed
- **Date**: 2026-04-25
- **Deciders**: Yusaku

## Context

LB のヘルスチェックおよびデプロイ時の「新 Container Instance がトラフィックを受けられる状態か」の判定にエンドポイントが必要。実装パターンとして：

- **TCP port check**: ポートが開いていれば OK
- **`/health`（liveness）**: HTTP 応答ができれば OK、依存関係はチェックしない
- **`/ready`（readiness）**: DB 接続など依存関係まで含めてチェック
- **Deep health check**: DB クエリまで含めて全部チェック

LB の常時ヘルスチェックでは、依存先の一時障害が連鎖してアプリ全停止になるリスクがあるため、用途を分けて設計する。

## Decision

各アプリ（Next.js / NestJS）に **2 つのエンドポイントを実装する**：

| エンドポイント | 内容                                                | 用途                                  |
| -------------- | --------------------------------------------------- | ------------------------------------- |
| `/health`      | `{"status":"ok"}` を返す。依存関係チェックなし      | LB の常時ヘルスチェック               |
| `/ready`       | DB 接続など依存関係を含む確認                       | デプロイ時の「トラフィック受入可能」判定 |

両エンドポイントは認証不要（VCN 内の LB からのみアクセス可能）。  
NestJS では `@nestjs/terminus`、Next.js では Route Handler 等で実装する。

## Alternatives Considered

### 単一エンドポイント（`/health` のみ）で全用途をカバー

- **不採用理由**:
  - `/health` を Deep にすると DB 一時障害時に LB が全 Backend を unhealthy 判定し、アプリ全停止に陥るリスク
  - `/health` を浅くすると、デプロイ時の readiness 判定が不十分

### TCP port check のみ

- **不採用理由**: HTTP 応答できることまでは確認できない（プロセス hang しても TCP は開く）

## Consequences

### Positive

- LB の常時チェックは軽量で、依存障害の連鎖を引き起こさない
- デプロイ時は `/ready` ベースで判定するため、DB 未接続状態のインスタンスにトラフィックが流れない

### Negative / Trade-off

- アプリ実装に 2 エンドポイントが必要（実装コストは小さい）
- 認証なしで叩けるため、内容は最小限に留める

### Neutral

- LB バックエンドセットのヘルスチェック設定では `/health` を指定する
- デプロイスクリプトでは LB の backend-health API をポーリングして判定する（GitHub-hosted runner からはプライベート IP に到達不可）
