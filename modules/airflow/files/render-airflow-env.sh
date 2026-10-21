#!/usr/bin/env bash
set -euo pipefail

source /etc/energia-data.conf

secret() {
  aws secretsmanager get-secret-value --region "$REGION" --secret-id "$1" \
    --query SecretString --output text
}

config="$(aws ssm get-parameter --region "$REGION" --name "$CONFIG_PARAMETER" \
  --query Parameter.Value --output text)"
warehouse="$(secret "$WAREHOUSE_SECRET_ID")"
machine="$(secret "$MACHINE_CLIENT_SECRET_ID")"
airflow="$(secret "$AIRFLOW_SECRET_ID")"

mkdir -p "$(dirname "$ENV_FILE")"
tmp="$(mktemp)"
chmod 600 "$tmp"

{
  echo "ENVIRONMENT=prod"
  echo "AIRFLOW_UID=50000"
  echo "AWS_REGION=$REGION"
  echo "AWS_DEFAULT_REGION=$REGION"
  echo "AWS_ACCOUNT_ID=$(jq -r .aws_account_id <<<"$config")"
  echo "LAKE_BUCKET=$(jq -r .lake_bucket <<<"$config")"
  echo "API_URL=$(jq -r .api_url <<<"$config")"
  echo "COGNITO_TOKEN_URL=$(jq -r .token_url <<<"$machine")"
  echo "DATA_CLIENT_ID=$(jq -r .client_id <<<"$machine")"
  echo "DATA_CLIENT_SECRET=$(jq -r .client_secret <<<"$machine")"
  echo "DATA_CLIENT_SCOPE=$(jq -r .scope <<<"$machine")"
  echo "WAREHOUSE_DSN=$(jq -r .dsn <<<"$warehouse")"
  echo "AIRFLOW_FERNET_KEY=$(jq -r .fernet_key <<<"$airflow")"
  echo "AIRFLOW_JWT_SECRET=$(jq -r .jwt_secret <<<"$airflow")"
  echo "AIRFLOW_ADMIN_USERNAME=$(jq -r .admin_username <<<"$airflow")"
  echo "AIRFLOW_ADMIN_PASSWORD=$(jq -r .admin_password <<<"$airflow")"
} >"$tmp"

chown ec2-user:ec2-user "$tmp"
mv "$tmp" "$ENV_FILE"
echo "Wrote $ENV_FILE"
