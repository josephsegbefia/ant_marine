#!/usr/bin/env bash
# F4-04B-H1: disposable DB checks for history protection + restricted runtime role.
# Does not touch production. Requires local PostgreSQL and psql.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB_NAME="${H1_VERIFY_DB:-ant_marine_h1_verify_$$}"
OWNER_ROLE="${H1_OWNER_ROLE:-$(whoami)}"
RUNTIME_ROLE="${H1_RUNTIME_ROLE:-ant_marine_h1_runtime_$$}"
PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-5432}"

cleanup() {
  psql -h "$PGHOST" -p "$PGPORT" -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS ${DB_NAME};" >/dev/null 2>&1 || true
  psql -h "$PGHOST" -p "$PGPORT" -d postgres -v ON_ERROR_STOP=1 -c "DROP ROLE IF EXISTS ${RUNTIME_ROLE};" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> Creating disposable database ${DB_NAME}"
psql -h "$PGHOST" -p "$PGPORT" -d postgres -v ON_ERROR_STOP=1 <<SQL
DROP DATABASE IF EXISTS ${DB_NAME};
CREATE DATABASE ${DB_NAME};
SQL

echo "==> Loading db/structure.sql"
psql -h "$PGHOST" -p "$PGPORT" -d "$DB_NAME" -v ON_ERROR_STOP=1 -f "$ROOT/db/structure.sql" >/dev/null

echo "==> Asserting protect functions have no history_bypass branch"
bypass_hits="$(psql -h "$PGHOST" -p "$PGPORT" -d "$DB_NAME" -Atc \
  "SELECT count(*) FROM pg_proc WHERE proname LIKE 'ant_marine%history%' OR (prosrc ILIKE '%history_bypass%' AND proname LIKE 'ant_marine%');")"
if [[ "$bypass_hits" != "0" ]]; then
  echo "FAIL: history_bypass still present in ant_marine functions (hits=${bypass_hits})"
  exit 1
fi

fn_count="$(psql -h "$PGHOST" -p "$PGPORT" -d "$DB_NAME" -Atc \
  "SELECT count(*) FROM pg_proc WHERE proname IN ('ant_marine_quote_revision_protect','ant_marine_quote_line_item_protect','ant_marine_quote_response_protect','ant_marine_reject');")"
if [[ "$fn_count" != "4" ]]; then
  echo "FAIL: expected 4 protect helpers, found ${fn_count}"
  exit 1
fi

trig_count="$(psql -h "$PGHOST" -p "$PGPORT" -d "$DB_NAME" -Atc \
  "SELECT count(*) FROM pg_trigger WHERE tgname IN ('quote_revisions_history_protect','quote_line_items_history_protect','quote_responses_history_protect') AND NOT tgisinternal;")"
if [[ "$trig_count" != "3" ]]; then
  echo "FAIL: expected 3 history triggers, found ${trig_count}"
  exit 1
fi

echo "==> Creating non-owner runtime role ${RUNTIME_ROLE}"
psql -h "$PGHOST" -p "$PGPORT" -d "$DB_NAME" -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${RUNTIME_ROLE}') THEN
    CREATE ROLE ${RUNTIME_ROLE} LOGIN PASSWORD 'h1-runtime-only';
  END IF;
END\$\$;
GRANT CONNECT ON DATABASE ${DB_NAME} TO ${RUNTIME_ROLE};
GRANT USAGE ON SCHEMA public TO ${RUNTIME_ROLE};
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ${RUNTIME_ROLE};
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ${RUNTIME_ROLE};
-- Explicitly withhold ownership / trigger admin / truncate where possible
REVOKE TRUNCATE ON quote_revisions, quote_line_items, quote_responses FROM PUBLIC, ${RUNTIME_ROLE};
SQL

run_as_runtime() {
  local sql="$1"
  PGPASSWORD='h1-runtime-only' psql -h "$PGHOST" -p "$PGPORT" -d "$DB_NAME" -U "$RUNTIME_ROLE" -v ON_ERROR_STOP=1 -c "$sql"
}

echo "==> Runtime must not DISABLE TRIGGER"
if run_as_runtime "ALTER TABLE quote_revisions DISABLE TRIGGER quote_revisions_history_protect;" 2>/tmp/h1_rt_err.txt; then
  echo "FAIL: runtime disabled trigger"
  exit 1
fi
grep -qiE 'must be owner|permission denied|insufficient' /tmp/h1_rt_err.txt

echo "==> Runtime must not DROP FUNCTION"
if run_as_runtime "DROP FUNCTION ant_marine_reject(text);" 2>/tmp/h1_rt_err.txt; then
  echo "FAIL: runtime dropped protect function"
  exit 1
fi
grep -qiE 'must be owner|permission denied|insufficient' /tmp/h1_rt_err.txt

echo "==> Runtime SET history_bypass must not exist as a usable protect gate"
# Setting an arbitrary GUC may succeed; protect functions must ignore it (already asserted absent).
run_as_runtime "SELECT set_config('ant_marine.history_bypass', 'on', true);" >/dev/null || true

echo "==> Runtime TRUNCATE denied"
if run_as_runtime "TRUNCATE quote_responses;" 2>/tmp/h1_rt_err.txt; then
  echo "FAIL: runtime truncated quote_responses"
  exit 1
fi
grep -qiE 'permission denied|must be owner|insufficient' /tmp/h1_rt_err.txt

echo "PASS: structure.sql restore + restricted runtime privilege boundary"
