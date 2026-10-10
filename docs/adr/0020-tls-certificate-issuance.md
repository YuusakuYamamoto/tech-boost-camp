# ADR-0020: TLS 証明書は内部 CA で開始し、Let's Encrypt へ移行する

- **Status**: Proposed
- **Date**: 2026-10-04
- **Deciders**: Yusaku

## Context

ADR-0005 で Load Balancer での HTTPS 終端を決めたが、証明書をどこから調達し、どう管理するかは未決のままだった。

選択肢は 3 つ。

- OCI Certificates の内部 CA で自己署名の証明書を発行する
- Let's Encrypt で取得した証明書を OCI Certificates にインポートする
- 証明書を手動で作成し、OCID を `terraform.tfvars` で Terraform に渡す

## Decision

**OCI Certificates の内部 CA で開始し、Phase 7 Step 12 で Let's Encrypt へ移行する。証明書関連のリソースはすべて Terraform で管理する。**

### 構成

| リソース | 管理モジュール | 補足 |
| -------- | -------------- | ---- |
| HSM 保護の非対称鍵（RSA 2048） | `modules/vault/` | Certificates サービスの CA は**ソフトウェア保護鍵をサポートしない**ため、Secret 暗号化用の master key は流用できない。選べるのは RSA 2048 / RSA 4096 / ECDSA NIST_P384 のみ |
| 内部 CA | `modules/certificates/` | |
| 証明書 | `modules/certificates/` | |

`modules/load_balancer/` は `certificate_ids`（list、既定 `[]`）で OCID を受け取るだけとし、証明書リソースそのものは持たない。

<!-- Docs: https://docs.oracle.com/en-us/iaas/Content/certificates/managing-certificate-authorities.htm -->

### 世代管理

KMS 鍵・CA・証明書はいずれもスケジュール削除で、削除猶予中は同名で作り直せない。ルート `locals` の `name_suffix`（既定 `01`）をインクリメントし、3 つまとめて世代を揃える。

## Alternatives Considered

### 最初から Let's Encrypt を使う

- **不採用理由**:
  - 取得と自動更新の仕組みを Step 9 の範囲に含めると作業量が膨らむ
  - まず HTTPS が通る状態を作り、証明書の調達方法は切り離して扱うほうが切り分けやすい

### 証明書を手動で作成し、OCID を `terraform.tfvars` で渡す

- **不採用理由**:
  - 証明書のライフサイクルが IaC の外に出る
  - 作り直しの手順が属人化する

## Consequences

### Positive

- HTTPS 終端の構成を Terraform だけで再現できる
- HSM 鍵は key version あたり $0.53 だが最初の 20 version は無料。Cost Analysis（2026-09-25〜10-09）で現状 **1 version** であることを確認済み。`SOFTWARE` 保護の master key はこの SKU で計量されない（2026-10-10 追記）

### Negative / Trade-off

- 内部 CA の証明書はブラウザが信頼しないため警告が出る。一般公開の前に Let's Encrypt への移行が必須

### Neutral（Step 12 への申し送り）

- **既知の問題**: Let's Encrypt が返す証明書チェーンをそのまま OCI にインポートするとトラストチェーンのエラーになる。中間証明書の補完が必要
- **比較のベースライン**（内部 CA 時点）: ルート CA 直下のリーフで中間証明書なし、TLSv1.2、`ECDHE-RSA-AES128-GCM-SHA256`、RSA 2048。切り替え後にチェーンの段数が変わるのが最初の確認ポイント
- DV 証明書は subject に C / O を持てないため、現在の `C = jp` / `O = tech-boost-camp` は消える
- **未確認**: 証明書が更新されてバージョン番号が増えたとき、LB が新しいバージョンを自動配信するのか再適用が必要なのか。Step 12 の自動更新の設計がこれに依存する
- TLS ポリシー（`protocols` / `cipher_suite_name`）は未指定で OCI の既定に任せている。片方だけ指定すると不整合で apply が失敗する
- 秘密鍵が plan 出力に現れないかの確認が必要（ADR-0021 を参照）
