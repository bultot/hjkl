#!/usr/bin/env bash
set -euo pipefail

# Build the CheatCore Swift package. The App/ target needs Xcode signing and is
# out of scope for CI.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root/CheatCore"
swift build