# ADR-0013: GitHub Actions → OCI 認証に OIDC 連携を採用

- **Status**: Proposed
- **Date**: 2026-04-25
- **Deciders**: Yusaku

## Context

GitHub Actions から OCI に対して `terraform apply` や `oci` CLI 操作を実行するには、OCI への認証情報が必要。選択肢として：

- **OCI API キーを GitHub Secrets に保管**: 古典的な静的シークレット方式
- **OIDC 連携（Workload Identity Federation）**: GitHub の OIDC トークンを OCI 側で短命な UPST に交換する方式

OIDC 連携の方が、長期的な秘密鍵を保管しなくて済むため、セキュリティ面で優れる。

## Decision

**OIDC 連携を採用する**。OCI Identity Domain に Identity Propagation Trust Configuration を設定し、GitHub Actions の OIDC トークンを OCI Service User の UPST に交換する仕組みを構築する。

GitHub Actions 側では、コミュニティ製の Action（例: `gtrevorrow/oci-token-exchange-action`）または独自スクリプトでトークン交換を行う。

手動デプロイ時は、自分の OCI API キー（`~/.oci/config`）で同じ `deploy.sh` が動作するように設計する。

## Alternatives Considered

### OCI API キーを GitHub Secrets に保管

- **不採用理由**:
  - 長期的な秘密鍵を GitHub Secrets に保管するため、漏洩時のリスクが大きい
  - 鍵のローテーション運用が必要

## Consequences

### Positive

- 長期的な秘密鍵を GitHub に保管しなくて済む
- 各 Actions 実行ごとに短命なトークンが発行されるため、漏洩時の被害範囲が限定的
- GitHub Repository / Branch 単位で OCI 側のアクセス制御を細かく設定可能

### Negative / Trade-off

- 初期設定の手数が API キー方式より多い（Identity Domain の設定、Service User 作成、Trust Configuration 等）
- OCI 公式の GitHub Action がまだ存在しないため、コミュニティ製 Action または独自スクリプトに依存する
- OCI Workload Identity Federation 機能自体が比較的新しいため、AWS の同種機能ほどのドキュメント・事例は少ない

### Neutral

- 手動デプロイ時は自分の API キーで認証可能。スクリプトを共通化しているため、OIDC・API キーどちらでも同じ手順でデプロイできる
- 万一 OIDC 連携に問題が発生した場合は、API キー方式へのフォールバックも可能
