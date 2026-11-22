#!/usr/bin/env sh
# Scans a host tempfile by copying into the isolated ClamAV PoC container.
set -eu
FILE="${1:?file path required}"
CONTAINER="${CLAMAV_POC_CONTAINER:-ant_marine_clamav_poc}"
REMOTE="/tmp/ant-marine-scan-$$"
docker cp "$FILE" "${CONTAINER}:${REMOTE}"
docker exec "$CONTAINER" clamdscan "${REMOTE}"
docker exec "$CONTAINER" rm -f "${REMOTE}"