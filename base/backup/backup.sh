#!/bin/sh
set -eu

: "${BACKUP_NAME:?BACKUP_NAME is required}"
: "${BACKUP_ROOT:=/backups}"
: "${BACKUP_RETENTION_DAYS:=7}"

dir="$BACKUP_ROOT/$BACKUP_NAME"
mkdir -p "$dir"

stamp=$(date -u +%Y%m%dT%H%M%SZ)
file="$dir/$BACKUP_NAME-$stamp.dump"

pg_dump -Fc -f "$file.part"
mv "$file.part" "$file"
echo "backup: wrote $file ($(du -h "$file" | cut -f1))"

find "$dir" -type f -name "$BACKUP_NAME-*.dump" -mmin +$((BACKUP_RETENTION_DAYS * 1440)) -print -delete \
  | sed 's/^/backup: removed /'
find "$dir" -type f -name '*.part' -mmin +60 -delete
