#!/usr/bin/env bash
# ANT Marine B0 foundation verification — run from the Rails application root.
set -uo pipefail

if [[ ! -f Gemfile || ! -f bin/rails ]]; then
  echo 'Run from the generated Rails application root (Gemfile and bin/rails are required).' >&2
  exit 1
fi

if [[ -f .env.local ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.local
  set +a
elif [[ -z "${ANT_MARINE_DB_PASSWORD:-}" ]]; then
  echo 'WARN: .env.local not found and ANT_MARINE_DB_PASSWORD is unset; database checks may fail.' >&2
fi

FAIL=0
RUN=( )
if command -v mise >/dev/null 2>&1 && [[ -f mise.toml ]]; then
  RUN=(mise exec --)
fi

check() {
  local name="$1"; shift
  printf '\n== %s ==\n' "$name"
  if "${RUN[@]}" "$@"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    FAIL=1
  fi
}

check 'Ruby' ruby -v
check 'Bundler' bundle -v
check 'Bundle check' bundle check
check 'Rails' bin/rails -v
check 'Database preparation (development)' bin/rails db:prepare
check 'Database preparation (test)' env RAILS_ENV=test bin/rails db:prepare
check 'Rails tests' bin/rails test
check 'Code autoload check' bin/rails zeitwerk:check
check 'Tailwind build' bin/rails tailwindcss:build

if [[ -x bin/rubocop ]]; then
  check 'RuboCop' bin/rubocop
else
  echo 'WARN: bin/rubocop unavailable.'
  FAIL=1
fi

if [[ -x bin/brakeman ]]; then
  check 'Brakeman' bin/brakeman -q
else
  echo 'WARN: bin/brakeman unavailable.'
  FAIL=1
fi

if [[ -x bin/bundler-audit ]]; then
  check 'Bundler audit' bin/bundler-audit check
else
  echo 'WARN: bin/bundler-audit unavailable.'
  FAIL=1
fi

if [[ "$FAIL" -ne 0 ]]; then
  echo 'Foundation FAIL: resolve failed checks before Phase 2.' >&2
  exit 1
fi

echo 'Foundation verification passed. Confirm PostgreSQL container health, browser root if needed, and that secrets are not in Git.'