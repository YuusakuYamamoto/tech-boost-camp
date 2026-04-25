# ADR-0008: コンテナレジストリに OCIR を採用

- **Status**: Proposed
- **Date**: 2026-04-25
- **Deciders**: Yusaku

## Context

ビルドした Docker イメージを保管・配布するコンテナレジストリが必要。選択肢として：

- **OCIR（OCI Container Registry）**: OCI ネイティブのレジストリ
- **GHCR（GitHub Container Registry）**: GitHub 内蔵のレジストリ
- **Docker Hub**: パブリックレジストリ

Container Instances がイメージを pull する際の認証・ネットワーク経路、egress コスト、CI/CD（GitHub Actions）からの push 容易性が判断軸となる。

## Decision

**OCIR** を採用する。リポジトリは Terraform で管理し、各アプリ（frontend / backend）ごとに別リポジトリとする。  
保管領域の節約のため、リテンションポリシー（古いイメージの自動削除）も設定する。

## Alternatives Considered

### GHCR（GitHub Container Registry）

- **不採用理由**:
  - GitHub Actions からの push は容易だが、Container Instances からの pull に GitHub PAT を Vault 経由で取得する一手間が必要
  - リージョン外からの pull となり、初回 pull 時に遅延が発生する可能性
  - egress 経路が外部インターネットになり、ネットワーク信頼性の観点でも OCIR が優位

### Docker Hub

- **不採用理由**:
  - パブリックネットワーク経由で pull 帯域がベストエフォート
  - 無料プランの pull rate limit に当たるリスク

## Consequences

### Positive

- Container Instances からの pull は同一クラウド内で完結し、Service Gateway 経由でネットワーク経路も短い
- egress 転送料金がかからない
- リソースプリンシパル（インスタンスプリンシパル）認証が利用可能で、長期トークンを別管理する必要がない
- レジストリサービス自体は無料、保管料金も Object Storage Standard 相当（実質無視できる規模）

### Negative / Trade-off

- GitHub Actions からの push には OCI 認証情報が必要（OIDC 連携で対応、ADR-0013 参照）

### Neutral

- リテンションポリシーは「直近 N バージョンを保持」程度の素朴な設定から開始し、運用しながら調整する
