#!/bin/bash
# アプリケーションスタックの起動（冪等・再起動時も実行される）
set -euo pipefail

NAMESPACE="${namespace}"
CONFIG_BUCKET="${config_bucket}"
DB_PASSWORD_SECRET_ID="${db_password_secret_id}"
SESSION_SECRET_ID="${session_secret_id}"
DB_HOST="${db_host}"
REGISTRY="${registry_domain}"
APP_DIR="/opt/tbcamp-app"

# --- 1. compose ファイルを Object Storage から取得 ---
mkdir -p "$APP_DIR"
oci os object get \
  --auth instance_principal \
  --namespace-name "$NAMESPACE" \
  --bucket-name "$CONFIG_BUCKET" \
  --name app/docker-compose.yml \
  --file "$APP_DIR/docker-compose.yml"

# --- 2. シークレットを Vault から取得 ---
# コンテナ自身には OCI の資格情報を持たせない（ADR-0015）。ホストが取得して
# .env に書き出し、compose が env_file で読む。
fetch_secret() {
  oci secrets secret-bundle get \
    --auth instance_principal \
    --secret-id "$1" \
    --query 'data."secret-bundle-content".content' \
    --raw-output | base64 -d
}

DB_PASSWORD=$(fetch_secret "$DB_PASSWORD_SECRET_ID")
SESSION_SECRET=$(fetch_secret "$SESSION_SECRET_ID")

umask 077
{
  printf 'DB_HOST=%s\n' "$DB_HOST"
  printf 'DB_PORT=5432\n'
  printf 'DB_NAME=tbcamp\n'
  printf 'DB_USER=tbcamp\n'
  printf 'DB_PASSWORD=%s\n' "$DB_PASSWORD"
  printf 'SESSION_SECRET=%s\n' "$SESSION_SECRET"
} > "$APP_DIR/.env"
chmod 600 "$APP_DIR/.env"
unset DB_PASSWORD SESSION_SECRET

# --- 3. コンテナ起動 ---
cd "$APP_DIR"

# コンテナレジストリは非公開。固定の資格情報を VM に置かず、
# Instance Principal で短命のベアラートークン（有効 1 時間）を都度取得する。
# raw-request の --query は応答を再び {data, headers, status} で包むため、jq で取り出す
OCIR_TOKEN=$(oci raw-request \
  --auth instance_principal \
  --http-method GET \
  --target-uri "https://$REGISTRY/20180419/docker/token" | jq -r '.data.token')
printf '%s' "$OCIR_TOKEN" | docker login "$REGISTRY" -u BEARER_TOKEN --password-stdin
unset OCIR_TOKEN

docker compose pull
docker logout "$REGISTRY"
docker compose up -d

echo "Bootstrap completed."
