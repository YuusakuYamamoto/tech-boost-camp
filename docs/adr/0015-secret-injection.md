# ADR-0015: シークレット注入をエントリポイントスクリプトで行う

- **Status**: Proposed
- **Date**: 2026-04-25
- **Deciders**: Yusaku

## Context

OCI Container Instances には、ECS Fargate の `secrets` フィールドのような「Vault シークレットの OCID を指定すれば自動で環境変数に展開する」機能がない。Vault 連携のネイティブサポートはイメージ pull 認証用に限定されている。

アプリケーション用のシークレットを Container Instance に注入する方式として、以下の選択肢がある：

- **A. デプロイ時に値を取得して環境変数として渡す**: デプロイスクリプトが Vault から値を取得し、Container Instance 作成時に平文の環境変数として設定
- **B. アプリコードが起動時に Vault から取得**: アプリに OCI SDK を導入し、起動時にリソースプリンシパルで Vault API を叩く
- **C. エントリポイントスクリプトが起動時に取得**: コンテナイメージのエントリポイントを、Vault からシークレット取得 → 環境変数設定 → アプリ起動するラッパースクリプトにする

## Decision

**パターン C（エントリポイントスクリプトでの取得）** を採用する。

具体的には：

- 各アプリの Dockerfile に OCI CLI をインストール
- `entrypoint.sh` でリソースプリンシパル認証を有効化（`OCI_CLI_AUTH=resource_principal`）し、必要なシークレットを Vault から取得して環境変数にセット
- 最後に `exec "$@"` で本来のアプリ起動コマンドを実行
- アプリ側のコードは通常の環境変数を読むだけ（クラウド非依存）

リソースプリンシパル認証のために、Container Instances を含む動的グループと、Vault 読み取り権限のポリシーを Terraform で定義する。

## Alternatives Considered

### A. デプロイ時に環境変数として渡す

- **不採用理由**:
  - シークレットの平文値が Container Instance の設定に焼き込まれ、OCI コンソールや API の `describe` 結果に表示される
  - シークレットのローテーション時に Container Instance 自体を再作成する必要がある

### B. アプリコードが起動時に Vault から取得

- **不採用理由**:
  - アプリが OCI 依存になり、別クラウドへの移植時に修正が必要
  - ローカル開発時の挙動と本番の挙動に差分が生じる
  - 新しい依存パッケージ（OCI SDK）が増える

## Consequences

### Positive

- アプリコードはクラウド非依存のまま保てる
- ローカル開発は通常の `.env` ファイルで動作可能
- セキュリティ面ではパターン B と同等
- シークレットローテーション時は、Container Instance を再起動するだけで新しい値が反映される

### Negative / Trade-off

- コンテナイメージに OCI CLI を含めるため、イメージサイズが約 50MB 程度増加
- エントリポイントスクリプトの記述・保守が必要
- 起動時の Vault API 呼び出しが追加されるため、コンテナ起動時間がわずかに伸びる

### Neutral

- 将来 OCI SDK ベースのパターン B に移行する場合も、エントリポイントを差し替えるだけで済む
- ローカル開発時は `entrypoint.sh` を bypass して `--env-file .env.local` で起動する形を取る
