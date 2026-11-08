#!/bin/bash
# 起動スクリプトを Object Storage から取得して実行する。
# スクリプト本体を cloud-init に埋め込むと、変更のたびに metadata が変わり
# VM が作り直される（ForceNew）。本体をバケットに置くことでそれを避ける。
# サービスが起動するたびに取得し直すため、バケット側の変更は次回の起動から効く。
set -euo pipefail

NAMESPACE="${namespace}"
CONFIG_BUCKET="${config_bucket}"
SCRIPT=/opt/scripts/bootstrap-app.sh

mkdir -p /opt/scripts
oci os object get \
  --auth instance_principal \
  --namespace-name "$NAMESPACE" \
  --bucket-name "$CONFIG_BUCKET" \
  --name app/bootstrap-app.sh \
  --file "$SCRIPT"
chmod 700 "$SCRIPT"

exec "$SCRIPT"
