#!/usr/bin/env bash
# Creates the local PoC bucket on SeaweedFS S3. Safe to re-run.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENDPOINT="${S3_POC_ENDPOINT:-http://127.0.0.1:8333}"
ACCESS_KEY="${S3_POC_ACCESS_KEY:-ant_marine_s3_poc}"
SECRET_KEY="${S3_POC_SECRET_KEY:-seaweedfs-poc-local-only}"
BUCKET="${S3_POC_BUCKET:-ant-marine-encrypted-poc}"
REGION="${S3_POC_REGION:-us-east-1}"

if command -v aws >/dev/null 2>&1; then
  export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
  export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
  export AWS_DEFAULT_REGION="$REGION"
  aws --endpoint-url "$ENDPOINT" s3 mb "s3://${BUCKET}" 2>/dev/null || true
  echo "S3 PoC bucket ready: ${BUCKET} @ ${ENDPOINT}"
  exit 0
fi

mise exec -- bundle exec rails runner "
  client = Aws::S3::Client.new(
    endpoint: '${ENDPOINT}',
    access_key_id: '${ACCESS_KEY}',
    secret_access_key: '${SECRET_KEY}',
    region: '${REGION}',
    force_path_style: true
  )
  begin
    client.create_bucket(bucket: '${BUCKET}')
  rescue Aws::S3::Errors::BucketAlreadyOwnedByYou, Aws::S3::Errors::BucketAlreadyExists
  end
  puts 'S3 PoC bucket ready: ${BUCKET} @ ${ENDPOINT}'
"