---
name: devcontainer
description: Run commands inside the Rails devcontainer. Use this whenever you need to run rails, ruby, bundle, or bin/ commands. All application commands MUST run inside the container - never on the host.
allowed-tools: Bash(docker exec:*)
---

# Devcontainer Command Runner

All Rails/Ruby commands must run inside the devcontainer. Never run them directly on the host.

## How It Works

A generic helper script auto-detects the container name and workspace path from `.devcontainer/` config. It works with any project that has a standard devcontainer setup.

## Command Pattern

Use the helper script for all commands:

```bash
$CLAUDE_PROJECT_DIR/.claude/skills/devcontainer/run.sh "<command>"
```

## Common Commands

### Tests

```bash
# all tests
$CLAUDE_PROJECT_DIR/.claude/skills/devcontainer/run.sh "bin/rails test"

# single file
$CLAUDE_PROJECT_DIR/.claude/skills/devcontainer/run.sh "bin/rails test test/models/business_test.rb"

# single test by line
$CLAUDE_PROJECT_DIR/.claude/skills/devcontainer/run.sh "bin/rails test test/models/business_test.rb:42"

# multiple files
$CLAUDE_PROJECT_DIR/.claude/skills/devcontainer/run.sh "bin/rails test test/models/business_test.rb test/services/places_import_service_test.rb"
```

### Linting

```bash
# all files
$CLAUDE_PROJECT_DIR/.claude/skills/devcontainer/run.sh "bundle exec rubocop"

# single file
$CLAUDE_PROJECT_DIR/.claude/skills/devcontainer/run.sh "bundle exec rubocop app/models/business.rb"

# auto-correct
$CLAUDE_PROJECT_DIR/.claude/skills/devcontainer/run.sh "bundle exec rubocop -a"
```

### Database

```bash
$CLAUDE_PROJECT_DIR/.claude/skills/devcontainer/run.sh "bin/rails db:migrate"
$CLAUDE_PROJECT_DIR/.claude/skills/devcontainer/run.sh "bin/rails db:prepare RAILS_ENV=test"
$CLAUDE_PROJECT_DIR/.claude/skills/devcontainer/run.sh "bin/rails db:rollback"
```

### Rails

```bash
$CLAUDE_PROJECT_DIR/.claude/skills/devcontainer/run.sh "bin/rails console"
$CLAUDE_PROJECT_DIR/.claude/skills/devcontainer/run.sh "bin/rails server"
$CLAUDE_PROJECT_DIR/.claude/skills/devcontainer/run.sh "bin/rails routes"
```

### Bundle

```bash
$CLAUDE_PROJECT_DIR/.claude/skills/devcontainer/run.sh "bundle install"
$CLAUDE_PROJECT_DIR/.claude/skills/devcontainer/run.sh "bundle exec <command>"
```

### BWS Credentials (if not loaded)

```bash
$CLAUDE_PROJECT_DIR/.claude/skills/devcontainer/run.sh "source /tmp/bws-env.sh && <command>"
```

## Important Notes

- Always use this script instead of running rails/ruby commands on the host
- Ruby, mise, and BWS credentials are only available inside the container
- File paths are bind-mounted, so edits on host are immediately visible in the container
- The script auto-detects container name and workspace from `.devcontainer/compose.yaml` and `.devcontainer/devcontainer.json`
