# code-review

Multi-agent code review of local changes without requiring a pull request. Three specialist agents review independently, then findings are cross-referenced and reconciled for higher accuracy.

## Usage

`/project:code-review [scope] [files...]`

## Context

- Arguments: $ARGUMENTS
- Read CLAUDE.md before reviewing.

## Scope

Determine what to review based on arguments:

- No arguments: all changes on the current branch vs `main`
- `--staged`: only staged changes (`git diff --cached`)
- `--uncommitted`: only uncommitted changes (`git diff`)
- Specific file paths: review those files in full (not just diffs)

## Process

### Phase 1: Gather Changes

Collect the changed files and read their full contents (not just diffs). You need the full file context to review properly.

```bash
# Branch diff (default)
git diff --name-only main -- '*.rb' '*.erb' '*.js' '*.yml'

# Staged
git diff --cached --name-only -- '*.rb' '*.erb' '*.js' '*.yml'

# Uncommitted
git diff --name-only -- '*.rb' '*.erb' '*.js' '*.yml'
```

Read every changed file in full. Also read the diff for each file to understand what specifically changed. Group files by type: models, controllers, views, services, tests, JavaScript, config.

### Phase 2: Parallel Specialist Review

Launch three specialist agents in parallel using the Agent tool. Each agent receives the same list of changed files and diffs but reviews through a different lens. Each agent must read the files independently and produce a structured findings list.

**IMPORTANT**: Launch all three agents in a single message so they run concurrently. Each agent should be given the `feature-dev:code-reviewer` subagent type. Pass each agent the full list of changed file paths and the diff output so it can read and review independently.

#### Agent 1: Architecture Reviewer

Prompt the agent to review ONLY for architectural and design issues against this project's standards:

- Skinny controllers: max 5 lines per action, only one object instantiated per action
- Fat models: business logic belongs in models, POROs, or service objects, not controllers or views
- RESTful routes: only 7 standard actions (index, show, new, create, edit, update, destroy), no custom member/collection routes
- Law of Demeter: no train wrecks - never chain through objects you don't own (e.g., `user.account.plan.name`). Use `delegate` or wrapper methods
- Sandi Metz rules: classes <100 lines, methods <5 lines, max 4 parameters (hash options count as one)
- No metaprogramming (`define_method`, `send`, `method_missing`)
- Turbo broadcasts must use `_later` variants
- No `perform_later` inside database transactions
- Stimulus controllers follow naming conventions and connect properly

Tell the agent to output findings as a structured list with: file_path, line_number, title, severity (critical/high/medium), description, suggestion.

#### Agent 2: Security Reviewer

Prompt the agent to review ONLY for security vulnerabilities and authorization issues:

- SQL injection (raw SQL, unsanitized interpolation in queries)
- XSS (unescaped output in ERB via `raw`, `html_safe`, `<%==`)
- Mass assignment (missing or overly permissive `permit` in strong params)
- Missing authorization checks (actions accessible without proper auth)
- CSRF gaps (non-GET requests without proper token handling)
- Unsafe redirects (redirecting to user-supplied URLs without validation)
- Exposed secrets or credentials (hardcoded API keys, tokens, passwords)
- Insecure file handling (path traversal, unrestricted uploads)
- Information disclosure (detailed error messages, stack traces in responses)

Tell the agent to output findings in the same structured format: file_path, line_number, title, severity, description, suggestion.

#### Agent 3: Correctness Reviewer

Prompt the agent to review ONLY for logic errors, bugs, and test coverage:

- Logic errors: off-by-one, incorrect conditionals, wrong operator, nil handling
- Race conditions: time-of-check to time-of-use, concurrent access without locking
- N+1 queries: associations accessed in loops without `includes`/`preload`
- Missing error handling at system boundaries (user input, external API calls, file I/O)
- Edge cases: empty collections, nil values, boundary conditions
- Dead code or unreachable branches
- Test coverage: changed code must have corresponding tests, identify gaps
- Test quality: tests follow Minitest + FactoryBot conventions, no `sleep`, no testing private methods

Tell the agent to output findings in the same structured format: file_path, line_number, title, severity, description, suggestion.

### Phase 3: Automated Checks

Run these in parallel with Phase 2 (or immediately after):

```bash
# RuboCop on changed Ruby files
.claude/skills/devcontainer/run.sh "bundle exec rubocop <changed-rb-files>"

# Run tests related to changed files
.claude/skills/devcontainer/run.sh "bin/rails test <related-test-files>"
```

### Phase 4: Cross-Reference and Reconcile

After all three agents complete, merge their findings:

1. **Deduplicate**: If multiple agents flagged the same file+line or the same underlying issue, merge into a single finding.

2. **Boost confidence**: Issues independently identified by 2+ agents are upgraded:
   - Medium found by 2 agents -> High
   - High found by 2+ agents -> Critical (confirmed)
   - Any issue found by all 3 agents -> Critical (unanimous)

3. **Scrutinize single-agent findings**: Issues found by only one agent:
   - Critical/High from Security agent -> keep as-is (security issues are often missed by other lenses)
   - Critical from any agent -> keep as-is
   - High from one agent only -> keep but mark as "single-reviewer"
   - Medium from one agent only -> include only if the reasoning is compelling, otherwise drop

4. **Filter out noise**: Drop any finding that:
   - Is purely stylistic (RuboCop handles this)
   - Has low confidence from the reporting agent
   - Contradicts another agent's analysis without strong evidence

5. **Add RuboCop and test results** from Phase 3 as separate sections.

## Output Format

```
## Code Review: <branch-name or scope>

### Summary
- Files reviewed: N
- Agents: Architecture, Security, Correctness
- Issues found: N (X critical, Y high, Z medium)
- Cross-referenced: N issues confirmed by multiple agents
- Tests: passing/failing
- RuboCop: clean/N offenses

### Critical Issues
(Issues confirmed by 2+ agents or critical security findings)

#### <file_path>:<line_number> - <short title>
**Severity**: Critical | High | Medium
**Flagged by**: Architecture + Correctness | Security | all three
<description of the issue and why it matters>
**Suggestion**: <how to fix it>

### High-Confidence Issues
(High-severity issues with strong single-agent reasoning)

### Medium Issues
(Context-dependent findings worth considering)

### Test Results
- Tests run: N, Passed: N, Failed: N
- Coverage gaps: <changed files missing tests>

### RuboCop
- Offenses: N (or clean)

### Architecture Notes
- <any structural concerns about the overall change set>
```

If no issues are found, say so and list what was checked across all three agents.
