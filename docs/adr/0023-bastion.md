# ADR-0023: プライベートサブネットの VM への到達手段として OCI Bastion を採用する

- **Status**: Proposed
- **Date**: 2026-10-20
- **Deciders**: Yusaku

## Context

アプリ VM と DB VM はプライベートサブネットに置かれており、パブリック IP を持たない。Phase 7 Step 10 の時点で、VM の中に入る手段は 3 つあるが、いずれも使えない。

- Cloud Shell からの SSH: FIPS モードが有効なため Ed25519 鍵の署名が作れない。SSH のオプションでは回避できない
- ローカル（WSL2）からの SSH: プライベートサブネットに直接到達できない
- Run Command: プラグインは `RUNNING` だがコマンドが配信されず `EXPIRED` になる。原因は未特定

Step 10 の検証は「起動スクリプトが途中で失敗したら停止する作りなので、外部から 200 が返れば内部の処理も成功している」という方法で通した。これは成功の証明には使えるが、失敗時の切り分けには使えない。

今後、本番イメージへの差し替え、PostgreSQL のリストア手順の確立、`docker-compose.yml` 更新後の反映といった作業が控えており、いずれも VM 内での操作またはログの確認を必要とする。とくに現時点では、compose を更新しても VM に反映させる手段が存在しない。

## Decision

**OCI Bastion を導入し、アプリ VM と DB VM の双方で Bastion プラグインを有効化する。**

<!-- Docs: https://docs.oracle.com/en/solutions/use-bastion-service/index.html -->

- Bastion は `tbcamp` コンパートメントに 1 つ作成し、接続先サブネットはプライベートサブネットとする
- Bastion の名前は英数字のみ受け付けられるため、命名規約 `${app_name}-${role}` の例外として `tbcampbastion` とする
- 接続元の制限（`client_cidr_block_allow_list`）は設けない。利用者の回線が固定 IP ではないため。接続には OCI の認可とセッションごとの SSH 鍵の双方を要するため、素通しにはならない
- 接続先サブネットには、Bastion のプライベートエンドポイントから VM の 22 番ポートへの送信を許可する Security List を 1 つ追加する
- VM 側の ingress は NSG で、Bastion のプライベートエンドポイントの IP アドレスのみに限定する。ただし DB 側の NSG には VCN 全体（`10.0.0.0/16`）からの 22 番を許可する既存ルール（`db_ssh_ingress`）が残っており、これを削除するまで DB については限定が成立しない。削除は Bastion の疎通確認後に別途行う

## Alternatives Considered

### VM の metadata に RSA 鍵を追加する

- **不採用理由**:
  - 鍵の配置を変えるために VM の再作成が必要になる懸念があった
  - Cloud Shell 側の制約の回避にとどまり、ローカルからの到達性の問題は解決しない

### Run Command の原因究明

- **不採用理由**: 原因が特定できておらず、解決までの見通しが立たない。Bastion で代替できるため、調査は任意とする

### パブリックサブネットに踏み台 VM を立てる

- **不採用理由**:
  - A1 の無料枠（合計 4 OCPU / 24 GB）を消費する。現在 2 OCPU / 12 GB を使用しており、残りはアプリの拡張に充てたい
  - 常時公開されるサーバーが 1 台増える

### VM に入らない構成を先に作り込む

- **不採用理由**: ログの外部転送とデプロイの自動取得を先に実装すれば VM に入る必要はなくなるが、その仕組み自体の不具合を VM に入らずに切り分けることになる

## Consequences

### Positive

- 追加費用は発生しない。OCI Bastion は Oracle の価格表で Free と明示されている
- セッションは時間制限付きで、期限が切れると自動的に閉じる。常時接続の経路は残らない

<!-- Docs: https://www.oracle.com/security/cloud-security/bastion/ -->

### Negative / Trade-off

- Bastion のプライベートエンドポイントは NSG に所属できないため、NSG 統一の方針に対する例外として Security List を 1 つ持つことになる。この Security List は送信ルールのみを持ち、ingress は従来どおり NSG で制御する
- Managed SSH セッションでは VM 上のエージェントが OCI の Bastion バックエンドへ接続する。この経路は Service Gateway を通るため、Service Gateway の対象が Oracle Services Network 全体を含んでいる必要がある

<!-- Docs: https://docs.oracle.com/iaas/Content/Bastion/Tasks/connectingtosessions.htm -->

### Neutral

- Bastion は接続先サブネットから IP アドレスを 2 つ消費する。プライベートサブネットは `/24` のため枯渇の懸念はない
