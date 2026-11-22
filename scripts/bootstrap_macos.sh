#!/usr/bin/env bash
# Local macOS preflight only. Read before running. No cloud access, no repository deletion.
set -euo pipefail

if [[ "$(uname -s)" != 'Darwin' ]]; then
  echo 'This script is for macOS. Follow docs/SETUP_AND_BOOTSTRAP.md manually on other operating systems.' >&2
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  echo 'Xcode Command Line Tools missing. Run: xcode-select --install, finish installation, then rerun.' >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo 'Homebrew is missing. Install it from https://brew.sh, then rerun.' >&2
  exit 1
fi

echo 'Installing local prerequisites (mise, libpq, libyaml, openssl, vips).'
brew install mise libpq libyaml openssl@3 vips

export PATH="$(brew --prefix libpq)/bin:$PATH"
# Local project-level mise configuration (no changes to global default Ruby).
mise use --pin --path "${PWD}" ruby@3.4
mise exec -- ruby -v
mise exec -- gem install bundler --no-document
mise exec -- gem install rails -v 8.1.4.1 --no-document
mise exec -- rails -v

echo 'Checking Docker Compose. Docker Desktop is installed/launched separately.'
if ! command -v docker >/dev/null 2>&1; then
  echo 'Docker is missing; install Docker Desktop (or Colima with Docker Compose) and start it before local DB setup.'
elif ! docker info >/dev/null 2>&1; then
  echo 'Docker is installed but its engine is not running; start it before database setup.'
else
  docker compose version
fi

echo 'Prerequisite pass finished. Next: scaffold Rails, set up local PostgreSQL, and run verification. See docs/SETUP_AND_BOOTSTRAP.md.'
