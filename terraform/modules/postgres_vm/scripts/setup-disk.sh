#!/bin/bash
# Block volume のフォーマットとマウント（冪等）
set -euo pipefail

DEVICE="/dev/oracleoci/oraclevdb"
MOUNT_POINT="/data"

if ! blkid "$DEVICE" > /dev/null 2>&1; then
  echo "Formatting $DEVICE as xfs..."
  mkfs.xfs "$DEVICE"
else
  echo "$DEVICE is already formatted, skipping."
fi

mkdir -p "$MOUNT_POINT"
if ! grep -q "oraclevdb" /etc/fstab; then
  echo "$DEVICE $MOUNT_POINT xfs defaults,_netdev,nofail 0 2" >> /etc/fstab
  systemctl daemon-reload
fi

mountpoint -q "$MOUNT_POINT" || mount "$MOUNT_POINT"
mkdir -p "$MOUNT_POINT/postgres"
chown -R 999:999 "$MOUNT_POINT/postgres"
echo "Done. Block volume mounted at $MOUNT_POINT"
