# ADR-0019: DNS は Xserver Domain で管理し、LB には予約パブリック IP を使う

- **Status**: Proposed
- **Date**: 2026-10-04
- **Deciders**: Yusaku

## Context

Phase 7 Step 9 で HTTPS 公開を構成するにあたり、ドメイン名が必要になった。`y12u.com` を Xserver Domain で取得済み。

決める必要があるのは 2 点。

- 名前解決をどこで管理するか（Xserver のネームサーバーを使い続けるか、OCI DNS に移管するか）
- Load Balancer のパブリック IP をどう扱うか（既定のエフェメラル IP か、予約パブリック IP か）

OCI には DNS サービスがあり、ゾーンもレコードも Terraform で管理できる。IaC の一貫性という点では魅力がある。

## Decision

**DNS は Xserver Domain のネームサーバー（`ns1-3.xdomain.ne.jp`）をそのまま使い、A レコードは管理画面で手動登録する。Terraform の管理対象外とする。**

**Load Balancer のパブリック IP は予約パブリック IP（`RESERVED`）を使う。**

2 つは独立した判断ではない。A レコードを手で管理する以上、LB を作り直すたびに IP が変わると手作業が発生する。IP の固定は手動管理の前提条件である。

## Alternatives Considered

### OCI DNS にゾーンを移管し、A レコードも Terraform で管理する

- **不採用理由**:
  - ゾーンの月額とクエリ課金が発生する。本プロジェクトは追加費用ゼロを優先する
  - 個人アプリの規模ではレコードの変更頻度が低く、IaC 化の便益が費用に見合わない
  - 移行自体は後からでも可能。Issue 化して後回しとする

### エフェメラル（既定）のパブリック IP を使う

- **不採用理由**:
  - LB を再作成すると IP が変わり、そのたびに Xserver の管理画面で A レコードを直す必要がある
  - 復旧手順に手作業が挟まるとダウンタイムが伸びる

## Consequences

### Positive

- 追加費用がゼロ。予約パブリック IP についても、Cost Analysis（2026-09-25〜10-09、Usage ビュー）で**該当する SKU 行が存在しない**ことを確認済み
- LB が再作成（replace）されても予約パブリック IP は別リソースとして残るため、同じ IP が引き継がれる。A レコードの修正が不要

### Negative / Trade-off

- A レコードが IaC の外にある。リポジトリだけでは構成の全体像が完結しない
- DNS の変更は常に手作業になる。手順を学びノートに残しておく必要がある
- 予約パブリック IP は `modules/load_balancer/` の管理下にあるため、`terraform destroy` では LB と一緒に削除される。IP を保持したまま作り直したい場合は、destroy ではなく `-replace` で LB だけを置き換える

### Neutral

- OCI DNS への移行は Issue 化して保留する。移行する場合は本 ADR を更新する
- 予約パブリック IP が未アタッチの状態で課金されるかは未確認。常時アタッチして使う前提のため、現時点では影響しない
