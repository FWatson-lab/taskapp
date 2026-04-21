#!/usr/bin/env bash
# Initialize the database by applying every .sql file in migrations/ in order.
set -euo pipefail

DB="${TASKAPP_DB:-tasks.db}"
MIGRATIONS_DIR="$(dirname "$0")/../migrations"

echo "Applying migrations to $DB"

for f in "$MIGRATIONS_DIR"/*.sql; do
    echo "  -> $(basename "$f")"
    sqlite3 "$DB" < "$f"
done

echo "Done."
