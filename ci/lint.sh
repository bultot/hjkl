#!/usr/bin/env bash
set -euo pipefail

# Lint with SwiftLint if it is installed. A missing linter must not fail the
# gate, so we skip cleanly when SwiftLint is absent.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "swiftlint not installed; skipping lint"
  exit 0
fi

cd "$repo_root"
swiftlint lint