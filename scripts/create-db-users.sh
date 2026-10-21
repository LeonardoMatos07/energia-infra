#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_PORT="${LOCAL_PORT:-15432}"

tf() { terraform -chdir="$ROOT/envs/prod" output -raw "$@"; }
tfjson() { terraform -chdir="$ROOT/envs/prod" output -json "$@"; }

REGION="$(tfjson cognito | jq -r .region)"
INSTANCE_ID="$(tf airflow_instance_id)"
DB_HOST="$(tfjson database | jq -r .address)"
DB_PORT="$(tfjson database | jq -r .port)"
DB_NAME="$(tfjson database | jq -r .name)"
SECRETS="$(tfjson secrets)"

secret() {
  aws secretsmanager get-secret-value --region "$REGION" --secret-id "$1" \
    --query SecretString --output text
}

master="$(secret "$(jq -r .rds_master <<<"$SECRETS")")"
api_password="$(secret "$(jq -r .api_database <<<"$SECRETS")" | jq -r .password)"
data_password="$(secret "$(jq -r .data_warehouse <<<"$SECRETS")" | jq -r .password)"

echo "Opening port forward localhost:$LOCAL_PORT -> $DB_HOST:$DB_PORT via $INSTANCE_ID"
aws ssm start-session --region "$REGION" --target "$INSTANCE_ID" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "host=$DB_HOST,portNumber=$DB_PORT,localPortNumber=$LOCAL_PORT" >/dev/null &
tunnel_pid=$!
trap 'kill "$tunnel_pid" 2>/dev/null || true' EXIT
sleep 5

PGPASSWORD="$(jq -r .password <<<"$master")" PGSSLMODE=require psql \
  --host 127.0.0.1 --port "$LOCAL_PORT" \
  --username "$(jq -r .username <<<"$master")" --dbname "$DB_NAME" \
  -v api_password="$api_password" -v data_password="$data_password" \
  -f "$ROOT/scripts/create-db-users.sql"

echo "Done."
