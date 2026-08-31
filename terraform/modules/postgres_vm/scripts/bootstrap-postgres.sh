#!/bin/bash
# PostgreSQL スタックの起動（冪等・再起動時も実行される）
set -euo pipefail

NAMESPACE="${namespace}"
CONFIG_BUCKET="${config_bucket}"
SECRET_ID="${secret_id}"
APP_DIR="/opt/postgres"
DEVICE="/dev/oracleoci/oraclevdb"

# --- 1. ブロックボリュームのアタッチを待つ ---
echo "Waiting for block volume..."
for i in $(seq 1 30); do
  if [ -e "$DEVICE" ]; then
    echo "Block volume detected."
    break
  fi
  sleep 10
done

if [ ! -e "$DEVICE" ]; then
  echo "ERROR: block volume did not appear within 300s" >&2
  exit 1
fi

/opt/scripts/setup-disk.sh

# --- 2. compose ファイルを Object Storage から取得 ---
mkdir -p "$APP_DIR"
oci os object get \
  --auth instance_principal \
  --namespace-name "$NAMESPACE" \
  --bucket-name "$CONFIG_BUCKET" \
  --name postgres/docker-compose.yml \
  --file "$APP_DIR/docker-compose.yml"

# --- 3. DB パスワードを Vault から取得 ---
PASSWORD=$(oci secrets secret-bundle get \
  --auth instance_principal \
  --secret-id "$SECRET_ID" \
  --query 'data."secret-bundle-content".content' \
  --raw-output | base64 -d)

umask 077
printf 'POSTGRES_PASSWORD=%s\n' "$PASSWORD" > "$APP_DIR/.env"
chmod 600 "$APP_DIR/.env"
unset PASSWORD

# --- 4. コンテナ起動 ---
cd "$APP_DIR"
docker compose pull
docker compose up -d

echo "Bootstrap completed."
