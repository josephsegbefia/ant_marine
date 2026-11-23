#!/usr/bin/env sh
# Host ClamAV scan for development PoC (Homebrew: brew install clamav && freshclam).
set -eu
FILE="${1:?file path required}"
DB_DIR="${CLAMAV_DATABASE_DIRECTORY:-/opt/homebrew/var/lib/clamav}"
exec clamscan --database="$DB_DIR" --no-summary "$FILE"