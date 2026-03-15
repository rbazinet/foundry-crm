#!/usr/bin/env bash
# Shared devcontainer detection logic.
# Source this script to get: CONTAINER, REMOTE_USER, WORKSPACE
# Callers must set their own error-handling (e.g. set -euo pipefail).
#
# Usage: source "$(dirname "$0")/../devcontainer/detect.sh"

# In a worktree, --show-toplevel returns the worktree path. The container
# is bound to the main repo, so resolve via --git-common-dir instead.
GIT_COMMON_DIR="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
if [ -n "$GIT_COMMON_DIR" ]; then
  PROJECT_ROOT="$(dirname "$GIT_COMMON_DIR")"
else
  PROJECT_ROOT="$(pwd)"
fi
DEVCONTAINER_DIR="$PROJECT_ROOT/.devcontainer"
DEVCONTAINER_JSON="$DEVCONTAINER_DIR/devcontainer.json"

if [ ! -f "$DEVCONTAINER_JSON" ]; then
  echo "Error: No .devcontainer/devcontainer.json found at $PROJECT_ROOT" >&2
  exit 1
fi

# Strip JSONC comments: first remove full-line comments, then inline comments outside strings
_strip_jsonc() {
  sed -e 's/^\s*\/\/.*//' -e 's/^\(\([^"]*"[^"]*"\)*[^"]*\)\/\/.*/\1/' "$1"
}

_jsonc_get() {
  local file="$1" key="$2" default="${3:-}"
  if command -v jq &>/dev/null; then
    _strip_jsonc "$file" | jq -r --arg key "$key" --arg default "$default" '.[$key] // $default'
  else
    local escaped_key val
    escaped_key=$(printf '%s' "$key" | sed 's/[][\\.^$*+?(){}|]/\\&/g')
    val=$(_strip_jsonc "$file" | sed -n "s/.*\"$escaped_key\"\s*:\s*\"\([^\"]*\)\".*/\1/p" | head -1)
    echo "${val:-$default}"
  fi
}

SERVICE=$(_jsonc_get "$DEVCONTAINER_JSON" "service")
if [ -z "$SERVICE" ]; then
  echo "Error: Could not find 'service' in devcontainer.json" >&2
  exit 1
fi

REMOTE_USER=$(_jsonc_get "$DEVCONTAINER_JSON" "remoteUser" "vscode")

WORKSPACE=$(_jsonc_get "$DEVCONTAINER_JSON" "workspaceFolder")
BASENAME=$(basename "$PROJECT_ROOT")
WORKSPACE="${WORKSPACE//\$\{localWorkspaceFolderBasename\}/$BASENAME}"
if [ -z "$WORKSPACE" ]; then
  WORKSPACE="/workspaces/$BASENAME"
fi

# When running from a worktree, adjust the working directory so commands
# execute against the worktree's branch, not the main repo's.
WORKTREE_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$WORKTREE_DIR" ] && [ "$WORKTREE_DIR" != "$PROJECT_ROOT" ]; then
  # Isolated worktree: sentinel file written by create.sh distinguishes
  # worktree compose files from project compose files on feature branches.
  # No project-root boundary check here -- isolated worktrees are always
  # created by create.sh under .claude/worktrees/, so .claude-worktree
  # is a sufficient signal. Shared worktrees (else branch) still validate.
  if [ -f "$WORKTREE_DIR/.claude-worktree" ] && [ -f "$WORKTREE_DIR/compose.yaml" ]; then
    # create.sh writes `name:` on the first line of compose.yaml; this sed
    # pattern must match that format. If it fails, abort rather than silently
    # falling through to the main container name.
    COMPOSE_FILE="$WORKTREE_DIR/compose.yaml"
    COMPOSE_NAME=$(sed -n "s/^name:\s*[\"']\{0,1\}\([^\"']*\)[\"']\{0,1\}\s*$/\1/p" "$COMPOSE_FILE" | head -1 || true)
    if [ -z "$COMPOSE_NAME" ]; then
      echo "Error: Could not extract compose project name from $COMPOSE_FILE" >&2
      exit 1
    fi
    # WORKSPACE stays as-is from devcontainer.json (no relative path needed)
  else
    # Shared worktree: uses main container with adjusted workspace path
    RELATIVE="${WORKTREE_DIR#$PROJECT_ROOT/}"
    if [ "$RELATIVE" = "$WORKTREE_DIR" ]; then
      echo "Error: worktree at $WORKTREE_DIR is outside the project root ($PROJECT_ROOT)" >&2
      exit 1
    fi
    WORKSPACE="$WORKSPACE/$RELATIVE"
  fi
fi

# Extract compose project name (skip if already set by isolated worktree detection)
if [ -z "${COMPOSE_NAME:-}" ]; then
  COMPOSE_FILE="$DEVCONTAINER_DIR/compose.yaml"
  if [ ! -f "$COMPOSE_FILE" ]; then
    COMPOSE_FILE="$DEVCONTAINER_DIR/docker-compose.yaml"
  fi
  if [ ! -f "$COMPOSE_FILE" ]; then
    COMPOSE_FILE="$DEVCONTAINER_DIR/docker-compose.yml"
  fi
  COMPOSE_NAME=$(sed -n "s/^name:\s*[\"']\{0,1\}\([^\"']*\)[\"']\{0,1\}\s*$/\1/p" "$COMPOSE_FILE" 2>/dev/null | head -1 || true)

  # Fallback: use directory-based compose project name
  if [ -z "$COMPOSE_NAME" ]; then
    COMPOSE_NAME=$(basename "$PROJECT_ROOT" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g')
  fi
fi

# Container name follows Docker Compose convention: {project}_{service}_1 or {project}-{service}-1
CONTAINER="${COMPOSE_NAME}-${SERVICE}-1"

_container_is_running() {
  docker ps --filter "name=^${1}$" --format '{{.Names}}' 2>/dev/null | grep -q .
}

_start_compose_services() {
  echo "Container not running. Starting services via docker compose..." >&2
  docker compose -f "$COMPOSE_FILE" up -d --wait 2>&1 >&2
}

if ! _container_is_running "$CONTAINER"; then
  CONTAINER="${COMPOSE_NAME}_${SERVICE}_1"
  if ! _container_is_running "$CONTAINER"; then
    _start_compose_services
    CONTAINER="${COMPOSE_NAME}-${SERVICE}-1"
    if ! _container_is_running "$CONTAINER"; then
      CONTAINER="${COMPOSE_NAME}_${SERVICE}_1"
      if ! _container_is_running "$CONTAINER"; then
        echo "Error: Could not find running container after starting services. Tried:" >&2
        echo "  ${COMPOSE_NAME}-${SERVICE}-1" >&2
        echo "  ${COMPOSE_NAME}_${SERVICE}_1" >&2
        exit 1
      fi
    fi
  fi
fi

# Clean up intermediate variables; callers get CONTAINER, REMOTE_USER, WORKSPACE.
unset GIT_COMMON_DIR PROJECT_ROOT DEVCONTAINER_DIR DEVCONTAINER_JSON SERVICE
unset BASENAME WORKTREE_DIR RELATIVE COMPOSE_FILE COMPOSE_NAME
