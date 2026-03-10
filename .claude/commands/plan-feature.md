# plan-feature

Plan and build a full-stack feature by combining multi-agent codebase exploration with high-quality frontend design.

## Usage

`/project:plan-feature <FEATURE_DESCRIPTION>`

## Context

- Feature description: $ARGUMENTS
- Read through CLAUDE.md before every action, every single time.
- This project uses Rails 8.x with server-side rendering, Stimulus, Turbo, and Tailwind CSS.
- All commands run inside the devcontainer via the devcontainer skill.

## Your Role

You are the Feature Lead coordinating specialist agents and two design phases. You synthesize parallel exploration into a unified architecture, then drive it through frontend design and integration.

## Process

### Phase 1: Parallel Codebase Exploration

Launch three explorer agents in parallel using the Agent tool in a single message. Each agent uses the `feature-dev:code-explorer` subagent type. Pass each agent the feature description and tell it to focus on its specific domain.

#### Agent 1: Data and Model Explorer

Prompt this agent to explore the data layer relevant to the feature:

- Identify which models are involved (existing and new ones needed)
- Map associations, validations, scopes, and callbacks on those models
- Read the database schema (`db/schema.rb`) for relevant tables
- Identify concerns, delegations, and domain groupings
- Check for existing service objects that handle related business logic
- Note any Solid Queue jobs related to the domain
- Read `app/models/CLAUDE.md` for model conventions

Output: list of relevant models with their associations, key methods, and gaps that need to be filled.

#### Agent 2: Controller and Route Explorer

Prompt this agent to explore the request handling layer:

- Identify existing controllers and actions in the relevant namespace
- Read `config/routes.rb` for current routing structure
- Check authorization patterns (before_actions, policy objects)
- Map the controller-to-view wiring for related features
- Identify Turbo Frame and Turbo Stream response patterns in use
- Note any Action Cable channels or broadcast patterns
- Read `app/controllers/CLAUDE.md` for controller conventions

Output: list of relevant controllers/routes, auth patterns, Turbo patterns, and what new routes/actions are needed.

#### Agent 3: UI and Frontend Explorer

Prompt this agent to explore the frontend layer:

- Find existing view templates and partials in the relevant area
- Identify Stimulus controllers used by related features (read their JS source)
- Map the Tailwind CSS patterns, component styles, and design tokens in use
- Check the application layout and any shared partials (`app/views/shared/`, `app/views/layouts/`)
- Identify Turbo Frame boundaries and how pages compose
- Note any existing helper methods for the relevant views
- Read `app/views/CLAUDE.md` and `app/javascript/controllers/CLAUDE.md`

Output: list of existing UI patterns to reuse, Stimulus controllers, Tailwind conventions, and what new views/components are needed.

### Phase 2: Architecture Synthesis and Design Brief

After all three agents complete, synthesize their findings into a unified architecture:

1. **Merge the exploration results**: Combine model, controller, and UI findings into a single coherent picture. Identify where agent outputs agree, disagree, or have gaps.

2. **Produce the architecture blueprint**:
   - Models to create or modify (with associations and validations)
   - Controllers and actions to add (with authorization)
   - Routes to define (RESTful only)
   - Database migrations needed
   - Service objects or jobs needed
   - Test strategy (which test types for which components)

3. **Prepare the design brief** for frontend work:
   - Key UI components, pages, and user flows
   - Data each view needs (models, associations, computed values)
   - Existing UI patterns, partials, and Stimulus controllers to reuse
   - Tailwind design tokens and component patterns already established
   - Constraints: mobile-responsive requirements, accessibility, Turbo Frame/Stream boundaries

Present the architecture blueprint and design brief to the user for confirmation before proceeding.

### Phase 3: Feature Development (feature-dev)

Invoke `/feature-dev:feature-dev` with the architecture blueprint from Phase 2. This phase implements the backend:

1. Create database migrations.
2. Build or modify models with associations, validations, and business logic.
3. Create controllers with proper authorization and Turbo responses.
4. Add routes (RESTful only).
5. Write tests following TDD (red, green, refactor).

### Phase 4: Frontend Design (frontend-design)

Invoke `/frontend-design` with the design brief from Phase 2. This phase creates the UI:

1. Create distinctive, production-grade view templates and partials.
2. Build any required Stimulus controllers for interactivity.
3. Apply Tailwind CSS with attention to responsive design and visual polish.
4. Ensure all UI integrates with the Turbo architecture from Phase 3.

### Phase 5: Verification

Run verification checks in parallel where possible:

```bash
# In parallel:
.claude/skills/devcontainer/run.sh "bin/rails test"
.claude/skills/devcontainer/run.sh "bundle exec rubocop <changed-files>"
```

If tests fail or RuboCop reports offenses, fix them before proceeding.

Use the playwright-cli skill for visual verification when screenshots would help confirm the design.

## Coordination Rules

- Never skip Phase 1. Parallel exploration produces a richer understanding than a single-pass analysis.
- The architecture blueprint and design brief (Phase 2) are the contracts between phases. Backend and frontend must agree on component boundaries and data flow.
- Follow all project conventions: fat models, skinny controllers (max 5 lines per action), RESTful routes only, Sandi Metz rules, Law of Demeter.
- All new code must have corresponding tests written first (TDD: red, green, refactor).
- Use the devcontainer skill for all Rails/Ruby commands.

## Output Format

After each phase, provide:

1. **Phase Summary** - What was accomplished and key decisions made.
2. **Files Changed** - List of files created or modified with a one-line description of each.
3. **Next Phase Preview** - What the next phase will address.

At completion, provide:

1. **Feature Summary** - Complete description of what was built.
2. **Architecture Decisions** - Key technical choices and why they were made.
3. **Test Coverage** - What tests were written and what they verify.
4. **Follow-up Items** - Anything that needs attention after this feature ships.
