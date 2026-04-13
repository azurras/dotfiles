#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -x "$ROOT/bin/dotfiles" ]]; then
  echo "error: missing $ROOT/bin/dotfiles" >&2
  exit 1
fi

exec "$ROOT/bin/dotfiles" bootstrap
