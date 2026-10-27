#!/usr/bin/env bash
# Verifies the database users created by scripts/create-db-users.sql against a database that
# already has the energia-api schema (alembic upgrade head). Used by the "database-permissions"
# job in .github/workflows/ci.yml; it can also be run against a local Postgres.
#
# Environment: PGHOST, PGPORT, PGDATABASE, ADMIN_USER and ADMIN_PASSWORD. The passwords of the two
# application users are generated here.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
export PGHOST="${PGHOST:-localhost}" PGPORT="${PGPORT:-5432}" PGDATABASE="${PGDATABASE:-energia}"
ADMIN_USER="${ADMIN_USER:-postgres}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-postgres}"
USERS_SQL="${USERS_SQL:-$DIR/../create-db-users.sql}"
API_PASSWORD="api-$(date +%s%N)"
DATA_PASSWORD="data-$(date +%s%N)"

run_as() {
  local user="$1" password="$2"
  shift 2
  PGUSER="$user" PGPASSWORD="$password" psql --no-psqlrc --quiet --set ON_ERROR_STOP=1 "$@"
}

create_users() {
  run_as "$ADMIN_USER" "$ADMIN_PASSWORD" \
    -v api_password="$API_PASSWORD" -v data_password="$DATA_PASSWORD" \
    -f "$USERS_SQL" >/dev/null
}

echo "Creating the database users"
create_users
echo "Reapplying the script (it has to be idempotent)"
create_users

echo "Checking that every table is classified"
run_as "$ADMIN_USER" "$ADMIN_PASSWORD" -f "$DIR/classify.sql"

run_as energia_api "$API_PASSWORD" -f "$DIR/api-writes.sql"
run_as energia_data "$DATA_PASSWORD" -f "$DIR/data-writes.sql"
echo "Database permissions OK"
