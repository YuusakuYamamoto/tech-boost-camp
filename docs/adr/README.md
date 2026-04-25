# Architecture Decision Records (ADR)

本ディレクトリには、個人アプリケーション（Next.js + NestJS + PostgreSQL on OCI、認証付きパブリック、仲間内利用）のインフラ・デプロイに関するアーキテクチャ決定記録（ADR）を格納する。

## ADR 一覧

| #    | タイトル                                                       | Status   |
| ---- | -------------------------------------------------------------- | -------- |
| 0001 | デプロイプラットフォームに OCI Container Instances を採用     | Proposed |
| 0002 | PostgreSQL は VM 上の Docker でセルフホスト運用                | Proposed |
| 0003 | Next.js は SSR 前提で運用する                                  | Proposed |
| 0004 | 単一 VCN によるネットワーク基盤                                | Proposed |
| 0005 | Public Load Balancer による HTTPS 終端とパスベースルーティング | Proposed |
| 0006 | IaC ツールに Terraform を採用、単一環境構成                    | Proposed |
| 0007 | CI/CD プラットフォームに GitHub Actions を採用                 | Proposed |
| 0008 | コンテナレジストリに OCIR を採用                               | Proposed |
| 0009 | CI/CD パイプラインを役割別に分離                               | Proposed |
| 0010 | デプロイトリガに `deployment/{app}` ブランチを採用             | Proposed |
| 0011 | Container Instance 切替方式（パターン A・割り切り型）          | Proposed |
| 0012 | ヘルスチェックを liveness / readiness の 2 段で実装            | Proposed |
| 0013 | GitHub Actions → OCI 認証に OIDC 連携を採用                    | Proposed |
| 0014 | シークレットストレージに OCI Vault を採用                      | Proposed |
| 0015 | シークレット注入をエントリポイントスクリプトで行う             | Proposed |
| 0016 | アプリケーション認証は Google アカウント + allowlist           | Proposed |
| 0017 | 監視・アラートの初期方針                                       | Proposed |
| 0018 | DB VM の OS に Oracle Linux を採用                             | Proposed |

## Status の運用

| Status       | 意味                                  | 扱い                                             |
| ------------ | ------------------------------------- | ------------------------------------------------ |
| `Proposed`   | 提案中。未承認・未適用                | **規約として参照しない**。議論中扱い             |
| `Accepted`   | 承認済み（適用作業中の場合あり）      | 有効。`(移行完了: YYYY-MM-DD)` 等の補記を確認    |
| `Superseded` | 後続 ADR に置き換えられた             | 参照禁止。Supersede 先の ADR に従う              |
| `Deprecated` | 廃止                                  | 参照禁止                                         |

## 前提

- OCI テナンシーは個人用（会社用とは別）
- 環境は単一（dev / prod の分離なし）。検証はローカルで実施
- 利用ユーザーは事前に allowlist 登録した仲間内のみ
- コスト目標: 月数ドル以内
- 外部 API 連携はなし（バッチ処理・Gmail 連携・GenAI 連携などはなし）
