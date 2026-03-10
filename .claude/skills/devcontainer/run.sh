#!/usr/bin/env bash
set -euo pipefail

# Generic devcontainer command runner.
# Detects container name and workspace path from .devcontainer/ config.
#
# Usage: run.sh <command>
# Example: run.sh "bin/rails test"

if [ $# -eq 0 ]; then
  echo "Usage: $0 <command>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/detect.sh"

exec docker exec -u "$REMOTE_USER" -w "$WORKSPACE" "$CONTAINER" bash -ic "$1"
