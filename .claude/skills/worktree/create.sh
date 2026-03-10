#!/usr/bin/env bash
set -euo pipefail

# Creates an isolated git worktree with its own app container, database, and port.
# Project-agnostic: reads all config from .devcontainer/ files.
# Usage: create.sh <branch-name> [base-branch]

BRANCH="${1:?Usage: create.sh <branch-name> [base-branch]}"
BASE="${2:-HEAD}"

# Resolve project root (works from inside worktrees too)
_git_common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
if [ -n "$_git_common" ] && [ "$_git_common" != ".git" ]; then
  PROJECT_ROOT="$(dirname "$_git_common")"
else
  PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi

PROJECT_NAME=$(basename "$PROJECT_ROOT")

# --- Read devcontainer config ---

DEVCONTAINER_DIR="$PROJECT_ROOT/.devcontainer"
DEVCONTAINER_JSON="$DEVCONTAINER_DIR/devcontainer.json"

if [ ! -f "$DEVCONTAINER_JSON" ]; then
  echo "Error: No .devcontainer/devcontainer.json found at $PROJECT_ROOT" >&2
  exit 1
fi

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
WORKSPACE="${WORKSPACE//\$\{localWorkspaceFolderBasename\}/$PROJECT_NAME}"
if [ -z "$WORKSPACE" ]; then
  WORKSPACE="/workspaces/$PROJECT_NAME"
fi

# Get compose project name from compose.yaml
COMPOSE_FILE="$DEVCONTAINER_DIR/compose.yaml"
[ ! -f "$COMPOSE_FILE" ] && COMPOSE_FILE="$DEVCONTAINER_DIR/docker-compose.yaml"
[ ! -f "$COMPOSE_FILE" ] && COMPOSE_FILE="$DEVCONTAINER_DIR/docker-compose.yml"

COMPOSE_NAME=$(sed -n "s/^name:\s*[\"']\{0,1\}\([^\"']*\)[\"']\{0,1\}\s*$/\1/p" "$COMPOSE_FILE" 2>/dev/null | head -1 || true)
if [ -z "$COMPOSE_NAME" ]; then
  COMPOSE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g')
fi

# --- Slugify and set paths ---

WT_SLUG=$(echo "$BRANCH" | sed 's|[/._]|-|g' | tr '[:upper:]' '[:lower:]')
WT_DIR="$PROJECT_ROOT/.claude/worktrees/$WT_SLUG"

# Compose project name: normalize main project name to dashes, append -wt-<slug>
WT_PREFIX=$(echo "$COMPOSE_NAME" | sed 's/_/-/g')
COMPOSE_PROJECT="${WT_PREFIX}-wt-${WT_SLUG}"

if [ -d "$WT_DIR" ]; then
  echo "Error: Worktree already exists at $WT_DIR" >&2
  exit 1
fi

# --- Find the running main devcontainer ---

_container_is_running() {
  docker ps --filter "name=^${1}$" --format '{{.Names}}' 2>/dev/null | grep -q .
}

MAIN_CONTAINER="${COMPOSE_NAME}-${SERVICE}-1"
if ! _container_is_running "$MAIN_CONTAINER"; then
  MAIN_CONTAINER="${COMPOSE_NAME}_${SERVICE}_1"
  if ! _container_is_running "$MAIN_CONTAINER"; then
    echo "Error: Main devcontainer is not running. Tried:" >&2
    echo "  ${COMPOSE_NAME}-${SERVICE}-1" >&2
    echo "  ${COMPOSE_NAME}_${SERVICE}_1" >&2
    exit 1
  fi
fi

# Reuse the exact image from the running container (includes devcontainer features)
IMAGE=$(docker inspect --format='{{.Config.Image}}' "$MAIN_CONTAINER" 2>/dev/null || echo "")
if [ -z "$IMAGE" ] || [ "$IMAGE" = "<no value>" ]; then
  IMAGE="${COMPOSE_NAME}-${SERVICE}"
  if ! docker image inspect "$IMAGE" &>/dev/null; then
    echo "Error: Cannot determine container image. Is the devcontainer built?" >&2
    exit 1
  fi
fi

# --- Find an available host port ---

_port_in_use() {
  docker ps --format '{{.Ports}}' 2>/dev/null | grep -q "0.0.0.0:${1}->" && return 0
  ss -tln 2>/dev/null | grep -q ":${1} " && return 0
  return 1
}

RAILS_PORT=3001
while _port_in_use "$RAILS_PORT"; do
  RAILS_PORT=$((RAILS_PORT + 1))
done

# --- Create the git worktree ---

echo "== Creating git worktree =="
mkdir -p "$(dirname "$WT_DIR")"
git worktree add -b "$BRANCH" "$WT_DIR" "$BASE"

# --- Generate an isolated compose stack ---

echo "== Generating compose stack =="
cat > "$WT_DIR/compose.yaml" <<YAML
name: "${COMPOSE_PROJECT}"

services:
  ${SERVICE}:
    image: ${IMAGE}
    volumes:
      - .:${WORKSPACE}:cached
      - ~/.gitconfig:/home/${REMOTE_USER}/.gitconfig:ro
      - ~/.ssh:/home/${REMOTE_USER}/.ssh:ro
      - /var/run/docker.sock:/var/run/docker.sock
    command: sleep infinity
    ports:
      - "${RAILS_PORT}:3000"
    depends_on:
      - selenium
      - postgres
    environment:
      DB_HOST: postgres
      CAPYBARA_SERVER_PORT: "45678"
      SELENIUM_HOST: selenium
      RAILS_ENV: development

  selenium:
    image: selenium/standalone-chromium
    restart: unless-stopped

  postgres:
    image: pgvector/pgvector:pg17
    restart: unless-stopped
    volumes:
      - postgres-data:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres

volumes:
  postgres-data:
YAML

# --- Start the isolated stack ---

echo "== Starting containers =="
docker compose -f "$WT_DIR/compose.yaml" up -d

WT_CONTAINER="${COMPOSE_PROJECT}-${SERVICE}-1"
echo "== Waiting for PostgreSQL =="
for _ in $(seq 1 30); do
  if docker exec "$WT_CONTAINER" bash -c "pg_isready -h postgres -U postgres" &>/dev/null; then
    break
  fi
  sleep 1
done

# --- Prepare the database ---

echo "== Running bin/setup =="
docker exec -u "$REMOTE_USER" -w "$WORKSPACE" "$WT_CONTAINER" bash -ic "bin/setup --skip-server"

echo ""
echo "Worktree created successfully!"
echo "  Branch:    $BRANCH"
echo "  Directory: $WT_DIR"
echo "  Container: $WT_CONTAINER"
echo "  Rails:     http://localhost:$RAILS_PORT"
