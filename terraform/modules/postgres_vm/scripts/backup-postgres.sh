#!/bin/bash
# PostgreSQL の論理バックアップを Object Storage に保存
set -euo pipefail

NAMESPACE="${namespace}"
BACKUP_BUCKET="${backup_bucket}"
APP_DIR="/opt/postgres"
CONTAINER="tbcamp-postgres"
DB_USER="tbcamp"
DB_NAME="tbcamp"

TS=$(date -u +%Y%m%dT%H%M%SZ)
DUMP_FILE="/tmp/$DB_NAME-$TS.sql.gz"

trap 'rm -f "$DUMP_FILE"' EXIT

PGPASSWORD=$(sed -n 's/^POSTGRES_PASSWORD=//p' "$APP_DIR/.env")

docker exec -e PGPASSWORD="$PGPASSWORD" "$CONTAINER" \
  pg_dump -U "$DB_USER" -d "$DB_NAME" --clean --if-exists \
  | gzip > "$DUMP_FILE"

if [ ! -s "$DUMP_FILE" ]; then
  echo "ERROR: dump file is empty" >&2
  exit 1
fi

oci os object put \
  --auth instance_principal \
  --namespace-name "$NAMESPACE" \
  --bucket-name "$BACKUP_BUCKET" \
  --name "postgres/$DB_NAME-$TS.sql.gz" \
  --file "$DUMP_FILE" \
  --force

echo "Backup uploaded: postgres/$DB_NAME-$TS.sql.gz"
