#!/usr/bin/env bash
# Synthetic P3 storage backup drill (development/test only). Does not touch production.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ -f .env.local ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env.local
  set +a
fi

DEST="${1:-tmp/p3_backup_drill_$(date +%Y%m%d%H%M%S)}"
mkdir -p "$DEST"

echo "Running isolated storage recovery test evidence into $DEST"
bin/rails test test/integration/storage_recovery_proof_test.rb

echo "Drill complete. Review test output; ciphertext copies remain under tmp/storage_recovery_proof (cleaned by test)."