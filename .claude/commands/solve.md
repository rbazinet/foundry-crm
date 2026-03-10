# solve

Multi-agent orchestrator for general-purpose tasks: debugging, refactoring, investigation, migration, performance analysis. For feature development with UI, use `/plan-feature` instead.

## Usage

`/project:solve <TASK_DESCRIPTION>`

## Context

- Task description: $ARGUMENTS
- Read through CLAUDE.md before every action, every single time.

## When to Use This

- Debugging: "figure out why webhook processing is failing"
- Refactoring: "extract the notification logic into a service object"
- Investigation: "why are background jobs backing up"
- Migration: "upgrade from Turbo 7 to Turbo 8"
- Performance: "N+1 queries on the business index page"

For building new features with UI, use `/plan-feature` instead.

## Your Role

You are the Coordinator Agent. You launch specialist sub-agents in parallel waves, synthesize their outputs, identify conflicts, and drive toward a cohesive solution. You think first, then act.

## Process

### Step 1: Frame the Problem

Before launching any agents, think step-by-step:

- What is the core problem or goal?
- What are the unknowns and assumptions?
- What areas of the codebase are likely involved?
- What constraints apply (from CLAUDE.md, project conventions, existing patterns)?

Write down your initial framing. This becomes the brief for Wave 1.

### Step 2: Wave 1 - Architect + Research (parallel)

Launch two agents in parallel using the Agent tool in a single message.

#### Architect Agent

Use subagent type `feature-dev:code-architect`. Prompt it with the task description and your problem framing. Tell it to:

- Analyze the existing codebase to understand relevant patterns and conventions
- Design a high-level approach: which files to create/modify, component interactions, data flow
- Identify risks, trade-offs, and alternative approaches
- Produce a concrete implementation blueprint with specific file paths and changes
- Flag any decisions that need user input

#### Research Agent

Use subagent type `Explore`. Prompt it with the task description and specific questions from your problem framing. Tell it to:

- Search the codebase for precedents (how similar problems were solved before)
- Find relevant patterns in models, controllers, services, and tests
- Identify dependencies and potential conflicts with existing code
- Look for relevant configuration, environment variables, or infrastructure
- Check test patterns for how similar functionality is tested

### Step 3: Synthesize Wave 1

After both agents complete:

1. **Compare outputs**: Where do Architect and Research agree? Where do they conflict?
2. **Resolve conflicts**: If the Architect proposes a pattern that contradicts existing precedent found by Research, prefer the existing pattern unless there's a strong reason to diverge.
3. **Identify gaps**: What questions remain unanswered? What risks weren't addressed?
4. **Produce a unified plan**: Merge the architecture blueprint with research findings into a concrete implementation plan.

If significant gaps remain, launch targeted follow-up agents to fill them before proceeding.

### Step 4: Wave 2 - Implementer + Reviewer (parallel)

Launch two agents in parallel using the Agent tool in a single message. Pass each agent the unified plan from Step 3.

#### Implementer Agent

Use subagent type `general-purpose`. Prompt it with the unified plan and tell it to:

- Implement the changes according to the plan (write actual code, not pseudocode)
- Follow all project conventions (CLAUDE.md): TDD, skinny controllers, Sandi Metz rules, Law of Demeter, RESTful routes
- Write test files first, then implementation (TDD: red, green, refactor)
- Use the devcontainer skill for running tests and RuboCop
- Stop and report if the plan has ambiguities that need resolution

#### Reviewer Agent

Use subagent type `feature-dev:code-reviewer`. Prompt it with the unified plan and tell it to:

- Review the plan for correctness, security, and adherence to project conventions
- Identify edge cases, error scenarios, and boundary conditions
- Propose specific test cases that should be written
- Check that the plan covers authorization, validation, and error handling
- Flag anything that could break existing functionality

### Step 5: Reconcile and Finalize

After Wave 2 completes:

1. **Cross-reference**: Does the implementation address all issues the Reviewer identified? Are there edge cases the Implementer missed?
2. **Apply Reviewer feedback**: Ensure all valid findings are addressed in the final implementation.
3. **Run verification**:
   ```bash
   .claude/skills/devcontainer/run.sh "bin/rails test"
   .claude/skills/devcontainer/run.sh "bundle exec rubocop <changed-files>"
   ```
4. **Iterate if needed**: If tests fail or significant issues were found, launch targeted agents to fix specific problems. Do not re-run the full pipeline unless the approach fundamentally changed.

### Step 6: Final Check

Before presenting the final answer:

- Does the solution actually solve the original problem?
- Are there loose ends or assumptions that weren't validated?
- Does the implementation follow all project conventions?
- What could go wrong in production?
- What follow-up work is needed?

## Output Format

1. **Problem Framing** - The core problem, constraints, and approach.
2. **Analysis** - Key findings from Wave 1, noting where agents agreed/disagreed.
3. **Implementation** - What was changed, files modified, with brief descriptions.
4. **Test Coverage** - Tests written and what they verify.
5. **Follow-up** - Remaining risks or work needed.
