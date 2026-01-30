#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Installing dependencies ==="
"$SCRIPT_DIR/install-deps.sh"

echo "=== Installing config ==="
"$SCRIPT_DIR/install-config.sh"

echo "Done!"
