#!/usr/bin/env bash
set -euo pipefail

# Cheap sanity check: the CheatCore package resolves and builds.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root/CheatCore"
swift build