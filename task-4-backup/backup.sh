#!/usr/bin/env bash

set -Eeuo pipefail

log() {
  printf '[%s] %s\n' "$1" "$2"
}

fail() {
  log ERROR "$1"
  exit 1
}

for command_name in mysqldump gzip aws mktemp stat; do
  command -v "$command_name" >/dev/null 2>&1 || fail "Required command is missing: $command_name"
done

MYSQL_HOST="${MYSQL_HOST:-}"
MYSQL_DATABASE="${MYSQL_DATABASE:-}"
MYSQL_USER="${MYSQL_USER:-}"
S3_BUCKET="${S3_BUCKET:-}"
AWS_REGION="${AWS_REGION:-}"

required_variables=(MYSQL_HOST MYSQL_DATABASE MYSQL_USER S3_BUCKET AWS_REGION)

for variable_name in "${required_variables[@]}"; do
  [[ -n "${!variable_name:-}" ]] || fail "Required environment variable is not set: $variable_name"
done

[[ "$MYSQL_DATABASE" =~ ^[A-Za-z0-9_]+$ ]] || fail 'MYSQL_DATABASE may contain only letters, numbers, and underscores'
[[ "$S3_BUCKET" != s3://* ]] || fail 'S3_BUCKET must contain only the bucket name, without s3://'

MYSQL_PORT="${MYSQL_PORT:-3306}"
S3_PREFIX="${S3_PREFIX:-mysql-backups}"

[[ "$MYSQL_PORT" =~ ^[0-9]+$ ]] || fail 'MYSQL_PORT must be numeric'
((MYSQL_PORT >= 1 && MYSQL_PORT <= 65535)) || fail 'MYSQL_PORT must be between 1 and 65535'

if [[ -n "${MYSQL_DEFAULTS_FILE:-}" && ! -r "$MYSQL_DEFAULTS_FILE" ]]; then
  fail 'MYSQL_DEFAULTS_FILE is not readable'
fi

umask 077
work_directory="$(mktemp -d "${TMPDIR:-/tmp}/mysql-backup.XXXXXX")"

cleanup() {
  if [[ -n "${work_directory:-}" && -d "$work_directory" ]]; then
    rm -rf -- "$work_directory"
  fi
}

trap cleanup EXIT

backup_timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
backup_filename="${MYSQL_DATABASE}_${backup_timestamp}.sql.gz"
backup_path="${work_directory}/${backup_filename}"
s3_key="${S3_PREFIX%/}/${backup_filename}"

dump_command=(mysqldump)

if [[ -n "${MYSQL_DEFAULTS_FILE:-}" ]]; then
  dump_command+=("--defaults-extra-file=${MYSQL_DEFAULTS_FILE}")
fi

dump_command+=(
  --protocol=tcp
  "--host=${MYSQL_HOST}"
  "--port=${MYSQL_PORT}"
  "--user=${MYSQL_USER}"
  --single-transaction
  --quick
  --skip-lock-tables
  --no-tablespaces
  --databases
  "$MYSQL_DATABASE"
)

log INFO 'Creating compressed MySQL backup'

if ! "${dump_command[@]}" | gzip -c >"$backup_path"; then
  fail 'mysqldump or gzip failed'
fi

[[ -s "$backup_path" ]] || fail 'Backup archive is empty'
gzip -t "$backup_path" || fail 'Backup archive failed gzip validation'

local_size="$(stat -c '%s' "$backup_path")"
log INFO 'Backup archive created and validated'
log INFO 'Uploading backup archive to S3'

if ! aws s3 cp "$backup_path" "s3://${S3_BUCKET}/${s3_key}" \
  --region "$AWS_REGION" \
  --sse AES256 \
  --only-show-errors \
  --no-progress; then
  fail 'S3 upload failed'
fi

if ! remote_size="$(aws s3api head-object \
  --bucket "$S3_BUCKET" \
  --key "$s3_key" \
  --region "$AWS_REGION" \
  --query ContentLength \
  --output text)"; then
  fail 'S3 upload verification failed'
fi

[[ "$remote_size" == "$local_size" ]] || fail 'Uploaded object size does not match the local archive'

log INFO 'S3 upload verified'
log INFO 'Backup completed successfully'
