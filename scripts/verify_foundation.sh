#!/usr/bin/env bash
# Run from a fully scaffolded Rails app root after local DB configuration.
set -uo pipefail

if [[ ! -f Gemfile || ! -f bin/rails ]]; then
  echo 'Run from the generated Rails application root (Gemfile and bin/rails are required).' >&2
  exit 1
fi

FAIL=0
check() {
  local name="$1"; shift
  printf '\n== %s ==\n' "$name"
  if "$@"; then echo "PASS: $name"; else echo "FAIL: $name"; FAIL=1; fi
}

check 'Ruby' ruby -v
check 'Bundler' bundle -v
check 'Rails' bin/rails -v
check 'Database preparation (dev)' bin/rails db:prepare
check 'Rails tests' bin/rails test
check 'Code autoload check' bin/rails zeitwerk:check
check 'Tailwind build' bin/rails tailwindcss:build
if [[ -x bin/rubocop ]]; then check 'RuboCop' bin/rubocop; else echo 'WARN: bin/rubocop unavailable; record reason or install at Phase 3 gate.'; fi
if [[ -x bin/brakeman ]]; then check 'Brakeman' bin/brakeman -q; else echo 'WARN: bin/brakeman unavailable; record reason or install at Phase 3 gate.'; fi
if [[ "$FAIL" -ne 0 ]]; then echo 'Foundation FAIL: resolve failed checks before Phase 2.' >&2; exit 1; fi
echo 'Foundation verification commands passed. Also check browser root, committed lockfile and that secrets are not in Git.'
