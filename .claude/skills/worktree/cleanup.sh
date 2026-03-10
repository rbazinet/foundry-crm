#!/usr/bin/env bash
set -euo pipefail

# Tears down an isolated worktree: stops containers, removes volumes, removes worktree.
# Usage: cleanup.sh <worktree-slug> [--delete-branch]

WT_SLUG="${1:-}"
DELETE_BRANCH=false

if [ -z "$WT_SLUG" ]; then
  echo "Usage: cleanup.sh <worktree-slug> [--delete-branch]"
  echo ""
  echo "Available worktrees:"

  _git_common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  if [ -n "$_git_common" ] && [ "$_git_common" != ".git" ]; then
    _project_root="$(dirname "$_git_common")"
  else
    _project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  fi

  ls "$_project_root/.claude/worktrees/" 2>/dev/null || echo "  (none)"
  exit 1
fi

[[ "${2:-}" == "--delete-branch" ]] && DELETE_BRANCH=true

# Resolve project root
_git_common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
if [ -n "$_git_common" ] && [ "$_git_common" != ".git" ]; then
  PROJECT_ROOT="$(dirname "$_git_common")"
else
  PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi

WT_DIR="$PROJECT_ROOT/.claude/worktrees/$WT_SLUG"

if [ ! -d "$WT_DIR" ]; then
  echo "Error: Worktree not found at $WT_DIR" >&2
  echo ""
  echo "Available worktrees:"
  ls "$PROJECT_ROOT/.claude/worktrees/" 2>/dev/null || echo "  (none)"
  exit 1
fi

# Capture branch name before removing worktree
BRANCH=$(git -C "$WT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# Tear down Docker Compose stack and volumes
COMPOSE_FILE="$WT_DIR/compose.yaml"
if [ -f "$COMPOSE_FILE" ]; then
  echo "== Stopping containers and removing volumes =="
  docker compose -f "$COMPOSE_FILE" down -v --remove-orphans 2>/dev/null || true
fi

# Remove git worktree
echo "== Removing git worktree =="
git worktree remove --force "$WT_DIR" 2>/dev/null || rm -rf "$WT_DIR"

# Prune stale worktree references
git worktree prune

# Optionally delete the branch
if $DELETE_BRANCH && [ -n "$BRANCH" ] && [ "$BRANCH" != "main" ] && [ "$BRANCH" != "HEAD" ]; then
  echo "== Deleting branch: $BRANCH =="
  git branch -D "$BRANCH" 2>/dev/null || true
fi

echo ""
echo "Cleanup complete: $WT_SLUG"
