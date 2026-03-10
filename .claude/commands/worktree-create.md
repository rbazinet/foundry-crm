# worktree-create

Create a fully isolated development worktree with its own app container, database, and port.

## Usage

`/project:worktree-create <branch-name> [base-branch]`

## Context

- Arguments: $ARGUMENTS

## Process

Run the worktree create script:

```bash
.claude/skills/worktree/create.sh $ARGUMENTS
```

After the worktree is created, report:
1. The branch name
2. The worktree directory path
3. The container name
4. The Rails URL (port)

To run commands in the new worktree, `cd` into the worktree directory first. The devcontainer skill auto-detects isolated worktrees and routes commands to the correct container.
