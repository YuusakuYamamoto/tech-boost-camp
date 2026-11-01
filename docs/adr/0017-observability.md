# ADR-0017: 監視・アラートの初期方針

- **Status**: Proposed
- **Date**: 2026-04-25
- **Deciders**: Yusaku

## Context

運用開始時から以下を把握できる状態にしておく必要がある：

- アプリケーションが正常に動作しているか
- インフラリソースに異常がないか
- 想定を超える費用が発生していないか（個人アプリのコスト目標は月数ドル）

最初から精緻な監視・アラート設計を行うコストは規模に見合わない。本格的な監視・ログ分析は運用開始後の状況を見ながら拡充していく。

## Decision

最初の運用フェーズでは、**OCI 標準の Logging / Monitoring サービスを使い、最低限の運用アラートとコストアラートのみ設定する**。

### 設定する最低限のアラート

| アラート | 閾値 | 実装 |
|---|---|---|
| LB のバックエンド異常（実質的な全滅） | 異常バックエンド > 0 が 3 分継続 | Step 11 で実装（`oci_lbaas` / `unhealthyBackendServers`） |
| VM のインフラ起因の停止 | `instance_status` > 0 が 5 分継続 | Step 11 で実装（`oci_compute_infrastructure_health`） |
| 月間予算アラート | 予算（JPY 1500）の 50% / 80% / 100%、すべて実績ベース | Step 11 で実装 |
| PostgreSQL VM のディスク使用率 | 80% 超過 | **Phase 8 へ。標準メトリックでは実装できない**（下記） |
| PostgreSQL コンテナの異常停止 | コンテナの health 失敗 | **Phase 8 へ。標準メトリックなし** |
| OCI API の異常な使用量 | 通常の数倍以上の呼び出し | **Phase 8 へ。実装手段が未特定** |

### ログ取得

LB アクセスログと VM のログ（OS / コンテナ）は **Phase 8 へ送る**。

ログは有効化した時点より前にさかのぼって取得できないため、**本番アプリイメージに差し替える前までに導入する**。

当面、コンテナのログは VM 内に `json-file` ドライバで 10 MB × 3 世代ローテーションされており、ディスクが埋まる懸念はない。

### コスト保護

OCI Budget 機能で本アプリの Compartment に予算（**JPY 1500/月**）を設定する。VM 等の誤った構成、想定外のコスト発生を早期検知する。

- 金額は $10 ではなく **JPY 1500** で設定した。`oci_budget_budget` の `amount` は**顧客のレートカードの通貨における整数**であり、USD 固定ではない。本テナンシーのレートカードが JPY であることは、コンソールの予算作成画面に「予算金額(JPY)」と表示されることで確認した
- **Budget はターゲットのコンパートメントに関わらず、ルートコンパートメントに作成される**。そのため IAM ポリシーも `manage usage-budgets in tenancy` でなければ効かない。`monitoring` は `tbcamp` の外にリソースを作る唯一のモジュールである（出所: https://docs.oracle.com/en-us/iaas/Content/Billing/Concepts/budgetsoverview.htm ）
- アラート閾値は 50 / 80 / 100 の 3 段で、すべて実績（`ACTUAL`）とする。50% にあたる 750 円は、Step 10 後の実績見込み（月換算 約 660 円、未実測）のすぐ上にある。出所不明のブロックストレージ約 147 GB を整理すれば実績はほぼゼロになるが、整理するまでは 50% のアラートがいつ鳴ってもおかしくない水準である。鳴ったときは、まずブロックストレージを疑う

## Alternatives Considered

### Datadog / New Relic 等の商用 SaaS

- **不採用理由**:
  - 個人アプリの規模・コスト目標に対して過剰
  - OCI 標準のサービスで初期要件は満たせる

### 監視は完全に後回し

- **不採用理由**:
  - 異常検知の仕組みなしで運用するのはリスク
  - コストの暴走を防ぐ Budget アラートは特に重要（個人課金のため）

## Consequences

### Positive

- 初期コストを最小化しつつ、最低限の異常検知ができる
- OCI 標準サービスのため、追加の運用負担なし
- Budget アラートで誤設定によるコスト事故を早期検知できる（個人課金保護）

### Negative / Trade-off

- アプリケーション層の詳細な性能監視（APM）は含まれない
- ログの相関分析や可視化は限定的
- 通知先がメールのみ
- PostgreSQL VM のディスク使用率は標準メトリックでは監視できない。`oci_computeagent` が提供するメトリックは `CpuUtilization` / `MemoryUtilization` / `DiskBytesRead` / `DiskBytesWritten` / `DiskIopsRead` / `DiskIopsWritten` / `LoadAverage` / `MemoryAllocationStalls` / `NetworksBytesIn` / `NetworksBytesOut` の 10 個で、**ディスクの空き容量を表すメトリックは存在しない**（出所: https://docs.oracle.com/en-us/iaas/Content/Compute/References/computemetrics.htm ）
  - 監視するには、VM 側から `PostMetricData` でカスタムメトリックを送るか、Management Agent を導入する必要がある
  - PostgreSQL は LB の背後にいないため、外形監視でも代替できない

### Neutral

- Budget 金額は Phase 7 Step 8 以降、一時的に $25 / $40 の二段構えへ改訂されたが、根拠とした NAT Gateway 月額 $22 に裏付けがなく、実績でも課金が発生しなかったため 2026-10-04 に $10 へ戻した。この改訂は本 ADR を更新せず下流ドキュメントのみで行ったことが混乱の原因となった。**金額を変更する場合は本 ADR を正本として更新する**
- 2026-10-10 時点の実績は日額 約 11 円（月換算 約 330 円）で、内訳は Block Storage のみ。Step 9 で追加した Load Balancer・予約パブリック IP・HSM 鍵はいずれも課金ゼロであることを Cost Analysis で確認済み。$10 は実績の約 4.5 倍にあたり、異常検知の閾値として機能する水準のため**据え置く**
- 2026-11-01: Step 11 で Budget を実装する際、金額は $10 相当の **JPY 1500** とした。本テナンシーのレートカードは JPY であり、`amount` はその通貨で指定する（「コスト保護」節を参照）
- 運用開始後、必要性に応じて以下を追加検討する：
  - APM ツール導入
  - 構造化ログと Logging Analytics の活用
  - SLO / SLI の定義
