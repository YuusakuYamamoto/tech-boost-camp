# ADR-0021: public リポジトリの PR コメントに OCID を出すことを許容する

- **Status**: Proposed
- **Date**: 2026-10-04
- **Deciders**: Yusaku

## Context

`terraform-plan.yml` は `actions/github-script` を使い、`terraform plan` の出力を PR のコメントとして投稿する。plan を品質ゲートとして機能させるための仕組みで、Phase 5 以降運用している。

本リポジトリは public であり、PR のコメントは誰でも閲覧できる。PR #34 の時点で 10 種類以上の OCID がフルで投稿済みになっている。

方針を決めずに運用を続けてきたため、明文化する。

## Decision

**plan 出力に含まれる OCID は許容する。マスクも抑止も行わない。**

判断の根拠:

- OCID は識別子であって認証情報ではない。OCID を知っていても、テナンシーへの認証がなければ操作はできない
- plan 出力から OCID を落とすと、どのリソースが変更対象なのかをレビューで判別できなくなる。品質ゲートとしての plan の価値が落ちる
- 本リポジトリは個人の学習記録として公開することを目的の一つにしている

## Alternatives Considered

### plan 出力をマスクしてから投稿する

- **不採用理由**:
  - レビューの実効性が落ちる
  - マスク漏れのリスクが残り、「マスクしてあるはず」という前提が逆に危険

### PR コメントに投稿せず、Actions のログにのみ残す

- **不採用理由**:
  - public リポジトリでは Actions のログも閲覧可能であり、秘匿の効果がない
  - レビュー時に毎回ログを開く手間だけが増える

### リポジトリを private にする

- **不採用理由**: 公開して学習記録として残すこと自体が目的の一つ

## Consequences

### Positive

- plan の全文をレビューできる状態を維持できる

### Negative / Trade-off

- **本 ADR の判断は OCID に限る。秘密鍵には適用しない。** Step 12 で Let's Encrypt の証明書をインポートする構成にすると、`private_key_pem` が「設定 → state → plan 出力」の経路に入る。state は Object Storage に置かれ非公開だが、PR のコメントは public である
- プロバイダーが `private_key_pem` を sensitive としてマークしているかは**未確認**。Step 12 の着手前に確認し、マークされていなければ本 ADR を更新のうえ、投稿方法を変更する

### Neutral

- OCID 以外の識別子（バケット名、ドメイン名、プライベート IP など）も同様に許容する
- シークレットの値そのものは Vault に置き Terraform で扱わない方針（ADR-0014 / ADR-0015）のため、plan 出力に現れない
