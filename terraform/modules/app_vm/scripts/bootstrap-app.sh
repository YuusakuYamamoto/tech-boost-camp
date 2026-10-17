#!/bin/bash
# アプリケーションスタックの起動（冪等・再起動時も実行される）
set -euo pipefail

NAMESPACE="${namespace}"
CONFIG_BUCKET="${config_bucket}"
DB_PASSWORD_SECRET_ID="${db_password_secret_id}"
SESSION_SECRET_ID="${session_secret_id}"
DB_HOST="${db_host}"
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
docker compose pull
docker compose up -d

echo "Bootstrap completed."
