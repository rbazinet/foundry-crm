# worktree-cleanup

Tear down an isolated worktree: stop containers, remove volumes, remove worktree.

## Usage

`/project:worktree-cleanup <worktree-slug> [--delete-branch]`

## Context

- Arguments: $ARGUMENTS

## Process

1. If no worktree slug is provided, list available worktrees:
   ```bash
   ls .claude/worktrees/
   ```
   Ask the user which one to clean up.

2. Confirm with the user before proceeding (this is destructive: removes containers, database volumes, and the worktree).

3. Run the cleanup script:
   ```bash
   .claude/skills/worktree/cleanup.sh $ARGUMENTS
   ```

4. Report what was removed (containers, volumes, worktree, branch if applicable).
