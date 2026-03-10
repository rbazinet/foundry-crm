---
name: worktree
description: Create and manage isolated git worktrees with dedicated app containers and databases. Non-interfering parallel development environments.
allowed-tools: Bash(.claude/skills/worktree/*), Bash(docker compose *), Bash(git worktree *)
---

# Worktree Management

Create fully isolated development environments with their own app containers, databases, and ports.

## Commands

### Create a worktree

```bash
$CLAUDE_PROJECT_DIR/.claude/skills/worktree/create.sh <branch-name> [base-branch]
```

- `branch-name`: Name of the new git branch (required)
- `base-branch`: Branch or commit to base from (default: HEAD)

Creates:
- A git worktree at `.claude/worktrees/<branch-slug>/`
- An isolated Docker Compose stack with its own rails-app, postgres, and selenium containers
- A fresh database prepared via `bin/setup`
- Auto-assigned port for Rails (starting from 3001)

### Clean up a worktree

```bash
$CLAUDE_PROJECT_DIR/.claude/skills/worktree/cleanup.sh <worktree-slug> [--delete-branch]
```

- `worktree-slug`: Directory name under `.claude/worktrees/` (required)
- `--delete-branch`: Also delete the git branch (optional)

Removes the Docker Compose stack (containers + volumes), the git worktree, and optionally the branch.

## Integration with devcontainer skill

The devcontainer skill (`detect.sh`) auto-detects isolated worktree stacks. When you `cd` into an isolated worktree and run commands via the devcontainer skill, they execute in the worktree's own container.

## Examples

```bash
# Create isolated worktree for a feature
.claude/skills/worktree/create.sh feature/new-search main

# Work in it
cd .claude/worktrees/feature-new-search
.claude/skills/devcontainer/run.sh "bin/rails test"

# Clean up when done
.claude/skills/worktree/cleanup.sh feature-new-search --delete-branch
```
