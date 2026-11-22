#!/usr/bin/env bash
# Verifies Solid Queue worker processing (development). Exits non-zero on failure.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ -f .env.local ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env.local
  set +a
fi

if [ -z "${ANT_MARINE_DB_PASSWORD:-}" ]; then
  echo "ANT_MARINE_DB_PASSWORD required (see .env.example)" >&2
  exit 1
fi

export SOLID_QUEUE_SUPERVISOR_MODE="${SOLID_QUEUE_SUPERVISOR_MODE:-async}"
unset RUBY_DEBUG_OPEN RUBY_DEBUG_LAZY

LOG="$(mktemp -t ant_marine_sq_runtime)"
mise exec -- env RUBY_DEBUG_OPEN= RUBY_DEBUG_LAZY= bin/jobs start >>"$LOG" 2>&1 &
WPID=$!
cleanup() {
  kill -INT "$WPID" 2>/dev/null || true
  sleep 2
  kill -9 "$WPID" 2>/dev/null || true
}
trap cleanup EXIT

sleep 6
if ! ps -p "$WPID" >/dev/null 2>&1; then
  echo "Worker exited before smoke checks. Log tail:" >&2
  tail -30 "$LOG" >&2
  exit 1
fi

OK=0
for _run in 1 2 3; do
  ref=$(mise exec -- bundle exec rails runner "t=SecureRandom.hex(6); Infrastructure::WorkerSmokeJob.perform_later(t); puts t")
  verified=0
  for _ in $(seq 1 25); do
    if mise exec -- bundle exec rails runner "
      abort 'missing' unless AuditEvent.exists?(event_type: 'infrastructure.worker_smoke', metadata: { smoke_ref: '$ref', source: 'solid_queue' })
      j = SolidQueue::Job.order(id: :desc).find_by(class_name: 'Infrastructure::WorkerSmokeJob')
      abort 'unfinished' unless j&.finished_at
      puts 'ok'
    " 2>/dev/null | grep -q ok; then
      verified=1
      break
    fi
    sleep 1
  done
  if [ "$verified" -eq 1 ]; then
    OK=$((OK + 1))
  fi
done

if grep -q "Segmentation fault" "$LOG" 2>/dev/null; then
  echo "Segfault detected in worker log" >&2
  exit 1
fi

if [ "$OK" -lt 3 ]; then
  echo "Only $OK/3 smoke jobs verified" >&2
  tail -25 "$LOG" >&2
  exit 1
fi

echo "Solid Queue runtime: $OK/3 Infrastructure::WorkerSmokeJob finished (real adapter, audit trail)"